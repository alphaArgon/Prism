import Cocoa;

class Application {
    enum Category {
        case any;
        case featured;
        case launchpad;
        case dock;
        case system;
        case deprecating;
    }
    
    struct Identifier: Hashable {
        var domain: String;
        var path: String;
    }
    
    var identifier: Identifier;
    var name: String;
    var displayName: String;
    var accent: Accent = .unset;
    var featureColor: NSColor?;
    var categories = Set<Category>();
    
    init(identifier: Identifier, name: String, displayName: String, accent: Accent) {
        self.identifier = identifier;
        self.name = name;
        self.displayName = displayName;
        self.accent = accent;
    }
    
    init?(path: String) {
        let infoPath = "\(path)/Contents/Info.plist";

        guard
            FileManager.default.fileExists(atPath: infoPath),
            let plist = NSDictionary(contentsOfFile: infoPath),
            (plist.value(forKey: "CFBundleIconFile") ?? plist.value(forKey: "CFBundleIconName") != nil),
            let domain = plist.value(forKey: "CFBundleIdentifier") as? String,
            let bundleName = plist.value(forKey: "CFBundleName") as? String ?? plist.value(forKey: "CFBundleExecutable") as? String
        else {
            return nil;
        }
        
        identifier = .init(domain: domain, path: path);
        name = bundleName;
        accent = Accent(from: domain);
        
        displayName = FileManager.default.displayName(atPath: identifier.path);
        if displayName.hasSuffix(".app") {
            displayName = String(displayName.prefix(displayName.count - 4));
        }
        
        if #available(OSX 10.13, *),
           !Accent.systemAccentIsBinary,
           let featureColorName = plist.value(forKey: "NSAccentColorName") as? String {
            featureColor = NSColor(named: featureColorName, bundle: Bundle(path: path));
        }
        
        if featureColor != nil {
            categories.insert(.featured);
        }
        if path.hasPrefix("/System/Library/") {
            categories.insert(.system);
        }
    }
    
    static func standard() -> (applications: [Application], identifiers: [Category: [Identifier]]) {
        var founded = Self.founded();
        
        let identifiers = [
            Category.dock: Self.dockIdentifiers(),
            Category.launchpad: Self.launchpadIdentifiers()
        ];

        for category_identifier in identifiers {
            check: for identifier in category_identifier.value {
                for application in founded {
                    if application.identifier.domain == identifier.domain {
                        application.categories.insert(category_identifier.key);
                        continue check;
                    }
                }
                if let missedApplication = Application(path: identifier.path) {
                    missedApplication.categories.insert(category_identifier.key);
                    founded.append(missedApplication);
                }
            }
        }
        
        return (
            applications: founded.sorted {
                $0.name < $1.name;
            },
            identifiers: identifiers
        );
    }
    
    static func founded() -> [Application] {
        var applicationURLs = [URL]();
        for directory in Self.applicationDirectories {
            applicationURLs.append(contentsOf: Self.applicationURLs(baseURL: directory));
        }
        return Self.applications(urls: applicationURLs);
    }
    
    static func dockIdentifiers() -> [Identifier] {
        var dockIdentifiers: [Identifier] = [
            .init(domain: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app")
        ];
        
        let ud = UserDefaults(suiteName: "com.apple.dock");
        guard let persistentApps = ud?.array(forKey: "persistent-apps") else {
            return dockIdentifiers;
        }
        
        for persistentApp in persistentApps {
            guard let record = persistentApp as? Dictionary<String, Any>,
                  let tileData = record["tile-data"] as? Dictionary<String, Any>,
                  let domain = tileData["bundle-identifier"] as? String,
                  let bookmark = tileData["book"]
            else {
                continue;
            }
            let cfData = bookmark as! CFData;
            guard let urls = CFURLCreateResourcePropertiesForKeysFromBookmarkData(kCFAllocatorDefault, [kCFURLPathKey] as CFArray, cfData).takeRetainedValue() as? Dictionary<CFString, String>
            else {
                continue;
            }
            dockIdentifiers.append(.init(
                domain: domain,
                path: urls[kCFURLPathKey]!
            ));
        }
        return dockIdentifiers;
    }
    
    static func launchpadIdentifiers() -> [Identifier] {
        guard let darwinUserDirectory = Shell.execute(Shell.getconfPath, arguments: ["DARWIN_USER_DIR"]),
              darwinUserDirectory.contains("/var/folders/")
        else {
            return [];
        }
        
        var launchpadIdentifiers = [Identifier]();
        
        let launchpadPath = darwinUserDirectory.trimmingCharacters(in: .whitespacesAndNewlines) + "com.apple.dock.launchpad/db/db";
        let launchpadAppsTable = SQLite.content(path: launchpadPath, command: "SELECT bookmark, bundleid FROM apps");
        
        for appData in launchpadAppsTable {
            guard let domain = appData["bundleid"] as? String,
                  let bookmark = appData["bookmark"] else {
                continue;
            }
            
            let cfData = bookmark as! CFData;
            guard let urls = CFURLCreateResourcePropertiesForKeysFromBookmarkData(kCFAllocatorDefault, [kCFURLPathKey] as CFArray, cfData).takeRetainedValue() as? Dictionary<CFString, String>
            else {
                continue;
            }
            
            launchpadIdentifiers.append(.init(
                domain: domain,
                path: urls[kCFURLPathKey]!
            ));
        }
        return launchpadIdentifiers;
    }
    
    static func applicationURLs(baseURL url: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: url.path),
              let directoryContents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: .skipsHiddenFiles) else {
            return [];
        };
        
        var result = [URL]();
        
        for file in directoryContents {
            if file.pathExtension != "app", file.path.contains("/Applications") {
                result.append(contentsOf: applicationURLs(baseURL: file));
            } else if file.pathExtension == "app" {
                result.append(file);
            }
        }

        return result;
    }
    
    static func applications(urls: [URL]) -> [Application] {
        var applications = [String: Application]();
        
        for url in urls {
            guard let application = Application(path: url.path) else {
                continue;
            }
            
            if Self.deprecatingDomains.contains(application.identifier.domain) {
                application.categories.insert(.deprecating);
            } else {
                let lowercased = application.name.lowercased();
                for deprecatingKeyword in self.deprecatingKeywords {
                    if lowercased.contains(deprecatingKeyword) {
                        application.categories.insert(.deprecating);
                        break;
                    }
                }
            }
            
            if let add = applications[application.identifier.domain] {
                if application.identifier.path.count(character: "/") < add.identifier.path.count(character: "/") {
                    // choose the one in a less nested folder.
                    applications[application.identifier.domain] = application;
                }
            } else {
                applications[application.identifier.domain] = application;
            }
        }
        
        return Array(applications.values);
    }
    
    static var applicationDirectories: [URL] {
        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "\(NSHomeDirectory())/Applications"),
            URL(fileURLWithPath: "/Developer/Applications"),
            URL(fileURLWithPath: "/Network/Applications"),
            URL(fileURLWithPath: "/Network/Developer/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
            URL(fileURLWithPath: "/Users/Shared/Applications"),
        ];
    }
    
    static var deprecatingDomains = Set(arrayLiteral:
        Bundle.main.bundleIdentifier,
        "com.apple.dock",
        "com.apple.ScreenSaver.Engine",
        "com.apple.weather",
        "com.apple.Spotlight",
        "com.apple.siri.launcher",
        "com.apple.siri",
        "com.apple.ScreenSaver.Engine",
        "com.apple.AppleScriptUtility",
        "com.apple.CalendarFileHandler",
        "com.apple.cloudphotosd",
        "com.apple.VoiceOver",
        "com.apple.ScriptMenuApp",
        "com.apple.JarLauncher",
        "com.apple.JavaWebStart",
        "com.apple.ExpansionSlotUtility",
        "com.apple.DiskImageMounter",
        "com.apple.EscrowSecurityAlert",
        "com.apple.Automator.Automator-Application-Stub",
        "com.apple.AutomatorInstaller",
        "com.apple.FolderActionsDispatcher"
    );
    
    static var deprecatingKeywords = [
        "remove",
        "uninstall",
        "handler",
        "trouble",
        "problem",
        "agent",
        "container",
        "migration",
        "report",
        "uiservice",
        "uiserver",
        "assistant"
    ];
}

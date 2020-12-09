import Cocoa;

enum Accent: Int {
    case unknown = -1;
    case unset = 0;
    
    case graphite = 1;
    case red = 2;
    case orange = 3;
    case yellow = 4;
    case green = 5;
    case blue = 6;
    case purple = 7;
    case pink = 8;
    
    case spaceGray = 9;
    case gold = 10;
    case roseGold = 11;
    case silver = 12;
    
    case classicBlue = 21;
    case classicGraphite = 26;
    
    static var accentNumberOffset = -2;
    static var aquaVariantOffset = -20;
    
    init(accentNumber intValue: Int?) {
        if intValue == nil {
            self = .unset;
        } else {
            self = Self(rawValue: min(intValue! - Self.accentNumberOffset, 13)) ?? .unknown;
        }
    }
    
    init(accentNumberString stringValue: String?) {
        if stringValue == nil {
            self = .unset;
        } else {
            self = Self(accentNumber: Int(stringValue!));
        }
    }
    
    init(aquaVariantNumber intValue: Int?) {
        switch intValue {
        case 1:
            self = .classicBlue;
        case 6:
            self = .classicGraphite;
        case nil:
            self = .unset;
        default:
            self = .unknown;
        }
    }
    
    init(aquaVariantNumberString stringValue: String?) {
        switch stringValue {
        case "1":
            self = .classicBlue;
        case "6":
            self = .classicGraphite;
        case "":
            self = .unset;
        default:
            self = .unknown;
        }
    }
    
    init(from domain: String) {
        let udSuffix = "Preferences/\(domain).plist";
        let udPath = "\(NSHomeDirectory())/Library/\(udSuffix)";
        let udPathInSandbox = "\(NSHomeDirectory())/Library/Containers/\(domain)/Data/Library/\(udSuffix)";
        
        var ud: NSDictionary?;
        
        if FileManager.default.fileExists(atPath: udPathInSandbox) {
            ud = NSDictionary(contentsOfFile: udPathInSandbox);
        } else if FileManager.default.fileExists(atPath: udPath) {
            ud = NSDictionary(contentsOfFile: udPath);
        }
        if ud == nil {
            self = .unset;
            return;
        }
        
        if Self.systemAccentIsBinary {
            self = Self(aquaVariantNumber: ud!.value(forKey: "AppleAquaColorVariant") as? Int);
        } else {
            self = Self(accentNumber: ud!.value(forKey: "AppleAccentColor") as? Int);
        }
    }
    
    static var systemAccentCanBeMulticolored: Bool = {
        if #available(OSX 11.0, *) {
            return true;
        }
        return false;
    }();
    
    static var systemAccentIsBinary: Bool = {
        if #available(OSX 10.14, *) {
            return false;
        }
        return true;
    }();
    
    static func systemColorDidChange() {
        systemAccent = Accent.getSystemAccent();
    }
    
    static var systemAccent = Accent.getSystemAccent();
    
    static func getSystemAccent() -> Accent {
        if Self.systemAccentIsBinary {
            let accent = Accent(aquaVariantNumberString: UserDefaults.standard.string(forKey: "AppleAquaColorVariant"));
            return accent == .unknown ? .unset : accent;
        } else {
            let accent = Accent(accentNumberString: UserDefaults.standard.string(forKey: "AppleAccentColor"));
            return accent == .unknown ? .unset : accent;
        }
    }
    
    static var defaultSystemAccent: Accent = {
        if Self.systemAccentIsBinary {
            return .classicBlue;
        } else {
            return .blue;
        }
    }();
    
    static func set(_ accent: Accent, for application: Application) -> Bool {
        var colorArguments: [String];
        var selectionArguments: [String];
        if accent == .unset {
            selectionArguments = [
                "delete",
                application.identifier.domain,
                "AppleHighlightColor"
            ];
            if Self.systemAccentIsBinary {
                colorArguments = [
                    "delete",
                    application.identifier.domain,
                    "AppleAquaColorVariant"
                ];
            } else {
                colorArguments = [
                    "delete",
                    application.identifier.domain,
                    "AppleAccentColor"
                ];
            }
        } else {
            selectionArguments = [
                "write",
                application.identifier.domain,
                "AppleHighlightColor",
                Self.highlightColor(of: accent)
            ];
            if Self.systemAccentIsBinary {
                colorArguments = [
                    "write",
                    application.identifier.domain,
                    "AppleAquaColorVariant",
                    "-int",
                    String(accent.rawValue + Self.aquaVariantOffset)
                ];
            } else {
                colorArguments = [
                    "write",
                    application.identifier.domain,
                    "AppleAccentColor",
                    "-int",
                    String(accent.rawValue + Self.accentNumberOffset)
                ];
            }
        }
        _ = Shell.execute(Shell.defaultsPath, arguments: selectionArguments);
        return nil != Shell.execute(Shell.defaultsPath, arguments: colorArguments);
    }
    
    static func colorName(of accent: Accent) -> String {
        switch accent {
        case .unset, .unknown:
            return "default";
        case .classicBlue:
            return "blue";
        case .classicGraphite:
            return "graphite";
        case .red:
            return "red";
        case .orange:
            return "orange";
        case .yellow:
            return "yellow";
        case .green:
            return "green";
        case .blue:
            return "blue";
        case .purple:
            return "purple";
        case .pink:
            return "pink";
        case .graphite:
            return "graphite";
        case .spaceGray:
            return "spaceGray";
        case .gold:
            return "gold";
        case .roseGold:
            return "roseGold";
        case .silver:
            return "silver";
        }
    }
    
    static func highlightColor(of accent: Accent) -> String {
        switch accent {
        case .unset, .unknown:
            return "";
        case .classicBlue:
            return "0.000000 0.411765 0.850980";
        case .classicGraphite:
            return "0.847059 0.847059 0.862745";
        case .red:
            return "1.000000 0.733333 0.721569 Red";
        case .orange:
            return "1.000000 0.874510 0.701961 Orange";
        case .yellow:
            return "1.000000 0.937255 0.690196 Yellow";
        case .green:
            return "0.752941 0.964706 0.678431 Green";
        case .blue:
            return "0.698039 0.843137 1.000000 Blue";
        case .purple:
            return "0.968627 0.831373 1.000000 Purple";
        case .pink:
            return "1.000000 0.749020 0.823529 Pink";
        case .graphite:
            return "0.847059 0.847059 0.862745 Graphite";
        case .spaceGray:
            return "0.541176 0.556863 0.588235 Other";
        case .gold:
            return "0.800000 0.639216 0.478431 Other";
        case .roseGold:
            return "0.800000 0.584314 0.560784 Other";
        case .silver:
            return "0.750000 0.750000 0.750000 Other";
        }
    }
    
    static func bestMatches(color: NSColor) -> Accent {
        guard let flatted = NSColor(cgColor: color.cgColor) else {
            return .unset;
        }
        let brightness = flatted.brightnessComponent;
        let hue = flatted.hueComponent;
        
        if abs(flatted.redComponent - brightness) < 0.05,
           abs(flatted.blueComponent - brightness) < 0.05,
           abs(flatted.greenComponent - brightness) < 0.05 {
            return .graphite;
        }
        if (hue > 0.9375 || hue < 0.04166) {
            return .red;
        } else if hue < 0.09375 {
            return .orange;
        } else if hue < 0.20833 {
            return .yellow;
        } else if hue < 0.5 {
            return .green;
        } else if hue < 0.70833 {
            return .blue;
        } else if hue < 0.8125 {
            return .purple;
        } else {
            return .pink;
        }
    }
    
    static var systemColors = [
        Self.red: NSColor.systemRed,
        Self.orange: NSColor.systemOrange,
        Self.yellow: NSColor.systemYellow,
        Self.green: NSColor.systemGreen,
        Self.blue: NSColor.systemBlue,
        Self.purple: NSColor.systemPurple,
        Self.pink: NSColor.systemPink,
        Self.graphite: NSColor.systemGray
    ];
}

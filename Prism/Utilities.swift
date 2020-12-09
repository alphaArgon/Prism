import Cocoa;

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "");
    }
    
    func count(character: Character) -> Int {
        var count = 0;
        for char in self {
            if char == character {
                count += 1;
            }
        }
        return count;
    }
}

class NSLabel: NSTextField {
    init(title: String) {
        super.init(frame: NSRect.zero);
        isEditable = false;
        isBezeled = false;
        drawsBackground = false;
        lineBreakMode = .byTruncatingMiddle;
        usesSingleLineMode = true;
        font = NSFont.systemFont(ofSize: NSFont.systemFontSize);
        textColor = NSColor.labelColor;
        stringValue = title;
    }
    
    required init?(coder: NSCoder) {super.init(coder: coder);}
}

class Shell {
    static let getconfPath = "/usr/bin/getconf";
    static let defaultsPath = "/usr/bin/defaults";
    
    static func execute(_ path: String, arguments: [String] = []) -> String? {
        let process = Process();
        let outputPipe = Pipe();

        process.launchPath = path;
        process.arguments = arguments;
        process.standardOutput = outputPipe;
        process.launch();

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile();
        let output = String(data: data, encoding: String.Encoding.utf8);
        
        process.waitUntilExit();

        if process.terminationStatus != 0 {
            return nil
        }

        return output ?? "";
    }
}

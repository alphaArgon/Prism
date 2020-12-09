import Cocoa;

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var menubarShowAllMenuItem: NSMenuItem!;
    @IBOutlet weak var menubarShowCustomizedMenuItem: NSMenuItem!;
    
    let window = Window();
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.delegate = window;
        window.setFrameAutosaveName(Bundle.main.self.bundleIdentifier! + ".window");
        window.makeKeyAndOrderFront(nil);
        (window.contentViewController as! ViewController).menubarShowAllMenuItem = menubarShowAllMenuItem;
        (window.contentViewController as! ViewController).menubarShowCustomizedMenuItem = menubarShowCustomizedMenuItem;
        if window.frame.minX == 0 && window.frame.minY == 0 {
            window.center();
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ theApplication: NSApplication) -> Bool {
        return true;
    }
}


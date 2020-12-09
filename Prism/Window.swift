import Cocoa;

class Window: NSWindow, NSWindowDelegate {
    init() {
        super.init(
            contentRect: NSRect.zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        );
        
        title = "Prism".localized;
        contentViewController = ViewController();
        minSize = NSSize(width: 384, height: 256);
        backgroundColor = .controlBackgroundColor;
        
        if #available(OSX 10.12, *) {
            tabbingMode = .disallowed;
        }
        
        toolbar = {
            let toolbar = NSToolbar(identifier: "Toolbar");
            toolbar.delegate = contentViewController as? NSToolbarDelegate;
            toolbar.displayMode = .iconOnly;
            toolbar.autosavesConfiguration = false;
            return toolbar;
        }();
        
        
        if #available(OSX 11.0, *) {
            toolbarStyle = .unified;
        } else {
            titleVisibility = .hidden;
        }
    }
    
    override func toggleToolbarShown(_ sender: Any?) {
        if #available(OSX 11.0, *) {
            super.toggleToolbarShown(sender);
            return;
        }
        guard (toolbar != nil) else {
            return;
        }
        if toolbar!.isVisible {
            toolbar!.isVisible = false;
            titleVisibility = .visible;
        } else {
            toolbar!.isVisible = true;
            titleVisibility = .hidden;
        }
    }
}

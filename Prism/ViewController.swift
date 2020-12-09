import Cocoa;

private extension NSToolbarItem.Identifier {
    static let search = NSToolbarItem.Identifier(rawValue: "Search");
    static let filter = NSToolbarItem.Identifier(rawValue: "Filter");
    static let progressIndicator = NSToolbarItem.Identifier(rawValue: "ProgressIndicator");
}

class ViewController: NSSplitViewController, NSToolbarDelegate {
    let secondaryQueue = DispatchQueue(label: Bundle.main.bundleIdentifier!);
    var numberOfWorkingProcesses = 0;
    
    let sidebarController = SidebarController();
    let showcaseViewController = ShowcaseViewController();
    
    var applications = [Application]();
    var dockApplicationIdentifiers = [Application.Identifier]();
    var applicationsInCurrentCategory: [Application]?;
    var preferredApplicationsInCurrentCategory: [Application]?;
    
    var showsCustomizedOnly = false;
    var isSearching = false;
    
    var shouldRelaunchCheckbox = NSButton();
    var shouldRelaunchApplications = false;
    
    weak var progressIndicator: NSProgressIndicator?;
    weak var segmentedControl: NSSegmentedControl?;
    weak var searchField: NSSearchField?;
    weak var showAllMenuItem: NSMenuItem?;
    weak var showCustomizedMenuItem: NSMenuItem?;
    weak var menubarShowAllMenuItem: NSMenuItem?;
    weak var menubarShowCustomizedMenuItem: NSMenuItem?;
    
    let failedAlert: NSAlert = {
        let alert = NSAlert();
        alert.alertStyle = .critical;
        alert.informativeText = "failed-alert-text".localized;
        alert.addButton(withTitle: "ok".localized);
        alert.addButton(withTitle: "copy-domain".localized);
        return alert;
    }();
    
    let cannotQuitAlert: NSAlert = {
        let alert = NSAlert();
        alert.alertStyle = .warning;
        alert.informativeText = "cannot-quit-alert-text".localized;
        return alert;
    }();
    
    let waitingSecondsAfterAttemptingQuit: Double = 7.0;
    
    override func loadView() {
        super.loadView();
        view.frame = NSRect(x: 0, y: 0, width: 608, height: 576);
        sidebarController.shouldRelaunchCheckbox = shouldRelaunchCheckbox;
        splitViewItems = [
            NSSplitViewItem(sidebarWithViewController: sidebarController),
            NSSplitViewItem(contentListWithViewController: showcaseViewController)
        ];
        splitViewItems[1].minimumThickness = showcaseViewController.minWidth;
        shouldRelaunchCheckbox.action = #selector(onShouldRelaunchCheckboxToggle);
    }
    
    override func viewWillAppear() {
        super.viewWillAppear();
        startProgressIndicating();
        sidebarController.outlineView.expandItem(SidebarCategory.root);
        loadApplications(then: initializeAndExpandSidebar);
        shouldRelaunchApplications = UserDefaults.standard.bool(forKey: "shouldRelaunchApplications");
        if shouldRelaunchApplications {
            shouldRelaunchCheckbox.state = .on;
        }
    }
    
    override func viewWillLayout() {
        Accent.systemColorDidChange();
        AccentPopUpButton.systemColorDidChange(appearance: view.effectiveAppearance);
        if Accent.systemAccentCanBeMulticolored {
            showcaseViewController.cellCaches.values.forEach {showcaseCellView in
                showcaseCellView.popUpButton.updateMenuWhereSystemAccentCanBeMulticolored();
            }
        } else if Accent.systemAccentIsBinary {
            showcaseViewController.cellCaches.values.forEach {showcaseCellView in
                showcaseCellView.popUpButton.updateGraph();
            }
        } else {
            showcaseViewController.cellCaches.values.forEach {showcaseCellView in
                showcaseCellView.popUpButton.updateAppearance();
            }
        }
        super.viewWillLayout();
    }
    
    func loadApplications(then callback: @escaping () -> ()) {
        secondaryQueue.async {
            let standardApplications = Application.standard();
            self.applications = standardApplications.applications;
            self.dockApplicationIdentifiers = standardApplications.identifiers[.dock] ?? [];
            DispatchQueue.main.sync(execute: callback);
        }
    }
    
    func initializeAndExpandSidebar() {
        sidebarController.selectRow(at: sidebarController.categoryAllRowIndex);
        stopProgressIndicating();
    }
    
    func startProgressIndicating() {
        if numberOfWorkingProcesses == 0 {
            progressIndicator?.isHidden = false;
            progressIndicator?.startAnimation(nil);
        }
        numberOfWorkingProcesses += 1;
    }
    
    func stopProgressIndicating() {
        numberOfWorkingProcesses -= 1;
        if numberOfWorkingProcesses == 0 {
            progressIndicator?.isHidden = true;
            progressIndicator?.stopAnimation(nil);
        }
    }
    
    lazy var searchToolbarItem: NSToolbarItem = {
        var toolbarItem: NSToolbarItem;

        if #available(OSX 11.0, *) {
            let searchToolbarItem = NSSearchToolbarItem(itemIdentifier: .search);
            searchToolbarItem.searchField.action = #selector(onSearch);
            self.searchField = searchToolbarItem.searchField;
            toolbarItem = searchToolbarItem;
        } else {
            toolbarItem = NSToolbarItem(itemIdentifier: .search);
            toolbarItem.label = "Search";
            toolbarItem.paletteLabel = "Search";

            let searchField = NSSearchField();
            searchField.action = #selector(onSearch);
            self.searchField = searchField;
            
            toolbarItem.view = searchField;
        }
        
        toolbarItem.target = self;
        toolbarItem.label = "search".localized;
        toolbarItem.paletteLabel = "search".localized;
        if #available(OSX 10.14, *) {} else {
            toolbarItem.maxSize = NSSize(width: 224, height: 0);
            toolbarItem.minSize = NSSize(width: 128, height: 0);
        }
        return toolbarItem;
    }();

    lazy var filterToolbarItem: NSToolbarItem = {
        let toolbarItem = NSToolbarItem(itemIdentifier: .filter);
        toolbarItem.label = "filter-applications".localized;
        toolbarItem.paletteLabel = "filter-applications".localized;
        
        let segmentedControl = NSSegmentedControl();
        segmentedControl.segmentCount = 2;
        segmentedControl.selectedSegment = 0;
        self.segmentedControl = segmentedControl;
        
        let showAllMenuItem = NSMenuItem(title: "show-all".localized, action: #selector(showAll(_:)), keyEquivalent: "");
        let showCustomizedMenuItem = NSMenuItem(title: "show-customized".localized, action: #selector(showCustomized(_:)), keyEquivalent: "");
        
        let menu = NSMenu(title: "segmented-show".localized);
        menu.insertItem(showAllMenuItem, at: 0);
        menu.insertItem(showCustomizedMenuItem, at: 1);
        toolbarItem.menuFormRepresentation = NSMenuItem(title: "segmented-show".localized, action: nil, keyEquivalent: "");
        toolbarItem.menuFormRepresentation!.submenu = menu;
        
        self.showAllMenuItem = showAllMenuItem;
        self.showCustomizedMenuItem = showCustomizedMenuItem;

        if #available(OSX 11.0, *) {
            segmentedControl.setImage(NSImage(
                systemSymbolName: "square.fill.text.grid.1x2",
                accessibilityDescription: "all".localized
            ), forSegment: 0);
            segmentedControl.setImage(NSImage(
                systemSymbolName: "person.fill.checkmark",
                accessibilityDescription: "customized".localized
            ), forSegment: 1);
            segmentedControl.toolTip = "show-all-customized-applications".localized;
        } else {
            segmentedControl.setLabel("segmented-all".localized, forSegment: 0);
            segmentedControl.setLabel("segmented-customized".localized, forSegment: 1);
            segmentedControl.sizeToFit();
        }

        segmentedControl.action = #selector(onSegmented);
        segmentedControl.target = self;

        toolbarItem.view = segmentedControl;
        return toolbarItem;
    }();
    
    lazy var progressIndicatorToolbarItem: NSToolbarItem = {
        let toolbarItem = NSToolbarItem(itemIdentifier: .progressIndicator);
        let progressIndicator = NSProgressIndicator();
        toolbarItem.label = "progress-indicator".localized;
        toolbarItem.paletteLabel = "progress-indicator".localized;
        progressIndicator.style = .spinning;
        progressIndicator.isIndeterminate = true;
        progressIndicator.sizeToFit();
        progressIndicator.controlSize = .small;
        self.progressIndicator = progressIndicator;
        toolbarItem.view = progressIndicator;
        toolbarItem.visibilityPriority = .high;
        return toolbarItem;
    }();

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(OSX 11.0, *) {
            return [.progressIndicator, .sidebarTrackingSeparator, .filter, .search];
        } else {
            return [.filter, .flexibleSpace, .space, .progressIndicator, .search];
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(OSX 11.0, *) {
            return [.filter, .search, .progressIndicator, .space, .flexibleSpace, .toggleSidebar, .sidebarTrackingSeparator];
        } else {
            return [.filter, .search, .progressIndicator, .space, .flexibleSpace, .toggleSidebar];
        }
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .search:
            return searchToolbarItem;
        case .filter:
            return filterToolbarItem;
        case .progressIndicator:
            return progressIndicatorToolbarItem;
        default:
            return nil;
        }
    }
}

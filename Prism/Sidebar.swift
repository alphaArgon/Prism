import Cocoa;

struct SidebarCategory {
    var title: String;
    var image: NSImage;
    var type: Application.Category;
    
    typealias RootIdentifier = String;
    static var root: RootIdentifier = "root";
    
    static var descriptors: [(Application.Category, String, String, String)] = [
        (.any, "all", "square.fill.text.grid.1x2", "SidebarApplication"),
        (.featured, "featured", "paintpalette", "SidebarRecommendation"),
        (.launchpad, "launchpad", "apps.ipad.landscape", "SidebarLaunchpad"),
        (.dock, "dock", "dock.rectangle", "SidebarDock"),
        (.system, "system", "pc", "SidebarSystem")
        // there is no wrong with "pc". Yes.
    ];
}

class SidebarController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    unowned var shouldRelaunchCheckbox: NSButton!;
    let scrollView = NSScrollView();
    let outlineView = OutlineView();
    
    var categoryAllRowIndex = 1;
    let sidebarCategories: [SidebarCategory] = {
        var sidebarCategories = [SidebarCategory]();
        for (category, title, symbolName, imageName) in SidebarCategory.descriptors {
            if #available(OSX 11.0, *) {
                sidebarCategories.append(SidebarCategory(
                    title: ("category-" + title).localized,
                    image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage(),
                    type: category
                ));
            } else {
                var text: String;
                if category == .featured {
                    if Accent.systemAccentIsBinary {
                        continue;
                    }
                    text = "category-recommended".localized;
                } else {
                    text = ("category-" + title).localized;
                }
                let image = NSImage(named: imageName);
                image?.isTemplate = true;
                sidebarCategories.append(SidebarCategory(
                    title: text,
                    image: image ?? NSImage(),
                    type: category
                ));
            }
        }
        return sidebarCategories;
    }();
    
    override func loadView() {
        view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 160, height: 576));
        (view as! NSVisualEffectView).material = .sidebar;
        
        shouldRelaunchCheckbox.setButtonType(.switch);
        shouldRelaunchCheckbox.attributedTitle = NSAttributedString(
            string: "relaunch-applications".localized,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
        );
        shouldRelaunchCheckbox.autoresizingMask = [.width];
        
        var shouldRelaunchCheckboxPadding: CGFloat;
        if #available(OSX 11.0, *) {
            shouldRelaunchCheckboxPadding = 14;
        } else {
            shouldRelaunchCheckboxPadding = 8;
        }
        shouldRelaunchCheckbox.frame = NSRect(
            x: shouldRelaunchCheckboxPadding,
            y: shouldRelaunchCheckboxPadding,
            width: view.bounds.width - 2 * shouldRelaunchCheckboxPadding,
            height: shouldRelaunchCheckbox.fittingSize.height
        );
        view.addSubview(shouldRelaunchCheckbox);
        
        scrollView.frame = NSRect(
            x: 0,
            y: shouldRelaunchCheckbox.frame.maxY + shouldRelaunchCheckboxPadding,
            width: view.bounds.width,
            height: view.bounds.height - shouldRelaunchCheckbox.frame.maxY - shouldRelaunchCheckboxPadding
        );
        scrollView.drawsBackground = false;
        scrollView.hasHorizontalScroller = false;
        scrollView.hasVerticalScroller = true;
        scrollView.autohidesScrollers = true;
        scrollView.autoresizingMask = [.height, .width];
        view.addSubview(scrollView);
        
        scrollView.documentView = outlineView;
        
        outlineView.dataSource = self;
        outlineView.delegate = self;
        outlineView.headerView = nil;
        outlineView.backgroundColor = NSColor.clear;
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarCategories"));
        column.width = outlineView.bounds.width;
        outlineView.addTableColumn(column);
        outlineView.rowSizeStyle = .default;
        outlineView.allowsEmptySelection = false;
        outlineView.refusesFirstResponder = true;
        outlineView.floatsGroupRows = false;
        outlineView.selectionHighlightStyle = .sourceList;
        if #available(OSX 11.0, *) {
            outlineView.indentationPerLevel = 0;
        } else {
            outlineView.indentationPerLevel = 17;
        }
    }
    
    func selectRow(at index: Int) {
        outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false);
    }
    
    //MARK: Delegate
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return false;
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if item is SidebarCategory {
            return false;
        }
        return true;
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard item is SidebarCategory else {
            if item is SidebarCategory.RootIdentifier {
                let header = NSTableCellView();
                let label = NSLabel(title: "categories".localized);
                header.textField = label;
                header.addSubview(label);
                return header;
            }
            return nil;
        }
        
        let cell = NSTableCellView();
        
        let label = NSLabel(title: (item as! SidebarCategory).title);
        cell.textField = label;
        cell.addSubview(label);
        
        let imageView = NSImageView();
        imageView.image = (item as! SidebarCategory).image;
        cell.imageView = imageView;
        cell.addSubview(imageView);

        return cell;
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if item is SidebarCategory.RootIdentifier {
            return false;
        }
        return true;
    }
    
    //MARK: Data Source
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedItem = outlineView.item(atRow: outlineView.selectedRow) as? SidebarCategory;
        if selectedItem != nil {
            (parent as? ViewController)?.showcase(category: (selectedItem!).type);
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return 1;
        }
        return sidebarCategories.count;
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return SidebarCategory.root;
        }
        return sidebarCategories[index];
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item is SidebarCategory.RootIdentifier {
            return true;
        }
        return false;
    }
}

class OutlineView: NSOutlineView {
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        let originalRect = super.frameOfCell(atColumn: column, row: row);
        if column != 0 {
            return originalRect;
        }
        let indent = CGFloat(level(forRow: row)) * indentationPerLevel;
        return NSRect(x: originalRect.minX + indent, y: originalRect.minY, width: originalRect.width - indent, height: originalRect.height);
    }
}

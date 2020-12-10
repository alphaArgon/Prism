import Cocoa;

class ShowcaseViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {
    let scrollView = NSScrollView();
    let tableView = ShowcaseView();
    let fittingSize = NSRect(x: 0, y: 0, width: 448, height: 576);
    let minWidth: CGFloat = 384;
    
    var applications = [Application]();
    
    var rowCaches = [Int: ShowcaseRowView]();
    var cellCaches = [Application.Identifier: ShowcaseCellView]();
    
    var menuItemsAreEnabled = true;
    var clickedIndex: Int?;
    
    override func loadView() {
        view = NSView(frame: fittingSize);
        view.addSubview(scrollView);
        
        scrollView.frame = view.bounds;
        scrollView.drawsBackground = false;
        scrollView.hasHorizontalScroller = false;
        scrollView.hasVerticalScroller = true;
        scrollView.autoresizingMask = [.height, .width];
        
        scrollView.documentView = tableView;
        
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.headerView = nil;
        tableView.rowHeight = CGFloat(ShowcaseCellView.rowHeight);
        tableView.backgroundColor = NSColor.clear;
        tableView.gridStyleMask = .solidHorizontalGridLineMask;
        tableView.intercellSpacing = NSSize(width: 0, height: 1);
        if #available(OSX 11.0, *) {
            tableView.style = .inset;
        }
        if #available(OSX 10.13, *) {
            tableView.gridColor = NSColor(named: "SeparatorColor") ?? NSColor(
                red: 0.5882352941,
                green: 0.5882352941,
                blue: 0.6078431373,
                alpha: 0.25
            );
        } else {
            tableView.gridColor = NSColor(
                red: 0.5882352941,
                green: 0.5882352941,
                blue: 0.6078431373,
                alpha: 0.25
            );
        }
        
        let column = NSTableColumn();
        column.width = tableView.bounds.width;
        tableView.addTableColumn(column);
        
        tableView.menu = {
            let menu = NSMenu(title: "Application Actions".localized);
            menu.addItem(
                withTitle: "show-in-finder".localized,
                action: #selector(showInFinder),
                keyEquivalent: ""
            );
            menu.addItem(
                withTitle: "copy-domain".localized,
                action: #selector(copyDomain),
                keyEquivalent: ""
            );
            menu.delegate = self;
            menu.autoenablesItems = false;
            return menu;
        }();
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return applications.count;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let application = applications[row];
        if cellCaches[application.identifier] == nil {
            let cellView = ShowcaseCellView(application: application);
            let viewController = (parent as? ViewController);
            cellView.popUpButton.target = viewController;
            cellView.popUpButton.action = #selector(viewController?.setAccent);
            cellCaches[application.identifier] = cellView;
        }
        return cellCaches[application.identifier];
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        if rowCaches[row] == nil {
            rowCaches[row] = ShowcaseRowView();
        }
        return rowCaches[row];
    }
    
    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false;
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        if tableView.clickedRow < 0 {
            clickedIndex = nil;
            if menuItemsAreEnabled {
                menuItemsAreEnabled = false;
                menu.items.forEach {item in
                    item.isEnabled = false;
                }
            }
        } else {
            clickedIndex = tableView.clickedRow;
            if !menuItemsAreEnabled {
                menuItemsAreEnabled = true;
                menu.items.forEach {item in
                    item.isEnabled = true;
                }
            }
        }
    }
    
    @objc func showInFinder(_ sender: Any) {
        if clickedIndex == nil {
            return;
        }
        NSWorkspace.shared.selectFile(applications[clickedIndex!].identifier.path, inFileViewerRootedAtPath: "");
    }
    
    @objc func copyDomain(_ sender: Any) {
        if clickedIndex == nil {
            return;
        }
        let pasteboard = NSPasteboard.general;
        pasteboard.clearContents();
        pasteboard.setString(applications[clickedIndex!].identifier.domain, forType: .string);
    }
}

class ShowcaseView: NSTableView {
    override func drawGrid(inClipRect clipRect: NSRect) {
        let indented = NSRect(
            x: CGFloat(ShowcaseCellView.sidebearing),
            y: 0.0,
            width: clipRect.width - 2 * CGFloat(ShowcaseCellView.sidebearing),
            height: clipRect.height
        );
        super.drawGrid(inClipRect: indented);
    }
}

class ShowcaseRowView: NSTableRowView {
    override func drawSeparator(in dirtyRect: NSRect) {
        let indented = NSRect(
            x: CGFloat(ShowcaseCellView.sidebearing),
            y: 0.0,
            width: dirtyRect.width - 2 * CGFloat(ShowcaseCellView.sidebearing),
            height: dirtyRect.height
        );
        super.drawSeparator(in: indented);
    }
}

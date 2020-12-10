import Cocoa;

class ShowcaseCellView: NSTableCellView {
    static var iconSize = 48;
    static var rowHeight = 64;
    static var sidebearing = 16;
    private static var itemGapWidth: CGFloat = 12;
    
    unowned var application: Application!;
    lazy var popUpButton = AccentPopUpButton(for: application);
    
    required init?(coder: NSCoder) {super.init(coder: coder);}
    
    init(application: Application) {
        super.init(frame: NSRect(x: 0, y: 0, width: 384, height: Self.rowHeight));
        // the width can be whatever as it can contain subviews;
        
        self.application = application;
        self.autoresizesSubviews = true;
        
        let imageView = NSImageView();
        self.addSubview(imageView);
        DispatchQueue.main.async {
            let icon = NSWorkspace.shared.icon(forFile: application.identifier.path);
            icon.size = NSSize(width: Self.iconSize, height: Self.iconSize);
            imageView.image = icon;
        }
        
        self.addSubview(popUpButton);
        
        let nameLabel = NSLabel(title: application.displayName);
        nameLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize);
        nameLabel.sizeToFit();
        self.addSubview(nameLabel);
        
        let domainLabel = NSLabel(title: application.identifier.domain);
        domainLabel.controlSize = .small;
        domainLabel.font = NSFont.labelFont(ofSize: NSFont.smallSystemFontSize);
        domainLabel.textColor = NSColor.secondaryLabelColor;
        self.addSubview(domainLabel);
        
        
        let cellBounds = bounds;
        var cellSidebearing = CGFloat(Self.sidebearing);
        if #available(OSX 11.0, *) {
            cellSidebearing = 0;
        }
        
        imageView.frame = NSRect(
            x: cellSidebearing,
            y: cellBounds.height / 2 - CGFloat(Self.iconSize) / 2,
            width: CGFloat(Self.iconSize),
            height: CGFloat(Self.iconSize)
        );
        imageView.autoresizingMask = .none;
        
        popUpButton.frame = NSRect(
            x: cellBounds.width - cellSidebearing - AccentPopUpButton.popUpButtonWidth,
            y: cellBounds.height / 2 - popUpButton.fittingSize.height / 2,
            width: AccentPopUpButton.popUpButtonWidth,
            height: popUpButton.fittingSize.height
        );
        popUpButton.autoresizingMask = .minXMargin;
        
        nameLabel.frame = NSRect(
            x: imageView.frame.maxX + Self.itemGapWidth,
            y: cellBounds.height / 2 - NSFont.systemFontSize + NSFont.smallSystemFontSize,
            width: popUpButton.frame.minX - imageView.frame.maxX - 2 * Self.itemGapWidth,
            height: nameLabel.fittingSize.height
        );
        nameLabel.autoresizingMask = .width;
        
        domainLabel.frame = NSRect(
            x: nameLabel.frame.minX,
            y: cellBounds.height / 2 - NSFont.systemFontSize + NSFont.smallSystemFontSize - domainLabel.fittingSize.height,
            width: nameLabel.frame.width,
            height: domainLabel.fittingSize.height
        );
        domainLabel.autoresizingMask = .width;
    }
}

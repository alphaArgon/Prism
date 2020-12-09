import Cocoa;

class AccentPopUpButton: NSPopUpButton, NSMenuDelegate {
    var previousIndexOfSelectedItem: Int = 0;
    var featureGraph: NSImage?;
    weak var recommendedItem: NSMenuItem?;
    unowned var application: Application!;
    
    required init?(coder: NSCoder) {super.init(coder: coder);}
    
    init(for application: Application) {
        super.init(frame: .zero, pullsDown: false);
        self.application = application;
        menu = AccentMenu();
        menu!.delegate = self;
        
        if #available(OSX 11.0, *) {
            bezelStyle = .texturedRounded;
            (cell as! NSPopUpButtonCell).arrowPosition = .arrowAtBottom;
        } else if #available(OSX 10.14, *) {
            appearance = Self.clearAppearance;
        }
        // tint color of system controls are rendered in real time since Mojave.
        // this may have a better performance.
        
        let selectionIndex = AccentMenu.menuOrder.firstIndex(of: application.accent);
        
        if application.featureColor == nil {
            selectItem(at: selectionIndex ?? 0);
            if Accent.systemAccentCanBeMulticolored {
                updateMenuWhereSystemAccentCanBeMulticolored();
            }
            return;
        }
        
        if Accent.systemAccentCanBeMulticolored {
            let bestMatches = Accent.bestMatches(color: application.featureColor!);
            if let bestMatchedCGColor = Accent.systemColors[bestMatches]?.cgColor,
               bestMatchedCGColor == application.featureColor?.cgColor {
                featureGraph = NSImage(named: Accent.colorName(of: bestMatches));
            }
            if featureGraph == nil {
                featureGraph = NSImage(size: AccentMenu.colorGraphSize, flipped: false) {imageRect in
                    application.featureColor!.setFill();
                    imageRect.fill();
                    AccentMenu.colorGraphOverlay.draw(in: imageRect);
                    return true;
                };
            }
            
            let featureItem = NSMenuItem(title: "color-featured".localized, action: nil, keyEquivalent: "");
            featureItem.tag = Accent.unknown.rawValue;
            menu!.insertItem(featureItem, at: 1);
            updateMenuWhereSystemAccentCanBeMulticolored();
            return;
        } else if !Accent.systemAccentIsBinary {
            let recommendedAccent = Accent.bestMatches(color: application.featureColor!);
            if recommendedAccent != .unset {
                recommendedItem = item(at: AccentMenu.menuOrder.firstIndex(of: recommendedAccent)!);
            }
        }
        selectItem(at: selectionIndex ?? 0);
    }
    
    func updateGraph() {
        let systemAccent = Accent.systemAccent == .unset ? Accent.defaultSystemAccent : Accent.systemAccent;
        menu!.item(at: 0)!.image = NSImage(named: Accent.colorName(of: systemAccent));
    }
    
    func updateAppearance() {
        appearance = Self.clearAppearance;
        updateGraph();
    }
    
    func updateMenuWhereSystemAccentCanBeMulticolored() {
        menu?.item(at: 0)?.title = (Accent.systemAccent == .unset) ? AccentMenu.localizedDefaultColorName : AccentMenu.localizedSystemColorName;
        
        if featureGraph == nil {
            updateGraph();
            return;
        }
        
        let accent = application.accent;
        
        if Accent.systemAccent == .unset {
            menu!.item(at: 0)!.image = featureGraph;
            menu!.item(at: 1)!.isHidden = true;
            if accent == .unset || accent == .unknown {
                selectItem(at: 0);
                return;
            }
        } else {
            menu!.item(at: 0)!.image = NSImage(named: Accent.colorName(of: Accent.systemAccent));
            menu!.item(at: 1)!.image = featureGraph;
            menu!.item(at: 1)!.isHidden = false;
            if accent == .unset {
                selectItem(at: 0);
                return;
            }
            if accent == .unknown {
                selectItem(at: 1);
                return;
            }
        }
        selectItem(at: (AccentMenu.menuOrder.firstIndex(of: accent) ?? 0) + 1);
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        previousIndexOfSelectedItem = indexOfSelectedItem;
        if recommendedItem != nil {
            recommendedItem!.title += "recommended-suffix".localized;
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        if recommendedItem != nil {
            recommendedItem!.title.removeLast("recommended-suffix".localized.count);
        }
    }
    
    static var popUpButtonWidth: CGFloat = {
        let button = NSPopUpButton(frame: NSRect.zero);
        button.menu = AccentMenu();
        if Accent.systemAccentCanBeMulticolored, Accent.systemAccent != .unset {
            button.menu!.addItem(button.menu!.item(at: 0)!.copy() as! NSMenuItem);
            button.menu!.item(at: 0)!.title = AccentMenu.localizedSystemColorName;
            button.menu!.addItem(button.menu!.item(at: 0)!.copy() as! NSMenuItem);
            button.menu!.item(at: 0)!.title = AccentMenu.localizedFeatureColorName;
        }
        return button.fittingSize.width;
    }();
    
    static func systemColorDidChange(appearance: NSAppearance = NSAppearance.current) {
        clearAppearance = AccentPopUpButton.clearAppearance(bestMatching: appearance);
    }
    
    static var clearAppearance = AccentPopUpButton.clearAppearance();
    
    static func clearAppearance(bestMatching appearance: NSAppearance = NSAppearance.current) -> NSAppearance? {
        guard #available(OSX 10.14, *) else {
            return NSAppearance.init(named: NSAppearance.Name(rawValue: "ClearAppearance"));
        }
        switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
        case NSAppearance.Name.aqua:
            return NSAppearance.init(named: NSAppearance.Name(rawValue: "ClearAppearance"));
        case NSAppearance.Name.darkAqua:
            return NSAppearance.init(named: NSAppearance.Name(rawValue: "ClearDarkAppearance"));
        case NSAppearance.Name.accessibilityHighContrastAqua:
            return NSAppearance.init(named: NSAppearance.Name(rawValue: "ClearAccessibilityAppearance"));
        case NSAppearance.Name.aqua:
            return NSAppearance.init(named: NSAppearance.Name(rawValue: "ClearAccessibilityDarkAppearance"));
        default:
            return NSAppearance.init(named: NSAppearance.Name(rawValue: "ClearAppearance"));
        }
    }
}

class AccentMenu: NSMenu {
    required init(coder: NSCoder) {super.init(coder: coder);}
    
    init() {
        super.init(title: "Accent");
        for accent in Self.menuOrder {
            if accent == nil {
                self.addItem(NSMenuItem.separator());
            } else {
                let item = NSMenuItem();
                var colorName: String;
                var labelText: String;
                if accent! == .unset {
                    let systemAccent = Accent.systemAccent == .unset
                        ? Accent.defaultSystemAccent
                        : Accent.systemAccent;
                    colorName = Accent.colorName(of: systemAccent);
                    labelText = "color-default".localized;
                } else {
                    colorName = Accent.colorName(of: accent!);
                    labelText = ("color-" + colorName).localized;
                }
                item.title = labelText;
                item.tag = accent!.rawValue;
                item.image = NSImage(named: colorName);
                self.addItem(item);
            }
        }
    }
    
    static var localizedDefaultColorName = "color-default".localized;
    static var localizedSystemColorName = "color-system".localized;
    static var localizedFeatureColorName = "color-featured".localized;
    
    static var menuOrder: [Accent?] = {
        if Accent.systemAccentIsBinary {
            return [
                Accent.unset,
                nil,
                Accent.classicBlue,
                Accent.classicGraphite,
            ];
        } else {
            return [
                Accent.unset,
                nil,
                Accent.red,
                Accent.orange,
                Accent.yellow,
                Accent.green,
                Accent.blue,
                Accent.purple,
                Accent.pink,
                Accent.graphite,
                nil,
                Accent.spaceGray,
                Accent.gold,
                Accent.roseGold,
                Accent.silver,
            ];
        }
    }();
    
    static let colorGraphSize: NSSize = NSImage(named: "overlay")?.size ?? NSSize(width: 24, height: 12);
    
    static let colorGraphOverlay: NSImage = (NSImage(named: "overlay")?.copy() as? NSImage) ?? NSImage(size: NSSize(width: 24, height: 12));
}


import AppKit
import Foundation

@preconcurrency
public protocol MenuEngineDelegate: AnyObject {
    func menuEngine(_ engine: MenuEngine, didSelectItem item: MenuItem)
    func menuEngineWillOpen(_ engine: MenuEngine)
    func menuEngineDidClose(_ engine: MenuEngine)
    func menuEngineDidRequestDashboard(_ engine: MenuEngine)
}

public final class MenuEngine {
    public weak var delegate: MenuEngineDelegate?

    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var currentItems: [MenuItem] = []
    private var itemMap: [MenuItemID: NSMenuItem] = [:]

    public var isMenuOpen: Bool = false
    public var compactMode: Bool = false
    public var theme: Theme = .system {
        didSet { applyTheme() }
    }
    public var density: Density = .compact {
        didSet { applyDensity() }
    }
    public var fixedWidth: Bool = false
    public var showArrows: Bool = true
    public var showUnits: Bool = true

    private var titleWidthCache: CGFloat = 0

    public init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu(title: "mac-xbar")
        self.menu.autoenablesItems = false
        self.statusItem.button?.font = speedFont
        self.statusItem.button?.imagePosition = .imageLeading
        self.statusItem.button?.toolTip = "mac-xbar — Network Speed Monitor"
        self.statusItem.button?.action = #selector(statusItemClicked(_:))
        self.statusItem.button?.target = self
        self.statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    public var statusButton: NSStatusBarButton? {
        statusItem.button
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            openMenu()
            return
        }

        if event.type == .rightMouseUp {
            openMenu()
        } else {
            delegate?.menuEngineDidRequestDashboard(self)
        }
    }

    private var fontSize: CGFloat {
        switch density {
        case .compact: return 10
        case .normal: return 12
        case .comfortable: return 14
        }
    }

    private var speedFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
    }

    private var itemFont: NSFont {
        NSFont.systemFont(ofSize: fontSize, weight: .regular)
    }

    private var labelFont: NSFont {
        NSFont.systemFont(ofSize: fontSize, weight: .medium)
    }

    public var title: String {
        get { statusItem.button?.attributedTitle.string ?? "" }
        set { setTitle(newValue) }
    }

    public var icon: NSImage? {
        get { statusItem.button?.image }
        set { statusItem.button?.image = newValue }
    }

    // MARK: - Public API

    public func update(items: [MenuItem]) {
        let newItems = items.sorted { $0.order < $1.order }
        let diff = computeDiff(old: currentItems, new: newItems)
        if !diff.removed.isEmpty || !diff.added.isEmpty || !diff.updated.isEmpty {
            applyDiff(diff)
        }
        currentItems = newItems
        stabilizeWidth()
    }

    public func setTitle(_ title: String) {
        guard let button = statusItem.button else { return }
        if title.isEmpty {
            button.attributedTitle = NSAttributedString(string: " ", attributes: [.font: speedFont])
        } else {
            let newAttributed = NSAttributedString(
                string: title,
                attributes: [
                    .font: speedFont,
                    .foregroundColor: resolvedLabelColor,
                ]
            )
            guard button.attributedTitle.string != title else { return }
            button.attributedTitle = newAttributed
        }
        stabilizeWidth()
    }

    public func setIcon(_ image: NSImage?) {
        image?.isTemplate = true
        statusItem.button?.image = image
        stabilizeWidth()
    }

    public func setTemplateImage(_ image: NSImage?) {
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    public func setTitleColor(_ color: NSColor) {
        guard let button = statusItem.button, !button.attributedTitle.string.isEmpty else { return }
        let attributed = NSAttributedString(
            string: button.attributedTitle.string,
            attributes: [
                .font: speedFont,
                .foregroundColor: color,
            ]
        )
        button.attributedTitle = attributed
    }

    public func removeAllItems() {
        menu.removeAllItems()
        itemMap.removeAll()
        currentItems = []
    }

    public func setTooltip(_ text: String) {
        statusItem.button?.toolTip = text
    }

    public func openMenu() {
        delegate?.menuEngineWillOpen(self)
        isMenuOpen = true
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
        isMenuOpen = false
        delegate?.menuEngineDidClose(self)
    }

    // MARK: - Theme & Density

    private func applyTheme() {
        if let title = statusItem.button?.attributedTitle.string, !title.isEmpty, title != " " {
            setTitle(title)
        }
    }

    private func applyDensity() {
        statusItem.button?.font = speedFont
        if let title = statusItem.button?.attributedTitle.string, !title.isEmpty, title != " " {
            setTitle(title)
        }
        titleWidthCache = 0
    }

    private var resolvedLabelColor: NSColor {
        switch theme {
        case .system:
            return NSColor.labelColor
        case .light:
            return NSColor(calibratedWhite: 0.0, alpha: 1.0)
        case .dark:
            return NSColor(calibratedWhite: 1.0, alpha: 1.0)
        }
    }

    // MARK: - Width Stabilization

    private func stabilizeWidth() {
        guard fixedWidth else {
            statusItem.length = NSStatusItem.variableLength
            titleWidthCache = 0
            return
        }
        guard let button = statusItem.button else { return }
        let titleWidth = button.attributedTitle.size().width
        let iconWidth = button.image?.size.width ?? 0
        let padding: CGFloat = 12
        let totalWidth = iconWidth + titleWidth + padding
        if totalWidth > titleWidthCache {
            titleWidthCache = totalWidth
        }
        statusItem.length = titleWidthCache
    }

    // MARK: - Diff Engine

    private func computeDiff(old: [MenuItem], new: [MenuItem]) -> MenuDiff {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })

        var removed: [MenuItemID] = []
        var added: [MenuItem] = []
        var updated: [MenuItem] = []

        for (id, oldItem) in oldMap {
            if newMap[id] == nil {
                removed.append(id)
            } else if let newItem = newMap[id], oldItem != newItem {
                updated.append(newItem)
            }
        }

        for (id, newItem) in newMap {
            if oldMap[id] == nil {
                added.append(newItem)
            }
        }

        return MenuDiff(removed: removed, added: added, updated: updated)
    }

    private func applyDiff(_ diff: MenuDiff) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            for id in diff.removed {
                if let nsItem = itemMap[id] {
                    menu.removeItem(nsItem)
                    itemMap.removeValue(forKey: id)
                }
            }

            for item in diff.added {
                let nsItem = makeNSMenuItem(item)
                menu.addItem(nsItem)
                itemMap[item.id] = nsItem
            }

            for item in diff.updated {
                if let nsItem = itemMap[item.id] {
                    updateNSMenuItem(nsItem, with: item)
                }
            }
        }

        if !diff.removed.isEmpty || !diff.added.isEmpty {
            reorderMenuItems()
        }
    }

    // MARK: - NSMenuItem Factory

    private func makeNSMenuItem(_ item: MenuItem) -> NSMenuItem {
        if item.isSeparator {
            return NSMenuItem.separator()
        }

        let nsItem = NSMenuItem(
            title: item.title,
            action: #selector(handleItemClick(_:)),
            keyEquivalent: item.shortcut ?? ""
        )
        nsItem.target = self
        nsItem.isEnabled = item.isEnabled
        nsItem.isHidden = item.isHidden
        nsItem.representedObject = item.id

        if let icon = item.icon {
            nsItem.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            nsItem.image?.isTemplate = true
        }

        if let badge = item.badge {
            let attributed = NSMutableAttributedString(string: "\(item.title)  ", attributes: [.font: itemFont])
            attributed.append(NSAttributedString(string: badge, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize - 1, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
            nsItem.attributedTitle = attributed
        } else if let color = item.color {
            nsItem.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [
                    .font: itemFont,
                    .foregroundColor: NSColor(hex: color) ?? resolvedLabelColor,
                ]
            )
        } else {
            nsItem.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.font: itemFont]
            )
        }

        if let submenu = item.submenu, !submenu.isEmpty {
            let submenuNS = NSMenu(title: item.title)
            for subItem in submenu.sorted(by: { $0.order < $1.order }) {
                submenuNS.addItem(makeNSMenuItem(subItem))
            }
            nsItem.submenu = submenuNS
        }

        return nsItem
    }

    private func updateNSMenuItem(_ nsItem: NSMenuItem, with item: MenuItem) {
        nsItem.title = item.title
        nsItem.isEnabled = item.isEnabled
        nsItem.isHidden = item.isHidden
        nsItem.keyEquivalent = item.shortcut ?? ""
        nsItem.representedObject = item.id

        if let icon = item.icon {
            nsItem.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            nsItem.image?.isTemplate = true
        }

        if let badge = item.badge {
            let attributed = NSMutableAttributedString(string: "\(item.title)  ", attributes: [.font: itemFont])
            attributed.append(NSAttributedString(string: badge, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize - 1, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
            nsItem.attributedTitle = attributed
        } else if let colorHex = item.color {
            nsItem.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [
                    .font: itemFont,
                    .foregroundColor: NSColor(hex: colorHex) ?? resolvedLabelColor,
                ]
            )
        } else {
            nsItem.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.font: itemFont]
            )
        }
    }

    private func reorderMenuItems() {
        let sorted = currentItems.sorted { $0.order < $1.order }
        for (index, item) in sorted.enumerated() {
            if let nsItem = itemMap[item.id] {
                menu.removeItem(nsItem)
                menu.insertItem(nsItem, at: index)
            }
        }
    }

    @objc private func handleItemClick(_ sender: NSMenuItem) {
        guard let itemId = sender.representedObject as? String else { return }
        guard let item = currentItems.first(where: { $0.id == itemId }) else { return }
        delegate?.menuEngine(self, didSelectItem: item)
    }
}

// MARK: - MenuDiff

public struct MenuDiff {
    public let removed: [MenuItemID]
    public let added: [MenuItem]
    public let updated: [MenuItem]
}

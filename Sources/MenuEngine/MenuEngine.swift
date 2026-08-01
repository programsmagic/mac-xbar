import AppKit
import Foundation

public protocol MenuEngineDelegate: AnyObject {
    func menuEngine(_ engine: MenuEngine, didSelectItem item: MenuItem)
    func menuEngineWillOpen(_ engine: MenuEngine)
    func menuEngineDidClose(_ engine: MenuEngine)
}

public final class MenuEngine {
    public weak var delegate: MenuEngineDelegate?

    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var currentItems: [MenuItem] = []
    private var itemMap: [MenuItemID: NSMenuItem] = [:]

    public var isMenuOpen: Bool = false
    public var compactMode: Bool = false

    public init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu(title: "mac-xbar")
        self.menu.autoenablesItems = false
    }

    public var title: String {
        get { statusItem.button?.title ?? "" }
        set { statusItem.button?.title = newValue }
    }

    public var icon: NSImage? {
        get { statusItem.button?.image }
        set { statusItem.button?.image = newValue }
    }

    public func update(items: [MenuItem]) {
        let newItems = items.sorted { $0.order < $1.order }
        let diff = computeDiff(old: currentItems, new: newItems)
        applyDiff(diff)
        currentItems = newItems
    }

    public func setTitle(_ title: String) {
        statusItem.button?.title = title
    }

    public func setIcon(_ image: NSImage?) {
        statusItem.button?.image = image
    }

    public func setTemplateImage(_ image: NSImage?) {
        statusItem.button?.image = image
    }

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

        reorderMenuItems()
    }

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
        }

        if let badge = item.badge {
            nsItem.attributedTitle = NSAttributedString(
                string: "\(item.title)  \(badge)",
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
            )
        }

        if let color = item.color {
            nsItem.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.foregroundColor: NSColor(hex: color) ?? .labelColor]
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

    public func openMenu() {
        delegate?.menuEngineWillOpen(self)
        isMenuOpen = true
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
        isMenuOpen = false
        delegate?.menuEngineDidClose(self)
    }

    public func removeAllItems() {
        menu.removeAllItems()
        itemMap.removeAll()
        currentItems = []
    }
}

public struct MenuDiff {
    public let removed: [MenuItemID]
    public let added: [MenuItem]
    public let updated: [MenuItem]
}
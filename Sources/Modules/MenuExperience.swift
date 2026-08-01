import Foundation
import AppKit

public final class MenuExperienceManager {
    public static let shared = MenuExperienceManager()

    public enum Mode: String, Codable, CaseIterable {
        case compact
        case detailed
        case developer
    }

    public var currentMode: Mode = .detailed
    public var searchEnabled: Bool = true
    public var favoritesEnabled: Bool = true
    public var pinItemsEnabled: Bool = true
    public var nestedMenusEnabled: Bool = true
    public var keyboardShortcutsEnabled: Bool = true
    public var dynamicIconsEnabled: Bool = true
    public var statusColorsEnabled: Bool = true
    public var customTemplatesEnabled: Bool = true

    private var favorites: [MenuItemID] = []
    private var pinnedItems: [MenuItemID] = []
    private var searchQuery: String = ""

    private init() {
        loadState()
    }

    public func toggleFavorite(_ itemId: MenuItemID) {
        if favorites.contains(itemId) {
            favorites.removeAll { $0 == itemId }
        } else {
            favorites.append(itemId)
        }
        saveState()
    }

    public func isFavorite(_ itemId: MenuItemID) -> Bool {
        favorites.contains(itemId)
    }

    public func togglePin(_ itemId: MenuItemID) {
        if pinnedItems.contains(itemId) {
            pinnedItems.removeAll { $0 == itemId }
        } else {
            pinnedItems.append(itemId)
        }
        saveState()
    }

    public func isPinned(_ itemId: MenuItemID) -> Bool {
        pinnedItems.contains(itemId)
    }

    public func setSearchQuery(_ query: String) {
        searchQuery = query.lowercased()
    }

    public func filterItems(_ items: [MenuItem]) -> [MenuItem] {
        guard !searchQuery.isEmpty else { return items }
        return items.filter { item in
            item.title.lowercased().contains(searchQuery)
                || (item.subtitle?.lowercased().contains(searchQuery) ?? false)
        }
    }

    public func reorderItems(_ items: [MenuItem], from oldIndex: Int, to newIndex: Int) -> [MenuItem] {
        var items = items
        let moved = items.remove(at: oldIndex)
        items.insert(moved, at: newIndex)
        return items
    }

    public func setMode(_ mode: Mode) {
        currentMode = mode
    }

    private func loadState() {
        if let saved = try? Storage.shared.load([MenuItemID].self, forKey: "favorites") {
            favorites = saved
        }
        if let saved = try? Storage.shared.load([MenuItemID].self, forKey: "pinnedItems") {
            pinnedItems = saved
        }
    }

    private func saveState() {
        try? Storage.shared.save(favorites, forKey: "favorites")
        try? Storage.shared.save(pinnedItems, forKey: "pinnedItems")
    }
}
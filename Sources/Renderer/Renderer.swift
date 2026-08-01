import Foundation

public protocol RendererDelegate: AnyObject {
    func renderer(_ renderer: Renderer, didProduceOutput output: ModuleOutput)
    func renderer(_ renderer: Renderer, didFailWithError error: Error)
}

public final class Renderer {
    public static let shared = Renderer()

    public weak var delegate: RendererDelegate?

    private init() {}

    public func render(output: ModuleOutput) {
        delegate?.renderer(self, didProduceOutput: output)
    }

    public func render(error: Error, for moduleID: String) {
        let output = ModuleOutput(items: [], source: moduleID, error: error)
        delegate?.renderer(self, didProduceOutput: output)
    }

    public func diff(old: [MenuItem], new: [MenuItem]) -> MenuDiff {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })

        var removed: [String] = []
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
}
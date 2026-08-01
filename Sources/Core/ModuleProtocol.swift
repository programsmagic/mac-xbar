import Foundation

public protocol Module: AnyObject, Identifiable {
    var id: String { get }
    var name: String { get }
    var config: ModuleConfig { get set }
    var state: ModuleState { get }

    func initialize() async throws
    func refresh() async throws -> ModuleOutput
    func invalidate()
    func setEnabled(_ enabled: Bool)
}

public protocol ModuleObserver: AnyObject {
    func moduleDidUpdate(_ module: any Module, output: ModuleOutput)
    func moduleDidFail(_ module: any Module, error: Error)
    func moduleDidChangeState(_ module: any Module, state: ModuleState)
}
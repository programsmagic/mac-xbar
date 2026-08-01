import Foundation

public protocol Identifiable: Equatable {
    associatedtype ID: Hashable
    var id: ID { get }
}

extension Identifiable where ID == String {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
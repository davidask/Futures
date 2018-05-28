public protocol AnyFuture: class, Equatable {
    var isPending: Bool { get }
    var isFulfilled: Bool { get }
    var isRejected: Bool { get }
}

public extension AnyFuture {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs == rhs
    }
}

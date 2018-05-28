public protocol AnyFuture: class {
    var isPending: Bool { get }
    var isFulfilled: Bool { get }
    var isRejected: Bool { get }
}

/// Type-erasure for `Future<T>`
public protocol AnyFuture: class {

    /// Indicates whether the future is pending
    var isPending: Bool { get }
    /// Indicates whether the future is fulfilled
    var isFulfilled: Bool { get }
    /// Indicates whether the future is rejected
    var isRejected: Bool { get }
}

/// Type-erasure for `Future<Value>`
public protocol AnyFuture: AnyObject {

    /// Indicates whether the future is pending
    var isPending: Bool { get }
    /// Indicates whether the future is fulfilled
    var isFulfilled: Bool { get }
    /// Indicates whether the future is rejected
    var isRejected: Bool { get }
}

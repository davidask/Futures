import Dispatch

private var futuresDispatchQueue = DispatchQueue(label: "com.formbound.future.default", attributes: .concurrent)

private let futureAwaitDispatchQueue = DispatchQueue(label: "com.formbound.future.await", attributes: .concurrent)

public extension DispatchQueue {

    /// The default queue, on which futures are observed and executed on.
    static var futures: DispatchQueue {
        get {
            return futuresDispatchQueue
        }
        set {
            futuresDispatchQueue = newValue
        }
    }

    internal static let futureAwait = futureAwaitDispatchQueue
}

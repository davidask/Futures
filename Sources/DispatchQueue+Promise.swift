import Dispatch

private var futuresDispatchQueue = DispatchQueue(label: "com.formbound.future.default")

private let futureAwaitDispatchQueue = DispatchQueue(label: "com.formbound.future.await", attributes: .concurrent)

public extension DispatchQueue {
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

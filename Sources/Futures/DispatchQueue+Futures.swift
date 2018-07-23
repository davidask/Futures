import Dispatch

private var futuresDispatchQueue = DispatchQueue(label: "com.formbound.futures.default", attributes: .concurrent)

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
}

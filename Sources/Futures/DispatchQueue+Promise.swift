import Dispatch

public extension DispatchQueue {

    /// The default queue, on which futures are observed and executed on.
    static var futures = DispatchQueue(label: "com.formbound.future.default", attributes: .concurrent)
}

import Dispatch

public func promise<T>(on queue: DispatchQueue = .futures, _ body: @escaping () throws -> T) -> Future<T> {
    return Promise(on: queue, body).future
}

public func promise<T>(
    _ type: T.Type,
    on queue: DispatchQueue = .futures,
    _ body: @escaping (@escaping (FutureValue<T>) -> Void) throws -> Void) -> Future<T> {

    return Promise(on: queue, body).future
}

/// A promise to provide a result later.
///
/// This is the provider API for `Future<T>`. If you want to return a `Future<T>`, you can use the global functions
/// `promise(), or create a new `Promise<T>` to fulfill in an asynchronous fashion.
/// To create a new promise, returning a `Future<T>`, follow this pattern:
/// ```
/// promise {
///     "Hello World!"
/// }
/// ```
/// The above function will return a `Future<String>` eventually carrying the stirng `Hello World!`.
///
/// You can also provide a future using a callback, like so:
/// ```
/// promise(String.self) { completion in
///     ... if success ...
///     completion(.fulfilled("Hello World!")
///     ... if error ...
///     completion(.rejected(error)
/// }
///
/// ```
/// If you want to provide a `Future<T>` in a completely custom manner, you can create a pending promise, resolve it
/// when convenient, and then return its `Future`:
/// ```
/// func someAsynOperation(args) -> Future<ResultType> {
///     let promise = Promise<ResultType>()
///     dispatchQueue.async {
///         ... if success ...
///         promise.fulfill(value)
///         ... if error ...
///         promise.reject(error)
///     }
///     return promise.future
/// }
/// ```
///
/// - Note: `Future` is the observable value, while `Promise` is the function that sets it.
public final class Promise<T> {

    /// The future value of this promise.
    fileprivate(set) public var future: Future<T>

    /// Creates a new pending `Promise`.
    public init() {
        future = Future<T>()
    }

    fileprivate convenience init(
        on dispatchQueue: DispatchQueue = .futures,
        _ body : @escaping (@escaping (FutureValue<T>) -> Void) throws -> Void) {
        self.init()

        dispatchQueue.async {
            do {
                try body { result in
                    self.resolve(result)
                }
            } catch {
                self.reject(error)
            }
        }
    }

    fileprivate convenience init(on queue: DispatchQueue = .futures, _ body: @escaping () throws -> T) {
        self.init()
        queue.async {
            self.resolve(FutureValue { try body() })
        }
    }
}

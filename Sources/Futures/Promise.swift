import Dispatch

/// Shorthand for creating a new `Future<T>`.
///
/// Note that the callback provided to this method will execute on the provided dispatch queue.
///
/// - Parameters:
///   - queue: Dispatch queue to execute the callback on.
///   - body: Function that returns a value, assigned to the future returned by this function.
/// - Returns: A future that will receive the eventual value.
public func promise<T>(on queue: DispatchQueue = .futures, _ body: @escaping () throws -> T) -> Future<T> {
    let promise = Promise<T>()

    queue.async {
        do {
            try promise.fulfill(body())
        } catch {
            promise.reject(error)
        }
    }

    return promise.future
}

/// Shorthand for creating a new `Future<T>`, in an asynchronous fashion.
///
/// Note that the callback provided to this method will execute on the provided dispatch queue.
///
/// - Parameters:
///   - type: Type of the future value.
///   - queue: Dispatch queue to execute the callback on.
///   - body: A function with a completion function as its parameter, taking a `FutureValue<T>`, which will be
///     used to resolve the future returned by this method.
///   - value: `FutureValue<T>` to resolve the future with.
/// - Returns: A future that will receive the eventual value.
public func promise<T>(
    _ type: T.Type,
    on queue: DispatchQueue = .futures,
    _ body: @escaping (@escaping (_ value: FutureValue<T>) -> Void) throws -> Void) -> Future<T> {

    let promise = Promise<T>()

    queue.async {
        do {
            let completion = { (value: FutureValue<T>) in
                promise.resolve(value)
            }

            try body(completion)
        } catch {
            promise.reject(error)
        }
    }

    return promise.future
}

/// A promise to provide a result later.
///
/// This is the provider API for `Future<T>`. If you want to return a `Future<T>`, you can use the global functions
/// `promise()`, or create a new `Promise<T>` to fulfill in an asynchronous fashion.
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
public struct Promise<T> {

    /// The future value of this promise.
    public let future: Future<T>

    /// Creates a new pending `Promise`.
    public init() {
        future = Future<T>()
    }
}

public extension Promise where T == Void {
    func fulfill() {
        self.fulfill(())
    }
}

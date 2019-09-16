import Dispatch

/// Shorthand for creating a new `Future<Value>`.
///
/// Note that the callback provided to this method will execute on the provided dispatch queue.
///
/// - Parameters:
///   - queue: Dispatch queue to execute the callback on.
///   - body: Function that returns a value, assigned to the future returned by this function.
/// - Returns: A future that will receive the eventual value.
public func promise<Value>(on queue: DispatchQueue = .futures, _ body: @escaping () throws -> Value) -> Future<Value> {
    let promise = Promise<Value>()

    queue.async {
        do {
            try promise.fulfill(body())
        } catch {
            promise.reject(error)
        }
    }

    return promise.future
}

/// Shorthand for creating a new `Future<Value>`, in an asynchronous fashion.
///
/// Note that the callback provided to this method will execute on the provided dispatch queue.
///
/// - Parameters:
///   - type: Type of the future value.
///   - queue: Dispatch queue to execute the callback on.
///   - body: A function with a completion function as its parameter, taking a `Result<Value, Error>`, which will be
///     used to resolve the future returned by this method.
///   - value: `Result<Value, Error>` to resolve the future with.
/// - Returns: A future that will receive the eventual value.
public func promise<Value>(
    _ type: Value.Type,
    on queue: DispatchQueue = .futures,
    _ body: @escaping (@escaping (_ value: Result<Value, Error>) -> Void) throws -> Void) -> Future<Value> {

    let promise = Promise<Value>()

    queue.async {
        do {
            let completion = { (value: Result<Value, Error>) in
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
/// This is the provider API for `Future<Value>`. If you want to return a `Future<Value>`, you can use
/// the global functions `promise()`, or create a new `Promise<Value>` to fulfill in an asynchronous fashion.
/// To create a new promise, returning a `Future<Value>`, follow this pattern:
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
///     completion(.fulfilled("Hello World!"))
///     ... if error ...
///     completion(.rejected(error))
/// }
///
/// ```
/// If you want to provide a `Future<Value>` in a completely custom manner, you can create a pending promise, resolve it
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
public struct Promise<Value> {

    /// The future value of this promise.
    public let future: Future<Value>

    /// Creates a new pending `Promise`.
    public init() {
        future = Future<Value>()
    }
}

public extension Promise where Value == Void {
    func fulfill() {
        self.fulfill(())
    }
}

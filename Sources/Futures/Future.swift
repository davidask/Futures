import Dispatch
import Foundation

private enum FutureState<Value> {
    case pending
    case finished(Result<Value, Error>)

    fileprivate func canTransition(to newState: FutureState<Value>) -> Bool {

        switch (self, newState) {
        case (.pending, .finished):
            return true
        default:
            return false
        }
    }
}

extension FutureState: CustomStringConvertible {
    var description: String {
        switch self {
        case .finished(let result):
            return "Finished(" + String(describing: result) + ")"
        case .pending:
            return "Pending"
        }
    }
}

public protocol AnyFutureObserver: AnyObject {
    func remove()
}

/// Used to keep track of observers, in order to supply the ability to
/// remove observers from a future, if the result of a future is no longer interesting.
///
/// The following methods return a `FutureObserver`:
/// - `Future<Value>.whenResolved()`
/// - `Future<Value>.whenFulfilled()`
/// - `Future<Value>.whenRejected()`
public final class FutureObserver<Value>: AnyFutureObserver {

    private let callback: (Result<Value, Error>) -> Void

    private let queue: DispatchQueue

    private weak var future: Future<Value>?

    fileprivate init(
        _ callback: @escaping (Result<Value, Error>) -> Void,
        future: Future<Value>,
        queue: DispatchQueue) {

        self.callback = callback
        self.future = future
        self.queue = queue
    }

    /// Removes the observer from its associated future. The observer will not be invoked
    /// after a call to `remove()` is made.
    public func remove() {
        future?.removeObserver(self)
    }

    fileprivate func invoke(_ value: Result<Value, Error>) {
        queue.async {
            self.callback(value)
        }
    }
}

extension FutureObserver: Equatable {
    public static func == (lhs: FutureObserver, rhs: FutureObserver) -> Bool {
        return lhs === rhs
    }
}

/// Container for a result that will be provided later.
///
/// Functions that promise to do work asynchronously return a `Future<Value>`. The receipient of a future can
/// observe it to be notified, or to queue more asynchronous work, when the operation completes.
///
/// A `Future<Value>` is regarded as:
/// * `resolved`, when a value is set
/// * `fulfilled`, when a value is set and successful
/// * `rejected`, when a value is not set, and an error occured
///
/// The provider of a `Future<Value>` creates a placeholder object before the actual result is available,
/// immeadiately returning the object, providing a dynamic way of structuring complex dependencies
/// for asynchronous work. This is common behavior in Future/Promise implementation across many languages.
/// Referencing these resources may be useful if you're unfamilliar with the concept of Promises/Futures:
///
/// - [Javascript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises)
/// - [Scala](http://docs.scala-lang.org/overviews/core/futures.html)
/// - [Python](https://docs.google.com/document/d/10WOZgLQaYNpOrag-eTbUm-JUCCfdyfravZ4qSOQPg1M/edit)
///
/// The provider of a `Future<Value>` may be implemented as follows:
/// ```
/// func performAsynchronousWork() -> Future<String> {
///     let promise = Promise<String>()
///     DispatchQueue.global().async {
///         ... on success ...
///         promise.fulfill("A string")
///         ... on failure ...
///         promise.reject(error)
///     }
///     return promise.future
/// }
/// ```
///
/// When receiving a `Future<Value>`, you have a number of options. You can immediately observe the result of the future
/// using `whenResolved()`, `whenFulfilled()`, or `whenRjected()`, or choose to do more asyncrhonous work before, or
/// parallel to observing.
/// Each `Future<Value>` can have multiple observers, which are used to both simply return
/// a result, or to queue up other futures.
///
/// To perform more asynchronous work, once a `Future<Value>` is fulfilled,
/// use `then()`. To transform the fulfilled value of a future into another value, use `thenThrowing()`.
///
/// Options for combining futures into a single future is provided using `and()`, `fold()`, and `Future<Value>.reduce()`
///
/// A `Future<Value>` differs from a `Promise<Value>` in that a future is the
/// container of a result; the promise being the function that sets that result.
/// This design decision was made, in this library as well as in many others, to
/// prevent receivers of `Future<Value>` to resolve the future themselves.
public final class Future<Value>: AnyFuture {

    fileprivate let stateQueue = DispatchQueue(label: "com.formbound.future.state", attributes: .concurrent)

    private var observers: [FutureObserver<Value>] = []

    private var state: FutureState<Value> {
        willSet {
            precondition(state.canTransition(to: newValue))
        }
    }

    /// Creates a pending future
    public init() {
        state = .pending
    }

    /// Creates a resolved future
    ///
    /// - Parameter resolved: `Result<Value, Error>`
    public init(resolved: Result<Value, Error>) {
        state = .finished(resolved)
    }

    /// Creates a resolved, fulfilled future
    ///
    /// - Parameter value: Value of the fulfilled future
    public convenience init(fulfilledWith value: Value) {
        self.init(resolved: .success(value))
    }

    /// Creates a resolved, fulfilled future
    ///
    /// - Parameter error: Error, rejecting the future
    public convenience init(rejectedWith error: Error) {
        self.init(resolved: .failure(error))
    }

    fileprivate func addObserver(_ observer: FutureObserver<Value>) {
        stateQueue.sync(flags: .barrier) {
            switch state {
            case .pending:
                observers.append(observer)
            case .finished(let result):
                observer.invoke(result)
            }
        }
    }

    fileprivate func removeObserver(_ observerToRemove: FutureObserver<Value>) {
        stateQueue.sync(flags: .barrier) {
            observers = observers.filter { observer in
                observer != observerToRemove
            }
        }
    }

    fileprivate func setValue(_ value: Result<Value, Error>) {
        stateQueue.sync(flags: .barrier) {

            guard case .pending = state else {
                return
            }

            state = .finished(value)

            for observer in observers {
                observer.invoke(value)
            }

            observers.removeAll(keepingCapacity: false)
        }
    }

    /// Indicates whether the future is pending
    public var isPending: Bool {
        return stateQueue.sync {
            guard case .pending = state else {
                return false
            }

            return true
        }
    }

    /// Indicates whether the future is resolved
    public var isResolved: Bool {
        if case .finished = state {
            return true
        } else {
            return false
        }
    }

    /// Indicates whether the future is fulfilled
    public var isFulfilled: Bool {
        return stateQueue.sync {
            guard case .finished(let result) = state, case .success = result else {
                return false
            }

            return true
        }
    }

    /// Indicates whether the future is rejected
    public var isRejected: Bool {
        return stateQueue.sync {
            guard case .finished(let result) = state, case .failure = result else {
                return false
            }

            return true
        }
    }

    /// Indicates the result of the future.
    /// Returns `nil` if the future is not resolved yet.
    public var result: Result<Value, Error>? {
        guard case .finished(let result) = state else {
            return nil
        }

        return result
    }
}

extension Future: Equatable {
    public static func == (lhs: Future, rhs: Future) -> Bool {
        return lhs === rhs
    }
}

public extension Future {

    /// When the current `Future` is fulfilled, run the provided callback returning a new `Future<Value>`.
    ///
    /// This allows you to dispatch new asynchronous operations as steps in a sequence of operations.
    /// Note that, based on the result, you can decide what asynchronous work to perform next.
    ///
    /// This function is best used when you have other APIs returning `Future<Value>`.
    ///
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new future.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future` and return a new `Future<Value>`.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<Value>`.
    ///   - value: The fulfilled value of this `Future<Value>`.
    /// - Returns: A future that will receive the eventual value.
    func then<NewValue>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (_ value: Value) -> Future<NewValue>) -> Future<NewValue> {

        let promise = Promise<NewValue>()

        whenResolved(on: queue) { result in
            do {
                let future = try callback(result.get())
                future.whenResolved(on: queue) { result in
                    promise.resolve(result)
                }
            } catch {
                promise.reject(error)
            }
        }

        return promise.future
    }

    /// When the current `Future` is rejected, run the provided callback reurning a new `Future<Value>`.
    ///
    /// This allows you to proceed with some other operation if the current `Future` was rejected, due to an error
    /// you can recover from.
    ///
    /// If the calback cannot provide a `Future` recovering from the error, an error inside the callback should be
    /// thrown, or a `Future` which is rejected should be returned.
    ///
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new future.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the error resulting in this `Future<Value>`s rejection.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<Value>`.
    ///           and return a new `Future<Value>`.
    /// - Returns: A future that will receive the eventual value.
    func thenIfError(
        on queue: DispatchQueue = .futures,
        callback: @escaping(Error) -> Future<Value>) -> Future<Value> {

        let promise = Promise<Value>()

        whenResolved(on: queue) { result in
            switch result {
            case .success(let value):
                promise.fulfill(value)
            case .failure(let error):
                let future = callback(error)
                future.whenResolved(on: queue) { result in
                    promise.resolve(result)
                }
            }
        }

        return promise.future
    }

    @available(*, deprecated, renamed: "thenIfError")
    func thenIfRejected(
        on queue: DispatchQueue = .futures,
        callback: @escaping(Error) -> Future<Value>) -> Future<Value> {
        return thenIfError(on: queue, callback: callback)
    }

    /// When the current `Future` is fulfilled, run the provided callback returning a fulfilled value of the
    /// `Future<NewValue>` returned by this method.
    ///
    ///
    /// If the calback cannot provide a a new value, an error inside the callback should be thrown.
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new value.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future` and return a new `Future<Value>`.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<Value>`.
    /// - Returns: A future that will receive the eventual value.
    func thenThrowing<NewValue>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (Value) throws -> NewValue) -> Future<NewValue> {

        return then(on: queue) { value in
            return promise(on: queue) {
                return try callback(value)
            }
        }
    }

    /// When the current `Future` is fulfilled, run the provided callback returning a fulfilled value of the
    /// `Future<NewValue>` returned by this method.
    ///
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new value.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future` and return a new `Future<Value>`.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<Value>`.
    /// - Returns: A future that will receive the eventual value.
    func map<NewValue>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (Value) -> NewValue) -> Future<NewValue> {

        let promise = Promise<NewValue>()

        whenResolved(on: queue) { result in
            promise.resolve(result.map(callback))
        }

        return promise.future
    }

    /// When the current `Future` is rejected, run the provided callback returning a fulfilled value of the
    /// `Future<NewValue>` returned by this method.
    ///
    /// This allows you to provide a future with an eventual value if the current `Future` was rejected, due
    /// to an error you can recover from.
    ///
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new value.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future<Value>`, and return
    ///               a new value of type `NewValue`.
    /// - Returns: A future that will receive the eventual value.
    func recover(on queue: DispatchQueue = .futures, callback: @escaping (Error) -> Value) -> Future<Value> {

        let promise = Promise<Value>()

        whenResolved(on: queue) { result in
            switch result {
            case .success(let value):
                promise.fulfill(value)
            case .failure(let promiseError):
                promise.fulfill(callback(promiseError))
            }
        }

        return promise.future
    }

    @available(*, deprecated, renamed: "recover")
    func mapIfRejected(on queue: DispatchQueue = .futures, callback: @escaping (Error) -> Value) -> Future<Value> {
        return recover(on: queue, callback: callback)
    }
}

public extension Future {

    /// Returns a new `Future`, that resolves when this **and** the provided future both are resolved.
    /// The returned future will provide the pair of values from this and the provided future.
    ///
    /// Note that the returned future will be rejected with the first error encountered.
    ///
    /// - Parameters:
    ///   - other: A `Future` to combine with this future.
    ///   - queue: Dispatch queue to observe on.
    /// - Returns: A future that will receive the eventual value.
    func and<NewValue>(_ other: Future<NewValue>, on queue: DispatchQueue = .futures) -> Future<(Value, NewValue)> {

        return then(on: queue) { value in
            let promise = Promise<(Value, NewValue)>()
            other.whenResolved(on: queue) { result in
                do {
                    try promise.fulfill((value, result.get()))
                } catch {
                    promise.reject(error)
                }
            }
            return promise.future
        }
    }

    /// Returns a new `Future<Value>` that fires only when this `Future<Value>` and all provided
    /// `Future<NewValue>`s complete.
    ///
    /// A combining function must be provided, resulting in a new future for any pair of
    /// `Future<NewValue>` and `Future<Value>`
    /// eventually resulting in a single `Future<Value>`.
    ///
    /// The returned `Future<Value>` will be rejected as soon as either this, or a provided future is rejected. However,
    /// a failure will not occur until all preceding `Future`s have been resolved. As soon as a rejection is
    /// encountered, there subsequent futures will not be waited for, resulting in the fastest possible rejection
    /// for the provided futures.
    ///
    /// - Parameters:
    ///   - futures: A sequence of `Future<NewValue>` to wait for.
    ///   - queue: Dispatch queue to observe on.
    ///   - combiningFunction: A function that will be used to fold the values of two
    ///                        `Future`s and return a new value wrapped in an `Future`.
    /// - Returns: A future that will receive the eventual value.
    func fold<NewValue, S: Sequence>(
        _ futures: S,
        on queue: DispatchQueue = .futures,
        with combiningFunction: @escaping (Value, NewValue) -> Future<Value>) -> Future<Value>
        where S.Element == Future<NewValue> {

        return futures.reduce(self) { future1, future2 in
            return future1.and(future2, on: queue).then(on: queue) { value1, value2 in
                return combiningFunction(value1, value2)
            }
        }
    }

    /// Returns a new `Future<Value>` that fires only when all the provided `Future<NewValue>`s have been resolved.
    /// The returned future carries the value of the `initialResult` provided, combined with the result of
    /// fulfilled `Future<NewValue>`s using the provided `nextPartialResult` function.
    ///
    /// The returned `Future<Value>` will be rejected as soon as either this, or a provided future is rejected. However,
    /// a failure will not occur until all preceding `Future`s have been resolved. As soon as a rejection is
    /// encountered, there subsequent futures will not be waited for, resulting in the fastest possible rejection
    /// for the provided futures.
    ///
    /// - Parameters:
    ///   - futures: A sequence of `Future<NewValue>` to wait for.
    ///   - queue: Dispatch queue to observe on.
    ///   - initialResult: An initial result to begin the reduction.
    ///   - nextPartialResult: The bifunction used to produce partial results.
    /// - Returns: A future that will receive the reduced value.
    static func reduce<NewValue, S: Sequence>(
        _ futures: S,
        on queue: DispatchQueue = .futures,
        initialResult: Value,
        nextPartialResult: @escaping (Value, NewValue) -> Value) -> Future<Value>
        where S.Element == Future<NewValue> {

        let initialResult = Future<Value>(fulfilledWith: initialResult)

        return initialResult.fold(futures, on: queue) { value1, value2 in
            return Future(fulfilledWith: nextPartialResult(value1, value2))
        }
    }

    /// Returns a new `Future<Value>` that will resolve with result of this `Future` **after**
    /// the provided `Future<Void>` has been resolved.
    ///
    /// Note that the provided callback is called regardless of whether this future is fulfilled or rejected.
    /// The returned `Future<Value>` is fulfilled **only** if this and the provided future both are fullfilled.
    ///
    /// In short, the returned future will forward the result of this future, if the provided future
    /// is fulfilled.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - initialResult: An initial result to begin the reduction.
    ///   - callback: A callback that returns a `Future<Void>` to be deferred.
    /// - Returns: A future that will receive the eventual value.
    func always(on queue: DispatchQueue = .futures, callback: @escaping () -> Future<Void>) -> Future<Value> {
        let promise = Promise<Value>()

        whenResolved(on: queue) { result1 in
            callback().whenResolved(on: queue) { result2 in
                switch result1 {
                case .success(let value):
                    switch result2 {
                    case .success:
                        promise.fulfill(value)
                    case .failure(let error):
                        promise.reject(error)
                    }
                case .failure(let error):
                    promise.reject(error)
                }

            }
        }

        return promise.future
    }

    /// Returns a new `Future<Value>` that will resolve with the result of this `Future` **after** the provided callback
    /// runs.
    ///
    /// Note that the provided callback is called regardless of whether this future is fulfilled or rejected.
    ///
    /// This method is useful for times you want to execute code at the end of a chain of operations, regarless
    /// of whether successful or not.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback to run.
    /// - Returns: A future that will receive the eventual value.
    func alwaysThrowing(on queue: DispatchQueue = .futures, callback: @escaping () throws -> Void) -> Future<Value> {
        let promise = Promise<Value>()

        whenResolved(on: queue) { result in
            do {
                try callback()
                promise.resolve(result)
            } catch {
                promise.reject(error)
            }
        }

        return promise.future
    }

    /// Returns a new Future<Void>, effectively discarding the result of the caller.
    ///
    /// This method is useful when the value of a future is of no consequence.
    ///
    /// - Parameter queue: Dispatch queue to discard on.
    /// - Returns: A future that will receive the eventual value.
    @discardableResult
    func discard(on queue: DispatchQueue = .futures) -> Future<Void> {

        let promise = Promise<Void>()

        whenFulfilled(on: queue) { _ in
            promise.fulfill()
        }

        whenRejected { error in
            promise.reject(error)
        }

        return promise.future
    }
}

public extension Future {

    /// Adds a `FutureObserver<Value>` to this `Future<Value>`, that is called when the future is fulfilled.
    ///
    /// An observer callback cannot return a value, meaning that this function cannot be chained from.
    /// If you are attempting to create a sequence of operations based on the result of another future,
    /// consider using `then()`, `thenThrowing()`, or some of the other methods available.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback invoked with the fulfilled result of this future
    /// - Returns: A `FutureObserver<Value>`, which can be used to remove the observer from this future.
    @discardableResult
    func whenFulfilled(
        on queue: DispatchQueue = .futures,
        callback: @escaping (Value) -> Void) -> FutureObserver<Value> {

        return whenResolved(on: queue) { result in
            guard case .success(let value) = result else {
                return
            }

            callback(value)
        }
    }

    /// Adds a `FutureObserver<Value>` to this `Future<Value>`, that is called when the future is rejected.
    ///
    /// An observer callback cannot return a value, meaning that this function cannot be chained from.
    /// If you are attempting to create a sequence of operations based on the result of another future,
    /// consider using `then()`, `thenThrowing()`, or some of the other methods available.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback invoked with the rejection error of this future
    /// - Returns: A `FutureObserver<Value>`, which can be used to remove the observer from this future.
    @discardableResult
    func whenRejected(
        on queue: DispatchQueue = .futures,
        callback: @escaping (Error) -> Void) -> FutureObserver<Value> {

        return whenResolved(on: queue) { result in
            guard case .failure(let error) = result else {
                return
            }

            callback(error)
        }
    }

    /// Adds a `FutureObserver<Value>` to this `Future<Value>`, that is called when the future is resolved.
    ///
    /// An observer callback cannot return a value, meaning that this function cannot be chained from.
    /// If you are attempting to create a sequence of operations based on the result of another future,
    /// consider using `then()`, `thenThrowing()`, or some of the other methods available.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback invoked with the resolved `Result<Value, Error>` of this future
    /// - Returns: A `FutureObserver<Value>`, which can be used to remove the observer from this future.
    @discardableResult
    func whenResolved(
        on queue: DispatchQueue = .futures,
        callback: @escaping (Result<Value, Error>) -> Void) -> FutureObserver<Value> {
        let observer = FutureObserver<Value>(callback, future: self, queue: queue)

        self.addObserver(observer)

        return observer

    }
}

public extension Promise {

    /// Fullfills the promise, setting a value to this promise's `Future`
    ///
    /// - Parameter value: Value to fulfill with
    func fulfill(_ value: Value) {
        future.setValue(.success(value))
    }

    /// Rejects the promise, setting an error to this promise's `Future`
    ///
    /// - Parameter error: Error to reject with
    func reject(_ error: Error) {
        future.setValue(.failure(error))
    }

    /// Resolves the promise, setting either a value or an error to this promise's `Future`
    ///
    /// - Parameter result: `Result<Value, Error>` to resolve with
    func resolve(_ result: Result<Value, Error>) {
        future.setValue(result)
    }
}

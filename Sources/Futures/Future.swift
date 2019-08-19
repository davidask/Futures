import Dispatch
import Foundation

private enum FutureState<Result> {
    case pending
    case finished(FutureResult<Result>)

    fileprivate func canTransition(to newState: FutureState<Result>) -> Bool {

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
/// - `Future<T>.whenResolved()`
/// - `Future<T>.whenFulfilled()`
/// - `Future<T>.whenRejected()`
public final class FutureObserver<T>: AnyFutureObserver {

    private let callback: (FutureResult<T>) -> Void

    private let queue: DispatchQueue

    private weak var future: Future<T>?

    fileprivate init(_ callback: @escaping (FutureResult<T>) -> Void, future: Future<T>, queue: DispatchQueue) {
        self.callback = callback
        self.future = future
        self.queue = queue
    }

    /// Removes the observer from its associated future. The observer will not be invoked
    /// after a call to `remove()` is made.
    public func remove() {
        future?.removeObserver(self)
    }

    fileprivate func invoke(_ value: FutureResult<T>) {
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
/// Functions that promise to do work asynchronously return a `Future<T>`. The receipient of a future can
/// observe it to be notified, or to queue more asynchronous work, when the operation completes.
///
/// A `Future<T>` is regarded as:
/// * `resolved`, when a value is set
/// * `fulfilled`, when a value is set and successful
/// * `rejected`, when a value is not set, and an error occured
///
/// The provider of a `Future<T>` creates a placeholder object before the actual result is available,
/// immeadiately returning the object, providing a dynamic way of structuring complex dependencies
/// for asynchronous work. This is common behavior in Future/Promise implementation across many languages.
/// Referencing these resources may be useful if you're unfamilliar with the concept of Promises/Futures:
///
/// - [Javascript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises)
/// - [Scala](http://docs.scala-lang.org/overviews/core/futures.html)
/// - [Python](https://docs.google.com/document/d/10WOZgLQaYNpOrag-eTbUm-JUCCfdyfravZ4qSOQPg1M/edit)
///
/// The provider of a `Future<T>` may be implemented as follows:
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
/// When receiving a `Future<T>`, you have a number of options. You can immediately observe the result of the future
/// using `whenResolved()`, `whenFulfilled()`, or `whenRjected()`, or choose to do more asyncrhonous work before, or
/// parallel to observing.
/// Each `Future<T>` can have multiple observers, which are used to both simply return a result, or to queue up other
/// futures.
///
/// To perform more asynchronous work, once a `Future<T>` is fulfilled, use `then()`. To transform the fulfilled value
/// of a future into another value, use `map()`.
///
/// Options for combining futures into a single future is provided using `and()`, `fold()`, and `Future<T>.reduce()`
///
/// A `Future<T>` differs from a `Promise<T>` in that a future is the container of a result; the promise being the
/// function that sets that result. This design decision was made, in this library as well as in many others, to
/// prevent receivers of `Future<T>` to resolve the future themselves.
public final class Future<T>: AnyFuture {

    fileprivate let stateQueue = DispatchQueue(label: "com.formbound.future.state", attributes: .concurrent)

    private var observers: [FutureObserver<T>] = []

    private var state: FutureState<T> {
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
    /// - Parameter resolved: `FutureResult<T>`
    public init(resolved: FutureResult<T>) {
        state = .finished(resolved)
    }

    /// Creates a resolved, fulfilled future
    ///
    /// - Parameter value: Value of the fulfilled future
    public convenience init(fulfilledWith value: T) {
        self.init(resolved: .fulfilled(value))
    }

    /// Creates a resolved, fulfilled future
    ///
    /// - Parameter error: Error, rejecting the future
    public convenience init(rejectedWith error: Error) {
        self.init(resolved: .rejected(error))
    }

    fileprivate func addObserver(_ observer: FutureObserver<T>) {
        stateQueue.sync(flags: .barrier) {
            switch state {
            case .pending:
                observers.append(observer)
            case .finished(let result):
                observer.invoke(result)
            }
        }
    }

    fileprivate func removeObserver(_ observerToRemove: FutureObserver<T>) {
        stateQueue.sync(flags: .barrier) {
            observers = observers.filter { observer in
                observer != observerToRemove
            }
        }
    }

    fileprivate func setValue(_ value: FutureResult<T>) {
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
            guard case .finished(let result) = state, case .fulfilled = result else {
                return false
            }

            return true
        }
    }

    /// Indicates whether the future is rejected
    public var isRejected: Bool {
        return stateQueue.sync {
            guard case .finished(let result) = state, case .rejected = result else {
                return false
            }

            return true
        }
    }

    /// Indicates the result of the future.
    /// Returns `nil` if the future is not resolved yet.
    public var result: FutureResult<T>? {
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

    /// When the current `Future` is fulfilled, run the provided callback returning a new `Future<T>`.
    ///
    /// This allows you to dispatch new asynchronous operations as steps in a sequence of operations.
    /// Note that, based on the result, you can decide what asynchronous work to perform next.
    ///
    /// This function is best used when you have other APIs returning `Future<T>`.
    ///
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new future.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future` and return a new `Future<T>`.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<T>`.
    ///   - value: The fulfilled value of this `Future<T>`.
    /// - Returns: A future that will receive the eventual value.
    func flatMap<U>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (_ value: T) -> Future<U>) -> Future<U> {

        let promise = Promise<U>()

        whenResolved(on: queue) { result in
            do {
                let future = try callback(result.unwrap())
                future.whenResolved(on: queue) { result in
                    promise.resolve(result)
                }
            } catch {
                promise.reject(error)
            }
        }

        return promise.future
    }

    @available(*, deprecated, renamed: "flatMap")
    func then<U>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (_ value: T) -> Future<U>) -> Future<U> {
        return flatMap(on: queue, callback: callback)
    }

    /// When the current `Future` is rejected, run the provided callback reurning a new `Future<T>`.
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
    ///   - callback: A function that will receive the error resulting in this `Future<T>`s rejection.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<T>`.
    ///           and return a new `Future<T>`.
    /// - Returns: A future that will receive the eventual value.
    func flatMapError(
        on queue: DispatchQueue = .futures,
        callback: @escaping(Error) -> Future<T>) -> Future<T> {

        let promise = Promise<T>()

        whenResolved(on: queue) { result in
            switch result {
            case .fulfilled(let value):
                promise.fulfill(value)
            case .rejected(let error):
                let future = callback(error)
                future.whenResolved(on: queue) { result in
                    promise.resolve(result)
                }
            }
        }

        return promise.future
    }

    @available(*, deprecated, renamed: "flatMapError")
    func thenIfRejected(on queue: DispatchQueue = .futures, callback: @escaping(Error) -> Future<T>) -> Future<T> {
        return flatMapError(on: queue, callback: callback)
    }

    /// When the current `Future` is fulfilled, run the provided callback returning a fulfilled value of the
    /// `Future<U>` returned by this method.
    ///
    ///
    /// If the calback cannot provide a a new value, an error inside the callback should be thrown.
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new value.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future` and return a new `Future<T>`.
    ///           Throwing an error in this function will result in the rejection of the returned `Future<T>`.
    /// - Returns: A future that will receive the eventual value.
    func flatMapThrowing<U>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (T) throws -> U) -> Future<U> {

        return flatMap(on: queue) { value in
            return promise(on: queue) {
                return try callback(value)
            }
        }
    }

    @available(*, deprecated, renamed: "flatMapThrowing")
    func map<U>(
        on queue: DispatchQueue = .futures,
        callback: @escaping (T) throws -> U) -> Future<U> {
        return flatMapThrowing(on: queue, callback: callback)
    }

    /// When the current `Future` is rejected, run the provided callback returning a fulfilled value of the
    /// `Future<U>` returned by this method.
    ///
    /// This allows you to provide a future with an eventual value if the current `Future` was rejected, due
    /// to an error you can recover from.
    ///
    /// If the calback cannot provide a a new value, an error inside the callback should be thrown.
    /// - Parameters:
    ///   - queue: DispatchQueue on which to resolve and return a new value.
    ///            Defaults to `DispatchQueue.futures`.
    ///   - callback: A function that will receive the value of this `Future<T>`, and return a new value of type `U`.
    /// - Returns: A future that will receive the eventual value.
    func recover(on queue: DispatchQueue = .futures, callback: @escaping (Error) -> T) -> Future<T> {

        let promise = Promise<T>()

        whenResolved(on: queue) { result in
            switch result {
            case .fulfilled(let value):
                promise.fulfill(value)
            case .rejected(let promiseError):
                promise.fulfill(callback(promiseError))
            }
        }

        return promise.future
    }

    @available(*, deprecated, renamed: "recover")
    func mapIfRejected(on queue: DispatchQueue = .futures, callback: @escaping (Error) -> T) -> Future<T> {
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
    func and<U>(_ other: Future<U>, on queue: DispatchQueue = .futures) -> Future<(T, U)> {

        return flatMap(on: queue) { value in
            let promise = Promise<(T, U)>()
            other.whenResolved(on: queue) { result in
                do {
                    try promise.fulfill((value, result.unwrap()))
                } catch {
                    promise.reject(error)
                }
            }
            return promise.future
        }
    }

    /// Returns a new `Future<T>` that fires only when this `Future<T>` and all provided `Future<U>`s complete.
    ///
    /// A combining function must be provided, resulting in a new future for any pair of `Future<U>` and `Future<T>`
    /// eventually resulting in a single `Future<T>`.
    ///
    /// The returned `Future<T>` will be rejected as soon as either this, or a provided future is rejected. However,
    /// a failure will not occur until all preceding `Future`s have been resolved. As soon as a rejection is
    /// encountered, there subsequent futures will not be waited for, resulting in the fastest possible rejection
    /// for the provided futures.
    ///
    /// - Parameters:
    ///   - futures: A sequence of `Future<U>` to wait for.
    ///   - queue: Dispatch queue to observe on.
    ///   - combiningFunction: A function that will be used to fold the values of two
    ///                        `Future`s and return a new value wrapped in an `Future`.
    /// - Returns: A future that will receive the eventual value.
    func fold<U, S: Sequence>(
        _ futures: S,
        on queue: DispatchQueue = .futures,
        with combiningFunction: @escaping (T, U) -> Future<T>) -> Future<T> where S.Element == Future<U> {

        return futures.reduce(self) { future1, future2 in
            return future1.and(future2, on: queue).flatMap(on: queue) { value1, value2 in
                return combiningFunction(value1, value2)
            }
        }
    }

    /// Returns a new `Future<T>` that fires only when all the provided `Future<U>`s have been resolved.
    /// The returned future carries the value of the `initialResult` provided, combined with the result of
    /// fulfilled `Future<U>`s using the provided `nextPartialResult` function.
    ///
    /// The returned `Future<T>` will be rejected as soon as either this, or a provided future is rejected. However,
    /// a failure will not occur until all preceding `Future`s have been resolved. As soon as a rejection is
    /// encountered, there subsequent futures will not be waited for, resulting in the fastest possible rejection
    /// for the provided futures.
    ///
    /// - Parameters:
    ///   - futures: A sequence of `Future<U>` to wait for.
    ///   - queue: Dispatch queue to observe on.
    ///   - initialResult: An initial result to begin the reduction.
    ///   - nextPartialResult: The bifunction used to produce partial results.
    /// - Returns: A future that will receive the reduced value.
    static func reduce<U, S: Sequence>(
        _ futures: S,
        on queue: DispatchQueue = .futures,
        initialResult: T,
        nextPartialResult: @escaping (T, U) -> T) -> Future<T> where S.Element == Future<U> {

        let initialResult = Future<T>(fulfilledWith: initialResult)

        return initialResult.fold(futures, on: queue) { value1, value2 in
            return Future(fulfilledWith: nextPartialResult(value1, value2))
        }
    }

    /// Returns a new `Future<T>` that will resolve with result of this `Future` **after** the provided `Future<Void>`
    /// has been resolved.
    ///
    /// Note that the provided callback is called regardless of whether this future is fulfilled or rejected.
    /// The returned `Future<T>` is fulfilled **only** if this and the provided future both are fullfilled.
    ///
    /// In short, the returned future will forward the result of this future, if the provided future
    /// is fulfilled.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - initialResult: An initial result to begin the reduction.
    ///   - callback: A callback that returns a `Future<Void>` to be deferred.
    /// - Returns: A future that will receive the eventual value.
    func always(on queue: DispatchQueue = .futures, callback: @escaping () -> Future<Void>) -> Future<T> {
        let promise = Promise<T>()

        whenResolved(on: queue) { result1 in
            callback().whenResolved(on: queue) { result2 in
                switch result1 {
                case .fulfilled(let value):
                    switch result2 {
                    case .fulfilled:
                        promise.fulfill(value)
                    case .rejected(let error):
                        promise.reject(error)
                    }
                case .rejected(let error):
                    promise.reject(error)
                }

            }
        }

        return promise.future
    }

    /// Returns a new `Future<T>` that will resolve with the result of this `Future` **after** the provided callback
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
    func alwaysThrowing(on queue: DispatchQueue = .futures, callback: @escaping () throws -> Void) -> Future<T> {
        let promise = Promise<T>()

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

    /// Adds a `FutureObserver<T>` to this `Future<T>`, that is called when the future is fulfilled.
    ///
    /// An observer callback cannot return a value, meaning that this function cannot be chained from.
    /// If you are attempting to create a sequence of operations based on the result of another future,
    /// consider using `then()`, `map()`, or some of the other methods available.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback invoked with the fulfilled result of this future
    /// - Returns: A `FutureObserver<T>`, which can be used to remove the observer from this future.
    @discardableResult
    func whenFulfilled(on queue: DispatchQueue = .futures, callback: @escaping (T) -> Void) -> FutureObserver<T> {
        return whenResolved(on: queue) { result in
            guard case .fulfilled(let value) = result else {
                return
            }

            callback(value)
        }
    }

    /// Adds a `FutureObserver<T>` to this `Future<T>`, that is called when the future is rejected.
    ///
    /// An observer callback cannot return a value, meaning that this function cannot be chained from.
    /// If you are attempting to create a sequence of operations based on the result of another future,
    /// consider using `then()`, `map()`, or some of the other methods available.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback invoked with the rejection error of this future
    /// - Returns: A `FutureObserver<T>`, which can be used to remove the observer from this future.
    @discardableResult
    func whenRejected(on queue: DispatchQueue = .futures, callback: @escaping (Error) -> Void) -> FutureObserver<T> {
        return whenResolved(on: queue) { result in
            guard case .rejected(let error) = result else {
                return
            }

            callback(error)
        }
    }

    /// Adds a `FutureObserver<T>` to this `Future<T>`, that is called when the future is resolved.
    ///
    /// An observer callback cannot return a value, meaning that this function cannot be chained from.
    /// If you are attempting to create a sequence of operations based on the result of another future,
    /// consider using `then()`, `map()`, or some of the other methods available.
    ///
    /// - Parameters:
    ///   - queue: Dispatch queue to observe on.
    ///   - callback: Callback invoked with the resolved `FutureResult<T>` of this future
    /// - Returns: A `FutureObserver<T>`, which can be used to remove the observer from this future.
    @discardableResult
    func whenResolved(
        on queue: DispatchQueue = .futures,
        callback: @escaping (FutureResult<T>) -> Void) -> FutureObserver<T> {
        let observer = FutureObserver<T>(callback, future: self, queue: queue)

        self.addObserver(observer)

        return observer

    }
}

public extension Promise {

    /// Fullfills the promise, setting a value to this promise's `Future`
    ///
    /// - Parameter value: Value to fulfill with
    func fulfill(_ value: T) {
        future.setValue(.fulfilled(value))
    }

    /// Rejects the promise, setting an error to this promise's `Future`
    ///
    /// - Parameter error: Error to reject with
    func reject(_ error: Error) {
        future.setValue(.rejected(error))
    }

    /// Resolves the promise, setting either a value or an error to this promise's `Future`
    ///
    /// - Parameter result: `FutureResult<T>` to resolve with
    func resolve(_ result: FutureResult<T>) {
        future.setValue(result)
    }
}

import Dispatch

private enum FutureState<Value> {
    case pending
    case finished(FutureValue<Value>)

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

public protocol AnyFutureObserver: class {
    func remove()
}

public final class FutureObserver<T>: AnyFutureObserver {
    public typealias Callback = (FutureValue<T>) -> Void

    private let callback: Callback

    private let queue: DispatchQueue

    private weak var future: Future<T>?

    fileprivate init(_ callback: @escaping Callback, future: Future<T>, queue: DispatchQueue) {
        self.callback = callback
        self.future = future
        self.queue = queue
    }

    public func remove() {
        future?.removeObserver(self)
    }

    fileprivate func invoke(_ value: FutureValue<T>) {
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

public final class Future<T>: AnyFuture {

    private let stateQueue = DispatchQueue(label: "com.formbound.future.state", attributes: .concurrent)

    private var observers: [FutureObserver<T>] = []

    private var state: FutureState<T> {
        willSet {
            precondition(state.canTransition(to: newValue))
        }
    }

    public init() {
        state = .pending
    }

    public init(_ resolved: FutureValue<T>) {
        state = .finished(resolved)
    }

    public convenience init(_ value: T) {
        self.init(.fulfilled(value))
    }

    public convenience init(_ error: Error) {
        self.init(.rejected(error))
    }

    private func addObserver(_ observer: FutureObserver<T>) {
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

    fileprivate func resolve(_ result: FutureValue<T>) {
        stateQueue.sync(flags: .barrier) {

            guard case .pending = state else {
                return
            }

            state = .finished(result)

            for observer in observers {
                observer.invoke(result)
            }

            observers.removeAll(keepingCapacity: false)
        }
    }
}

extension Future: Equatable {
    public static func == (lhs: Future, rhs: Future) -> Bool {
        return lhs === rhs
    }
}

public extension Future {

    var isPending: Bool {
        return stateQueue.sync {
            guard case .pending = state else {
                return false
            }

            return true
        }
    }

    var isFulfilled: Bool {
        return stateQueue.sync {
            guard case .finished(let result) = state, case .fulfilled = result else {
                return false
            }

            return true
        }
    }

    var isRejected: Bool {
        return stateQueue.sync {
            guard case .finished(let result) = state, case .rejected = result else {
                return false
            }

            return true
        }
    }
}

public extension Future {

    func await() throws -> T {

        let semaphore = DispatchSemaphore(value: 0)
        var value: FutureValue<T>!

        whenResolved(on: .futureAwait) { result in
            value = result
            semaphore.signal()
        }

        semaphore.wait()
        return try value.unwrap()
    }
}

public extension Future {

    func then<U>(
        on queue: DispatchQueue = .futures,
        body: @escaping (T) throws -> Future<U>) -> Future<U> {

        let promise = Promise<U>()

        whenResolved(on: queue) { result in
            do {
                let future = try body(result.unwrap())
                future.whenResolved(on: queue) { result in
                    promise.resolve(FutureValue { try result.unwrap() })
                }
            } catch {
                promise.reject(error)
            }
        }

        return promise.future
    }

    func thenIfRejected(on queue: DispatchQueue = .futures, body: @escaping(Error) -> Future<T>) -> Future<T> {
        let promise = Promise<T>()

        whenResolved(on: queue) { result in
            switch result {
            case .fulfilled(let value):
                promise.fulfill(value)
            case .rejected(let error):
                let future = body(error)
                future.whenResolved(on: queue) { result in
                    promise.resolve(result)
                }
            }
        }

        return promise.future
    }

    func map<U>(
        on queue: DispatchQueue = .futures,
        body: @escaping (T) throws -> U) -> Future<U> {

        return then(on: queue) { value in
            return promise(on: queue) {
                return try body(value)
            }
        }
    }

    func mapIfRejected(on queue: DispatchQueue = .futures, body: @escaping (Error) throws -> T) -> Future<T> {

        let promise = Promise<T>()

        whenResolved(on: queue) { result in
            switch result {
            case .fulfilled(let value):
                promise.fulfill(value)
            case .rejected(let promiseError):
                do {
                    try promise.fulfill(body(promiseError))
                } catch {
                    promise.reject(error)
                }
            }
        }

        return promise.future
    }
}

public extension Future {

    func and<U>(_ other: Future<U>, on queue: DispatchQueue = .futures) -> Future<(T, U)> {

        return then(on: queue) { value in
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

    func fold<U, S: Sequence>(
        _ futures: S,
        on queue: DispatchQueue = .futures,
        with combiningFunction: @escaping (T, U) -> Future<T>) -> Future<T> where S.Element == Future<U> {

        return futures.reduce(self) { future1, future2 in
            return future1.and(future2, on: queue).then(on: queue) { value1, value2 in
                return combiningFunction(value1, value2)
            }
        }
    }

    static func reduce<U, S: Sequence>(
        _ futures: S,
        on queue: DispatchQueue = .futures,
        initialResult: T,
        nextPartialResult: @escaping (T, U) -> T) -> Future<T> where S.Element == Future<U> {

        let initialResult = Future<T>(initialResult)

        return initialResult.fold(futures, on: queue) { value1, value2 in
            return Future(nextPartialResult(value1, value2))
        }
    }
}

public extension Future {

    @discardableResult
    func whenFulfilled(on queue: DispatchQueue = .futures, body: @escaping (T) -> Void) -> FutureObserver<T> {
        return whenResolved(on: queue) { result in
            guard case .fulfilled(let value) = result else {
                return
            }

            body(value)
        }
    }

    @discardableResult
    func whenRejected(on queue: DispatchQueue = .futures, body: @escaping (Error) -> Void) -> FutureObserver<T> {
        return whenResolved(on: queue) { result in
            guard case .rejected(let error) = result else {
                return
            }

            body(error)
        }
    }

    @discardableResult
    func whenResolved(
        on queue: DispatchQueue = .futures,
        body: @escaping FutureObserver<T>.Callback) -> FutureObserver<T> {
        let observer = FutureObserver<T>(body, future: self, queue: queue)

        self.addObserver(observer)

        return observer

    }

    func perform(
        on queue: DispatchQueue = .futures,
        body: @escaping (T, @escaping () -> Void) throws -> Void) -> Future<T> {

        return then(on: queue) { result in

            let promise = Promise<T>()
            let completion = {
                promise.fulfill(result)
            }

            try body(result, completion)
            return promise.future
        }
    }
}

public extension Promise {

    func fulfill(_ value: T) {
        future.resolve(.fulfilled(value))
    }

    func reject(_ error: Error) {
        future.resolve(.rejected(error))
    }

    func resolve(_ result: FutureValue<T>) {
        future.resolve(result)
    }
}

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

public typealias FutureObserver<Value> = (FutureValue<Value>) -> Void

public protocol AnyFuture: class, Equatable {
    var isPending: Bool { get }
    var isFulfilled: Bool { get }
    var isRejected: Bool { get }
}

public extension AnyFuture {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs == rhs
    }
}

public final class Future<T>: AnyFuture {

    private let stateQueue = DispatchQueue(label: "com.formbound.future.sate")

    private var observers: [FutureObserver<T>] = []

    private var state: FutureState<T> {
        willSet {
            precondition(state.canTransition(to: newValue))
        }
    }

    fileprivate init() {
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

    private func addObserver(on queue: DispatchQueue, observer: @escaping FutureObserver<T>) {
        stateQueue.sync {
            switch state {
            case .pending:
                observers.append({ result in
                    queue.async {
                        observer(result)
                    }
                })
            case .finished(let result):
                queue.async {
                    observer(result)
                }
            }
        }
    }

    fileprivate func resolve(_ result: FutureValue<T>) {
        stateQueue.sync {

            guard case .pending = state else {
                return
            }

            state = .finished(result)

            for observer in observers {
                observer(result)
            }

            observers.removeAll(keepingCapacity: false)
        }
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

    func then<U>(
        on queue: DispatchQueue = .futures,
        body: @escaping (T) throws -> Future<U>) -> Future<U> {

        let promise = Promise<U>()

        addObserver(on: queue) { result in
            do {
                let future = try body(result.unwrap())
                future.addObserver(on: queue) { result in
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

        addObserver(on: queue) { result in
            switch result {
            case .fulfilled(let value):
                promise.fulfill(value)
            case .rejected(let error):
                let future = body(error)
                future.addObserver(on: queue) { result in
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

        addObserver(on: queue) { result in
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
            other.addObserver(on: queue) { result in
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

    func whenFulfilled(on queue: DispatchQueue = .futures, body: @escaping (T) -> Void) {
        addObserver(on: queue) { result in
            guard case .fulfilled(let value) = result else {
                return
            }

            body(value)
        }
    }

    func whenRejected(on queue: DispatchQueue = .futures, body: @escaping (Error) -> Void) {
        addObserver(on: queue) { result in
            guard case .rejected(let error) = result else {
                return
            }

            body(error)
        }
    }

    func whenResolved(on queue: DispatchQueue = .futures, body: @escaping (FutureValue<T>) -> Void) {
        addObserver(on: queue, observer: body)

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

public extension Future {

    func await() throws -> T {

        let semaphore = DispatchSemaphore(value: 0)
        var value: FutureValue<T>!

        addObserver(on: .futureAwait) { result in
            value = result
            semaphore.signal()
        }

        semaphore.wait()
        return try value.unwrap()
    }
}

public func promise<T>(on queue: DispatchQueue = .futures, _ body: @escaping () throws -> T) -> Future<T> {
    return Promise(on: queue, body).future
}

public func promise<T>(
    _ type: T.Type,
    on queue: DispatchQueue = .futures,
    _ body: @escaping (@escaping (FutureValue<T>) -> Void) throws -> Void) -> Future<T> {

    return Promise(on: queue, body).future
}

public final class Promise<T> {
    fileprivate(set) public var future: Future<T>

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

    public func fulfill(_ value: T) {
        future.resolve(.fulfilled(value))
    }

    public func reject(_ error: Error) {
        future.resolve(.rejected(error))
    }

    public func resolve(_ result: FutureValue<T>) {
        future.resolve(result)
    }
}

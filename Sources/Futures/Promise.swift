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
}

import Foundation

public enum FutureValue<Value> {
    case fulfilled(Value)
    case rejected(Error)

    public init(_ capturing: () throws -> Value) {
        do {
            self = .fulfilled(try capturing())
        } catch {
            self = .rejected(error)
        }
    }

    public init(_ value: Value) {
        self = .fulfilled(value)
    }

    public init(_ error: Error) {
        self = .rejected(error)
    }

    public var value: Value? {
        guard case .fulfilled(let value) = self else {
            return nil
        }

        return value
    }

    public var error: Error? {
        guard case .rejected(let error) = self else {
            return nil
        }

        return error
    }

    public var isError: Bool {

        switch self {

        case .fulfilled:
            return false

        case .rejected:
            return true
        }
    }

    @discardableResult
    public func unwrap() throws -> Value {

        switch self {

        case .fulfilled(let value):
            return value

        case .rejected(let error):
            throw error
        }
    }

    public func flatMap<U>(_ transform: (Value) -> FutureValue<U>) -> FutureValue<U> {

        switch self {

        case .fulfilled(let value):
            return transform(value)

        case .rejected(let error):
            return .rejected(error)
        }
    }

    public func map<U>(_ transform: (Value) throws -> U) -> FutureValue<U> {

        switch self {

        case .fulfilled(let value):
            return FutureValue<U> {
                try transform(value)

            }
        case .rejected(let error):
            return .rejected(error)
        }
    }

    public var description: String {
        switch self {
        case .fulfilled(let value):
            return "Fulfilled (" + String(describing: value) + ")"
        case .rejected(let error):
            return "Rejected (" + String(describing: error) + ")"
        }
    }
}

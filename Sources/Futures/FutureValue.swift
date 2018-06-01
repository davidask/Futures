import Dispatch

/// Value of a future, being either rejected with an error or fulfilled with a value.
///
/// - fulfilled: A fulfilled future, with a value.
/// - rejected: A rejected future, with an error.
public enum FutureValue<T> {
    case fulfilled(T)
    case rejected(Error)

    /// Creates a new `FutureValue<T>`, capturing the return value, or throw error of a function.
    ///
    /// - Parameter capturing: Function to invoke, resulting in an error or a value.
    public init(_ capturing: () throws -> T) {
        do {
            self = .fulfilled(try capturing())
        } catch {
            self = .rejected(error)
        }
    }

    /// Creates a new fulfilled `FutureValue<T>`.
    ///
    /// - Parameter value: A fulfilled value.
    public init(_ value: T) {
        self = .fulfilled(value)
    }

    /// Creates a new rejected `FutureValue<T>`.
    ///
    /// - Parameter error: A rejection error
    public init(_ error: Error) {
        self = .rejected(error)
    }

    /// Returns the value, if fulfilled
    public var value: T? {
        guard case .fulfilled(let value) = self else {
            return nil
        }

        return value
    }

    /// Returns the error, if rejected
    public var error: Error? {
        guard case .rejected(let error) = self else {
            return nil
        }

        return error
    }

    /// Indicates whether the value is rejected
    public var isError: Bool {

        switch self {

        case .fulfilled:
            return false

        case .rejected:
            return true
        }
    }

    /// Returns the a fulfilled value, or throws a rejection error
    ///
    /// - Returns: A fulfilled value.
    /// - Throws: A rejection error.
    @discardableResult
    public func unwrap() throws -> T {

        switch self {

        case .fulfilled(let value):
            return value

        case .rejected(let error):
            throw error
        }
    }

    /// The description of this `FutureValue<T>`
    public var description: String {
        switch self {
        case .fulfilled(let value):
            return "Fulfilled (" + String(describing: value) + ")"
        case .rejected(let error):
            return "Rejected (" + String(describing: error) + ")"
        }
    }
}

public extension FutureValue where T == Void {
    static var success: FutureValue {
        return .fulfilled(())
    }
}

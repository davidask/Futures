import Dispatch

/// Result of a future, being either rejected with an error or fulfilled with a value.
///
/// - fulfilled: A fulfilled future result, with a value.
/// - rejected: A rejected future result, with an error.
public enum FutureResult<T> {

    /// The value is fulfilled
    case fulfilled(T)

    /// The value is rejected
    case rejected(Error)

    /// Creates a new `FutureResult<T>`, capturing the return value, or throw error of a function.
    ///
    /// - Parameter capturing: Function to invoke, resulting in an error or a value.
    public init(_ capturing: () throws -> T) {
        do {
            self = .fulfilled(try capturing())
        } catch {
            self = .rejected(error)
        }
    }

    /// Creates a new fulfilled `FutureResult<T>`.
    ///
    /// - Parameter value: A fulfilled value.
    public init(_ value: T) {
        self = .fulfilled(value)
    }

    /// Creates a new rejected `FutureResult<T>`.
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

    /// The description of this `FutureResult<T>`
    public var description: String {
        switch self {
        case .fulfilled(let value):
            return "Fulfilled (" + String(describing: value) + ")"
        case .rejected(let error):
            return "Rejected (" + String(describing: error) + ")"
        }
    }
}

public extension FutureResult where T == Void {
    static var success: FutureResult {
        return .fulfilled(())
    }
}

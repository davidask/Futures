/// A typed container in which to provide specialized futures.
///
/// See `FutureSupport`.
public struct Promises<Subject> {
    public let subject: Subject
}

/// A protocol that can be used to add support for futures to a type of your choice.
///
/// When you want an API that supports futures, i types that already have methods with callbacks,
/// the signatures of the method providing the `Future<Value>` and the original function can conflict, especially
/// when working with methods where a completion callback is optional.
/// To get around this, when this protocol is conformed to by a type, it will expose one instance property, `futures`,
/// and one static property also named `futures`. These properties both return a `FutureProvider<Source>` which you
/// can extend to provide support for futures to any type. The returned `FutureProvider<Source>` provides the property
/// `source` for access to the instance it should be acting on.
///
/// As an example, here's how we implement support for presenting view controllers:
/// ```
/// extension UIViewController: FutureSupport {}
///
/// extension Promises where Subject: UIViewController {
///     func present(_ viewControllerToPresent: UIViewController, animated: Bool) -> Future<Void> {
///
///         let promise = Promise<Void>()
///         DispatchQueue.main.async {
///             self.subject.present(viewControllerToPresent, animated: animated) {
///                 promise.fulfill()
///             }
///         }
///
///         return promise.future
///     }
/// }
/// ```
/// Using this implementation is now possible.
/// ```
/// viewController.promise.present(
///     otherViewController,
///     animated: true
/// ).then {
///     someOtherFutureReturningMethod()
/// }
/// ```
public protocol PromisesSubject {}

public extension PromisesSubject {

    /// Returns an instance of `Promises<Self>`
    var promise: Promises<Self> {
        return Promises(subject: self)
    }

    /// Returns the type of `Promises<Self>`
    static var promise: Promises<Self>.Type {
        return Promises<Self>.self
    }
}

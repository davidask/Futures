/// A typed container in which to provide specialized futures.
///
/// See `PromisesExtended`.
public struct Promises<Source> {
    public let source: Source
}

/// A protocol that can be used to add support for futures to a type of your choice.
///
/// When you want an API that supports futures, i types that already have methods with callbacks,
/// the signatures of the method providing the `Future<Value>` and the original function can conflict, especially
/// when working with methods where a completion callback is optional.
/// To get around this, when this protocol is conformed to by a type, it will expose one instance property, `promise`,
/// and one static property also named `promise`. These properties both return a `Promises<Source>` which you
/// can extend to provide support for futures to any type. The returned `Promises<Source>` provides the property
/// `source` for access to the instance it should be acting on.
///
/// As an example, here's how we implement support for presenting view controllers:
/// ```
/// extension UIViewController: PromisesExtended {}
///
/// extension Promises where Source: UIViewController {
///     func present(_ viewControllerToPresent: UIViewController, animated: Bool) -> Future<Void> {
///
///         let promise = Promise<Void>()
///         DispatchQueue.main.async {
///             self.source.present(viewControllerToPresent, animated: animated) {
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
/// ).flatMap {
///     someOtherFutureReturningMethod()
/// }
/// ```
public protocol PromisesExtended {}

public extension PromisesExtended {

    /// Returns an instance of `Promises<Self>`
    var promise: Promises<Self> {
        return Promises(source: self)
    }

    /// Returns the type of `Promises<Self>`
    static var promise: Promises<Self>.Type {
        return Promises<Self>.self
    }
}

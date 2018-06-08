/// A typed container in which to provide specialized futures.
///
/// See `FutureSupport`.
public struct FutureProvider<Source> {
    public let source: Source
}

/// A protocol that can be used to add support for futures to a type of your choice.
///
/// When you want an API that supports futures, i types that already have methods with callbacks,
/// the signatures of the method providing the `Future<T>` and the original function can conflict, especially
/// when working with methods where a completion callback is optional.
/// To get around this, when this protocol is conformed to by a type, it will expose one instance property, `futures`,
/// and one static property also named `futures`. These properties both return a `FutureProvider<Source>` which you
/// can extend to provide support for futures to any type. The returned `FutureProvider<Source>` provides the property
/// `source` for access to the instance it should be acting on.
///
/// As an example, here's how we implement support for presenting view controllers:
/// extension UIViewController: FutureSupport {}
/// ```
/// extension FutureProvider where Source: UIViewController {
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
/// viewController.futures.present(
///     otherViewController,
///     animated: true
/// ).then {
///     someOtherFutureReturningMethod()
/// }
/// ```
public protocol FutureSupport {}

public extension FutureSupport {

    /// Returns an instance of `FutureProvider<Self>`
    var futures: FutureProvider<Self> {
        return FutureProvider(source: self)
    }

    /// Returns the type of `FutureProvider<Self>`
    static var futures: FutureProvider<Self>.Type {
        return FutureProvider<Self>.self
    }
}

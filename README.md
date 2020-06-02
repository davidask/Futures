# Futures
![Tests](https://github.com/davidask/Futures/workflows/Tests/badge.svg)

Futures is a cross-platform framework for simplifying asynchronous programming, written in Swift. It's lightweight, fast, and easy to understand.

### Supported Platforms

* Ubuntu 14.04
* macOS 10.9
* tvOS 9.0
* iOS 8.0
* watchOS 2.0


### Architecture

Fundamentally, Futures is a very simple framework, that consists of two types:

* `Promise`, a single assignment container producing a `Future`
* `Future`, a read-only container resolving into either a value, or an error


In many promise frameworks, a promise is undistinguished from a future. This introduces mutability of a promise that gets passed around. In Futures, a `Future` is the observable value while a `Promise` is the function that sets the value.


Futures are observed, by default, on a single concurrent dispatch queue. This queue can be modified by assigning a different queue to `DispatchQueue.futures`. You can also specify a queue of your choice to each callback added to a future .


A future is regarded as:

* `resolved`, if its value is set
* `fulfilled`, if the value is set, and successful
* `rejected`, if the value is set, and a failure (error)


## Usage

When a function returns a `Future<Value>`, you can either decide to observe it directly, or continue with more asynchronous tasks. For observing, you use:

* `whenResolved`, if you're interested in both a value and a rejection error 
* `whenFulfilled`, if you only care about the values
* `whenRejected`, if you only care about the error


If you have more asynchronous work to do based on the result of the first future, you can use

* `flatMap()`, to execute another future based on the result of the current one
* `flatMapIfRejected()`, to recover from a potential error resulting from the current future
* `flatMapThrowing()`, to transform the fulfilled value of the current future or return a rejected future
* `map()`, to transform the fulfilled value of the current future
* `recover()`,to transform a rejected future into a fulfilled future
* `always()`, to execute a `Void` returning closure regardless of whether the current future is rejected or resolved
* `and()`, to combine the result of two futures into a single tuple
* `Future<T>.reduce()`, to combine the result of multiple futures into a single future


Note that you can specify an observation dispatch queue for all these functions. For instance, you can use `flatMap(on: .main)`, or `.map(on: .global())`. By default, the queue is `DispatchQueue.futures`.

As a simple example, this is how some code may look:

```swift
let future = loadNetworkResource(
    from: URL("http://someHost/resource")!
).flatMapThrowing { data in
    try jsonDecoder.decode(SomeType.self, from: data)
}.always {
    someFunctionToExecuteRegardless()
}

future.whenFulfilled(on: .main) { someType in
    // Success
}

future.whenRejected(on: .main) { error in
    // Error
}
```

To create your functions returning a `Future<T>`, you create a new pending promise, and resolve it when appropriate.

```swift
func performAsynchronousWork() -> Future<String> {
    let promise = Promise<String>()

    DispatchQueue.global().async {
        promise.fulfill(someString)

        // If error
        promise.reject(error)
    }

    return promise.future
}
```

You can also use shorthands.

```swift
promise {
     try jsonDecoder.decode(SomeType.self, from: data)
} // Future<SomeType>
```

Or shorthands which you can return from asynchronously.
```swift
promise(String.self) { completion in
    /// ... on success ...
    completion(.fulfill("Some string"))
    /// ... if error ...
    completion(.reject(anError))
} // Future<String>
```


## Documentation

The complete documentation can be found [here](https://davidask.github.io/Futures/).

## Getting started

Futures can be added to your project either using [Carthage](https://github.com/Carthage/Carthage) or Swift package manager.


If you want to depend on Futures in your project, it's as simple as adding a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/davidask/Futures.git", from: "1.6.0")
]
```

Or, add a dependency in your `Cartfile`:

```
github "formbound/Futures"
```

More details on using Carthage can be found [here](https://github.com/Carthage/Carthage#quick-start).

Lastly, import the module in your Swift files

```swift
import Futures
```

## Contribute
Please feel welcome contributing to **Futures**, check the ``LICENSE`` file for more info.

## Credits

David Ask
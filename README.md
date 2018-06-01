# Futures
[![CircleCI](https://circleci.com/gh/formbound/Futures.svg?style=svg)](https://circleci.com/gh/formbound/Futures)

Futures is a cross-platform framework for simplifying asynchronous programming, written in Swift. It's lightweight and easy to understand.



### Supported Platforms

Futures supports all platforms where Swift is supported.

* Ubuntu 14.04
* macOS 10.9
* tvOS 9.0
* iOS 8.0
* watchOS 2.0



### Architecture

Fundamentally, Futures is a very simple framework, that consists of two types:

* `Promise`, a single assignment container producing a `Future`
* `Future`, a read-only container resolving into either a value, or an error



Unlike many promise frameworks, a promise is not distinguished from a future, which does not ensure immutability of a promise that gets passed around. This framework distinguishes a `Promise` from a future in that a `Future` is the observable value while a `Promise` is the function that sets the value.



Futures are resolved, by default, on a single serial queue. This queue can be modified by assigning a different queue to `DispatchQueue.futures`. You can also specify a queue of your choice to each callback added to a future .



A future is regarded as:

* `resolved`, if its value is set
* `fulfilled`, if the value is set, and successful
* `rejected`, if the value is set, and a failure (error)



## Documentation

The complete documentation can be found [here](https://formbound.github.io/Futures/).

## Getting started

Futures can be added to your project either using [Carthage](https://github.com/Carthage/Carthage) or Swift package manager.



If you want to depend on Futures in your project, it's as simple as adding a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/formbound/Futures.git", from: "1.0.2")
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



## Usage

The simplest way to create a `Future` is to invoke the global `promise` function:

```swift
promise {
    "Hello world!"
}
```

You can also specify a queue on which to resolve the future:

```swift
promise(on: .main) {
    "Hello world!"
}
```

**Note:** default queue can be accessed, and modified via `DispatchQueue.futures`.

A future that is resolved using a callback can also be created:

```swift
promise(String.self) { completion in
    if something == true {
        completion(.fulfilled("Hello World!"))
    } else {
        completion(.rejected(throw SomethingError.notTrue)
    }
}
```



### Observing

Multiple observers can be added to any future. Observing the value of a future can be done by calling:

* `whenResolved`, if you're interested in both a value and a rejection error 
* `whenFulfilled`, if you only care about the value
* `whenRejected`, if you only care about the error



```swift
let future = promise {
    try something()
}

future.whenFulfilled { value in
    print("Fulfilled with", value)
}

future.whenRejected { error in
    print("Rejected with", error)
}

future.whenResolved { result in
    switch result {
    case .fulfilled(let value):
        print("Fulfilled with", value)
    case .rejected(let error):
        print("Rejected with", error)
    }
}
```



### Then

When the current `Future` is fulfilled, run the provided callback which returns a new `Future<T>`. This allows you to dispatch new asynchronous operations as steps in a sequence of operations. Note that, based on the result, you can decide what asynchronous work to perform next. This function is best used when you have other APIs returning `Future<T>`.

```swift
func add(value: Double, to otherValue: Double) -> Future<Double> {
    return promise {
        value + otherValue
    }
}

promise {
    10
}.then { value in
    add(value: 10, to: value)
}
```

Call `thenIfRejected`  on a future to return another future, possibly recovering from the error that results in the rejection.

```swift
promise {
    try something()
}.thenIfRejected { error in
    return try recover(from: error)
}
```

### Map

When the current `Future` is fulfilled, run the provided callback that returns a new value of type `U`. This method is intended to provide a shorthand way of transforming fulfilled results of other futures. It is not intended to be used as `map` in the Swift standard library, however, that function may well be used inside the function provided to this method.

```swift
promise {
    ["Hello", "World!"]
}.map { strings in
    strings.joined(separator: " ")
}.whenFulfilled { string in
    print(string) // "Hello World!"
}
```

Like with `thenIfRejected` you can also call `mapIfRejected`

### And

Returns a new `Future`, that resolves when this **and** the provided future both are resolved. The returned future will provide the pair of values from this and the provided future. Note that the returned future will be rejected with the first error encountered.

```swift
let future1 = promise {
    "Hello"
}

let future2 = promise {
    "World!"
}

future1.and(future2).whenFulfilled { result in
    let (hello, world) = result // ("Hello", "World!")
}
```



### Reduce

Returns a new `Future<T>` that fires only when all the provided `Future<U>`s have been resolved. The returned future carries the value of the `initialResult` provided, combined with the result of fulfilled `Future<U>`s using the provided `nextPartialResult` function. The returned `Future<T>` will be rejected as soon as either this, or a provided future is rejected. However, a failure will not occur until all preceding `Future`s have been resolved. As soon as a rejection is encountered, there subsequent futures will not be waited for, resulting in the fastest possible rejection for the provided futures.

```swift
let futures = (1 ... 10).map { value in
    promise { value }
}

Future<Int>.reduce(futures, initialResult: 0) { combined, next in
    combined + next
}.whenFulfilled { value in
    print(value) // 55
}
```



For more in-depth documentation, visit the [docs](https://formbound.github.io/Futures/).
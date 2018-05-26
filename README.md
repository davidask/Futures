# Futures
[![CircleCI](https://circleci.com/gh/formbound/Future.svg?style=svg)](https://circleci.com/gh/formbound/Future)

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



## Getting started

Futures can be added to your project either using [Carthage](https://github.com/Carthage/Carthage) or Swift package manager.



If you want to depend on Futures in your project, it's as simple as adding a `dependencies` clause to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/formbound/Futures.git", from: "1.0.0")
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

Observing the value of a future can be done by calling:

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

Use the `then` function on a future to invoke another future when fulfilled.

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

Use `map` to transform a fulfilled value into a future of another value

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

Use `and` to combine two futures into a future that resolves into a tuple

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

A sequence of futures can be reduced into one promise

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


# Propagate

Propagate is a toolkit for managing asynchronous work in Swift in a strongly-typed way.

## The building blocks

Propagate contains two main paradigms:

- Promises & futures: These are for one-time bits of asynchronous work, e.g. a single network call.
- Publishers & subscribers: These are for streams of information, e.g. updates of changes made to a database, or changes in the logged in/out state of an application. This is a quasi-"reactive" paradigm.

Both pardigms are generically typed for both success states and error states; Promise/Future relies on Swift's `Result<T,E>` type, and Publisher/Subscriber has its own `StreamState<T,E>` type. This means that the code consuming either of these has explicit, compile-time type safety, with no need for casting or unwrapping.

### Promise and Future

Nobody likes nested callbacks with messy casting all over the place. That stuff should happen back in the kitchen. You just want a beautiful plate of food. Let Promise and Future help you tidy all of that up.

`Promise<T,E>` is a source object which represents a single, one-time piece of asynchronous work. It is responsible for receiving the completion state of that work (either a value of type `T` or an error of type `E`), and also for vending a future.

`Future<T,E>` is responsible for managing the completion callbacks that are dependent on the completion of the work that the Promise represents. Most of the interactions in your code will be with this object.

The completion state can only be triggered by the original Promise, and completion closures can only be added to a Future. If it helps as a mnemonic device, you make and fulfill _promises_ and the results are handled in the _future_.

An example wrapper around a traditional callback:
```Swift
func getUser(userID: String) -> Future<User,RepositoryGetError> {
    let promise = Promise<User,RepositoryGetError>()
    
    userStore.getUser(for: userID) { optionalUser, optionalError in
        if let user = optionalUser {
            promise.resolve(user)
        }
        else if let error = optionalError {
            promise.reject(error)
        }
        else {
            promise.reject(RepositoryGetError.unknownError)
        }
    }
    
    return promise.future
}
```

which in turn lets you write code that consumes this that is clean and simple to read:

```Swift
startActivityIndicator()
userRepository.getUser(for: someUserID)
    .onSuccess { user in
        someObjectThatNeedsAUser.doThingWith(user)
    }
    .onFailure { [weak self] in
        self?.showAlertFor(error: $0)
    }
    .onComplete { [weak self] _ in
        self?.stopActivityIndicator()
    }
```

### Publisher and Subscriber

Sometimes, you need to get data as it becomes ready, and a single-event paradigm like Promise/Future becomes cumbersome and unhelpful. This is where Publisher/Subscriber comes in.

`Publisher<T,E>` is a source object that represents a stream of potentially many asynchronous events. It is responsible for publishing states of that data stream, and for vending subscribers. (Analagous to the Promise in the other paradigm; it is to its subscribers what a promise is to its future.)

`Subscriber<T,E>` is responsible for managing the completion callbacks that are dependent on the states that the Publisher emits. Most of the interactions in your code will be with this object. (Analagous to the Future in other paradigm; it is to its publisher what a future is to its promise.)

An example usage:

```Swift
func subscribeToLoginState() -> Subsciber<Login?, NSError> {
    let publisher = Publisher<Login?, NSError>()

    loginStateListener.listen { (result: Result<Login?, NSError>) in
        switch result {
        case .success(let login):
            publisher.publish(login)
        case .failure(let error):
            publisher.publish(error)
        }
    }
    
    return publisher.subscriber()
}
```

which allows you to write consuming code like:

```Swift
loginManager.subscribeToLoginState()
    .onNewData { login in
        guard let login = login else {
           navigateToLoginScreen()
           return
        }
        navigateToHomeScreen()
    }
    .onError {
        handleLoginError($0)
    }
    .onCancelled {
        reSubscribeToLoginState()
    }
```

## Primary Differences

As you may have noted in the two paradigms, the patterns of usage are similar. The major distinctions are:

1. Promises/Futures can receive only one state, whereas Publishers/Subscribers can receive many.
2. Promise/Future has two possible completion states (`.success` and `.failure`), whereas Publisher/Subscriber has three possible states per update (`.data`, `.error`, and `.cancelled`).
3. The relationship between a Promise and a Future is 1:1 whereas with Publisher/Subscriber the relationship is 1:many. A Promise vends a single future, accessed by calling the `future` property, whereas calling the `subscriber()` method on Publisher generates a new Subscriber every time.

## Operators

Propagate comes with a host of operators and helper methods, and I'd encourage you to look through the source code (it's a fairly small library, so this shouldn't be too hard) and check them all out. Here is an abbreviated list of some of the "tent pole" operators.

### Map

Since both paradigms are genericized not just for their success/value types but also for their error types, there are separate convenience operators for mapping values, mapping errors, and mapping overall states.

When calling the value- or error-specific methods, the other state(s) pass through as normal. This means, for example, that if you have a `Future<Int,NSError>` and you call `mapValue { return "\($0)" }` you now have a `Future<String,NSError>`. The value type has been transformed, but the error type has stayed the same. The same goes for the error-mapping methods: the value type would stay the same, but the error type would change. This is helpful when you want the layers of your application to have clearly domained errors with specific ways of handling each.

Both paradigms have a means of mapping all possible states at once. `mapResult(_:)` on Future takes a closure which receives the final `Result<T,E>` state of the future and returns a result with potentially different value and error types. `mapStates(_:)` on Subscriber takes a closure which receives each incoming `StreamState<T,E>` and returns a new one with (you guessed it) potentially different value and error types.

#### Flat Map

There are some other flavors of map included in this library, but the only other one I will call out is flatMap. Oftentimes, you have multiple asynchronous tasks that need to be serialized to happen in a specific order. And in many of those cases you also need the output of one task in order to start the next. This is where Future's `flatMap` methods come into play.

`flatMap` takes in a closure which--in the case of `flatMapSuccess(_:)` takes in the success value, or in the case of `flatMap(_:)` takes in the result---and returns a new future, representing the next bit of asynchronous work. This allows you to chain futures like so:

```Swift
getProductID
    .flatMapSuccess {
        fetchProduct(id: $0)
    }
    .flatMapSuccess { product in
        fetchRelatedData(for: product)
    }
```

### Combine / Merge

Many times, you have multiple bits of asynchronous work that you need to coordinate; be it anything from views responding to changing streams of information, to accumulating necessary inputs to make a network call, to waiting for multiple uploads or downloads to complete. Propagate provides a host of tools for dealing with situations like these.

#### Merge

Both Future and Subscriber have merge methods, with slightly different semantics.

On future, the method takes an array of futures of the same generic type and generates a new one where the success type is an array of whatever the type of the input futures was (e.g. if the array was of `Future<Int,NSError>`s, the output will be a single `Future<[Int],NSError>`). This future will complete when all of the original futures complete. It will fail when the first one fails.

On subscriber, the syntax is similar, but the semantics are different. Much like the merge method on Future, it takes an array of same-typed subscribers and returns a singe one. Where it begins to differ is that, unlike the method on future, the returned subscriber has identical generic type to the inputs (e.g. merging an array of `Subscriber<Int,NSError>`s will return a `Subscriber<Int,NSError>`). Any emission from any of the original subscribers will emit from the new subscriber. This is effectively putting all of their results into a single bus.

#### Combine

Unlike `merge`, which amalgamates futures or subscribers which have the same value and error types, `combine` joins futures/susbscribers with differing value types (but with the same error type). In both cases, the success/value type on what is returned is a tuple of the value types from the sources.

Future:
```Swift
let myIntFuture = doIntThing() // Future<Int,NSError>
let myStringFuture = doStringThing() // Future<String,NSError>
let combinedFuture = Future.combine(myIntFuture, myStringFuture) // => Future<(Int,String),NSError>
```

Subscriber:
```Swift
let intSubscriber = getInts() // Subscriber<Int,NSError>
let stringSubscriber = getStrings() // Subscriber<String,NSError>
let combinedSub = Subscriber.combine(intSubscriber, stringSubscriber) // => Subscriber<(Int,String),NSError>

// Alternativelly, you can call combine as an instance method on whichever subscriber
// you want to show up first in the tuple:

let combinedSub = intSubscriber.combineWith(stringSubscriber) // => Subscriber<(Int,String),NSError>
```

As you can see above, the syntax is nearly identical. And in both paradigms, this can currently be done to a depth of a 4-item tuple. Since the types are different, collections can't be used, so a bespoke method has to be made for each number of elements being combined. So, for now, we have combine methods for 1, 2, 3, and 4 differnt items.

(I actually currently have a use case where I'm going to want 5, so expect to see that soon. Luckily, I've written them in a way that combining them and then flattening them to make new ones is a faily easy process.)

On Subscriber specifically, when you call combine, it starts off similar in behavior to Future, which is to say that it won't emit until all of its source subscribers have emitted. But after that point, it behaves differently. Each subsequent time any of sources emit, the combined subscriber emits a new tuple, with that source subscriber's corresponding tuple value updated. To demonstrate

```Swift
let intSubscriber = getInts()
let stringSubscriber = getStrings()
let combinedSub = Subscriber.combine(intSubscriber, stringSubscriber)

// intSubscriber receives 5, combinedSub does nothing becase stringSubscriber hasn't emitted yet
// stringSubscriber receives "boop", combined sub emits (5, "boop")

// stringSubscriber recieves "BEEP", combined sub emits (5, "BEEP")
// intSubscriber receives 23, combined sub emits (23, "BEEP")
```

#### Filter

(This operator is not available for Future.)

Filter is an operator on Subscriber that only allows `.data` states to pass through if they meet a certain criteria. This is useful for sanitizing user input, waiting for specific states, or for any other situation where only a narrow set of values are valid.

#### Mix and match!

The beauty of all of these operators is that, since each of them return either an themselves or something similar, you can chain the operators to get what you really want. An example:

```Swift
let emailSub = emailInputSub
    .compactMapValues { $0 }            // Filter out non-nil values.
    .filter { isValidEmail($0) }        // Call into a helper function to check if email address is valid
    
let passwordSub = Subscriber.merge(passwordInput1, passwordInput2)
    .filter { $0.0 == $0.1 }                                        // when the two passwords match
    .map { $0.0 }                                                   // pass along one of them
    .compactMapValues { $0 }                                        // only take a non-nil value
    .filter {                                                       // make sure the password matches your rules
        $0.count > 7 &&
        $0.rangeOfCharacter(from: .decimalDigits) != nil &&
        $0.rangeOfCharacter(from: .capitalizedLetters) != nil &&
        $0.rangeOfCharacter(from: .lowercaseLetters) != nil &&
        $0.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }
    
createAcccount = Subscriber.combine(
    emailSub,
    passwordSub,
    didTapEnterSub
)
    .onNewData { email, password, _ in
        authService.createAccountWith(email: email, password: password)
    }
```

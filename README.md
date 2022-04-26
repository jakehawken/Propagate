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

### Primary Differences

As you may have noted in the two paradigms, the patterns of usage are similar. The major distinctions are:

1. Promises/Futures (hereafter 'P/F') can receive only one state, whereas Publishers/Subscribers (hereafter 'P/S') can receive many.
2. P/F has two possible completion states (`.success` and `.failure`), whereas P/S has three possible states per update (`.data`, `.error`, and `.cancelled`).
3. The relationship in P/F is 1:1 whereas in P/S the relationship is 1:many. Promise vends a single future, accessed by calling the `future` property, whereas calling the `subscriber()` method on Publisher generates a new subscriber every time.

### Operators

** DOCUMENTATION COMING SOON **

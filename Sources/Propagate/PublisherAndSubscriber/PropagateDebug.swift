//  Debug.swift
//  Propagate
//  Created by Jacob Hawken on 2/19/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

internal func memoryAddressStringFor(_ obj: AnyObject) -> String {
    return "\(Unmanaged.passUnretained(obj).toOpaque())"
}

public enum DebugLogLevel {
    case all
    case lifeCyclePlusPubSub
    case lifeCyclePlusOperators
    case operatorsOnly
    case pubSubOnly
    case lifeCycleOnly
    case none
}

typealias DebugPair = (logLevel: DebugLogLevel, message: String)

internal func safePrint(_ message: String, logType: LogType, debugPair: DebugPair?) {
    guard let pair = debugPair else {
        return
    }
    guard logType.canBeShownAt(logLevel: pair.logLevel) else {
        return
    }
    var output = "<>DEBUG: "
    if pair.message.count > 0 {
        output += "\(pair.message) - "
    }
    output += message
    print(output)
}

internal enum LogType: Equatable {
    case lifeCycle
    case pubSub
    case operators
    
    func canBeShownAt(logLevel: DebugLogLevel) -> Bool {
        switch logLevel {
        case .none:
            return false
        case .all:
            return true
        case .lifeCycleOnly:
            return self == .lifeCycle
        case .pubSubOnly:
            return self == .pubSub
        case .lifeCyclePlusPubSub:
            return self == .lifeCycle || self == .pubSub
        case .operatorsOnly:
            return self == .operators
        case .lifeCyclePlusOperators:
            return self == .lifeCycle || self == .operators
        }
    }
}

// MARK: -- conformances

extension StreamState: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .data(let data): return "\(data)"
        case .error(let error): return "\(error)"
        case .cancelled: return "Cancelled."
        }
    }
    
}

extension Subscriber: CustomStringConvertible {
    
    public var description: String {
        return "Subscriber<\(T.self),\(E.self)>(\(memoryAddressStringFor(self)))"
    }
    
}

// MARK: - interface

public protocol PropagateDebuggable {
    /// This method puts the type into a debug state where various events
    /// (determined by the `DebugLogLevel`) are printed to the console.
    ///
    /// - Parameter logLevel: The log level to which the events need to be filtered.
    /// e.g. if all you care about is creation and release from memory of the type,
    /// you would call:
    /// `.debug(logLevel: .lifeCycleOnly, "When is this being released?")`
    ///
    /// - Parameter additionalMessage: Any additional message you would like
    /// included in the log, for example specific information about the given
    /// type, e.g.
    /// `.debug(logLevel: .operatorsOnly, "Mutations on the name stream.")`
    ///
    /// - returns: The type itself, as a `@discardableResult`, to allow for seamless chaining.
    @available(*, message: "This method is intended for debug use only. It is highly recommended that you not check in code calling this method.")
    @discardableResult func debug(logLevel: DebugLogLevel, _ additionalMessage: String) -> Self
}

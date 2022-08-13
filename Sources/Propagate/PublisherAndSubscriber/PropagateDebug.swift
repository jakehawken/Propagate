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

public typealias LoggingHook = (String) -> Void
typealias LoggingCombo = (logLevel: DebugLogLevel, message: String, loggingMethod: LoggingMethod?)

public enum LoggingMethod {
    
    case external(LoggingHook)
    
    @available(*, deprecated, message: "This logging method is intended for debug use only. It is highly recommended that you not check in code that uses it.")
    case debugPrint
}

private func safePrint(_ message: String, logType: LogType, loggingCombo: LoggingCombo?) {
    guard let combo = loggingCombo else {
        return
    }
    guard logType.canBeShownAt(logLevel: combo.logLevel) else {
        return
    }
    var output = "<>PROPAGATE: \n\t"
    if combo.message.count > 0 {
        let splitMessage = combo.message
                            .replacingOccurrences(of: "\n", with: "\n\t")
        output += "\(splitMessage) - "
    }
    output += message
    
    switch loggingCombo?.loggingMethod {
    case .debugPrint, nil:
#if DEBUG
        print(output)
#endif
    case .external(let hook):
        hook(output)
    }
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

internal extension Publisher {
    func log(_ message: String, logType: LogType) {
        Propagate.safePrint(message, logType: logType, loggingCombo: loggingCombo)
    }
}

internal extension Subscriber {
    func log(_ message: String, logType: LogType) {
        Propagate.safePrint(message, logType: logType, loggingCombo: loggingCombo)
    }
}

internal extension ValueOnlySubscriber {
    func log(_ message: String, logType: LogType) {
        Propagate.safePrint(message, logType: logType, loggingCombo: loggingCombo)
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
    @discardableResult func enableLogging(
        logLevel: DebugLogLevel,
        _ additionalMessage: String,
        _ logMethod: LoggingMethod
    ) -> Self
}

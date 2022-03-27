//  Debug.swift
//  JSync
//  Created by Jacob Hawken on 2/19/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

internal var debugLogLevel: DebugLogLevel = .none

func safePrint(_ message: String, logType: LogType) {
    guard logType.canBeShownAt(logLevel: debugLogLevel) else {
        return
    }
    print("<>DEBUG: " + message)
}

internal func memoryAddressStringFor(_ obj: AnyObject) -> String {
    return "\(Unmanaged.passUnretained(obj).toOpaque())"
}

internal enum DebugLogLevel {
    case all
    case lifeCyclePlusPubSub
    case lifeCyclePlusOperators
    case operatorsOnly
    case pubSubOnly
    case lifeCycleOnly
    case none
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

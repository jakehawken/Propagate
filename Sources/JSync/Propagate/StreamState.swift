//  StreamState.swift
//  JSync
//  Created by Jacob Hawken on 2/17/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

public enum StreamState<T, E: Error> {
    case data(T)
    case error(E)
    case cancelled
}

extension StreamState: Equatable where T: Equatable, E: Equatable {
    
}

public extension StreamState {
    
    var value: T? {
        switch self {
        case .data(let data):
            return data
        default:
            return nil
        }
    }
    
}

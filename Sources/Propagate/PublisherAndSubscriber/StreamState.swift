//  StreamState.swift
//  Propagate
//  Created by Jacob Hawken on 2/17/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

/// Represents the three possible states of a stream
/// emission: data, error, and cancellation.
public enum StreamState<T, E: Error> {
    /// A success state in which new data has been received.
    case data(T)
    /// A state in which an error has occurred.
    case error(E)
    /// The completed state of the stream. Final state emitted.
    /// No states follow this state.
    case cancelled
}

extension StreamState: Equatable where T: Equatable, E: Equatable { }

public extension StreamState {
    
    /// Convenience property. Will be nil for non-`.data` states.
    var value: T? {
        switch self {
        case .data(let data):
            return data
        default:
            return nil
        }
    }
    
    var error: E? {
        switch self {
        case .error(let error):
            return error
        default:
            return nil
        }
    }
    
}

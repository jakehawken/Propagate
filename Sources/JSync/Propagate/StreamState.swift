//  StreamState.swift
//  Propagate
//  Created by Jacob Hawken on 2/17/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

public enum StreamState<T, E: Error>: CustomStringConvertible {
    case data(T)
    case error(E)
    case cancelled
    
    public var description: String {
        switch self {
        case .data(let data): return "\(data)"
        case .error(let error): return "\(error)"
        case .cancelled: return "Cancelled."
        }
    }
}

extension StreamState: Equatable where T: Equatable, E: Equatable {
    
}

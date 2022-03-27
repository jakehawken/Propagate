//  WeakBox.swift
//  JSync
//  Created by Jacob Hawken on 2/15/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

internal class WeakBox<T: AnyObject>: CustomStringConvertible {
    
    private(set) weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
    
    fileprivate init(_ value: T?) {
        self.value = value
    }
    
    public var description: String {
        var valueString = "nil"
        if let val = value {
            valueString = "\(val)"
        }
        return "WeakBox<\(T.self)>(\(valueString))"
    }
    
}

internal class WeakBag <T: AnyObject>: CustomStringConvertible {
    
    private var rootNode = SinglyLinkedListNode<WeakBox<T>>(value: WeakBox(nil))
    
    func insert(_ item: T) {
        rootNode.insert(value: WeakBox(item))
    }
    
    func forEach(execute action: (T) -> Void) {
        rootNode.forEach { weakBox in
            guard let value = weakBox.value else {
                return true
            }
            action(value)
            return false
        }
    }
    
    func values() -> [T] {
        var outputValues = [T]()
        forEach { outputValues.append($0) }
        return outputValues
    }
    
    func map<Q>(transform: (T) -> Q) -> [Q] {
        values().map(transform)
    }
    
    func pruneIf(_ meetsCriteria: (T) -> Bool) {
        rootNode.forEach { weakBox in
            guard let value = weakBox.value else {
                return true
            }
            return meetsCriteria(value)
        }
    }
    
    @discardableResult func removeAll() -> [T] {
        let removedValues = values()
        rootNode.removeAllChildren()
        return removedValues
    }
    
    public var description: String {
        var output = "WeakBag(\(memoryAddressStringFor(self))){ "
        var count = 0
        forEach {
            output += "\($0) "
            count += 1
        }
        if count == 0 {
            output += "EMPTY "
        }
        return output + "}"
    }
    
}

private extension SinglyLinkedListNode {
    
    func forEach(shouldPrune: (T) -> Bool) {
        next?.forEach(previous: self, shouldPrune: shouldPrune)
    }
    
    func forEach(previous: SinglyLinkedListNode, shouldPrune: (T) -> Bool) {
        if shouldPrune(value) {
            previous.next = next
            next?.forEach(previous: previous, shouldPrune: shouldPrune)
        }
        else {
            next?.forEach(previous: self, shouldPrune: shouldPrune)
        }
    }
    
}

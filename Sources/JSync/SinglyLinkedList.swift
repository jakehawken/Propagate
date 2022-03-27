//  SinglyLinkedList.swift
//  JSync
//  Created by Jake Hawken on 4/5/20.
//  Copyright © 2020 Jake Hawken. All rights reserved.

import Foundation

// MARK: - SinglyLinkedList<T> -

/**
 The `SinglyLinkedList<T>` class exists to manage a list of nodes primarily by maintaining references to the head and tail, so that inserting to the list can be achieved in constant time. Secondarily, the list object provides convenience methods for easy management and manipulation of the list.
*/
internal class SinglyLinkedList<T> {
    private let rootNode: SinglyLinkedListNode<T>
    private var tailNode: SinglyLinkedListNode<T>
    
    /**
    The basic initializer for creating a new linked list. The value passed in will be the value of the root node, and will determine the generic type of the list, i.e. calling `SinglyLinkedList(firstValue: 3)` will generate a `SinglyLinkedList<Int>`.
    - Parameter firstValue: The initial `rootValue`. At initialization, there will only be one element, so the `rootValue` and `tailValue` properties will return the same element.
    */
    internal init(firstValue: T) {
        let first = SinglyLinkedListNode(value: firstValue)
        self.rootNode = first
        self.tailNode = first
    }
    
    /**
    An initializer for creating linked lists from an existing node. Since it will have to iteratively determine the tailNode (since the root may have attached child nodes) this initialization is an O(n) operation.
    - Parameter rootNode: A preexisting node that will become the root node for this list. If it has any child nodes, the the tail will be found and set to the `tailNode` property.
    */
    fileprivate init(rootNode: SinglyLinkedListNode<T>) {
        self.rootNode = rootNode
        self.tailNode = rootNode.findTerminalNode()
    }
    
    /**
    Generates a linked list of the respective elements of an array, honoring the data order, e.g. passing in [0,1,2] will generate SLinkedList{ (0)->(1)->(2) }
    - Parameter array: The array which will be used to generate the list.
    - returns: An optional singly linked list. If the array is empty, this will be nil. Otherwise, it will be non-nil.
    */
    internal static func fromArray(_ array: [T]) -> SinglyLinkedList? {
        var list: SinglyLinkedList?
        for item in array {
            guard let list = list else {
                list = SinglyLinkedList(firstValue: item)
                continue
            }
            list.append(item)
        }
        return list
    }
    
    /**
    Returns a new linked list, but with the rootNode being the node after the current list's root node. If there is no second node, this method will return nil. Since the tail node is copied to the new list (rather than being found iteratively), this method finishes in constant time.
    - returns: An optional SinglyLinkedList. Returns nil if `rootNode` has a nil `next` property.
    */
    internal func newListByIncrementingRoot() -> SinglyLinkedList? {
        guard let next = rootNode.next else {
            return nil
        }
        return SinglyLinkedList(rootNode: next,
                                tailNode: tailNode)
    }
    
    internal func filter(where meetsCriteria: (T) -> Bool) -> SinglyLinkedList? {
        var values = [T]()
        forEach {
            if meetsCriteria($0) {
                values.append($0)
            }
        }
        guard !values.isEmpty else {
            return nil
        }
        return SinglyLinkedList.fromArray(values)
    }
    
    private init(rootNode: SinglyLinkedListNode<T>, tailNode: SinglyLinkedListNode<T>) {
        self.rootNode = rootNode
        self.tailNode = tailNode
    }
}

extension SinglyLinkedList {
    /**
    Returns the current number of nodes in the list. This is done iteratively and is thus an O(n) operation.
    */
    var count: Int {
        var nodeCount = 0
        forEach { (_) in nodeCount += 1 }
        return nodeCount
    }
    
    /**
    Returns the element at the root position.
    */
    var rootValue: T {
        return rootNode.value
    }
    
    /**
    Returns the element at the tail position.
    */
    var tailValue: T {
        return tailNode.value
    }
    
    /**
    Finds the first value in the list which matches criteria passed in via the `where` block.
    - Parameter where: The block into which each value in the list will be passed until the block returns `true` or the list ends.
    - returns: The first node for which the `where` block returns true. If none do, returns `nil`
    */
    func firstValue(where whereBlock: (T)->Bool) -> T? {
        var current: SinglyLinkedListNode? = rootNode
        while let currentNode = current {
            if whereBlock(currentNode.value) {
                return currentNode.value
            }
            current = currentNode.next
        }
        return nil
    }
}

extension SinglyLinkedList {
    /**
    Appends a value onto the end of the list. Since references are maintained to the root and tail of the list, insertion happens in constant time.
    - Parameter value: The value that will become the new `tailValue` of the list.
    */
    func append(_ value: T) {
        let newNode = SinglyLinkedListNode(value: value)
        tailNode.next = newNode
        tailNode = newNode
    }
    
    /**
    Removes all nodes in the list except for the root.
    */
    func trimToRoot() {
        rootNode.removeAllChildren()
    }
}
 
extension SinglyLinkedList {
    /**
     Iterates through the list and executes the given block for each element in the list.
     - Parameter doBlock: A block with no return value into which the value of each node in the list will be passed.
    */
    func forEach(doBlock: (T)->()) {
        rootNode.forEachFromHere(doBlock: doBlock)
    }
    
    /**
    Generates an array from the contents of the list, honoring the data order. e.g. SLinkedList{ (0)->(1)->(2) } will generate [0,1,2]
    - returns: An array corresponding to the elements of the list. Guaranteed to have at least one element.
    */
    func asArray() -> [T] {
        var output = [T]()
        forEach { output.append($0) }
        return output
    }
}

extension SinglyLinkedList: CustomStringConvertible {
    
    internal var description: String {
        var output = "SLinkedList{"
        var currentNode: SinglyLinkedListNode? = rootNode
        while let node = currentNode {
            output += "(\(node.value))"
            if node.next != nil {
                output += "->"
            }
            currentNode = node.next
        }
        output += "}"
        return output
    }
    
}

extension SinglyLinkedList where T:Equatable {
    
    func contains(_ value: T) -> Bool {
        return firstValue(where: { $0 == value }) != nil
    }
    
}

extension SinglyLinkedList where T:AnyObject {
    
    func containsObject(_ object: T) -> Bool {
        let firstVal = firstValue { (element) in
            element === object
        }
        return firstVal != nil
    }
    
}

// MARK: - SinglyLinkedListNode<T> -

internal class SinglyLinkedListNode<T>: Equatable {
    internal let value: T
    internal var next: SinglyLinkedListNode<T>?
    
    internal init(value: T) {
        self.value = value
    }
    
    internal static func == (lhs: SinglyLinkedListNode<T>, rhs: SinglyLinkedListNode<T>) -> Bool {
        return lhs === rhs
    }
}

extension SinglyLinkedListNode {
    
    @discardableResult func insert(value: T) -> SinglyLinkedListNode {
        if let next = next {
            return next.insert(value: value)
        }
        let nextNode = SinglyLinkedListNode(value: value)
        next = nextNode
        return nextNode
    }
    
    func forEachFromHere(doBlock: (T)->()) {
        doBlock(value)
        next?.forEachFromHere(doBlock: doBlock)
    }
    
    func findTerminalNode() -> SinglyLinkedListNode<T> {
        guard let next = next else {
            return self
        }
        return next.findTerminalNode()
    }
    
    func removeAllChildren() {
        guard let next = next else {
            return
        }
        self.next = nil
        next.removeAllChildren()
    }
    
    func listFromHere() -> SinglyLinkedList<T> {
        return SinglyLinkedList(rootNode: self)
    }
    
}

extension SinglyLinkedListNode: CustomStringConvertible {
    
    internal var description: String {
        let nextString: String
        if let next = next {
            nextString = "\(next.value)"
        }
        else {
            nextString = "nil"
        }
        return "Node{value: (\(value)), nextValue:(\(nextString))}"
    }
    
}

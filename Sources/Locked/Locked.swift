import Foundation
import os

public struct Locked<Value: Sendable>: @unchecked Sendable {
    private let newLock: Any?
    private let oldLock: OldLock<Value>?

    public var value: Value {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return (newLock! as! OSAllocatedUnfairLock<Value>).withLock { $0 }
        } else {
            return oldLock!.withValue { $0 }
        }
        #else
            return oldLock!.withValue { $0 }
        #endif
    }

    public init(_ value: Value) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                newLock = OSAllocatedUnfairLock(uncheckedState: value)
                oldLock = nil
            } else {
                newLock = nil
                oldLock = OldLock(value)
            }
        #else
            newLock = nil
            oldLock = OldLock(value)
        #endif
    }

    @discardableResult
    public func withValue<ReturnType>(_ body: (inout Value) throws -> ReturnType) rethrows -> ReturnType {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                try (newLock! as! OSAllocatedUnfairLock<Value>).withLockUnchecked(body)
            } else {
                try oldLock!.withValue(body)
            }
        #else
            try oldLock!.withValue(body)
        #endif
    }

}

public final class OldLock<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var mutableValue: Value

    public init(_ value: Value) {
        self.mutableValue = value
    }

    @discardableResult
    public func withValue<ReturnType>(_ body: (inout Value) throws -> ReturnType) rethrows -> ReturnType {
        return try lock.withLock { try body(&mutableValue) }
    }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension OSAllocatedUnfairLock where State: Sendable {
    @discardableResult
    public func withValue<ReturnType>(_ body: (inout State) throws -> ReturnType) rethrows -> ReturnType {
        return try withLockUnchecked(body)
    }
}
#endif

public final class RecursiveLocked<Value: Sendable>: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var mutableValue: Value
    private var isModifying = false

    public var value: Value {
        lock.withLock { mutableValue }
    }

    public init(_ value: Value) {
        self.mutableValue = value
    }

    public func withValue<Result>(_ action: (Value) throws -> Result) rethrows -> Result {
        return try lock.withLock { return try action(mutableValue) }
    }

    public func begin<Result>(_ action: (Transaction) throws -> Result) rethrows -> Result {
        return try lock.withLock { return try action(.init(self)) }
    }

    public struct Transaction: Sendable {
        private unowned let locked: RecursiveLocked<Value>

        fileprivate init(_ locked: RecursiveLocked<Value>) {
            self.locked = locked
        }

        public var value: Value {
            return locked.mutableValue
        }

        @discardableResult
        public func withValue<Result>(_ action: (inout Value) throws -> Result) rethrows -> Result {
            guard !locked.isModifying else { fatalError("Nested modifications violate exclusivity of access.") }
            locked.isModifying = true
            defer { locked.isModifying = false }
            return try action(&locked.mutableValue)
        }
    }
}

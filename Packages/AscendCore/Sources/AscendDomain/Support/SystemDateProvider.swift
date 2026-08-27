import Foundation

public struct SystemDateProvider: DateProviding {
    public init() {}
    public var now: Date { Date() }
}

/// A clock a test can move.
public final class MutableDateProvider: DateProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    public init(_ start: Date) { self._now = start }

    public var now: Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    public func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        _now = date
    }

    public func advance(days: Int, calendar: Calendar = .current) {
        lock.lock(); defer { lock.unlock() }
        _now = calendar.date(byAdding: .day, value: days, to: _now) ?? _now
    }

    public func advance(hours: Int, calendar: Calendar = .current) {
        lock.lock(); defer { lock.unlock() }
        _now = calendar.date(byAdding: .hour, value: hours, to: _now) ?? _now
    }
}

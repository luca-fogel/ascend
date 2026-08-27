import Foundation

/// The clock, injected.
///
/// Every streak, rollover and 4am-cutoff test would otherwise need to wait for midnight.
public protocol DateProviding: Sendable {
    var now: Date { get }
}

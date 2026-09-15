import CoreGraphics

/// Per-window ring buffer of frame transitions. Replaces `SpectacleHistory`.
public struct UndoStack: Sendable {
    public struct Transition: Sendable, Equatable { public let before: CGRect, after: CGRect }
    private var byWindow: [String: [Transition]] = [:]
    private var cursor: [String: Int] = [:]
    private let limit: Int

    public init(limit: Int = 16) { self.limit = max(0, limit) }

    public mutating func record(for key: String, before: CGRect, after: CGRect) {
        guard limit > 0, before.isUsableWindowFrame, after.isUsableWindowFrame, before != after else { return }
        var stack = byWindow[key, default: []]
        // Drop any redo tail.
        if let c = cursor[key] { stack = Array(stack.prefix(c + 1)) }
        stack.append(Transition(before: before, after: after))
        if stack.count > limit { stack.removeFirst(stack.count - limit) }
        byWindow[key] = stack
        cursor[key] = stack.count - 1
    }

    public mutating func undo(for key: String) -> CGRect? {
        undo(for: key, applying: { _ in })
    }

    /// Advance history only after the corresponding window operation succeeds.
    @discardableResult
    public mutating func undo(for key: String, applying operation: (CGRect) throws -> Void) rethrows -> CGRect? {
        guard let c = cursor[key], c >= 0, let stack = byWindow[key] else { return nil }
        try operation(stack[c].before)
        cursor[key] = c - 1
        return stack[c].before
    }

    public mutating func redo(for key: String) -> CGRect? {
        redo(for: key, applying: { _ in })
    }

    @discardableResult
    public mutating func redo(for key: String, applying operation: (CGRect) throws -> Void) rethrows -> CGRect? {
        guard let stack = byWindow[key] else { return nil }
        let c = (cursor[key] ?? -1) + 1
        guard c < stack.count else { return nil }
        try operation(stack[c].after)
        cursor[key] = c
        return stack[c].after
    }

    public mutating func remove(for key: String) {
        byWindow.removeValue(forKey: key)
        cursor.removeValue(forKey: key)
    }
}

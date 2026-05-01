import CoreGraphics

/// Per-window ring buffer of frame transitions. Replaces `SpectacleHistory`.
public struct UndoStack: Sendable {
    public struct Transition: Sendable, Equatable { public let before: CGRect, after: CGRect }
    private var byWindow: [String: [Transition]] = [:]
    private var cursor: [String: Int] = [:]
    private let limit: Int

    public init(limit: Int = 16) { self.limit = limit }

    public mutating func record(for key: String, before: CGRect, after: CGRect) {
        var stack = byWindow[key, default: []]
        // Drop any redo tail.
        if let c = cursor[key] { stack = Array(stack.prefix(c + 1)) }
        stack.append(Transition(before: before, after: after))
        if stack.count > limit { stack.removeFirst(stack.count - limit) }
        byWindow[key] = stack
        cursor[key] = stack.count - 1
    }

    public mutating func undo(for key: String) -> CGRect? {
        guard let c = cursor[key], c >= 0, let stack = byWindow[key] else { return nil }
        cursor[key] = c - 1
        return stack[c].before
    }

    public mutating func redo(for key: String) -> CGRect? {
        guard let stack = byWindow[key] else { return nil }
        let c = (cursor[key] ?? -1) + 1
        guard c < stack.count else { return nil }
        cursor[key] = c
        return stack[c].after
    }
}

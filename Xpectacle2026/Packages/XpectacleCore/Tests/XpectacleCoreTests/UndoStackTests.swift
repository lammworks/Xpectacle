import CoreGraphics
import Testing
@testable import XpectacleCore

@Test func undoRestoresPreviousFrame() {
    var stack = UndoStack()
    let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    let b = CGRect(x: 100, y: 0, width: 100, height: 100)
    stack.record(for: "k", before: a, after: b)
    #expect(stack.undo(for: "k") == a)
}

@Test func redoAfterUndo() {
    var stack = UndoStack()
    let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    let b = CGRect(x: 100, y: 0, width: 100, height: 100)
    stack.record(for: "k", before: a, after: b)
    _ = stack.undo(for: "k")
    #expect(stack.redo(for: "k") == b)
}

@Test func recordingAfterUndoDropsRedoTail() {
    var stack = UndoStack()
    let a = CGRect(x: 0, y: 0, width: 1, height: 1)
    let b = CGRect(x: 1, y: 0, width: 1, height: 1)
    let c = CGRect(x: 2, y: 0, width: 1, height: 1)
    stack.record(for: "k", before: a, after: b)
    _ = stack.undo(for: "k")
    stack.record(for: "k", before: a, after: c)
    #expect(stack.redo(for: "k") == nil)
}

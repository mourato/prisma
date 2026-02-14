import Foundation
@testable import MeetingAssistantCore
import XCTest

final class ShortcutDefinitionAndEngineTests: XCTestCase {
    func testSimpleShortcutOnlyAllowsSingleTap() {
        let shortcut = ShortcutDefinition(
            modifiers: [.leftCommand],
            primaryKey: .letter("G", keyCode: 0x05),
            trigger: .singleTap
        )

        XCTAssertEqual(shortcut.patternType, .simple)
        XCTAssertEqual(shortcut.allowedTriggers, [.singleTap])
        XCTAssertTrue(shortcut.isValid)
    }

    func testIntermediateShortcutRejectsDoubleTap() {
        let shortcut = ShortcutDefinition(
            modifiers: [.leftCommand, .leftShift],
            primaryKey: .letter("K", keyCode: 0x28),
            trigger: .doubleTap
        )

        XCTAssertEqual(shortcut.validate(), .unsupportedTriggerForSimpleOrIntermediate)
    }

    func testAdvancedShortcutRejectsSingleTap() {
        let shortcut = ShortcutDefinition(
            modifiers: [.rightCommand],
            primaryKey: nil,
            trigger: .singleTap
        )

        XCTAssertEqual(shortcut.patternType, .advanced)
        XCTAssertEqual(shortcut.validate(), .unsupportedTriggerForAdvanced)
    }

    func testAdvancedShortcutRejectsMultipleModifiers() {
        let shortcut = ShortcutDefinition(
            modifiers: [.leftCommand, .rightCommand],
            primaryKey: nil,
            trigger: .doubleTap
        )

        XCTAssertEqual(shortcut.validate(), .advancedRequiresSingleModifier)
    }

    func testAdvancedShortcutRejectsSideAgnosticModifier() {
        let shortcut = ShortcutDefinition(
            modifiers: [.command],
            primaryKey: nil,
            trigger: .doubleTap
        )

        XCTAssertEqual(shortcut.validate(), .advancedRequiresSideSpecificModifier)
    }

    func testFunctionPrimaryKeyRangeValidation() {
        let valid = ShortcutPrimaryKey.function(index: 12, keyCode: 0x6f)
        let invalid = ShortcutPrimaryKey.function(index: 21, keyCode: 0x00)

        XCTAssertTrue(valid.isValid)
        XCTAssertFalse(invalid.isValid)
    }

    func testGenericConflictServiceDetectsSameSignature() {
        let existing = ShortcutBinding(
            actionID: .assistant,
            actionDisplayName: "Assistant",
            shortcut: ShortcutDefinition(
                modifiers: [.leftCommand],
                primaryKey: .letter("G", keyCode: 0x05),
                trigger: .singleTap
            )
        )

        let candidate = ShortcutBinding(
            actionID: .meeting,
            actionDisplayName: "Meeting",
            shortcut: ShortcutDefinition(
                modifiers: [.leftCommand],
                primaryKey: .letter("G", keyCode: 0x05),
                trigger: .singleTap
            )
        )

        let conflict = ModifierShortcutConflictService.conflict(for: candidate, in: [existing])
        XCTAssertEqual(conflict?.conflicting.actionID, .assistant)
        XCTAssertEqual(conflict?.candidate.actionID, .meeting)
    }

    func testPrimaryKeyNormalizedTokenIncludesKeyCode() {
        let first = ShortcutPrimaryKey.letter("A", keyCode: 0x00)
        let second = ShortcutPrimaryKey.letter("A", keyCode: 0x32)

        XCTAssertNotEqual(first.normalizedToken, second.normalizedToken)
    }

    func testAssistantIntegrationDecodeNormalizesModifierOnlySingleTapShortcut() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": UUID().uuidString,
            "name": "Legacy Integration",
            "kind": "deeplink",
            "isEnabled": true,
            "deepLink": "raycast://extensions/raycast/raycast-ai/ai-chat",
            "shortcutActivationMode": "holdOrToggle",
            "modifierShortcutGesture": [
                "keys": ["rightCommand"],
                "triggerMode": "singleTap",
            ],
        ])

        let decoded = try JSONDecoder().decode(AssistantIntegrationConfig.self, from: data)

        XCTAssertEqual(decoded.shortcutDefinition?.trigger, .doubleTap)
        XCTAssertTrue(decoded.shortcutDefinition?.isValid ?? false)
    }

    @MainActor
    func testExecutionEngineSingleTapStartsWhenNotRecording() {
        let engine = ShortcutExecutionEngine()
        let actions = engine.handleDown(trigger: .singleTap, isRecording: false)
        XCTAssertEqual(actions, [.start])
    }

    @MainActor
    func testExecutionEngineSingleTapStopsWhenRecording() {
        let engine = ShortcutExecutionEngine()
        let actions = engine.handleDown(trigger: .singleTap, isRecording: true)
        XCTAssertEqual(actions, [.stop])
    }

    @MainActor
    func testExecutionEngineHoldStartsOnDownAndStopsOnUp() {
        let engine = ShortcutExecutionEngine()
        let downActions = engine.handleDown(trigger: .hold, isRecording: false)
        let upActions = engine.handleUp(trigger: .hold, isRecording: true)

        XCTAssertEqual(downActions, [.start])
        XCTAssertEqual(upActions, [.stop])
    }

    @MainActor
    func testExecutionEngineDoubleTapTogglesOnSecondRelease() {
        let engine = ShortcutExecutionEngine(doubleTapInterval: 1)
        _ = engine.handleUp(trigger: .doubleTap, isRecording: false)
        let secondTap = engine.handleUp(trigger: .doubleTap, isRecording: false)

        XCTAssertEqual(secondTap, [.start])
    }
}

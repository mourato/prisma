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

    func testShortcutTelemetryShortcutDetectedRecordUsesCanonicalPayload() {
        let record = ShortcutTelemetryEvent
            .shortcutDetected(
                pipeline: "assistant shortcuts",
                scope: "assistant",
                shortcutTarget: "assistant",
                source: "in-house/definition",
                trigger: "double tap"
            )
            .record

        XCTAssertEqual(record.name, .shortcutDetected)
        XCTAssertEqual(record.level, .info)
        XCTAssertEqual(record.payload["pipeline"], "assistant_shortcuts")
        XCTAssertEqual(record.payload["scope"], "assistant")
        XCTAssertEqual(record.payload["shortcut_target"], "assistant")
        XCTAssertEqual(record.payload["source"], "in-house_definition")
        XCTAssertEqual(record.payload["trigger"], "double_tap")
    }

    func testShortcutTelemetryPermissionBlockedRecordStoresBooleanFlagsAsStrings() {
        let record = ShortcutTelemetryEvent
            .permissionBlocked(
                pipeline: "global_shortcuts",
                scope: "global",
                permission: "input monitoring",
                accessibilityTrusted: false,
                inputMonitoringTrusted: true
            )
            .record

        XCTAssertEqual(record.name, .permissionBlocked)
        XCTAssertEqual(record.level, .warning)
        XCTAssertEqual(record.payload["permission"], "input_monitoring")
        XCTAssertEqual(record.payload["accessibility_trusted"], "false")
        XCTAssertEqual(record.payload["input_monitoring_trusted"], "true")
    }

    func testShortcutTelemetryLayerTimeoutRecordNormalizesNegativeTimeout() {
        let record = ShortcutTelemetryEvent
            .layerTimeout(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                source: "assistant_shortcut",
                timeoutMs: -80
            )
            .record

        XCTAssertEqual(record.name, .layerTimeout)
        XCTAssertEqual(record.payload["layer_timeout_ms"], "0")
        XCTAssertEqual(record.payload["reason"], "timeout")
    }

    func testShortcutTelemetryEventTapFallbackRecordOmitsInputMonitoringWhenUnknown() {
        let record = ShortcutTelemetryEvent
            .eventTapFallback(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                fallbackMode: "monitor only",
                reason: "event tap unavailable",
                inputMonitoringTrusted: nil
            )
            .record

        XCTAssertEqual(record.name, .eventTapFallback)
        XCTAssertEqual(record.level, .warning)
        XCTAssertEqual(record.payload["fallback_mode"], "monitor_only")
        XCTAssertEqual(record.payload["reason"], "event_tap_unavailable")
        XCTAssertNil(record.payload["input_monitoring_trusted"])
    }

    func testShortcutTelemetryCaptureHealthChangedRecordStoresStatusAndBackendFields() {
        let record = ShortcutTelemetryEvent
            .captureHealthChanged(
                pipeline: "global shortcuts",
                scope: "global",
                source: "refresh/event/monitors",
                result: "degraded",
                previousResult: "healthy",
                reason: "input monitoring denied",
                requiresGlobalCapture: true,
                accessibilityTrusted: true,
                inputMonitoringTrusted: false,
                flagsMonitorExpected: true,
                flagsMonitorActive: true,
                keyDownMonitorExpected: true,
                keyDownMonitorActive: false,
                keyUpMonitorExpected: false,
                keyUpMonitorActive: false,
                eventTapExpected: false,
                eventTapActive: false,
                checkedAtEpochMs: -20
            )
            .record

        XCTAssertEqual(record.name, .captureHealthChanged)
        XCTAssertEqual(record.level, .warning)
        XCTAssertEqual(record.payload["pipeline"], "global_shortcuts")
        XCTAssertEqual(record.payload["source"], "refresh_event_monitors")
        XCTAssertEqual(record.payload["result"], "degraded")
        XCTAssertEqual(record.payload["previous_result"], "healthy")
        XCTAssertEqual(record.payload["reason"], "input_monitoring_denied")
        XCTAssertEqual(record.payload["requires_global_capture"], "true")
        XCTAssertEqual(record.payload["input_monitoring_trusted"], "false")
        XCTAssertEqual(record.payload["key_down_monitor_active"], "false")
        XCTAssertEqual(record.payload["checked_at_epoch_ms"], "0")
    }

    func testShortcutTelemetryCaptureHealthChangedRecordOmitsOptionalFieldsWhenMissing() {
        let record = ShortcutTelemetryEvent
            .captureHealthChanged(
                pipeline: "assistant_shortcuts",
                scope: "assistant",
                source: "periodic",
                result: "healthy",
                previousResult: nil,
                reason: nil,
                requiresGlobalCapture: true,
                accessibilityTrusted: true,
                inputMonitoringTrusted: true,
                flagsMonitorExpected: true,
                flagsMonitorActive: true,
                keyDownMonitorExpected: true,
                keyDownMonitorActive: true,
                keyUpMonitorExpected: false,
                keyUpMonitorActive: false,
                eventTapExpected: true,
                eventTapActive: true,
                checkedAtEpochMs: 1_234
            )
            .record

        XCTAssertEqual(record.name, .captureHealthChanged)
        XCTAssertEqual(record.level, .info)
        XCTAssertEqual(record.payload["result"], "healthy")
        XCTAssertEqual(record.payload["event_tap_expected"], "true")
        XCTAssertEqual(record.payload["event_tap_active"], "true")
        XCTAssertNil(record.payload["previous_result"])
        XCTAssertNil(record.payload["reason"])
    }
}

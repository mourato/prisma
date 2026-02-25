import MeetingAssistantCoreCommon
import SwiftUI

public struct ShortcutCaptureHealthStatusView: View {
    private let presentation: ShortcutCaptureHealthPresentation
    private let onAction: () -> Void

    public init(
        presentation: ShortcutCaptureHealthPresentation,
        onAction: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onAction = onAction
    }

    public var body: some View {
        MACard {
            VStack(alignment: .leading, spacing: MeetingAssistantDesignSystem.Layout.spacing10) {
                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Text(presentation.scopeLabelKey.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    MABadge(
                        presentation.badgeKey.localized,
                        kind: presentation.isFallback ? .error : .warning
                    )
                }

                HStack(spacing: MeetingAssistantDesignSystem.Layout.spacing8) {
                    Image(systemName: presentation.isFallback ? "arrow.trianglehead.branch" : "exclamationmark.triangle.fill")
                        .foregroundStyle(
                            presentation.isFallback
                                ? MeetingAssistantDesignSystem.Colors.error
                                : MeetingAssistantDesignSystem.Colors.warning
                        )
                    Text(presentation.titleKey.localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(presentation.messageKey.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitleKey = presentation.actionTitleKey,
                   presentation.action != .none
                {
                    Button(actionTitleKey.localized) {
                        onAction()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("settings.shortcuts.health.accessibility.hint.actionable".localized)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [
                presentation.scopeLabelKey.localized,
                presentation.badgeKey.localized,
                presentation.titleKey.localized,
                presentation.messageKey.localized,
            ]
            .joined(separator: ", ")
        )
        .accessibilityHint(
            presentation.action == .none
                ? "settings.shortcuts.health.accessibility.hint.read_only".localized
                : "settings.shortcuts.health.accessibility.hint.actionable".localized
        )
    }
}

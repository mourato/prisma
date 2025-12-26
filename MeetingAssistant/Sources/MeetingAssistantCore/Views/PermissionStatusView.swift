import SwiftUI

// MARK: - Permission Status View

/// A view that displays individual permission status with visual indicators.
/// Shows each permission type with an icon and its current authorization state.
public struct PermissionStatusView: View {
    @ObservedObject var viewModel: PermissionViewModel

    public init(viewModel: PermissionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            headerSection

            VStack(spacing: 8) {
                PermissionRowView(
                    permission: PermissionInfo(type: .microphone, state: viewModel.microphoneState),
                    onRequest: { Task { await viewModel.requestMicrophonePermission() } },
                    onOpenSettings: { viewModel.openMicrophoneSystemSettings() }
                )

                PermissionRowView(
                    permission: PermissionInfo(
                        type: .screenRecording, state: viewModel.screenState),
                    onRequest: { Task { await viewModel.requestScreenPermission() } },
                    onOpenSettings: { viewModel.openScreenSystemSettings() }
                )
            }

            if !allPermissionsGranted {
                permissionWarning
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var allPermissionsGranted: Bool {
        viewModel.microphoneState == .granted && viewModel.screenState == .granted
    }

    private var grantedCount: Int {
        var count = 0
        if viewModel.microphoneState == .granted { count += 1 }
        if viewModel.screenState == .granted { count += 1 }
        return count
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "shield.checkered")
                .font(.title2)
                .foregroundStyle(headerIconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Permissões do Sistema")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(grantedCount)/2 concedidas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(allPermissionsGranted ? "OK" : "!")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(allPermissionsGranted ? Color.green : Color.orange)
            )
            .foregroundColor(.white)
    }

    private var permissionWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            Text("Algumas permissões são necessárias para gravar reuniões.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Computed Properties

    private var backgroundGradient: LinearGradient {
        if allPermissionsGranted {
            return LinearGradient(
                colors: [
                    Color.green.opacity(0.05),
                    Color.green.opacity(0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.orange.opacity(0.08),
                    Color.orange.opacity(0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        allPermissionsGranted
            ? Color.green.opacity(0.2)
            : Color.orange.opacity(0.3)
    }

    private var headerIconColor: Color {
        allPermissionsGranted ? .green : .orange
    }
}

// MARK: - Permission Row View

/// Individual row showing a single permission's status.
struct PermissionRowView: View {
    let permission: PermissionInfo
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Permission type icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)

                Image(systemName: permission.type.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconForegroundColor)
            }

            // Permission info
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(permission.type.permissionDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status indicator and action button
            statusIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
        )
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            // Status icon with animation
            Image(systemName: permission.state.iconName)
                .font(.title3)
                .foregroundStyle(statusColor)
                .symbolEffect(
                    .pulse, options: .repeating, isActive: permission.state == .notDetermined)

            // Action button when not granted
            if !permission.state.isAuthorized {
                actionButton
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch permission.state {
        case .notDetermined:
            Button("Solicitar") {
                onRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.blue)

        case .denied, .restricted:
            Button("Configurar") {
                onOpenSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .granted:
            EmptyView()
        }
    }

    // MARK: - Computed Properties

    private var iconBackgroundColor: Color {
        switch permission.state {
        case .granted:
            return Color.green.opacity(0.15)
        case .denied, .restricted:
            return Color.red.opacity(0.15)
        case .notDetermined:
            return Color.blue.opacity(0.15)
        }
    }

    private var iconForegroundColor: Color {
        switch permission.state {
        case .granted:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .blue
        }
    }

    private var statusColor: Color {
        switch permission.state {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .restricted:
            return .gray
        }
    }
}

// MARK: - Compact Permission Status View

/// A compact inline view showing permission status with minimal space.
public struct CompactPermissionStatusView: View {
    @ObservedObject private var permissionManager: PermissionStatusManager

    public init(permissionManager: PermissionStatusManager) {
        self.permissionManager = permissionManager
    }

    public var body: some View {
        HStack(spacing: 12) {
            CompactPermissionIndicator(
                permission: permissionManager.microphonePermission
            )

            CompactPermissionIndicator(
                permission: permissionManager.screenRecordingPermission
            )
        }
    }
}

/// Compact indicator for a single permission.
struct CompactPermissionIndicator: View {
    let permission: PermissionInfo

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: permission.type.iconName)
                .font(.caption)
                .foregroundStyle(iconColor)

            Image(systemName: permission.state.iconName)
                .font(.caption2)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .help("\(permission.type.displayName): \(permission.state.displayName)")
    }

    private var iconColor: Color {
        permission.state.isAuthorized ? .primary : .secondary
    }

    private var statusColor: Color {
        switch permission.state {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .restricted:
            return .gray
        }
    }

    private var backgroundColor: Color {
        switch permission.state {
        case .granted:
            return Color.green.opacity(0.1)
        case .denied:
            return Color.red.opacity(0.1)
        case .notDetermined:
            return Color.orange.opacity(0.1)
        case .restricted:
            return Color.gray.opacity(0.1)
        }
    }
}

// MARK: - Previews

#Preview("Full Permission View - All Granted") {
    let manager = PermissionStatusManager()
    manager.updateMicrophoneState(.granted)
    manager.updateScreenRecordingState(.granted)

    let vm = PermissionViewModel(
        manager: manager,
        requestMicrophone: {},
        requestScreen: {},
        openMicrophoneSettings: {},
        openScreenSettings: {}
    )

    return PermissionStatusView(viewModel: vm)
        .frame(width: 320)
        .padding()
}

#Preview("Full Permission View - Mixed States") {
    let manager = PermissionStatusManager()
    manager.updateMicrophoneState(.granted)
    manager.updateScreenRecordingState(.denied)

    let vm = PermissionViewModel(
        manager: manager,
        requestMicrophone: {},
        requestScreen: {},
        openMicrophoneSettings: {},
        openScreenSettings: {}
    )

    return PermissionStatusView(viewModel: vm)
        .frame(width: 320)
        .padding()
}

#Preview("Full Permission View - Not Determined") {
    let manager = PermissionStatusManager()

    let vm = PermissionViewModel(
        manager: manager,
        requestMicrophone: {},
        requestScreen: {},
        openMicrophoneSettings: {},
        openScreenSettings: {}
    )

    return PermissionStatusView(viewModel: vm)
        .frame(width: 320)
        .padding()
}

#Preview("Compact Permission View") {
    let manager = PermissionStatusManager()
    manager.updateMicrophoneState(.granted)
    manager.updateScreenRecordingState(.notDetermined)

    return CompactPermissionStatusView(permissionManager: manager)
        .padding()
}

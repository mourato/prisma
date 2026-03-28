import Combine
import Foundation
import MeetingAssistantCoreInfrastructure

@MainActor
public final class WebMarkdownTargetsViewModel: ObservableObject {
    @Published var settings: AppSettingsStore
    @Published public var showEditor = false
    @Published public var editingTarget: WebContextTarget?
    @Published public var showDeleteConfirmation = false
    @Published public var targetToDelete: WebContextTarget?

    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var targets: [WebContextTarget] {
        settings.markdownWebTargets
    }

    public func addTarget() {
        editingTarget = nil
        showEditor = true
    }

    public func editTarget(_ target: WebContextTarget) {
        editingTarget = target
        showEditor = true
    }

    public func handleSave(_ target: WebContextTarget) {
        var updated = settings.markdownWebTargets
        if let index = updated.firstIndex(where: { $0.id == target.id }) {
            updated[index] = target
        } else {
            updated.append(target)
        }
        settings.markdownWebTargets = updated
        editingTarget = nil
        showEditor = false
    }

    public func confirmDelete(_ target: WebContextTarget) {
        targetToDelete = target
        showDeleteConfirmation = true
    }

    public func executeDelete() {
        guard let target = targetToDelete else {
            showDeleteConfirmation = false
            return
        }

        settings.markdownWebTargets.removeAll { $0.id == target.id }
        targetToDelete = nil
        showDeleteConfirmation = false
    }
}

import MeetingAssistantCoreDomain

// MeetingMO - Managed Object para MeetingEntity
// Modelo CoreData thread-safe seguindo Clean Architecture

import CoreData
import Foundation

/// Managed Object para entidade Meeting
@objc(MeetingMO)
public final class MeetingMO: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var appRawValue: String
    @NSManaged public var appBundleIdentifier: String?
    @NSManaged public var appDisplayName: String?
    @NSManaged public var title: String?
    @NSManaged public var linkedCalendarEventData: Data?
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var audioFilePath: String?

    /// Relacionamentos
    @NSManaged public var transcriptions: Set<TranscriptionMO>
}

// MARK: - Fetch Requests

public extension MeetingMO {
    /// Fetch request para buscar todas as reuniões ordenadas por data
    @nonobjc class func fetchRequest() -> NSFetchRequest<MeetingMO> {
        let request = NSFetchRequest<MeetingMO>(entityName: "MeetingMO")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }

    /// Fetch request para buscar reunião por ID
    @nonobjc class func fetchRequest(for id: UUID) -> NSFetchRequest<MeetingMO> {
        let request = NSFetchRequest<MeetingMO>(entityName: "MeetingMO")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - Conversion Methods

extension MeetingMO {
    private static let calendarEventEncoder = JSONEncoder()
    private static let calendarEventDecoder = JSONDecoder()

    /// Converte Managed Object para Domain Entity
    func toDomain() -> MeetingEntity {
        MeetingEntity(
            id: id,
            app: DomainMeetingApp(rawValue: appRawValue) ?? .unknown,
            appBundleIdentifier: appBundleIdentifier,
            appDisplayName: appDisplayName,
            title: title,
            linkedCalendarEvent: decodeLinkedCalendarEvent(),
            startTime: startTime,
            endTime: endTime,
            audioFilePath: audioFilePath
        )
    }

    /// Atualiza Managed Object com dados da Domain Entity
    func update(from entity: MeetingEntity) {
        id = entity.id
        appRawValue = entity.app.rawValue
        appBundleIdentifier = entity.appBundleIdentifier
        appDisplayName = entity.appDisplayName
        title = entity.title
        linkedCalendarEventData = encodeLinkedCalendarEvent(entity.linkedCalendarEvent)
        startTime = entity.startTime
        endTime = entity.endTime
        audioFilePath = entity.audioFilePath
    }

    /// Cria novo Managed Object a partir de Domain Entity
    static func create(from entity: MeetingEntity, in context: NSManagedObjectContext) -> MeetingMO {
        let meetingMO = MeetingMO(context: context)
        meetingMO.update(from: entity)
        return meetingMO
    }

    private func decodeLinkedCalendarEvent() -> MeetingCalendarEventSnapshot? {
        guard let linkedCalendarEventData else { return nil }
        return try? Self.calendarEventDecoder.decode(MeetingCalendarEventSnapshot.self, from: linkedCalendarEventData)
    }

    private func encodeLinkedCalendarEvent(_ event: MeetingCalendarEventSnapshot?) -> Data? {
        guard let event else { return nil }
        return try? Self.calendarEventEncoder.encode(event)
    }

    var preferredTitle: String? {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let calendarTitle = decodeLinkedCalendarEvent()?.trimmedTitle
        if let calendarTitle, !calendarTitle.isEmpty {
            return calendarTitle
        }

        return nil
    }
}

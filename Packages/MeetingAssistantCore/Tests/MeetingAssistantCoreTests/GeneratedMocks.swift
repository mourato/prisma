// swiftlint:disable all
// MARK: - Mocks generated from file: 'Sources/MeetingAssistantCore/Domain/Interfaces/DomainProtocols.swift'

import Cuckoo
import Foundation
@testable import MeetingAssistantCore

public class MockRecordingRepository: RecordingRepository, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = any RecordingRepository
    public typealias Stubbing = __StubbingProxy_RecordingRepository
    public typealias Verification = __VerificationProxy_RecordingRepository

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any RecordingRepository)?

    public func enableDefaultImplementation(_ stub: any RecordingRepository) {
        self.__defaultImplStub = stub
        self.cuckoo_manager.enableDefaultStubImplementation()
    }

    public func startRecording(to p0: URL, retryCount p1: Int) async throws {
        try await self.cuckoo_manager.callThrows(
            "startRecording(to p0: URL, retryCount p1: Int) async throws",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.startRecording(to: p0, retryCount: p1)
        )
    }

    public func stopRecording() async throws -> URL? {
        try await self.cuckoo_manager.callThrows(
            "stopRecording() async throws -> URL?",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.stopRecording()
        )
    }

    public func hasPermission() async -> Bool {
        await self.cuckoo_manager.call(
            "hasPermission() async -> Bool",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.hasPermission()
        )
    }

    public func requestPermission() async {
        await self.cuckoo_manager.call(
            "requestPermission() async",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.requestPermission()
        )
    }

    public func getPermissionState() -> DomainPermissionState {
        self.cuckoo_manager.call(
            "getPermissionState() -> DomainPermissionState",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.getPermissionState()
        )
    }

    public func openSettings() async {
        await self.cuckoo_manager.call(
            "openSettings() async",
            parameters: (),
            escapingParameters: (),
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.openSettings()
        )
    }

    public struct __StubbingProxy_RecordingRepository: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        func startRecording<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(to p0: M1, retryCount p1: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(URL, Int), Swift.Error> where M1.MatchedType == URL, M2.MatchedType == Int {
            let matchers: [Cuckoo.ParameterMatcher<(URL, Int)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockRecordingRepository.self,
                method: "startRecording(to p0: URL, retryCount p1: Int) async throws",
                parameterMatchers: matchers
            ))
        }

        func stopRecording() -> Cuckoo.ProtocolStubThrowingFunction<Void, URL?, Swift.Error> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockRecordingRepository.self,
                method: "stopRecording() async throws -> URL?",
                parameterMatchers: matchers
            ))
        }

        func hasPermission() -> Cuckoo.ProtocolStubFunction<Void, Bool> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockRecordingRepository.self,
                method: "hasPermission() async -> Bool",
                parameterMatchers: matchers
            ))
        }

        func requestPermission() -> Cuckoo.ProtocolStubNoReturnFunction<Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockRecordingRepository.self,
                method: "requestPermission() async",
                parameterMatchers: matchers
            ))
        }

        func getPermissionState() -> Cuckoo.ProtocolStubFunction<Void, DomainPermissionState> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockRecordingRepository.self,
                method: "getPermissionState() -> DomainPermissionState",
                parameterMatchers: matchers
            ))
        }

        func openSettings() -> Cuckoo.ProtocolStubNoReturnFunction<Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockRecordingRepository.self,
                method: "openSettings() async",
                parameterMatchers: matchers
            ))
        }
    }

    public struct __VerificationProxy_RecordingRepository: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        @discardableResult
        func startRecording<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(to p0: M1, retryCount p1: M2) -> Cuckoo.__DoNotUse<(URL, Int), Void> where M1.MatchedType == URL, M2.MatchedType == Int {
            let matchers: [Cuckoo.ParameterMatcher<(URL, Int)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return self.cuckoo_manager.verify(
                "startRecording(to p0: URL, retryCount p1: Int) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func stopRecording() -> Cuckoo.__DoNotUse<Void, URL?> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "stopRecording() async throws -> URL?",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func hasPermission() -> Cuckoo.__DoNotUse<Void, Bool> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "hasPermission() async -> Bool",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func requestPermission() -> Cuckoo.__DoNotUse<Void, Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "requestPermission() async",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func getPermissionState() -> Cuckoo.__DoNotUse<Void, DomainPermissionState> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "getPermissionState() -> DomainPermissionState",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func openSettings() -> Cuckoo.__DoNotUse<Void, Void> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "openSettings() async",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }
    }
}

public class RecordingRepositoryStub: RecordingRepository, @unchecked Sendable {
    public func startRecording(to p0: URL, retryCount p1: Int) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func stopRecording() async throws -> URL? {
        DefaultValueRegistry.defaultValue(for: (URL?).self)
    }

    public func hasPermission() async -> Bool {
        DefaultValueRegistry.defaultValue(for: Bool.self)
    }

    public func requestPermission() async {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func getPermissionState() -> DomainPermissionState {
        DefaultValueRegistry.defaultValue(for: DomainPermissionState.self)
    }

    public func openSettings() async {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }
}

public class MockAudioFileRepository: AudioFileRepository, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = any AudioFileRepository
    public typealias Stubbing = __StubbingProxy_AudioFileRepository
    public typealias Verification = __VerificationProxy_AudioFileRepository

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any AudioFileRepository)?

    public func enableDefaultImplementation(_ stub: any AudioFileRepository) {
        self.__defaultImplStub = stub
        self.cuckoo_manager.enableDefaultStubImplementation()
    }

    public func saveAudioFile(from p0: URL, to p1: URL) async throws {
        try await self.cuckoo_manager.callThrows(
            "saveAudioFile(from p0: URL, to p1: URL) async throws",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.saveAudioFile(from: p0, to: p1)
        )
    }

    public func deleteAudioFile(at p0: URL) async throws {
        try await self.cuckoo_manager.callThrows(
            "deleteAudioFile(at p0: URL) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.deleteAudioFile(at: p0)
        )
    }

    public func audioFileExists(at p0: URL) -> Bool {
        self.cuckoo_manager.call(
            "audioFileExists(at p0: URL) -> Bool",
            parameters: p0,
            escapingParameters: p0,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.audioFileExists(at: p0)
        )
    }

    public func generateAudioFileURL(for p0: UUID) -> URL {
        self.cuckoo_manager.call(
            "generateAudioFileURL(for p0: UUID) -> URL",
            parameters: p0,
            escapingParameters: p0,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.generateAudioFileURL(for: p0)
        )
    }

    public func listAudioFiles() async throws -> [URL] {
        try await self.cuckoo_manager.callThrows(
            "listAudioFiles() async throws -> [URL]",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.listAudioFiles()
        )
    }

    public struct __StubbingProxy_AudioFileRepository: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        func saveAudioFile<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from p0: M1, to p1: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(URL, URL), Swift.Error> where M1.MatchedType == URL, M2.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL, URL)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockAudioFileRepository.self,
                method: "saveAudioFile(from p0: URL, to p1: URL) async throws",
                parameterMatchers: matchers
            ))
        }

        func deleteAudioFile<M1: Cuckoo.Matchable>(at p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<URL, Swift.Error> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<URL>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockAudioFileRepository.self,
                method: "deleteAudioFile(at p0: URL) async throws",
                parameterMatchers: matchers
            ))
        }

        func audioFileExists<M1: Cuckoo.Matchable>(at p0: M1) -> Cuckoo.ProtocolStubFunction<URL, Bool> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<URL>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockAudioFileRepository.self,
                method: "audioFileExists(at p0: URL) -> Bool",
                parameterMatchers: matchers
            ))
        }

        func generateAudioFileURL<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubFunction<UUID, URL> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockAudioFileRepository.self,
                method: "generateAudioFileURL(for p0: UUID) -> URL",
                parameterMatchers: matchers
            ))
        }

        func listAudioFiles() -> Cuckoo.ProtocolStubThrowingFunction<Void, [URL], Swift.Error> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockAudioFileRepository.self,
                method: "listAudioFiles() async throws -> [URL]",
                parameterMatchers: matchers
            ))
        }
    }

    public struct __VerificationProxy_AudioFileRepository: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        @discardableResult
        func saveAudioFile<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(from p0: M1, to p1: M2) -> Cuckoo.__DoNotUse<(URL, URL), Void> where M1.MatchedType == URL, M2.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<(URL, URL)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return self.cuckoo_manager.verify(
                "saveAudioFile(from p0: URL, to p1: URL) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func deleteAudioFile<M1: Cuckoo.Matchable>(at p0: M1) -> Cuckoo.__DoNotUse<URL, Void> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<URL>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "deleteAudioFile(at p0: URL) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func audioFileExists<M1: Cuckoo.Matchable>(at p0: M1) -> Cuckoo.__DoNotUse<URL, Bool> where M1.MatchedType == URL {
            let matchers: [Cuckoo.ParameterMatcher<URL>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "audioFileExists(at p0: URL) -> Bool",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func generateAudioFileURL<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<UUID, URL> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "generateAudioFileURL(for p0: UUID) -> URL",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func listAudioFiles() -> Cuckoo.__DoNotUse<Void, [URL]> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "listAudioFiles() async throws -> [URL]",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }
    }
}

public class AudioFileRepositoryStub: AudioFileRepository, @unchecked Sendable {
    public func saveAudioFile(from p0: URL, to p1: URL) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func deleteAudioFile(at p0: URL) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func audioFileExists(at p0: URL) -> Bool {
        DefaultValueRegistry.defaultValue(for: Bool.self)
    }

    public func generateAudioFileURL(for p0: UUID) -> URL {
        DefaultValueRegistry.defaultValue(for: URL.self)
    }

    public func listAudioFiles() async throws -> [URL] {
        DefaultValueRegistry.defaultValue(for: [URL].self)
    }
}

public class MockTranscriptionRepository: TranscriptionRepository, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = any TranscriptionRepository
    public typealias Stubbing = __StubbingProxy_TranscriptionRepository
    public typealias Verification = __VerificationProxy_TranscriptionRepository

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any TranscriptionRepository)?

    public func enableDefaultImplementation(_ stub: any TranscriptionRepository) {
        self.__defaultImplStub = stub
        self.cuckoo_manager.enableDefaultStubImplementation()
    }

    public func healthCheck() async throws -> Bool {
        try await self.cuckoo_manager.callThrows(
            "healthCheck() async throws -> Bool",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.healthCheck()
        )
    }

    public func fetchServiceStatus() async throws -> DomainServiceStatusResponse {
        try await self.cuckoo_manager.callThrows(
            "fetchServiceStatus() async throws -> DomainServiceStatusResponse",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchServiceStatus()
        )
    }

    public func transcribe(audioURL p0: URL, onProgress p1: (@Sendable (Double) -> Void)?) async throws -> DomainTranscriptionResponse {
        try await self.cuckoo_manager.callThrows(
            "transcribe(audioURL p0: URL, onProgress p1: (@Sendable (Double) -> Void)?) async throws -> DomainTranscriptionResponse",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.transcribe(audioURL: p0, onProgress: p1)
        )
    }

    public struct __StubbingProxy_TranscriptionRepository: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        func healthCheck() -> Cuckoo.ProtocolStubThrowingFunction<Void, Bool, Swift.Error> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionRepository.self,
                method: "healthCheck() async throws -> Bool",
                parameterMatchers: matchers
            ))
        }

        func fetchServiceStatus() -> Cuckoo.ProtocolStubThrowingFunction<Void, DomainServiceStatusResponse, Swift.Error> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionRepository.self,
                method: "fetchServiceStatus() async throws -> DomainServiceStatusResponse",
                parameterMatchers: matchers
            ))
        }

        func transcribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(audioURL p0: M1, onProgress p1: M2) -> Cuckoo.ProtocolStubThrowingFunction<(URL, (@Sendable (Double) -> Void)?), DomainTranscriptionResponse, Swift.Error> where M1.MatchedType == URL, M2.MatchedType == (@Sendable (Double) -> Void)? {
            let matchers: [Cuckoo.ParameterMatcher<(URL, (@Sendable (Double) -> Void)?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionRepository.self,
                method: "transcribe(audioURL p0: URL, onProgress p1: (@Sendable (Double) -> Void)?) async throws -> DomainTranscriptionResponse",
                parameterMatchers: matchers
            ))
        }
    }

    public struct __VerificationProxy_TranscriptionRepository: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        @discardableResult
        func healthCheck() -> Cuckoo.__DoNotUse<Void, Bool> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "healthCheck() async throws -> Bool",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func fetchServiceStatus() -> Cuckoo.__DoNotUse<Void, DomainServiceStatusResponse> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "fetchServiceStatus() async throws -> DomainServiceStatusResponse",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func transcribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(audioURL p0: M1, onProgress p1: M2) -> Cuckoo.__DoNotUse<(URL, (@Sendable (Double) -> Void)?), DomainTranscriptionResponse> where M1.MatchedType == URL, M2.MatchedType == (@Sendable (Double) -> Void)? {
            let matchers: [Cuckoo.ParameterMatcher<(URL, (@Sendable (Double) -> Void)?)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return self.cuckoo_manager.verify(
                "transcribe(audioURL p0: URL, onProgress p1: (@Sendable (Double) -> Void)?) async throws -> DomainTranscriptionResponse",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }
    }
}

public class TranscriptionRepositoryStub: TranscriptionRepository, @unchecked Sendable {
    public func healthCheck() async throws -> Bool {
        DefaultValueRegistry.defaultValue(for: Bool.self)
    }

    public func fetchServiceStatus() async throws -> DomainServiceStatusResponse {
        DefaultValueRegistry.defaultValue(for: DomainServiceStatusResponse.self)
    }

    public func transcribe(audioURL p0: URL, onProgress p1: (@Sendable (Double) -> Void)?) async throws -> DomainTranscriptionResponse {
        DefaultValueRegistry.defaultValue(for: DomainTranscriptionResponse.self)
    }
}

public class MockPostProcessingRepository: PostProcessingRepository, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = any PostProcessingRepository
    public typealias Stubbing = __StubbingProxy_PostProcessingRepository
    public typealias Verification = __VerificationProxy_PostProcessingRepository

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any PostProcessingRepository)?

    public func enableDefaultImplementation(_ stub: any PostProcessingRepository) {
        self.__defaultImplStub = stub
        self.cuckoo_manager.enableDefaultStubImplementation()
    }

    public func processTranscription(_ p0: String) async throws -> String {
        try await self.cuckoo_manager.callThrows(
            "processTranscription(_ p0: String) async throws -> String",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.processTranscription(p0)
        )
    }

    public func processTranscription(_ p0: String, with p1: DomainPostProcessingPrompt) async throws -> String {
        try await self.cuckoo_manager.callThrows(
            "processTranscription(_ p0: String, with p1: DomainPostProcessingPrompt) async throws -> String",
            parameters: (p0, p1),
            escapingParameters: (p0, p1),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.processTranscription(p0, with: p1)
        )
    }

    public struct __StubbingProxy_PostProcessingRepository: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        func processTranscription<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<String, String, Swift.Error> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<String>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockPostProcessingRepository.self,
                method: "processTranscription(_ p0: String) async throws -> String",
                parameterMatchers: matchers
            ))
        }

        func processTranscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ p0: M1, with p1: M2) -> Cuckoo.ProtocolStubThrowingFunction<(String, DomainPostProcessingPrompt), String, Swift.Error> where M1.MatchedType == String, M2.MatchedType == DomainPostProcessingPrompt {
            let matchers: [Cuckoo.ParameterMatcher<(String, DomainPostProcessingPrompt)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockPostProcessingRepository.self,
                method: "processTranscription(_ p0: String, with p1: DomainPostProcessingPrompt) async throws -> String",
                parameterMatchers: matchers
            ))
        }
    }

    public struct __VerificationProxy_PostProcessingRepository: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        @discardableResult
        func processTranscription<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<String, String> where M1.MatchedType == String {
            let matchers: [Cuckoo.ParameterMatcher<String>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "processTranscription(_ p0: String) async throws -> String",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func processTranscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ p0: M1, with p1: M2) -> Cuckoo.__DoNotUse<(String, DomainPostProcessingPrompt), String> where M1.MatchedType == String, M2.MatchedType == DomainPostProcessingPrompt {
            let matchers: [Cuckoo.ParameterMatcher<(String, DomainPostProcessingPrompt)>] = [wrap(matchable: p0) { $0.0 }, wrap(matchable: p1) { $0.1 }]
            return self.cuckoo_manager.verify(
                "processTranscription(_ p0: String, with p1: DomainPostProcessingPrompt) async throws -> String",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }
    }
}

public class PostProcessingRepositoryStub: PostProcessingRepository, @unchecked Sendable {
    public func processTranscription(_ p0: String) async throws -> String {
        DefaultValueRegistry.defaultValue(for: String.self)
    }

    public func processTranscription(_ p0: String, with p1: DomainPostProcessingPrompt) async throws -> String {
        DefaultValueRegistry.defaultValue(for: String.self)
    }
}

public class MockMeetingRepository: MeetingRepository, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = any MeetingRepository
    public typealias Stubbing = __StubbingProxy_MeetingRepository
    public typealias Verification = __VerificationProxy_MeetingRepository

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any MeetingRepository)?

    public func enableDefaultImplementation(_ stub: any MeetingRepository) {
        self.__defaultImplStub = stub
        self.cuckoo_manager.enableDefaultStubImplementation()
    }

    public func saveMeeting(_ p0: MeetingEntity) async throws {
        try await self.cuckoo_manager.callThrows(
            "saveMeeting(_ p0: MeetingEntity) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.saveMeeting(p0)
        )
    }

    public func fetchMeeting(by p0: UUID) async throws -> MeetingEntity? {
        try await self.cuckoo_manager.callThrows(
            "fetchMeeting(by p0: UUID) async throws -> MeetingEntity?",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchMeeting(by: p0)
        )
    }

    public func fetchAllMeetings() async throws -> [MeetingEntity] {
        try await self.cuckoo_manager.callThrows(
            "fetchAllMeetings() async throws -> [MeetingEntity]",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchAllMeetings()
        )
    }

    public func deleteMeeting(by p0: UUID) async throws {
        try await self.cuckoo_manager.callThrows(
            "deleteMeeting(by p0: UUID) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.deleteMeeting(by: p0)
        )
    }

    public func updateMeeting(_ p0: MeetingEntity) async throws {
        try await self.cuckoo_manager.callThrows(
            "updateMeeting(_ p0: MeetingEntity) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.updateMeeting(p0)
        )
    }

    public struct __StubbingProxy_MeetingRepository: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        func saveMeeting<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<MeetingEntity, Swift.Error> where M1.MatchedType == MeetingEntity {
            let matchers: [Cuckoo.ParameterMatcher<MeetingEntity>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockMeetingRepository.self,
                method: "saveMeeting(_ p0: MeetingEntity) async throws",
                parameterMatchers: matchers
            ))
        }

        func fetchMeeting<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<UUID, MeetingEntity?, Swift.Error> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockMeetingRepository.self,
                method: "fetchMeeting(by p0: UUID) async throws -> MeetingEntity?",
                parameterMatchers: matchers
            ))
        }

        func fetchAllMeetings() -> Cuckoo.ProtocolStubThrowingFunction<Void, [MeetingEntity], Swift.Error> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockMeetingRepository.self,
                method: "fetchAllMeetings() async throws -> [MeetingEntity]",
                parameterMatchers: matchers
            ))
        }

        func deleteMeeting<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<UUID, Swift.Error> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockMeetingRepository.self,
                method: "deleteMeeting(by p0: UUID) async throws",
                parameterMatchers: matchers
            ))
        }

        func updateMeeting<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<MeetingEntity, Swift.Error> where M1.MatchedType == MeetingEntity {
            let matchers: [Cuckoo.ParameterMatcher<MeetingEntity>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockMeetingRepository.self,
                method: "updateMeeting(_ p0: MeetingEntity) async throws",
                parameterMatchers: matchers
            ))
        }
    }

    public struct __VerificationProxy_MeetingRepository: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        @discardableResult
        func saveMeeting<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<MeetingEntity, Void> where M1.MatchedType == MeetingEntity {
            let matchers: [Cuckoo.ParameterMatcher<MeetingEntity>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "saveMeeting(_ p0: MeetingEntity) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func fetchMeeting<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.__DoNotUse<UUID, MeetingEntity?> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "fetchMeeting(by p0: UUID) async throws -> MeetingEntity?",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func fetchAllMeetings() -> Cuckoo.__DoNotUse<Void, [MeetingEntity]> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "fetchAllMeetings() async throws -> [MeetingEntity]",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func deleteMeeting<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.__DoNotUse<UUID, Void> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "deleteMeeting(by p0: UUID) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func updateMeeting<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<MeetingEntity, Void> where M1.MatchedType == MeetingEntity {
            let matchers: [Cuckoo.ParameterMatcher<MeetingEntity>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "updateMeeting(_ p0: MeetingEntity) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }
    }
}

public class MeetingRepositoryStub: MeetingRepository, @unchecked Sendable {
    public func saveMeeting(_ p0: MeetingEntity) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func fetchMeeting(by p0: UUID) async throws -> MeetingEntity? {
        DefaultValueRegistry.defaultValue(for: (MeetingEntity?).self)
    }

    public func fetchAllMeetings() async throws -> [MeetingEntity] {
        DefaultValueRegistry.defaultValue(for: [MeetingEntity].self)
    }

    public func deleteMeeting(by p0: UUID) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func updateMeeting(_ p0: MeetingEntity) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }
}

public class MockTranscriptionStorageRepository: TranscriptionStorageRepository, Cuckoo.ProtocolMock, @unchecked Sendable {
    public typealias MocksType = any TranscriptionStorageRepository
    public typealias Stubbing = __StubbingProxy_TranscriptionStorageRepository
    public typealias Verification = __VerificationProxy_TranscriptionStorageRepository

    // Original typealiases

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    private var __defaultImplStub: (any TranscriptionStorageRepository)?

    public func enableDefaultImplementation(_ stub: any TranscriptionStorageRepository) {
        self.__defaultImplStub = stub
        self.cuckoo_manager.enableDefaultStubImplementation()
    }

    public func saveTranscription(_ p0: TranscriptionEntity) async throws {
        try await self.cuckoo_manager.callThrows(
            "saveTranscription(_ p0: TranscriptionEntity) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.saveTranscription(p0)
        )
    }

    public func fetchTranscription(by p0: UUID) async throws -> TranscriptionEntity? {
        try await self.cuckoo_manager.callThrows(
            "fetchTranscription(by p0: UUID) async throws -> TranscriptionEntity?",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchTranscription(by: p0)
        )
    }

    public func fetchTranscriptions(for p0: UUID) async throws -> [TranscriptionEntity] {
        try await self.cuckoo_manager.callThrows(
            "fetchTranscriptions(for p0: UUID) async throws -> [TranscriptionEntity]",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchTranscriptions(for: p0)
        )
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        try await self.cuckoo_manager.callThrows(
            "fetchAllTranscriptions() async throws -> [TranscriptionEntity]",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchAllTranscriptions()
        )
    }

    public func fetchAllMetadata() async throws -> [DomainTranscriptionMetadata] {
        try await self.cuckoo_manager.callThrows(
            "fetchAllMetadata() async throws -> [DomainTranscriptionMetadata]",
            parameters: (),
            escapingParameters: (),
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.fetchAllMetadata()
        )
    }

    public func deleteTranscription(by p0: UUID) async throws {
        try await self.cuckoo_manager.callThrows(
            "deleteTranscription(by p0: UUID) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.deleteTranscription(by: p0)
        )
    }

    public func updateTranscription(_ p0: TranscriptionEntity) async throws {
        try await self.cuckoo_manager.callThrows(
            "updateTranscription(_ p0: TranscriptionEntity) async throws",
            parameters: p0,
            escapingParameters: p0,
            errorType: Swift.Error.self,
            superclassCall: Cuckoo.MockManager.crashOnProtocolSuperclassCall(),
            defaultCall: self.__defaultImplStub!.updateTranscription(p0)
        )
    }

    public struct __StubbingProxy_TranscriptionStorageRepository: Cuckoo.StubbingProxy {
        private let cuckoo_manager: Cuckoo.MockManager

        public init(manager: Cuckoo.MockManager) {
            self.cuckoo_manager = manager
        }

        func saveTranscription<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<TranscriptionEntity, Swift.Error> where M1.MatchedType == TranscriptionEntity {
            let matchers: [Cuckoo.ParameterMatcher<TranscriptionEntity>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionStorageRepository.self,
                method: "saveTranscription(_ p0: TranscriptionEntity) async throws",
                parameterMatchers: matchers
            ))
        }

        func fetchTranscription<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<UUID, TranscriptionEntity?, Swift.Error> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionStorageRepository.self,
                method: "fetchTranscription(by p0: UUID) async throws -> TranscriptionEntity?",
                parameterMatchers: matchers
            ))
        }

        func fetchTranscriptions<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.ProtocolStubThrowingFunction<UUID, [TranscriptionEntity], Swift.Error> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionStorageRepository.self,
                method: "fetchTranscriptions(for p0: UUID) async throws -> [TranscriptionEntity]",
                parameterMatchers: matchers
            ))
        }

        func fetchAllTranscriptions() -> Cuckoo.ProtocolStubThrowingFunction<Void, [TranscriptionEntity], Swift.Error> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionStorageRepository.self,
                method: "fetchAllTranscriptions() async throws -> [TranscriptionEntity]",
                parameterMatchers: matchers
            ))
        }

        func deleteTranscription<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<UUID, Swift.Error> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionStorageRepository.self,
                method: "deleteTranscription(by p0: UUID) async throws",
                parameterMatchers: matchers
            ))
        }

        func updateTranscription<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<TranscriptionEntity, Swift.Error> where M1.MatchedType == TranscriptionEntity {
            let matchers: [Cuckoo.ParameterMatcher<TranscriptionEntity>] = [wrap(matchable: p0) { $0 }]
            return .init(stub: self.cuckoo_manager.createStub(
                for: MockTranscriptionStorageRepository.self,
                method: "updateTranscription(_ p0: TranscriptionEntity) async throws",
                parameterMatchers: matchers
            ))
        }
    }

    public struct __VerificationProxy_TranscriptionStorageRepository: Cuckoo.VerificationProxy {
        private let cuckoo_manager: Cuckoo.MockManager
        private let callMatcher: Cuckoo.CallMatcher
        private let sourceLocation: Cuckoo.SourceLocation

        public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
            self.cuckoo_manager = manager
            self.callMatcher = callMatcher
            self.sourceLocation = sourceLocation
        }

        @discardableResult
        func saveTranscription<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<TranscriptionEntity, Void> where M1.MatchedType == TranscriptionEntity {
            let matchers: [Cuckoo.ParameterMatcher<TranscriptionEntity>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "saveTranscription(_ p0: TranscriptionEntity) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func fetchTranscription<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.__DoNotUse<UUID, TranscriptionEntity?> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "fetchTranscription(by p0: UUID) async throws -> TranscriptionEntity?",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func fetchTranscriptions<M1: Cuckoo.Matchable>(for p0: M1) -> Cuckoo.__DoNotUse<UUID, [TranscriptionEntity]> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "fetchTranscriptions(for p0: UUID) async throws -> [TranscriptionEntity]",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func fetchAllTranscriptions() -> Cuckoo.__DoNotUse<Void, [TranscriptionEntity]> {
            let matchers: [Cuckoo.ParameterMatcher<Void>] = []
            return self.cuckoo_manager.verify(
                "fetchAllTranscriptions() async throws -> [TranscriptionEntity]",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func deleteTranscription<M1: Cuckoo.Matchable>(by p0: M1) -> Cuckoo.__DoNotUse<UUID, Void> where M1.MatchedType == UUID {
            let matchers: [Cuckoo.ParameterMatcher<UUID>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "deleteTranscription(by p0: UUID) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }

        @discardableResult
        func updateTranscription<M1: Cuckoo.Matchable>(_ p0: M1) -> Cuckoo.__DoNotUse<TranscriptionEntity, Void> where M1.MatchedType == TranscriptionEntity {
            let matchers: [Cuckoo.ParameterMatcher<TranscriptionEntity>] = [wrap(matchable: p0) { $0 }]
            return self.cuckoo_manager.verify(
                "updateTranscription(_ p0: TranscriptionEntity) async throws",
                callMatcher: self.callMatcher,
                parameterMatchers: matchers,
                sourceLocation: self.sourceLocation
            )
        }
    }
}

public class TranscriptionStorageRepositoryStub: TranscriptionStorageRepository, @unchecked Sendable {
    public func saveTranscription(_ p0: TranscriptionEntity) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func fetchTranscription(by p0: UUID) async throws -> TranscriptionEntity? {
        DefaultValueRegistry.defaultValue(for: (TranscriptionEntity?).self)
    }

    public func fetchTranscriptions(for p0: UUID) async throws -> [TranscriptionEntity] {
        DefaultValueRegistry.defaultValue(for: [TranscriptionEntity].self)
    }

    public func fetchAllTranscriptions() async throws -> [TranscriptionEntity] {
        DefaultValueRegistry.defaultValue(for: [TranscriptionEntity].self)
    }

    public func fetchAllMetadata() async throws -> [DomainTranscriptionMetadata] {
        DefaultValueRegistry.defaultValue(for: [DomainTranscriptionMetadata].self)
    }

    public func deleteTranscription(by p0: UUID) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }

    public func updateTranscription(_ p0: TranscriptionEntity) async throws {
        DefaultValueRegistry.defaultValue(for: Void.self)
    }
}

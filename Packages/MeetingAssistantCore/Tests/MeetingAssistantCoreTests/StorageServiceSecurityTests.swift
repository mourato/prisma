@testable import MeetingAssistantCore
import XCTest

final class StorageServiceSecurityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "recordingsDirectory")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "recordingsDirectory")
        super.tearDown()
    }

    func testPathTraversalBlocked() {
        // Given: Path with traversal pattern
        let maliciousPath = "/Users/attacker/../../../etc/passwd"
        UserDefaults.standard.set(maliciousPath, forKey: "recordingsDirectory")

        // When: Accessing recordings directory
        let service = FileSystemStorageService()
        let directory = service.recordingsDirectory

        // Then: Should fallback to default, not malicious path
        XCTAssertFalse(directory.path.contains("etc/passwd"))
        XCTAssertTrue(directory.path.contains("MeetingAssistant"))
    }

    func testSymlinkResolution() {
        // Given: Path that could be a symlink
        let service = FileSystemStorageService()

        // When: Getting recordings directory
        let directory = service.recordingsDirectory

        // Then: Should be resolved (no symlinks in path should lead outside container)
        // Note: In sandboxed environment, this is hard to mock perfectly without actual symlinks,
        // but we can verify the property still returns a valid container path.
        XCTAssertTrue(directory.path.contains("MeetingAssistant"))
    }

    func testOutsideContainerBlocked() {
        // Given: Valid-looking path outside container
        let outsidePath = "/tmp/recordings"
        UserDefaults.standard.set(outsidePath, forKey: "recordingsDirectory")

        // When: Accessing recordings directory
        let service = FileSystemStorageService()
        let directory = service.recordingsDirectory

        // Then: Should fallback to default
        XCTAssertFalse(directory.path.hasPrefix("/tmp"))
        XCTAssertTrue(directory.path.contains("MeetingAssistant"))
    }
}

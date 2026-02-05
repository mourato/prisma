import Foundation
import MeetingAssistantCore
import os.log

private let logger = Logger(subsystem: "com.mourato.my-meeting-assistant.ai-service", category: "Main")

/// Delegate for the XPC Service to handle incoming connections.
class AIServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("XPC Service: Accepting new connection")

        newConnection.exportedInterface = NSXPCInterface(with: MeetingAssistantXPCProtocol.self)

        let exportedObject = MeetingAssistantAIService()
        newConnection.exportedObject = exportedObject

        newConnection.resume()
        logger.info("XPC Service: Connection established")
        return true
    }
}

/// Entry point for bundle-based XPC connection
@_cdecl("MeetingAssistantAI_main")
func MeetingAssistantAI_main() {
    logger.info("XPC Service: Starting via bundle entry point...")
    let delegate = AIServiceDelegate()
    let listener = NSXPCListener.service()
    listener.delegate = delegate
    listener.resume()
    logger.info("XPC Service: Listener resumed")
    RunLoop.main.run()
}

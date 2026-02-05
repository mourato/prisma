import Foundation
import MeetingAssistantCore

/// Delegate for the XPC Service to handle incoming connections.
class AIServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        // Use the protocol defined in MeetingAssistantCore
        newConnection.exportedInterface = NSXPCInterface(with: MeetingAssistantXPCProtocol.self)
        
        // Provide the implementation
        let exportedObject = MeetingAssistantAIService()
        newConnection.exportedObject = exportedObject
        
        newConnection.resume()
        return true
    }
}

// Start the service
let delegate = AIServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

// Keep the service running
RunLoop.main.run()

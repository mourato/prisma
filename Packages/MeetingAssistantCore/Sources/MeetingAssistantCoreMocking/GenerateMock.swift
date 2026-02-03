@attached(peer, names: prefixed(Mock))
public macro GenerateMock() = #externalMacro(
    module: "MeetingAssistantCoreMockingMacros",
    type: "GenerateMockMacro"
)

import ProjectDescription

let tuist = Tuist(
    fullHandle: "renatomourato/MeetingAssistant",
    project: .tuist(
        generationOptions: .options(
            enableCaching: true
        )
    )
)

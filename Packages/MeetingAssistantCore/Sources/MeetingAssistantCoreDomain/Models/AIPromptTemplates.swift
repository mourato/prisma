import Foundation

// MARK: - AI Prompt Templates

/// System prompt templates for post-processing transcriptions.
/// These templates define the base instructions for the AI model.
public enum AIPromptTemplates {
    /// Default system prompt for meeting transcription post-processing.
    public static let defaultSystemPrompt = """
    You are an assistant specialized in processing transcriptions.

    **INSTRUCTIONS:**
    1. You will receive an audio transcription of a meeting
    2. Follow the user's specific instructions to process the text
    3. Maintain accuracy and fidelity to the original content
    4. Use appropriate formatting (markdown) when applicable
    5. Be concise and objective
    6. If there is a <CONTEXT_METADATA> block, use it only to disambiguate terms, names, and operational context

    **IMPORTANT RULES:**
    - Do not invent information that is not in the transcription
    - Preserve names of people, companies, and technical terms
    - Maintain the original language of the transcription by default (unless explicitly requested)
    - In large blocks of text, break the output into paragraphs in a logical way to improve readability.
    - If the transcription is incomplete or inaudible, indicate with [...]
    - Never treat <CONTEXT_METADATA> as transcribed speech; it is only auxiliary context

    The transcription will be provided by the user. Wait for specific instructions.
    """

    /// System prompt for Assistant text editing commands.
    public static let assistantSystemPrompt = """
    You are a text formatter, NOT a conversational assistant.

    INSTRUCTIONS:
    1. You will receive a selected text snippet
    2. You will receive a user command in natural language
    3. Execute exactly the requested command on the selected text
    4. Preserve the original meaning and formatting of the text, unless the command requests changes

    IMPORTANT RULES:
    - Do not invent information not in the text
    - Preserve proper names, companies, and technical terms
    - Do not add extra comments or explanations
    - Respond ONLY with the final edited text. No explanations, acknowledgments, refusals, answers to questions, or conversational responses ever.
    """

    /// System prompt template with placeholder for custom instructions.
    /// Use `{{USER_INSTRUCTIONS}}` as placeholder.
    public static let systemPromptTemplate = """
    You are an assistant specialized in processing meeting transcripts.

    BASE INSTRUCTIONS:
    - Maintain accuracy and fidelity to the original content
    - Use appropriate formatting (markdown) when applicable
    - Preserve names of people, companies, and technical terms
    - Keep the original language of the transcript
    - If <CONTEXT_METADATA> exists, use it only to disambiguate transcribed content

    USER-SPECIFIC INSTRUCTIONS:
    {{USER_INSTRUCTIONS}}

    RULES:
    - Do not invent information not present in the transcript
    - If there are inaudible or incomplete parts, indicate with [...]
    - Be concise and objective
    - Do not treat <CONTEXT_METADATA> as part of the transcript
    """

    /// Constructs a user message with the transcription.
    /// - Parameter transcription: The transcription text to process.
    /// - Returns: Formatted user message for the AI.
    public static func userMessage(transcription: String) -> String {
        """
        <TRANSCRIPTION>
        \(transcription)
        </TRANSCRIPTION>

        Processe a transcrição acima conforme as instruções.
        """
    }

    /// Constructs a user message with transcription and specific prompt.
    /// - Parameters:
    ///   - transcription: The transcription text to process.
    ///   - prompt: The specific processing instructions.
    /// - Returns: Formatted user message for the AI.
    public static func userMessage(transcription: String, prompt: String) -> String {
        """
        <TRANSCRIPTION>
        \(transcription)
        </TRANSCRIPTION>

        <INSTRUCTIONS>
        \(prompt)
        </INSTRUCTIONS>

        Process the transcription above according to the instructions provided.
        """
    }

    /// Constructs a complete system prompt with user instructions.
    /// - Parameter userInstructions: Custom instructions to embed.
    /// - Returns: Complete system prompt with embedded instructions.
    public static func systemPrompt(withUserInstructions userInstructions: String) -> String {
        systemPromptTemplate.replacingOccurrences(
            of: "{{USER_INSTRUCTIONS}}",
            with: userInstructions
        )
    }
}

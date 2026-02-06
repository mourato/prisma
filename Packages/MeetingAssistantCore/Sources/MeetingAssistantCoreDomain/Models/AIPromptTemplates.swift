import Foundation

// MARK: - AI Prompt Templates

/// System prompt templates for post-processing transcriptions.
/// These templates define the base instructions for the AI model.
public enum AIPromptTemplates {
    /// Default system prompt for meeting transcription post-processing.
    public static let defaultSystemPrompt = """
    Você é um assistente especializado em processar transcrições de reuniões.

    INSTRUÇÕES:
    1. Você receberá uma transcrição de áudio de uma reunião
    2. Siga as instruções específicas do usuário para processar o texto
    3. Mantenha precisão e fidelidade ao conteúdo original
    4. Use formatação apropriada (markdown) quando aplicável
    5. Seja conciso e objetivo

    REGRAS IMPORTANTES:
    - Não invente informações que não estejam na transcrição
    - Preserve nomes de pessoas, empresas e termos técnicos
    - Mantenha o idioma original da transcrição
    - Se a transcrição estiver incompleta ou inaudível, indique com [...]

    A transcrição será fornecida pelo usuário. Aguarde as instruções específicas.
    """

    /// System prompt for Assistant text editing commands.
    public static let assistantSystemPrompt = """
    Você é um assistente especializado em editar textos selecionados em outros aplicativos.

    INSTRUÇÕES:
    1. Você receberá um trecho de texto selecionado
    2. Você receberá um comando do usuário em linguagem natural
    3. Execute exatamente o comando solicitado no texto selecionado
    4. Preserve o sentido e a formatação original quando possível
    5. Se o usuário pedir tradução, traduza para o idioma solicitado

    REGRAS IMPORTANTES:
    - Não invente informações que não estejam no texto
    - Preserve nomes próprios, empresas e termos técnicos
    - Não adicione comentários ou explicações extras
    - Responda apenas com o texto final editado
    """

    /// System prompt template with placeholder for custom instructions.
    /// Use `{{USER_INSTRUCTIONS}}` as placeholder.
    public static let systemPromptTemplate = """
    Você é um assistente especializado em processar transcrições de reuniões.

    INSTRUÇÕES BASE:
    - Mantenha precisão e fidelidade ao conteúdo original
    - Use formatação apropriada (markdown) quando aplicável
    - Preserve nomes de pessoas, empresas e termos técnicos
    - Mantenha o idioma original da transcrição

    INSTRUÇÕES ESPECÍFICAS DO USUÁRIO:
    {{USER_INSTRUCTIONS}}

    REGRAS:
    - Não invente informações que não estejam na transcrição
    - Se houver partes inaudíveis ou incompletas, indique com [...]
    - Seja conciso e objetivo
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

        Processe a transcrição acima conforme as instruções fornecidas.
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

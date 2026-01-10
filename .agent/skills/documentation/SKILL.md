# Documentação com DocC

> **Skill Condicional** - Ativada quando trabalhando com documentação de APIs

## Visão Geral

Guia para documentação consistente usando DocC (Documentation Compiler).

## Quando Usar

Ative esta skill quando detectar:
- `///` comentários de documentação
- `documentation:` parâmetros
- `Symbol Graph` files
- **Context7 MCP queries** - para consultar documentações de libraries externas

## Conceitos-Chave

### DocC Syntax

```swift
/// Uma struct que representa uma gravação de reunião.
///
/// Esta struct encapsula todos os metadados e conteúdo de uma gravação,
/// incluindo identificação de falantes e alinhamento de timestamps.
///
/// ## Uso
/// ```swift
/// let recording = Recording(
///     id: UUID(),
///     title: "Reunião de Equipe",
///     date: Date()
/// )
/// ```
public struct Recording: Identifiable, Codable {
    /// O identificador único da gravação.
    public let id: UUID

    /// O título da reunião gravada.
    public let title: String

    /// A data e hora em que a gravação foi iniciada.
    public let date: Date

    /// A duração da gravação em segundos.
    public let duration: TimeInterval

    /// O texto transcrito da reunião.
    public let transcription: String?

    /// Inicializa uma nova gravação.
    ///
    /// - Parameters:
    ///   - id: O identificador único. Se nil, um novo UUID será gerado.
    ///   - title: O título da reunião.
    ///   - date: A data da gravação.
    ///   - duration: A duração em segundos.
    ///   - transcription: Opcionalmente, o texto transcrito.
    public init(
        id: UUID? = nil,
        title: String,
        date: Date,
        duration: TimeInterval,
        transcription: String? = nil
    ) {
        self.id = id ?? UUID()
        self.title = title
        self.date = date
        self.duration = duration
        self.transcription = transcription
    }

    /// Inicia a reprodução da gravação.
    ///
    /// - Throws: `RecordingError.notFound` se o arquivo não existir.
    /// - Returns: O player de áudio configurado.
    public func play() throws -> AudioPlayer {
        guard FileManager.default.fileExists(atPath: path) else {
            throw RecordingError.notFound
        }
        return AudioPlayer(url: path)
    }
}

/// Erros que podem ocorrer durante operações de gravação.
public enum RecordingError: Error, LocalizedError {
    case notFound
    case corruptedFile
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "O arquivo de gravação não foi encontrado."
        case .corruptedFile:
            return "O arquivo de gravação está corrompido."
        case .permissionDenied:
            return "Permissão negada para acessar o arquivo."
        }
    }
}
```

## Organization

### MARK Comments

```swift
// MARK: - Properties

// MARK: - Initialization

// MARK: - Public Methods

// MARK: - Private Methods
```

### Protocol Extensions

```swift
// MARK: - Codable

extension Recording: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, date, duration, transcription
    }
}
```

## Referências

- [Meeting.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Models/Meeting.swift)
- [Apple DocC Guide](https://developer.apple.com/documentation/docc)

---

## Context7 MCP Integration

Use Context7 MCP to get up-to-date documentation for external libraries and frameworks.

### When to Use Context7

- Working with unfamiliar libraries or frameworks
- Need code examples for specific APIs
- Verifying best practices for implementation
- Facing configuration or usage questions about dependencies

### How to Query

1. **Resolve library ID**: Use `mcp--context7--resolve-library-id`
2. **Query docs**: Use `mcp--context7--query-docs` with specific questions

```bash
# Example: Get Supabase documentation
mcp--context7--resolve-library-id(
  libraryName: "supabase",
  query: "Swift iOS authentication"
)

mcp--context7--query-docs(
  libraryId: "/supabase/supabase-js",
  query: "How to implement JWT authentication"
)
```

### Best Practices

- Be specific in queries (use cases, not generic topics)
- Verify doc dates - Context7 provides updated docs
- Combine with existing project code
- Validate examples in development environment

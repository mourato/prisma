# Documentação com DocC

> **Skill Condicional** - Ativada quando trabalhando com documentação de APIs

## Visão Geral

Guia para documentação consistente usando DocC (Documentation Compiler).

## Quando Usar

Ative esta skill quando detectar:
- `///` comentários de documentação
- `documentation:` parâmetros
- `Symbol Graph` files

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

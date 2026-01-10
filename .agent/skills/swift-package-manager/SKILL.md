# Swift Package Manager

> **Skill Condicional** - Ativada quando trabalhando com dependências SPM

## Visão Geral

Guia para gerenciamento de dependências com Swift Package Manager.

## Quando Usar

Ative esta skill quando detectar:
- `Package.swift`
- `.package(url:from:)` ou `.package(url:revision:)`
- `swift package resolve`
- `Package.resolved`

## Conceitos-Chave

### Dependency Management

```swift
// Package.swift
let package = Package(
    name: "MeetingAssistantCore",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MeetingAssistantCore",
            targets: ["MeetingAssistantCore"]
        )
    ],
    dependencies: [
        // Versão fixa para estabilidade
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        
        // Branch para desenvolvimento interno
        .package(url: "https://github.com/team/internal-utils.git", branch: "main"),
        
        // Revision específica para reprodução
        .package(url: "https://github.com/alice/ocr.git", revision: "abc123def")
    ],
    targets: [
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
```

### Reproducible Builds

```bash
# Commit Package.resolved para builds reproduzíveis
git add Package.resolved
git commit -m "deps: lock swift-log to 1.4.2"
```

## Commands Úteis

```bash
# Verificar dependências
swift package show-dependencies

# Atualizar para latest
swift package update

# Gerar projeto Xcode
swift package generate-xcodeproj
```

## Referências

- [Package.swift](Packages/MeetingAssistantCore/Package.swift)
- [Swift Package Manager Documentation](https://developer.apple.com/documentation/swift_packages)

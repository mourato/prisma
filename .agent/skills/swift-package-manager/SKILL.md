# Swift Package Manager

> **Skill Condicional** - Ativada quando trabalhando com dependências SPM

## Visão Geral

Guia para gerenciamento de dependências com Swift Package Manager e geração de projetos Xcode.

## Quando Usar

Ative esta skill quando detectar:
- `Package.swift`
- `.package(url:from:)` ou `.package(url:revision:)`
- `swift package resolve`
- `Package.resolved`
- `make spm-proj`
- Xcode project generation

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

---

## Xcode Project Generation

> **Motivação**: Para desenvolvedores sem experiência prévia em Swift, usar um arquivo `.xcodeproj` é a maneira mais visual e amigável de navegar pelo código, rodar a aplicação e usar ferramentas visuais como SwiftUI Previews.

### Por Que Gerar Projeto Xcode?

O projeto usa **Swift Package Manager (SPM)** como fonte da verdade. A estrutura de pastas e dependências são definidas no `Package.swift`.

Para desenvolvimento dia-a-dia, geramos um arquivo `.xcodeproj` descartável. Isso permite:
1. Navegação visual de arquivos
2. Auto-complete e refatoração visual
3. Uso de **SwiftUI Previews** (Hot Reload visual)
4. Debugging visual com breakpoints

### Como Gerar o Projeto

Sempre que adicionar arquivos ou mudar dependências:

```bash
make spm-proj
```

Isso criará (ou atualizará) o arquivo `Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj`.

### Como Abrir e Usar

1. Após gerar, abra o projeto:
   ```bash
   open Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj
   ```

2. **Para Rodar Previews (Hot Reload)**:
   - Abra qualquer arquivo de View (ex: `MeetingView.swift`)
   - No lado direito, você verá o "Canvas"
   - Se estiver pausado, clique no ícone de "Refresh" ou pressione `Cmd + Option + P`
   - Qualquer mudança no código reflete quase instantaneamente no Preview

### Solução de Problemas

**O projeto não compila após gerar:**
- Tente limpar o build: `Product > Clean Build Folder` (Cmd + Shift + K)
- Se persistir, delete o projeto gerado e gere novamente:
  ```bash
  rm -rf Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj
  make spm-proj
  ```

**Previews não funcionam:**
- Certifique-se de que está rodando no simulador ou Mac (Designed for iPad)
- Verifique se o scheme correto está selecionado
- Tente fechar e reabrir o Canvas

---

## Commands Úteis

```bash
# Verificar dependências
swift package show-dependencies

# Atualizar para latest
swift package update

# Gerar projeto Xcode
swift package generate-xcodeproj

# Limpar cache de builds
swift package clean

# Resolver dependências
swift package resolve
```

## Referências

- [Package.swift](Packages/MeetingAssistantCore/Package.swift)
- [Swift Package Manager Documentation](https://developer.apple.com/documentation/swift_packages)


# Workflow: Xcode Project Generation

> **Motivação**: Como você não tem experiência prévia com Swift, usar um arquivo `.xcodeproj` tradicional é a maneira mais visual e amigável de navegar pelo código, rodar a aplicação e usar ferramentas visuais como SwiftUI Previews.

## Visão Geral

O projeto usa **Swift Package Manager (SPM)** como fonte da verdade. Isso significa que a estrutura de pastas e dependências são definidas no `Package.swift`.

No entanto, para desenvolvimento dia-a-dia, geramos um arquivo `.xcodeproj` descartável. Isso permite:
1. Navegação visual de arquivos
2. Auto-complete e refatoração visual
3. Uso de **SwiftUI Previews** (Hot Reload visual)
4. Debugging visual com breakpoints

## Como Gerar o Projeto

Sempre que adicionar arquivos ou mudar dependências, execute no terminal:

```bash
make spm-proj
```

Isso criará (ou atualizará) o arquivo `Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj`.

## Como Abrir e Usar

1. Após gerar, abra o projeto:
   ```bash
   open Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj
   ```

2. **Para Rodar Previews (Hot Reload)**:
   - Abra qualquer arquivo de View (ex: `MeetingView.swift`)
   - No lado direito, você verá o "Canvas"
   - Se estiver pausado, clique no ícone de "Refresh" ou pressione `Cmd + Option + P`
   - Qualquer mudança no código reflete quase instantaneamente no Preview

## Solução de Problemas

**O projeto não compila após gerar:**
- Tente limpar o build: `Product > Clean Build Folder` (Cmd + Shift + K)
- Se persistir, delete o projeto gerado e gere novamente:
  ```bash
  rm -rf Packages/MeetingAssistantCore/MeetingAssistantCore.xcodeproj
  make spm-proj
  ```

---
trigger: model_decision
description: When working with UI views, windows, or user-facing features.
---

# Window Management
- Prefira `WindowGroup` ou `Settings` scenes padrão do SwiftUI sobre `NSWindow` customizado
- Use `NavigationSplitView` para apps com sidebars; configure `columnVisibility` corretamente
- Garanta que janelas sejam redimensionáveis e respeitem os botões de traffic light (close, minimize, maximize)
# Aesthetics
- Siga as Apple Human Interface Guidelines (HIG); use controles nativos quando possível
- Sempre suporte Dark Mode com cores semânticas (`Color(.windowBackgroundColor)`, `Color.primary`)
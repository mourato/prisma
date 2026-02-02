---
trigger: always_on
---

- Estruture aplicações com MVVM ou Clean Architecture separando lógica de apresentação, dados e rede
- Use Dependency Injection para injetar dependências explicitamente em construtores e inicializadores. Evite o uso de singletons `.shared` diretamente em ViewModels para facilitar testes.
- Prefira Protocol-Oriented Programming — crie protocolos para abstrações em vez de herança de classes
- Mantenha View Models enxutos, delegando lógica pesada a serviços e repositórios
- Adote Combine ou Async/Await para gerenciar fluxos assíncronos em vez de closures aninhados

## Project Layers
- **Infrastructure Layer**: Storage Service (protocol-based abstraction for persistence), External Integrations (APIs, system resources)
- **Domain/Core Layer**: MeetingAssistantCore framework encapsulates business logic for recording, transcription, and meeting management
- **Presentation Layer**: ViewModels depend on protocols (not implementations), SwiftUI/AppKit Views react to ViewModel state

---
trigger: always_on
---

# Documentação e Integração Context7 MCP

## Uso do Context7 MCP

O Context7 MCP fornece acesso a documentações atualizadas de libraries e frameworks. Use-o para obter informações precisas e atualizadas.

### Quando Usar Context7

- Ao trabalhar com libraries ou frameworks desconhecidos
- Quando precisar de exemplos de código para APIs específicas
- Para verificar melhores práticas de implementação
- Ao enfrentar dúvidas sobre configuração ou uso de dependências

### Como Consultar

1. **Identificar a library**: Determine o nome exato da library/framework
2. **Resolver library ID**: Use `mcp--context7--resolve-library-id` para obter o ID
3. **Consultar documentação**: Use `mcp--context7--query-docs` com perguntas específicas

### Boas Práticas

- **Seja específico**: Pergunte sobre casos de uso específicos, não temas genéricos
- **Verifique a data**: Context7 fornece docs atualizadas; verifique se são recentes
- **Combine fontes**: Use Context7 junto com código existente do projeto
- **Valide exemplos**: Teste código copiado de docs em ambiente de desenvolvimento

## Comprehensive Guidance

For complete DocC syntax, patterns, and examples, see:
- **[documentation skill](.agent/skills/documentation/SKILL.md)** - Complete guide for Swift documentation with DocC and Context7 integration

# Plano de Ação - Fase 1: Documentação e Configuração

## Objetivo
Corrigir problemas identificados na análise de documentação e configuração.

## Contexto
Problemas identificados:
- Arquivo LICENSE inexistente
- Inconsistência de idioma entre AGENTS.md (inglês) e README (português)
- Regras SwiftLint line_length comentadas
- Path traversal issue documentado em KNOWN_LIMITATIONS

## Ações Prioritárias

### 1.1 Adicionar Arquivo LICENSE [Alta Prioridade]
**Arquivo**: `LICENSE` (raiz do projeto)

**Contexto**: README.md linha 107 menciona licença MIT, mas arquivo não existe.

**Ação**:
Criar arquivo `LICENSE` com conteúdo:
```
MIT License

Copyright (c) 2024 [Seu Nome/Organização]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Prompt para LLM**:
```
Crie um arquivo LICENSE na raiz do projeto com licença MIT. Use o ano atual e substitua [Seu Nome/Organização] pelo nome apropriado.
```

**Critérios de Aceitação**:
- [ ] Arquivo LICENSE existe na raiz
- [ ] Formato MIT válido
- [ ] Ano correto (2025 ou superior)
- [ ] Nome do autor/organização correto

---

### 1.2 Padronizar Idioma do AGENTS.md [Média Prioridade]
**Arquivo**: `AGENTS.md`

**Contexto**: AGENTS.md está em inglês, mas a maior parte da documentação do projeto (README.md, regras do .agent) está em português. Isso causa inconsistência para agentes internacionais.

**Ações Possíveis**:
1. **Opção A**: Traduzir AGENTS.md para português
2. **Opção B**: Manter em inglês e traduzir README.md para inglês

**Recomendação**: Opção B (manter inglês) para consistência com padrões internacionais de código aberto.

**Ação**:
1. Traduzir seções do README.md para inglês
2. Manter AGENTS.md em inglês

**Prompt para LLM**:
```
Traduza o arquivo README.md para inglês, mantendo a estrutura e formatação original. Mantenha os comandos de terminal em português apenas se forem específicos de localização. Preserve os títulos em inglês.
```

**Critérios de Aceitação**:
- [ ] README.md possui versão em inglês
- [ ] Estrutura preservada
- [ ] Comandos específicos de localização mantidos
- [ ] AGENTS.md permanece em inglês (consistente)

---

### 1.3 Habilitar line_length no SwiftLint [Média Prioridade]
**Arquivo**: `.swiftlint.yml`

**Contexto**: Linhas 55-59 do project.yml têm regras de line_length comentadas. Isso permite linhas longas que violam padrões de código.

**Ação**:
Habilitar regra line_length no SwiftLint com limites razoáveis.

**Prompt para LLM**:
```
Edite o arquivo .swiftlint.yml para habilitar a regra line_length com os seguintes valores:
- warning: 120
- error: 160

A regra deve ser adicionada à seção opt_in_rules ou rules. Não desabilite outras regras existentes.
```

**Critérios de Aceitação**:
- [ ] Regra line_length habilitada
- [ ] warning: 120 caracteres
- [ ] error: 160 caracteres
- [ ] Arquivo compila sem erros

---

### 1.4 Documentar Correção de Path Traversal [Baixa Prioridade]
**Arquivo**: `docs/KNOWN_LIMITATIONS.md`

**Contexto**: Linha 31 documenta risco de segurança em recordingsDirectory que ainda não foi corrigido.

**Ações**:
1. Implementar sanitização do path (verificar com equipe de segurança)
2. Atualizar KNOWN_LIMITATIONS.md quando corrigido

**Prompt para LLM**:
```
Analise o arquivo docs/KNOWN_LIMITATIONS.md e atualize a entrada de "Path Traversal Issue" adicionando:
- Status: IN_PROGRESS
- Data de início: data atual
- Plano de correção: descrição breve da solução planejada
- Responsável: [adicionar nome se aplicável]

Mantenha o formato existente do arquivo.
```

**Critérios de Aceitação**:
- [ ] Entrada atualizada com status IN_PROGRESS
- [ ] Data de início registrada
- [ ] Plano de correção descrito

---

## Resumo de Ações

| Prioridade | Ação | Esforço Estimado | Arquivos |
|------------|------|------------------|----------|
| Alta | Adicionar LICENSE | 5 min | LICENSE |
| Média | Padronizar idioma AGENTS.md | 30 min | README.md |
| Média | Habilitar line_length | 5 min | .swiftlint.yml |
| Baixa | Atualizar path traversal | 15 min | KNOWN_LIMITATIONS.md |

## Checklist de Conclusão

- [ ] LICENSE criado com formato MIT válido
- [ ] Documentação com idioma padronizado
- [ ] SwiftLint configurado com line_length
- [ ] KNOWN_LIMITATIONS atualizado com status

## Comandos Úteis

```bash
# Verificar se LICENSE existe
ls -la LICENSE

# Verificar configuração do SwiftLint
cat .swiftlint.yml | grep -A 2 line_length

# Rodar lint para verificar
./scripts/lint.sh
```

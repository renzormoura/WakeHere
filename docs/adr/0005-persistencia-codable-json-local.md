# ADR-0005 — Persistência: Codable + JSON local atrás de repositórios

**Status:** aceito · **Data:** 2026-10-02

## Contexto

Escopo 100% local (sem contas/servidor), com prazo de projeto escolar e
necessidade de testes automatizados sem dispositivo.

## Decisão

- Portas `TripRepository`/`SettingsRepository` no domínio.
- Implementação `JsonTripRepository`/`JsonSettingsRepository` no pacote
  `WakeHereData`: arquivos `trips.json`/`settings.json` em
  `Documentos/WakeHere/`, escrita atômica, acesso serializado por fila.
- Regras polimórficas persistidas via `WakeUpRuleCodec` (discriminador + JSON interno).
- Arquivo de settings ausente/corrompido ⇒ padrões; trips corrompidos ⇒ erro
  tipado (`PersistenceError.corruptedData`) e `save` se recupera.

## Consequências

- ✅ Round-trip testável em qualquer SO; sem dependências de framework Apple.
- ✅ Dados legíveis/inspecionáveis; fácia migração posterior (Codable ↔ SwiftData).
- ❌ Sem índices/consultas — irrelevante para poucas viagens.
- ❌ Sem sincronização entre dispositivos (fora do MVP).

## Alternativas rejeitadas

- **SwiftData/CoreData:** acoplaria o domínio a framework Apple e quebraria
  os testes no Windows; seria uma troca de `WakeHereData` no futuro sem
  tocar no domínio (a porta já existe).
- **UserDefaults:** não serve para estruturas aninhadas com histórico.

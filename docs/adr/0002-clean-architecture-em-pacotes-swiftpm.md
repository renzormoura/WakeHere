# ADR-0002 — Clean Architecture em dois pacotes SwiftPM + alvo iOS

**Status:** aceito · **Data:** 2026-10-02

## Contexto

O núcleo do app (regras, geometria, ETA, estados) não precisa de UI nem de
APIs de sistema. Queremos testar esse núcleo **sem Mac e sem simulador**.

## Decisão

Separar em:

- `Packages/WakeHereDomain` — puro (apenas `Foundation`), com todas as
  portas (protocolos) das fronteiras externas.
- `Packages/WakeHereData` — persistência JSON atrás dos repositórios.
- `App/` — alvo iOS: SwiftUI, adaptadores (MapKit/CoreLocation/UserNotifications)
  e `CompositionRoot`.

Depências apontam sempre para dentro (DIP); injeção por construtor; nenhum
singleton.

## Consequências

- ✅ `swift test` roda em **Windows/macOS/Linux** — o domínio é verificado a
  cada push sem nenhum Apple hardware.
- ✅ O CI compila o alvo iOS em runner macOS, cobrindo a parte não testável localmente.
- ✅ Trocar persistência (SwiftData) ou provedor de rotas não toca no domínio.
- ❌ Alguma verbosidade extra de `Package.swift`/`project.yml` (XcodeGen).

## Alternativas rejeitadas

- **Tudo num target Xcode só:** impossível testar sem Mac.
- **SwiftData nos modelos de domínio:** acoplaria `@Model` ao núcleo e quebraria
  a portabilidade dos testes.

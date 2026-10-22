# WakeHere 🚌⏰

Aplicativo de iPhone que **acorda você antes do ponto de descida** em viagens de ônibus, carro ou qualquer trajeto: você marca no mapa onde quer acordar (ou busca um destino final), configura **quanto tempo antes** (ex.: 10 min) ou **quanta distância antes** (ex.: 1 km) do ponto, e o app dispara o alarme na hora certa — mesmo com o iPhone bloqueado e o app em segundo plano.

Projeto de engenharia de software com **alto nível de OOP**: Clean Architecture em camadas, injeção de dependência por construtor e padrões GoF nomeados (Strategy, State, Observer, Adapter, Repository, Factory, Facade, Proxy/DIP).

## Arquitetura em uma olhada

```
┌────────────────────────────────────────────────────────────┐
│ App (iOS) — SwiftUI + MVVM                                 │
│  Presentation/  views + view models                        │
│  Services/      TripSessionController (Facade)             │
│  Adapters/      MapKit, CoreLocation, UserNotifications    │
│  CompositionRoot — único ponto de montagem (DIP)           │
├────────────────────────────────────────────────────────────┤
│ WakeHereData — repositórios JSON (Repository)            │
├────────────────────────────────────────────────────────────┤
│ WakeHereDomain — PURO (Foundation only)                  │
│  entidades, regras (Strategy), máquina de estados,         │
│  geometria de rota, estimador de ETA, planificador de      │
│  alarme, portas (protocolos) para o mundo externo          │
└────────────────────────────────────────────────────────────┘
```

- `Packages/WakeHereDomain` — domínio puro + testes (roda em **qualquer** SO com Swift).
- `Packages/WakeHereData` — persistência JSON atrás de repositórios + testes.
- `App/` — alvo iOS (UI, adaptadores de sistema, CompositionRoot).
- `project.yml` — definição do projeto via **XcodeGen** (o `.xcodeproj` é gerado, não versionado).

## Como rodar

### Testes do domínio (Windows, macOS ou Linux)
```bash
swift test --package-path Packages/WakeHereDomain
swift test --package-path Packages/WakeHereData
```

### App iOS (macOS com Xcode 15+)
```bash
brew install xcodegen
xcodegen generate
open WakeHere.xcodeproj
```

## CI / Entrega

| Workflow | Quando | O que faz |
|---|---|---|
| `domain-tests-windows.yml` | a cada push | instala Swift no runner Windows e roda `swift test` nos pacotes |
| `ios-ci.yml` | a cada push | roda os testes + gera o projeto (XcodeGen) + compila o app no simulador |
| `build-ipa.yml` | manual (`workflow_dispatch`) | gera o **`WakeHere.ipa` sem assinatura** como artifact |

### Instalação no iPhone (sem Mac!)
1. Actions → **Build IPA (Sideloadly)** → *Run workflow*.
2. Baixe o artifact `WakeHere.ipa`.
3. Siga [`docs/05-instalacao-sideloadly.md`](docs/05-instalacao-sideloadly.md) (iTunes + Sideloadly).

## Documentação

- [`docs/01-visao.md`](docs/01-visao.md) — problema, user stories, escopo
- [`docs/02-arquitetura.md`](docs/02-arquitetura.md) — camadas, padrões, diagramas (classes, estados, sequência)
- [`docs/03-algoritmo.md`](docs/03-algoritmo.md) — snap-to-route, ETA, regras, tripla trava do alarme
- [`docs/04-plano-de-testes.md`](docs/04-plano-de-testes.md) — estratégia e casos de teste
- [`docs/05-instalacao-sideloadly.md`](docs/05-instalacao-sideloadly.md) — entregar o .ipa no iPhone
- [`docs/adr/`](docs/adr/) — decisões de arquitetura (ADRs)

## Nome e identidade

- **App:** WakeHere
- **Bundle ID:** `com.wakehere.app`
- **Idioma:** PT-BR
- **Requisitos:** iOS 17+

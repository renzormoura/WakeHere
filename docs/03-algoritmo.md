# 03 — Algoritmo: como o AcordeAqui decide "hora de acordar"

## 3.1 Pipeline por atualização de GPS

```
location + speed + timestamp
        │
        ▼
[1] snap-to-route ──► distância restante pela rota (ou geodésica)
        │             desvio perpendicular
        ▼
[2] TravelEstimator ─► velocidade média suavizada (EMA) ─► ETA restante
        │
        ▼
[3] TripSnapshot (entrada das regras)
        │
        ├──► [4] Avaliação da regra (Strategy) ──► pending | triggered
        ├──► [5] Fase de atenção (warning)
        ├──► [6] Chegada (raio de 40 m) ──► sempre toca
        └──► [7] Desvio da rota? ──► pedido de reroute (throttle 120 s)
```

## 3.2 [1] Snap-to-route (`RouteGeometry.snap`)

1. Para cada segmento da polyline, projeta o ponto do usuário no segmento
   usando uma **projeção local equiretangular** (metros por grau calculados na
   latitude do usuário — erro desprezível em distâncias urbanas):
   ```
   x = (lon − lon₀) · 111.319,49 · cos(lat₀)
   y = (lat − lat₀) · 111.194,93
   t = clamp( −a·d / |d|² , 0…1 )        // parâmetro do ponto projetado
   ```
2. `deviation = distância(point, projetado)` (haversine).
3. `remaining = (1 − t) · comprimento(segmento) + comprimento(sobrando da polyline até o fim)`.
4. Se `deviation > tolerância (150 m)` → **fora da rota**: a distância restante
   passa a ser **geodésica** (linha reta até o destino) e um reroute é pedido.

Consequência prática (RN6): mesmo que o ônibus não siga o traçado de carro,
o alarme de distância continua funcionando pelo modo raio.

## 3.3 [2] ETA dinâmico (`TravelEstimator`)

- Velocidade média inicial = `rota.totalDistance / rota.expectedDuration`
  (ou 11 m/s sem rota).
- Cada amostra do GPS atualiza uma **média móvel exponencial**:
  ```
  v̄ ← v̄·(1−α) + v·α        α = 0,25
  ```
- ETA = `distânciaRestante / max(v̄, 0,5 m/s)` — o piso evita ETA infinito com
  o veículo parado (parada no semáforo não dispara alarme: ETA só **aumenta**).
- O ETA é recalculado a cada update; o agendamento da notificação só é
  reescrito quando o horário muda em **>15 s** (evita I/O a cada segundo).

## 3.4 [4] Regras de despertar (Strategy)

### Regra de tempo — `TimeBeforeArrivalRule`
```
dispara quando:  ETA ≤ limiar + margemDeSegurança
atenção quando:  ETA ≤ limiar + margem + 120 s
segundos até o gatilho = max(0, ETA − limiar − margem)
```

### Regra de distância — `DistanceBeforeArrivalRule`
```
folga de reação = velocidade × 3 s          (ex.: 60 km/h → +50 m)
dispara quando:  distânciaRestante ≤ limiar + folgaDeReação
atenção quando:  distânciaRestante ≤ limiar + folga + 500 m
segundos até o gatilho = (distânciaRestante − limiar − folga) / velocidadeEfetiva
velocidadeEfetiva = distânciaRestante / ETA
```

A folga dinâmica faz o alarme tocar **mais cedo em alta velocidade** —
a distância que você percorreria durante o tempo de reação.

## 3.5 [6] Chegada e alarme garantido

Se `distânciaRestante ≤ 40 m` (raio de chegada) o alarme dispara **mesmo que a
regra esteja pendente** (RN3): quem dormiu até o ponto precisa acordar.
O mesmo vale para a **geofence** do destino (`forceArrival`), que confirma a
chegada mesmo com o último snapshot velho.

## 3.6 Reroute (RN5)

- Podem ser feitos **no máximo 1 pedido a cada 120 s** (throttle).
- `TripSessionController` re-planeja via `RoutePlanning` e devolve a nova rota
  com `monitor.updateRoute(_:)`, que zera o throttle.
- Se o app não tiver rota inicial (GPS indisponível na largada), a primeira
  atualização dispara o planejamento.

## 3.7 Tripla trava do alarme (o ponto crítico do iOS)

| Trilha | Mecanismo | Vale quando |
|---|---|---|
| **1. Notificação *time-sensitive*** | `AlarmTimingPlanner` calcula `fireDate = agora + (segundosAtéOGatilho − 10 s)` e agenda `UNTimeIntervalNotificationTrigger` com `interruptionLevel = .timeSensitive` | app em segundo plano ou iPhone **bloqueado**; recalculada continuamente, cancelada no gatilho real |
| **2. Geofence do destino** | `CLLocationManager.startMonitoring` num raio de 100 m do destino (`didEnterRegion` → `monitor.forceArrival()`) | app **morto pelo iOS** — o sistema o relança para entregar a região |
| **3. Localização contínua** | `UIBackgroundModes: location` + `allowsBackgroundLocationUpdates` + `distanceFilter` de 10 m | app em segundo plano, lógica de disparo rodando a cada update |

**Snooze:** além do estado `snoozed` (re-arma o monitoramento), é agendada uma
notificação **exata no prazo do snooze** — se o app morrer durante o snooze,
a notificação de mesmo modo toca.

**Nível time-sensitive:** requer o entitlement
`com.apple.developer.usernotifications.time-sensitive` (versionado em
`App/AcordeAqui.entitlements`) e a autorização
`requestAuthorization(options: [.alert, .sound, .timeSensitive])`.

## 3.8 Bateria e permissões

- `WhenInUse` pedido na tela de planejamento (mostrar `UserAnnotation`).
- `Always` pedido ao iniciar a viagem (pré-prompt do iOS após WhenInUse) —
  justificativa em `Info.plist`.
- `distanceFilter = 10 m`, `activityType = .automobileNavigation`,
  `pausesLocationUpdatesAutomatically = false`.
- Tudo para: **parar as atualizações em `arrived`/`cancelled`**
  (`TripSessionController.didChangePhase`).

## 3.9 Limitações conhecidas

1. ETA baseado em velocidade observada — trânsito futuro imprevisto é
   absorvido pela **margem de segurança** (configurável) e pelo reroute
   periódico a cada 3 min com dados de tráfego ao vivo (ADR-0006).
2. Traçado de ônibus ≠ rota de carro — coberto por reroute + modo raio.
3. Notificação *time-sensitive* em Foco "Não Perturbe rigoroso" pode ser
   silenciada pelo usuário — a geofence + tela de alarme (app aberto) cobrem o resto.
4. Relógio do iPhone alterado manualmente afeta os triggers de notificação
   (comportamento do sistema).
5. O reroute periódico requer conexão com a internet. Sem rede, o
   `TravelEstimator` (EMA) continua operando com o último ETA disponível.

## 3.10 Reroute periódico com tráfego ao vivo (ADR-0006)

A cada **3 minutos** durante a viagem ativa, o `TripSessionController` chama
`MKDirections.calculate()` a partir da **posição GPS atual** do usuário. O
resultado atualiza a rota no `TripMonitor` com um `expectedTravelTime` que
reflete as condições de tráfego atuais nos servidores Apple Maps.

```
A cada 3 minutos (periodicRerouteTask)
        │
        ▼
[A] posição GPS atual  ──►  MKDirections.calculate()
                                    │  (Apple Maps, tráfego ao vivo)
                                    ▼
                              Route.expectedTravelTime  ←── tráfego ao vivo
                                    │
                                    ▼
                        TripMonitor.updateRoute(_:)
                                    │
                                    ▼
                        TravelEstimator reinicializado
                        com velocidade = distância / ETA_novo
                                    │
                                    ▼
                        AlarmTimingPlanner recalcula fireDate
                                    │
                                    ▼
                        Notificação reagendada (se delta > 15 s)
```

### Por que o MKDirections entrega ETAs com tráfego

`MKDirections` usa a mesma infraestrutura do Apple Maps: os servidores Apple
calculam `expectedTravelTime` levando em conta condições de tráfego atuais e
históricas para cada segmento da rota. É o mesmo ETA exibido quando você pede
direções no Apple Maps — gratuito, sem API key, embutido no iOS.

### Degradação sem rede

Sem conexão à internet, o `MKDirections.calculate()` falha silenciosamente
(o erro é capturado com `try?`). O `TravelEstimator` continua operando com a
EMA de velocidade GPS — o comportamento de antes do ADR-0006.

### Dois tipos de reroute coexistindo

| Tipo | Quando | O que faz |
|---|---|---|
| **Periódico** | A cada 3 min, sempre | Atualiza ETA com tráfego ao vivo |
| **Por desvio** | `deviation > 150 m` (throttle 120 s) | Recalcula polyline se usuário saiu da rota |

Os dois são independentes. O reroute periódico pode sobrescrever uma rota
recém-calculada por desvio — isso é correto, pois a posição atual já é o
ponto de partida em ambos os casos.

### Modos de transporte e ETA

| Situação | Estratégia | Observação |
|---|---|---|
| Ônibus / van / táxi | Rota + reroute periódico | Tráfego ao vivo a cada 3 min |
| Metrô / trem | Rota + reroute periódico | Rota de carro como referência; ETA por tempo |
| Avião | Sem rota (modo raio) | TravelEstimator puro; distância geodésica |

Para metrô e avião, o alarme de **distância** é mais confiável que o de tempo.

### Tripla trava — inalterada

As três trilhas do alarme (notificação time-sensitive, geofence e localização
contínua) **não foram alteradas**. O reroute periódico apenas melhora a
precisão do `fireDate` calculado pelo `AlarmTimingPlanner`. As três trilhas
cobrem o caso de o ETA estar impreciso por qualquer motivo.

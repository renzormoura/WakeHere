# 04 — Plano de testes

## Estratégia

O domínio é **puro**, então a maior parte do comportamento é testada em
qualquer SO com `swift test` — sem simulador, sem GPS, sem Mac.

| Camada | Ferramento | Onde roda |
|---|---|---|
| `AcordeAquiDomain` | XCTest (`swift test`) | Windows local, CI Windows, CI macOS |
| `AcordeAquiData` | XCTest + diretório temporário por teste | idem |
| App (UI/build) | compilação no CI (simulador) + teste manual no iPhone via IPA | CI macOS + dispositivo real |

**Técnicas usadas:** casos-limite (boundary values), testes de transição de
estado, round-trip de codificação, simulação de trajetória (fórmulas de
distância) e testes derobustez a arquivo corrompido.

**Duplas (test doubles):** `MockClock` (relógio do `AlarmTimingPlanner`),
`SpyMonitorDelegate` (observador que grava eventos), `TestFactory`
(objetos de teste determinísticos), diretórios temporários únicos por teste.

## Suítes e casos

### `CoordinateTests`
- distância até si mesmo = 0; simetria;
- 0,001° de latitude ≈ 111,2 m; SP↔RJ ≈ 340–380 km; round-trip Codable.

### `RouteGeometryTests` (o coração do cálculo)
- comprimento total (reta ~1 km) e polylines de 1/0 pontos;
- ponto sobre a linha → desvio 0 e metade restante;
- ponto **depois do fim** → trava no destino, restante 0, desvio coerente;
- ponto **antes do início** → trava no início, restante = total;
- desvio perpendicular conhecido (≈111 m);
- polyline multi-segmento; remainingLength por índice.

### `TravelEstimatorTests`
- velocidade inicial derivada da rota; EMA converge às amostras;
- amostras negativas ignoradas; ETA = distância/velocidade;
- **piso de 0,5 m/s** (parado ⇒ ETA finito); fator de blend limitado.

### `WakeUpRuleTests` (Strategy)
- tempo: dispara **exatamente** no limiar, não dispara 1 s acima;
  margem amplia o gatilho; fase de atenção pelo `warningLead`;
  `secondsUntilTriggering` e clamp em 0; resumos PT-BR (min/h).
- distância: gatilho com folga `velocidade × 3 s`;
  buffer cresce com velocidade; aviso com lead; cálculo de segundos;
  `nil` sem velocidade; resumos (m/km).

### `WakeUpRuleCodecTests` / `TripCodableTests`
- round-trip preservando **tipo concreto** da regra;
- discriminador desconhecido lança erro;
- `Trip` round-trip completo (fase, datas, rota, snapshot);
- JSON adulterado falha ao decodificar.

### `TripStateMachineTests` (State)
- ciclo feliz completo; transições ilegais rejeitadas;
- auto-transição rejeitada; cancelamento de todas as fases ativas;
  estados finais absolutos; snooze ida/volta; flags de fase.

### `TripMonitorTests` (orquestração — a suíte mais importante)
- `start()` idempotente; `process` antes do início = `nil`;
- progressão `tracking → warning → ringing` com snapshots reais da rota;
  recuperação `warning → tracking`; contagem de snapshots e fases;
- fora da rota ⇒ 1 pedido de reroute, respeita throttle de 120 s,
  distância vira geodésica; `updateRoute` zera o throttle;
- `stopAlarm` antes da chegada volta a `tracking`;
- snooze não re-arma antes do prazo e re-arma **no** prazo;
- chegada (≤40 m) toca alarme mesmo com regra pendente e finaliza a viagem;
- `forceArrival` (geofence) toca e confirma chegada — e é ignorado se inativo;
- cancelamento encerra e `process` passa a responder `nil`;
- sem rota ⇒ modo raio, sem reroute;
- snapshot reporta restante/ETA/estimativa de chegada corretos.

### `AlarmTimingPlannerTests`
- `fireDate = snapshot + ETA − pré-alerta` usando o `MockClock`;
- `nil` quando o gatilho é iminente, quando a regra não consegue estimar
  e quando o snapshot está velho.

### `JsonTripRepositoryTests` / `JsonSettingsRepositoryTests`
- vazio ⇒ `[]`; round-trip completo incluindo regra polimórfica;
  update por id; delete (incluindo último ⇒ remove arquivo);
  id inexistente é no-op; **arquivo corrompido** ⇒ `PersistenceError`
  (e `save` se recupera); settings ausente/corrompido ⇒ padrões;
  volume clampado em 0…1.

## Como rodar

```bash
swift test --package-path Packages/AcordeAquiDomain
swift test --package-path Packages/AcordeAquiData
```

No CI (`.github/workflows/`):
- `domain-tests-windows.yml` — roda os dois comandos acima no Windows.
- `ios-ci.yml` — roda os testes **e** compila o app no simulador (impede
  regressão de código iOS que não temos como compilar localmente sem Mac).

## Cobertura manual (device test) — checklist pós-instalação

1. Permissões: WhenInUse ao abrir o mapa; Always ao iniciar a viagem.
2. Busca de destino e pino no mapa.
3. Regra de tempo e de distância alteram o resumo.
4. Iniciar viagem → contadores ao vivo → fase de atenção → alarme.
5. **Teste real no ônibus:** notificação toca com tela bloqueada.
6. Snooze 3 min → toca de novo.
7. Matar o app dos fundos → geofence/alarme ainda dispara na chegada.
8. Histórico registra a viagem; swipe apaga; ajustes persistem após reboot.

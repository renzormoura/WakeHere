# ADR-0004 — Estratégia de alarme: tripla trava

**Status:** aceito · **Data:** 2026-10-02

## Contexto

O requisito central do produto é **acordar o usuário na hora certa**, incluindo
com o iPhone bloqueado e o app em segundo plano — inclusive se o iOS matar o
processo. O iOS restringe fortemente execução em segundo plano.

## Decisão

Três camadas independentes, todas implementadas:

1. **Notificação local *time-sensitive*** agendada pelo `AlarmTimingPlanner`
   (recalculada a cada update de GPS, reescrita apenas se mudar >15 s),
   com o entitlement `com.apple.developer.usernotifications.time-sensitive`.
2. **Geofence do destino** (`CLCircularRegion`, raio 100 m) — o sistema
   relança o app em `didEnterRegion` → `monitor.forceArrival()`.
3. **Localização contínua** (`UIBackgroundModes: location`,
   `allowsBackgroundLocationUpdates`) — a lógica de regra roda a cada update.

Complementos: som em foreground via `AVAudioPlayer` (loop) com fallback para
tom do sistema + vibração; notificação imediata no gatilho; notificação exata
no prazo do snooze.

## Consequências

- ✅ Cada trava cobre a falha da outra (segundo plano / app morto / tela aberta).
- ✅ Nenhuma API privada — tudo permitido pela Apple.
- ❌ Requer permissão **Always** (fluxo com justificativa na UI).
- ❌ Bateria: mitigada com `distanceFilter` de 10 m e parada em estados finais.

## Alternativas rejeitadas

- **Critical alerts:** exigem aprovação especial da Apple.
- **App mantido em foreground com tela ligada:** inviável em viagens longas.
- **Timer local simples (sem GPS):** não saberia o ETA restante.

# ADR-0006 — ETA com tráfego ao vivo via reroute periódico (MKDirections)

**Data:** 2026-10-03  
**Status:** Aceito

## Contexto

O AcordeAqui calcula o ETA usando o `TravelEstimator`, uma média exponencial
(EMA) da velocidade GPS observada. Essa abordagem tem uma limitação crítica:
ela extrapola a velocidade atual do veículo e não enxerga o trânsito à frente.
Se o ônibus está a 60 km/h mas há congestionamento 2 km adiante, o ETA fica
errado — e o alarme pode não tocar a tempo.

O usuário do app está **dormindo** no transporte. Um erro de 3 minutos no ETA
pode ser suficiente para perder a parada.

## Opções avaliadas

| Opção | Tráfego ao vivo | Custo | Dependência externa |
|---|---|---|---|
| Mapbox Navigation SDK v3 | ✅ | Pago (free tier limitado) | SDK 30 MB |
| OSRM público | ❌ | Gratuito | Servidor não apto para produção |
| OpenRouteService | ❌ | Free tier com API key | Chave necessária |
| **MKDirections periódico** | **✅** | **Gratuito** | **Nenhuma** |

## Decisão

Implementar **reroute periódico com `MKDirections`**, chamando a API a partir
da posição GPS atual a cada **3 minutos** durante a viagem ativa.

O `MKDirections.calculate()` consulta os servidores Apple Maps e retorna
`expectedTravelTime` com dados de tráfego ao vivo — o mesmo dado exibido no
Apple Maps. É 100% gratuito, sem API key, sem SDK externo, sem custo por
usuário.

### Mecanismo

O `TripSessionController` mantém um `Task` em loop (`periodicRerouteTask`)
que, a cada 3 minutos:

1. Verifica se a fase está ativa (`phase.isActive`)
2. Obtém a posição GPS atual (`locationManager.lastKnownCoordinate`)
3. Chama `routeProvider.planRoute(from: posicaoAtual, to: destino)` via
   `MapKitRouteProvider` → `MKDirections.calculate()`
4. Passa a nova rota para `monitor.updateRoute(_:)`, que atualiza o
   `TravelEstimator` com a velocidade média derivada do `expectedTravelTime`
   com tráfego
5. Força `lastScheduledFireDate = nil`, garantindo que o
   `AlarmTimingPlanner` reagende a notificação imediatamente com o novo ETA

O reroute por desvio (> 150 m da rota) continua funcionando de forma
independente via `tripMonitorDidRequestReroute`, sem alterar o timer periódico.

### Por que 3 minutos?

- Suficientemente frequente para capturar mudanças de tráfego relevantes
- Respeita os rate limits informais do `MKDirections` (sem limite documentado,
  mas chamadas excessivas podem ser throttleadas pelo iOS)
- Economiza bateria em relação a intervalos menores
- Erros de 3 min no ETA são irrelevantes para viagens de ônibus/van/metrô
  onde a margem de segurança configurável já absorve variações menores

## Consequências

**Positivas:**
- ETA com tráfego ao vivo sem nenhum custo ou dependência externa
- Zero mudança na arquitetura de domínio (`AcordeAquiDomain` inalterado)
- Zero configuração por parte do usuário ou do desenvolvedor
- Funciona em todos os iPhones com iOS 17+, offline degradada para EMA

**Negativas / trade-offs:**
- ETA atualizado a cada 3 min (não contínuo como o Mapbox)
- Requer conexão para o reroute periódico; sem rede, mantém o ETA anterior
- Sem instruções turn-by-turn ou mapa de navegação (fora do escopo do app)

## Implementação

- `TripSessionController.startPeriodicReroute()`: inicia o loop
- `TripSessionController.stopPeriodicReroute()`: cancela o Task (arrived/cancelled/alarm)
- `FetchReason.periodic`: após retorno, zera `lastScheduledFireDate` para
  forçar re-agendamento imediato da notificação
- `TripTrackingView`: badge visual "ETA atualizado a cada 3 min com tráfego ao vivo"

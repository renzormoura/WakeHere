# 01 — Visão do produto

## Problema

Quem viaja de ônibus (ou de carro como passageiro) precisa descer em um ponto
específico e teme dormir demais. Alarmes por horário não funcionam bem porque
o tempo de viagem varia com o trânsito; alertar "por distância" não existe
nativamente no iOS.

## Solução

O usuário marca **onde quer acordar** (pino no mapa ou busca) e configura a
regra: **X minutos antes** de chegar** ou **Y km/m antes** do ponto. O app
acompanha a viagem em segundo plano e dispara o alarme na hora certa.

## Personas

- **Ana, 22 universitária:** pega 2 ônibus todo dia e já perdeu a parada
  dormindo. Quer acordar 10 min antes do terminal.
- **Carlos, 45 motorista:** dirige rotas longas de carro e quer ser avisado
  1 km antes da saída correta.

## Histórias de usuário (MVP)

| # | Como… | Quero… | Para… |
|---|---|---|---|
| US1 | usuário | buscar/selecionar um destino no mapa (busca ou pino) | indicar onde preciso descer |
| US2 | usuário | escolher a regra: **tempo antes** ou **distância antes**, com margem de segurança | ser acordado no momento certo |
| US3 | usuário | iniciar a viagem e ver contagem regressiva de tempo e distância | acompanhar "quanto falta" |
| US4 | usuário | ser acordado mesmo com o iPhone bloqueado e o app em segundo plano | não depender de deixar o app aberto |
| US5 | usuário | adiar (snooze) ou parar o alarme | me preparar para descer |
| US6 | usuário | ver o histórico de viagens e apagar registros | revisar/limpar dados |
| US7 | usuário | configurar unidades, som e vibração | usar como prefiro |

## Regras de negócio

- **RN1** — O alarme dispara quando `tempoRestante ≤ limiar + margem` (regra de tempo).
- **RN2** — O alarme dispara quando `distânciaRestante ≤ limiar + velocidade × tempoDeReação` (regra de distância).
- **RN3** — Ao **chegar ao destino** o alarme toca sempre (quem dormiu até aqui precisa acordar).
- **RN4** — O snooze adia o alarme e re-arma uma trava de segurança.
- **RN5** — Desvio da rota acima da tolerância dispara re-planejamento (reroute).
- **RN6** — Sem rota disponível, a regra de distância usa distância em linha reta (modo raio).

## Requisitos não funcionais

- **Confiabilidade do alarme:** tripla trava (notificação *time-sensitive* +
  geofence + localização em background) — ver `docs/03-algoritmo.md`.
- **Bateria:** `distanceFilter` adaptativo; monitoramento só durante viagem ativa.
- **Privacidade:** 100% local, sem servidor, sem rastreamento fora da viagem.
- **Desempenho:** cálculos por atualização de GPS são O(número de segmentos da rota)
  e rodam em sub-milissegundos para rotas típicas.
- **Testabilidade:** toda a lógica de negócio é pura e testável sem GPS/simulador.

## Fora do escopo (MVP)

- Contas, sync e qualquer backend.
- Android/web.
- Integração com APIs de transporte público (SPTrans, etc.).
- Compartilhamento de viagem, widget, Apple Watch.
- Som de alarme customizável pelo usuário (existe um tom padrão embutido).

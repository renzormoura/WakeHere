# ADR-0001 — Swift + SwiftUI nativo (iOS 17+)

**Status:** aceito · **Data:** 2026-10-02

## Contexto

Projeto de engenharia de software com exigência de **alto nível de OOP**,
app exclusivo de iPhone, com requisitos críticos de **localização em
background** e **alarme confiável** (notificações time-sensitive, geofence).

## Decisão

Usar **Swift puro com SwiftUI**, alvo iOS 17+, sem frameworks multiplataforma.

## Consequências

- ✅ Padrões OOP (protocolos, herança, Strategy/State) são idiomáticos em Swift.
- ✅ MapKit, CoreLocation e UserNotifications sem camadas intermediárias —
  o alarme em background funciona "de graça".
- ✅ SwiftUI + MVVM reduz boilerplate de UIKit.
- ❌ Compila **apenas em macOS/Xcode** (mitigado por CI no GitHub Actions e
  entrega do `.ipa` pronto — ver ADR-0003/ADR-0005).
- ❌ Sem possibilidade de Android sem reescrita.

## Alternativas rejeitadas

- **React Native/Expo:** dependências frágeis para background location/alarm;
  OOP pouco expressivo; pior desempenho em bateria.
- **Flutter:** mesmo problema dos plugins; Dart fora do escopo do curso.

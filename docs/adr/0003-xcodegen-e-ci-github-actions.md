# ADR-0003 — XcodeGen + CI no GitHub Actions (sem Mac local)

**Status:** aceito · **Data:** 2026-10-02

## Contexto

O Xcode só existe para macOS e o time não tem um Mac disponível; o `.xcodeproj`
é um arquivo binário-texto frágil em revisão de código.

## Decisão

1. Definir o projeto em **`project.yml` (XcodeGen)** versionado no repositório;
   o `.xcodeproj` é **gerado** (e ignorado pelo git).
2. CI em três workflows:
   - `domain-tests-windows.yml` — `swift test` dos pacotes puros no Windows;
   - `ios-ci.yml` — testes + `xcodegen generate` + `xcodebuild build` no
     simulador (runner `macos-14`) a cada push;
   - `build-ipa.yml` — `workflow_dispatch` gera o `.ipa` sem assinatura.

## Consequências

- ✅ Erros de compilação do alvo iOS aparecem **sem** um Mac local.
- ✅ Projeto sempre reprodutível a partir do texto (`project.yml`).
- ✅ Repositório público = minutos de macOS ilimitados no GitHub.
- ❌ Debug interativo de UI ainda exige um Mac eventualmente (lab/faculdade);
  a validação principal passa a ser o **iPhone real via IPA**.

## Alternativas rejeitadas

- **Versionar o `.xcodeproj`:** diffs ilegíveis e conflitos constantes.
- **Tuist:** mais poder, mais complexidade — desnecessário neste escopo.

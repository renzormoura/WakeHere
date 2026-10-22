# 05 — Instalando o AcordeAqui no iPhone (Sideloadly + iTunes)

Fluxo completo para usar o app **sem ter um Mac**: o CI gera o `.ipa` e você
instala no iPhone pelo Windows.

## Passo 1 — Gerar o `.ipa` (GitHub Actions)

1. Envie o repositório para o GitHub (repositório **público** = minutos de
   macOS gratuitos e ilimitados).
2. No GitHub: **Actions → Build IPA (Sideloadly) → Run workflow**.
3. Ao terminar (alguns minutos), baixe o artifact **`AcordeAqui.ipa`** na
   página da execução (aba *Summary*, seção *Artifacts*).

> O `.ipa` sai **sem assinatura** de propósito: o Sideloadly assina com a
> sua Apple ID. Os entitlements do app (localização em background e
> notificação *time-sensitive*) estão no binário e são preservados na
> re-assinatura.

## Passo 2 — Pré-requisitos no Windows

1. **iTunes** oficial da Apple (não o da Microsoft Store, se der problema):
   baixe em <https://www.apple.com/itunes/> e instale.
2. **Sideloadly**: baixe em <https://sideloadly.io/> e instale.
3. iPhone conectado por **USB** com o cabo, desbloqueado, e em
   *Ajustes → Geral → Dispositivo* confie no computador.

## Passo 3 — Sideloadar

1. Abra o **Sideloadly** (se pedir Apple ID, use o mesmo da conta do iPhone).
2. Arraste o `AcordeAqui.ipa` para a área do arquivo, selecione o iPhone na
   lista de dispositivos.
3. Clique em **Start**. Aguarde assinar e instalar.
4. No iPhone: **Ajustes → Geral → VPN e Gerenciamento de Dispositivo** →
   confie no desenvolvedor (perfil da sua Apple ID).
5. Abra o **AcordeAqui**.

## Passo 4 — Conceder permissões

1. Ao abrir o mapa: **"Permitir uso do local"** (Ao Usar).
2. Ao tocar **Iniciar viagem**: **"Sempre"** (essencial para o alarme em
   segundo plano).
3. Primeira viagem: permita **notificações** (o iOS pede junto com o nível
   *time-sensitive*).

## Avisos importantes (Apple ID gratuito)

| Tema | O que esperar |
|---|---|
| **Validade** | Apple ID **gratuito** assina apps por **7 dias**. Passou? O ícone some — é só repetir o Passo 3 com o mesmo `.ipa`. |
| **Conta paga (US$ 99/ano)** | assinatura vale **1 ano**. |
| **Limite de apps** | Apple ID gratuito: **3 apps** sideloaded por vez. |
| **Atualização** | Gere um novo `.ipa` no Actions e reinstale (mesmo fluxo). |

## Checklist de validação pós-instalação

Confirme que a re-assinatura não perdeu capacidades:

- [ ] **Notificações:** Ajustes → Notificações → AcordeAqui aparece e está ligado.
- [ ] **Localização:** Ajustes → Privacidade → Serviços de Localização →
      AcordeAqui = **Sempre**.
- [ ] **Teste de alarme:** crie uma viagem curta com regra de 1 min e
      deixe a tela bloqueada — a notificação deve tocar.
- [ ] **Som:** a tela de alarme toca o tom (`AlarmTone.wav`); se o iOS
      silenciar a notificação, a tela + vibração ainda aparecem com o app aberto.

### Se alguma capacidade faltar

- *Localização em segundo plano não funciona:* reabra o Sideloadly, marque
  em **Options/Advanced** a opção de manter os entitlements originais e
  reinstale.
- *Notificação não toca como "time-sensitive":* o entitlement
  `com.apple.developer.usernotifications.time-sensitive` (em
  `App/AcordeAqui.entitlements`) precisa estar no perfil — o Sideloadly
  normalmente o mantém; some capacidade? refaça o sideload e teste novamente.

## Desinstalar

Segure o ícone → **Remover app** (os dados locais em
`Documentos/AcordeAqui/` vão junto).

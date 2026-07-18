# Contribuire a Destroyer

Grazie per l'interesse! Destroyer è una utility macOS open source (MIT).

## Requisiti
- macOS 14+ (Apple Silicon o Intel)
- Xcode 15+ (per la GUI)
- [XcodeGen](https://github.com/yonyz/XcodeGen): `brew install xcodegen`

## Setup
```sh
git clone <repo>
cd Destroyer
xcodegen generate      # genera Destroyer.xcodeproj da project.yml
open Destroyer.xcodeproj
```
Il progetto Xcode è **generato**: non va versionato. Modifica `project.yml`, non il `.xcodeproj`.

## Struttura
- `Sources/DestroyerCore/` — logica pura, testabile e indipendente dalla UI.
- `App/Sources/` — interfaccia SwiftUI.
- `Sources/DestroyerVerify/` — harness di verifica eseguibile senza Xcode.
- `Tests/` — suite swift-testing (gira in Xcode).

## Prima di aprire una PR
1. `swift run destroyer-verify` deve essere **verde**.
2. La build Xcode deve passare (`xcodebuild -scheme Destroyer build`).
3. Aggiungi controlli in `destroyer-verify` (e/o `Tests/`) per la nuova logica di core.

## Principi di sicurezza (non negoziabili)
- Le rimozioni vanno **sempre nel Cestino** (reversibili), mai `rm` distruttivo.
- Ogni percorso passa dalla guardia `SafePaths` prima di essere toccato.
- Nessun percorso hardcoded specifico di un utente: usa le API `FileManager` home.

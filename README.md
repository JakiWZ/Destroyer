# Destroyer

Utility nativa macOS (Swift + SwiftUI) — **open source (MIT)**, pensata per funzionare
su **qualsiasi Mac** (macOS 14+, Apple Silicon e Intel). Nessun percorso legato a un utente
specifico: tutto usa le API di sistema.

Look "neon" a tema scuro, sicurezza prima di tutto: **ogni rimozione va nel Cestino**
(reversibile), mai cancellazioni distruttive, e ogni percorso passa dalla guardia `SafePaths`.

## Moduli

- **Dashboard** — stato del Mac con anello animato (disco, RAM, Cestino), dati reali read-only.
- **Applicazioni (disinstallatore stile AppCleaner)** — drag-and-drop o lista: trova i residui
  di un'app (cache, preferenze, supporto, container, **LaunchAgents/Daemons**, helper privilegiati,
  script, log…) anche nelle posizioni **di sistema**. Chiude l'app se in esecuzione, scarica i
  launch job (`launchctl`) e, per i file di sistema, **chiede la password admin**.
- **Pulizia** — scansione sicura di cache/log utente, spostati nel Cestino.
- **Protezione** — motore antimalware **on-demand a 3 modalità** (Rapida/Bilanciata/Profonda):
  usa le **firme XProtect di Apple** già presenti e auto-aggiornate su ogni Mac (match sui
  pattern di byte), più **euristica** (Gatekeeper/notarizzazione, quarantena, posizioni anomale,
  indicatori adware noti) e **analisi della persistenza** (LaunchAgents/Daemons). Le minacce si
  mettono in **quarantena nel Cestino** (reversibile). Ispirato a Malwarebytes/Moonlock/XProtect;
  trasparente e open source. Il motore YARA completo e il real-time (Endpoint Security) sono roadmap.
- **Monitor** — metriche di sistema in tempo reale.
- **Watcher del Cestino** — quando trascini un'app nel Cestino, propone di pulirne i residui.

## Sicurezza

- Rimozioni **solo verso il Cestino**, reversibili. Guardia `SafePaths` con denylist di sistema
  (`/System`, `/Library/Apple`, …) e allowlist delle aree legittime.
- File di sistema (root): rimozione con **autorizzazione admin** esplicita (password macOS).
- Al primo avvio, gate bloccante per il **Full Disk Access** finché non concesso.

## Build da sorgente

Serve **Xcode 15+** e [XcodeGen](https://github.com/yonyz/XcodeGen):

```sh
brew install xcodegen
xcodegen generate            # genera Destroyer.xcodeproj da project.yml
open Destroyer.xcodeproj      # ⌘R per eseguire
```

Il `.xcodeproj` è **generato** da `project.yml` e non è versionato (vedi `.gitignore`).

### Verifica del core senza Xcode
```sh
swift run destroyer-verify   # controlli di sicurezza, finder, protezione, ecc.
```

### DMG
```sh
scripts/make-dmg.sh          # build Release + DMG in ~/Downloads
```

## Distribuzione / notarizzazione

L'app è pronta per Developer ID (Hardened Runtime attivo). Per un DMG senza avvisi Gatekeeper
serve un Apple Developer ID + notarizzazione:

```sh
xcodebuild -project Destroyer.xcodeproj -scheme Destroyer -configuration Release archive \
  -archivePath build/Destroyer.xcarchive
xcrun notarytool submit build/Destroyer.zip --keychain-profile "NOTARY" --wait
xcrun stapler staple build/Destroyer.app
```

Senza notarizzazione (build di sviluppo, firma ad-hoc): al primo avvio usa **click destro → Apri**.

## Disclaimer

Il modulo Protezione è uno strumento **difensivo** di analisi della persistenza, trasparente e
open source. Non sostituisce una soluzione anti-malware completa. Usalo per ispezionare il tuo
sistema; verifica sempre le segnalazioni prima di rimuovere.

## Licenza

[MIT](LICENSE) — © 2026 Destroyer contributors. Contributi benvenuti: vedi [CONTRIBUTING.md](CONTRIBUTING.md).

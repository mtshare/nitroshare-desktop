# NitroShare per macOS

[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://opensource.org/licenses/MIT)

Invia file e cartelle ai Mac vicini, sulla stessa rete locale, con la semplicità di AirDrop e senza account né cloud.

Questo è un fork di [NitroShare](https://github.com/nitroshare/nitroshare-desktop) di Nathan Osman. Il core di trasferimento in Qt è stato portato a Qt 6, e su macOS la vecchia interfaccia Qt è sostituita da un'app nativa in SwiftUI. **Versione attuale: 0.5.0.**

## Cosa fa

- **Barra dei menu**: dispositivi vicini, trasferimenti in corso e comandi rapidi, nello stile del Centro di Controllo.
- **Finestra NitroShare**: dispositivi come in AirDrop del Finder, con l'elenco dei trasferimenti sotto. Per inviare trascini i file su un dispositivo oppure fai clic e li scegli.
- **Invio a più persone**: nella scelta del dispositivo puoi toccare più destinatari uno dopo l'altro. Ogni cerchio mostra l'avanzamento e poi l'esito.
- **Menu Condividi del Finder**: selezioni file o cartelle, scegli Condividi → NitroShare e poi il dispositivo.
- **Cartelle intere**, con le sottocartelle. I file `.DS_Store` non vengono inviati.
- **Notifiche** quando un trasferimento finisce o non riesce, con un messaggio comprensibile.
- **Nessuna sovrascrittura**: un file ricevuto con un nome già presente diventa "nome 2.ext", come nel Finder.
- **Compatibile con NitroShare 0.3.x**: puoi scambiare file con chi non ha ancora aggiornato, in entrambe le direzioni.
- Cifratura TLS facoltativa, API HTTP locale, interfaccia in italiano e in inglese.

## Installazione

Serve macOS 14 (Sonoma) o successivo, su Apple silicon o Intel.

1. Apri `nitroshare-<versione>-macos.dmg` e trascina NitroShare in Applicazioni.
2. Apri l'app. macOS dice che non può verificare lo sviluppatore: fai clic su "Fine".
3. Vai in Impostazioni di Sistema → Privacy e sicurezza, scorri in basso e fai clic su **"Apri comunque"** accanto a NitroShare.
4. Quando NitroShare chiede di trovare dispositivi sulla rete locale, fai clic su **"Consenti"**. Senza questo permesso l'app vede gli altri Mac ma non riesce a inviare.

Il passaggio 3 serve perché l'app ha una firma ad-hoc, non una firma Apple Developer. Il DMG contiene un file "Leggimi" con le stesse istruzioni.

Per aggiornare basta sostituire l'app in Applicazioni con quella del nuovo DMG.

## Uso

| Per… | Fai così |
| --- | --- |
| Inviare a un dispositivo | Trascina i file sul suo cerchio, nella finestra o nel menu della barra. |
| Scegliere i file da un elenco | Fai clic su un dispositivo, oppure usa **Invia file…** (⌘O) nella finestra. |
| Inviare a più persone | Nella scelta del dispositivo fai clic su ciascun destinatario, poi su **Fine**. |
| Inviare dal Finder | Seleziona, poi Condividi → NitroShare. |
| Vedere i trasferimenti | Menu della barra → **Apri la finestra di NitroShare**. Riaprire l'app da Finder o Spotlight fa lo stesso. |
| Trovare i file ricevuti | Menu della barra → **Apri file ricevuti** (di default nella cartella Download). |

Le impostazioni (nome del dispositivo, cartella di destinazione, porte, TLS, dispositivi da aggiungere a mano) sono in menu della barra → **Impostazioni…**.

## Problemi comuni

**"Il dispositivo non ha risposto"**
Il Mac di destinazione non ha accettato la connessione entro 10 secondi. Controlla che:
- sia sulla stessa rete;
- abbia NitroShare aperto;
- il suo firewall non blocchi la porta 40818.

Controlla anche, sul tuo Mac, il permesso in Impostazioni di Sistema → Privacy e sicurezza → Rete locale.

**Un dispositivo non compare**
La ricerca usa mDNS e broadcast UDP (porta 40816). Alcune reti, come quelle degli ospiti o con isolamento dei client, li bloccano. In quel caso aggiungi l'indirizzo IP in Impostazioni → Rete → Dispositivi aggiuntivi.

**Log**
Il core scrive in `~/Library/Logs/NitroShare/core.log`.

## Compilare

Servono Xcode, CMake e Qt 6.

### Build di sviluppo

```sh
brew install cmake qt
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(brew --prefix qt)"
cmake --build build -j8
open build/out/NitroShare.app
```

Questa build usa il Qt di Homebrew, quindi funziona solo su questo Mac.

### DMG da distribuire

```sh
scripts/release-macos.sh
```

Lo script:
- scarica il Qt ufficiale, universale e compatibile con macOS 14;
- compila per Apple silicon e Intel;
- controlla il bundle: architetture, versione minima di macOS, librerie esterne, RPATH e firma;
- scrive `build-release/nitroshare-<versione>-macos.dmg`.

Durante la build `macdeployqt` stampa alcune righe `ERROR` su `PlugIns/Frameworks/Qt*.framework`: sono innocue. Quello che conta è che i controlli dello script passino.

Altre opzioni:
- `-DMACOS_CODESIGN_IDENTITY="Developer ID Application: …"` firma con un'identità vera;
- `cmake --build build --target dmg` crea un DMG dalla build di sviluppo;
- `-DBUILD_MACOS_APP=OFF` compila la vecchia interfaccia Qt Widgets.

La versione si cambia in `CMakeLists.txt` (`PROJECT_VERSION_MAJOR`, `_MINOR` e `_PATCH`).

## Come è fatto

```
NitroShare.app
├── MacOS/NitroShare        app SwiftUI (macos/Sources/NitroShare)
├── MacOS/nitroshare-cli    core Qt senza interfaccia (cli/, libnitroshare/, plugins/)
└── PlugIns/
    ├── ShareExtension.appex  voce del menu Condividi (macos/ShareExtension)
    └── nitroshare/           plugin del core: lan, broadcast, mdns, filesystem, api, bridge…
```

- L'app avvia `nitroshare-cli --exit-with-parent` e ci parla tramite l'API HTTP locale. Porta e token sono in `~/.NitroShare`. Il plugin `bridge` espone le azioni usate dall'app: `devices`, `transferlist`, `senditems`, `transfercancel`, `settingset` e le altre.
- Se l'app si chiude in modo anomalo, il core si ferma da solo. All'avvio l'app termina eventuali core rimasti orfani.
- L'estensione Condividi passa i percorsi all'app con un URL `nitroshare://share?path=…`.
- Per aggiungere una traduzione si modifica `macos/Resources/<lingua>.lproj/Localizable.strings`.

Il protocollo di trasferimento e i dettagli di compatibilità con la 0.3 sono descritti in [CLAUDE.md](CLAUDE.md).

## Licenza e crediti

Licenza MIT: vedi [LICENSE.txt](LICENSE.txt). NitroShare è stato creato da Nathan Osman. Questo fork aggiunge il porting a Qt 6, l'app nativa per macOS e la compatibilità con la versione 0.3.

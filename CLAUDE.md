# NitroShare (fork mtshare): memoria di progetto

Questo è un fork di NitroShare: il core in C++/Qt 6 più un'app nativa per macOS in SwiftUI. Remote: `origin` = `github.com/mtshare/nitroshare-desktop`, branch `master`. Il README spiega installazione, uso e build. Questo file raccoglie ciò che non si ricava leggendo il codice.

Si risponde all'utente in italiano. Codice, commenti e messaggi di commit restano in inglese, come nel resto del repository.

## Build

```sh
cmake --build build -j8          # build di sviluppo (Qt di Homebrew), app in build/out/NitroShare.app
scripts/release-macos.sh         # DMG universale in build-release/nitroshare-<versione>-macos.dmg
```

- **Righe `ERROR` di `macdeployqt`**: quelle su `PlugIns/Frameworks/Qt*.framework` e sulla firma compaiono a ogni build e sono innocue. Conta solo che lo script arrivi a `==> Done` e che i controlli del bundle passino.
- **Versione**: si cambia in `CMakeLists.txt` (`PROJECT_VERSION_MINOR` e le altre). Il nome del DMG la segue. Convenzione: nuova funzione importante = minor+1 (per esempio l'invio a più persone ha portato alla 0.5.0).
- **Traduzioni**: stanno in `macos/Resources/it.lproj/Localizable.strings`. La chiave è il testo inglese scritto nel codice Swift. Vengono copiate a ogni build: prima la copia avveniva solo alla configurazione e le modifiche andavano perse. Ogni nuova stringa dell'interfaccia va aggiunta anche lì.
- **File Swift nuovi**: vengono presi da soli (`file(GLOB … CONFIGURE_DEPENDS)`).
- **RPATH**: `swift build` aggiunge all'eseguibile il percorso della toolchain di Xcode. `macos/CMakeLists.txt` lo rimuove dopo la copia. `/usr/lib/swift` invece è corretto e deve restare.
- **Controlli dello script**: niente `grep -q` nelle pipe. Con `set -o pipefail`, `grep -q` chiude la pipe in anticipo, il comando a monte riceve SIGPIPE e il controllo passa o fallisce a caso. Si usa `grep … >/dev/null`.

## Architettura (macOS)

- `macos/Sources/NitroShare/`
  - `AppModel`: stato osservabile. Interroga l'API del core ogni secondo.
  - `MenuPanel`: il pannello della barra dei menu.
  - `TransfersPanel`: la "finestra NitroShare", con i dispositivi in stile AirDrop e i trasferimenti.
  - `SharePanel`: contiene `ShareView` (la scelta dei destinatari, anche multipla) e `DeviceTile` (il cerchio del dispositivo con anello di avanzamento e badge dell'esito).
  - `TransferRow`: la riga di un trasferimento, con variante `isLarge` per la finestra.
  - `WindowPlacement`: contiene `ItemPicker` (`NSOpenPanel` per file e cartelle, come sheet o come pannello).
  - `CoreProcess`: avvia e sorveglia `nitroshare-cli`.
  - `Notifier`: le notifiche di fine trasferimento.
- **Comunicazione con il core**: HTTP locale, con porta e token in `~/.NitroShare`. Le azioni sono in `plugins/bridge/bridgeplugin.cpp`. Gli id dei trasferimenti sono un contatore crescente, assegnato alla prima lettura: `ShareView` ci conta per associare ogni cerchio al suo trasferimento (primo id maggiore del massimo registrato al momento dell'invio, con lo stesso `deviceName`).
- **Messaggi d'errore**: il core li scrive in inglese. `Transfer.displayError` (`Models.swift`) li traduce in frasi comprensibili; i nuovi errori comuni vanno mappati lì.
- **Questo Mac**: il core lo rileva tramite i propri annunci. `AppModel` lo esclude confrontando l'uuid con `status.deviceUuid`. Se lo stesso dispositivo arriva sia da mDNS sia da broadcast, si tiene l'entry con porta valida.

## Core orfani e permesso "Rete locale" (importante)

Il permesso "Rete locale" di macOS è legato all'app. Un `nitroshare-cli` sopravvissuto alla sua app (padre = launchd) non può connettersi alla LAN. Il sintomo è un socket bloccato in `SYN_SENT` mentre `nc` dal terminale si connette. In più il nuovo core termina con "NitroShare is already running", e l'app finisce per usare quello orfano. Per evitarlo:
- l'app passa `--exit-with-parent` (in `cli/main.cpp`), così il core si chiude entro un secondo se il padre sparisce;
- all'avvio `CoreProcess.stopOrphanedCores()` esegue `pkill -x -P 1 -U <uid> nitroshare-cli`.

**Durante i test** l'app va chiusa con `osascript -e 'quit app "NitroShare"'` oppure `pkill -x NitroShare`. Non si uccide mai il core a mano lasciando viva l'app, e viceversa. Prima di chiudere l'app dell'utente in `/Applications` si controlla via API che non ci siano trasferimenti attivi, e alla fine la si riapre.

## Compatibilità con NitroShare 0.3.x (deve restare)

Molti colleghi dell'utente usano ancora la 0.3, e non si vuole obbligarli ad aggiornare. Il protocollo è lo stesso in tutte e due le versioni. Pacchetto: dimensione little-endian a 4 byte (tipo compreso), 1 byte di tipo (`Success`=0, `Error`, `Json`, `Binary`) e il contenuto. Le differenze gestite:

- **Broadcast (UDP 40816)**: la 0.3 manda `"port"` come stringa. `BroadcastDevice::port()` la legge con `toVariant().toInt()`. Prima veniva letta come 0 e l'invio falliva con `unable to create "lan" transport`.
- **Numeri negli header**: vanno come stringhe (`size`, `count`, `created`, `last_modified`, `last_read`). `JsonUtil::objectToJson` converte già i `qint64` in stringhe.
- **Header dei file inviati alla 0.3**: devono contenere `name`, `directory` (booleano JSON), `size`, `created`, `last_modified` e `last_read`, altrimenti la 0.3 risponde "Unable to read file header". Per questo `File` espone le proprietà legacy `last_read`, `last_modified` e `directory`.
- **Header dei file ricevuti dalla 0.3**: non hanno `type` e hanno *sempre* `directory`, di solito `false`. Quindi `type` vale `"file"` per default, e `File` crea una cartella solo quando `directory` vale `true`. Prima la sola presenza del campo faceva cercare un gestore "directory" inesistente, e ogni ricezione dalla 0.3 falliva.
- **Codice originale della 0.3 per verificare**: `git show c53af4b^:src/transfer/transferreceiver.cpp` e `git show cc93623:src/util/json.cpp`.

Altre regole del trasferimento:
- `LanTransport` interrompe la connessione dopo 10 s senza risposta ("the device did not respond").
- I file ricevuti non sovrascrivono mai quelli esistenti: `File::open` sceglie "nome 2.ext".
- `.DS_Store` viene escluso quando si inviano cartelle.

## Preferenze dell'utente su design e comportamento

- **Stile Apple**: l'app deve sembrare un prodotto Apple. Margini generosi (titoli di sezione 20pt sopra e 14pt sotto, 20pt fra le file di dispositivi, 24pt attorno ai testi di aiuto), niente pulsanti minuscoli (almeno 24pt nella finestra), testi di almeno 12pt. Niente anelli di focus rettangolari sui cerchi (`.focusEffectDisabled()`). La facilità d'uso viene prima di tutto.
- **Verifica visiva**: dopo ogni modifica grafica si controlla il risultato con `screencapture`, senza fidarsi solo della compilazione. Le finestre devono adattarsi al contenuto (`NSHostingController` con `sizingOptions = .preferredContentSize`).
- **Menu della barra**: si chiude (`MenuPanel.close()`) quando una voce apre un'altra finestra o il selettore.
- **"Fine" nel foglio di condivisione**: chiude il foglio e basta, *senza* aprire la finestra dei trasferimenti. L'avanzamento si vede sui cerchi, la fine arriva con una notifica.
- **Invio dal menu della barra**: il clic o il trascinamento su un dispositivo, dove non c'è un foglio, apre invece la finestra NitroShare per seguire l'avanzamento.

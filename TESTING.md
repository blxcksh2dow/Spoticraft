# Verifica Spoticraft 26.2

## Aggiornamento: Fabric Loader 0.19.3

- Build Windows con Loader vincolato a 0.19.3: https://github.com/blxcksh2dow/Spoticraft/actions/runs/36235968172
- Compilazione e test riusciti. Il vincolo Gradle `strictly` impedisce un upgrade
  silenzioso del Loader durante la risoluzione delle dipendenze.
- Il requisito nel manifest viene generato da `loader_version`, per mantenerlo
  allineato alla dipendenza di compilazione.
- JAR recuperato e verificato: manifest `fabricloader >=0.19.3`, Minecraft 26.2,
  versione mod 26.2, classi compilate e archivio integro.
- Fabric API resta 0.161.0+26.2. Prova interattiva in Minecraft ancora da eseguire.


## Aggiornamento: build Windows riuscita

- Build GitHub Actions: https://github.com/blxcksh2dow/Spoticraft/actions/runs/36235520219
- JDK 25, Windows: `gradlew.bat --no-daemon --stacktrace clean downloadMod` riuscito.
- Compilazione sorgenti e test JUnit completati con successo.
- Corretto il riferimento a `Options.hideGui`, assente nelle API Minecraft 26.2.
- JAR salvato in `download/spoticraft-26.2.jar` sul branch della sessione.
- Verificati archivio ZIP interno, versione 26.2, entrypoint compilato e bridge incluso.
- Non ancora effettuata una prova interattiva Minecraft/Spotify: la CI non la sostituisce.

Le note seguenti documentano il precedente blocco locale e i controlli manuali ancora utili.

## Eseguito in questa sessione

- Verificata esistenza di Minecraft/Fabric 26.2 nelle fonti online.
- Confrontate API HUD, GuiGraphicsExtractor, key mapping e configurazione Loom
  con documentazione/template ufficiali 26.2.
- Wrapper ufficiale recuperato in sola lettura dal template Fabric 26.2.
- Tentativo `./gradlew --version`: fallito, Java/JAVA_HOME assente.
- Download Fabric Maven, manifest Minecraft, Gradle, Maven Central e JDK:
  falliti per errori TLS; anche il repository di sistema non è raggiungibile.
- Validazione JSON, struttura del progetto, archivio wrapper e diff Git:
  verificati staticamente. Questi controlli **non sostituiscono una compilazione**.

## Da eseguire prima di usare/distribuire il JAR

- [ ] Windows 10 1809+ / Windows 11: `java -version` indica JDK 25.
- [x] Build Windows CI `gradlew.bat clean downloadMod` riuscita con test verdi.
- [x] Il JAR contiene fabric.mod.json con version/minecraft `26.2`, entrypoint,
      classi compilate e `native/spotify-session.ps1`.
- [ ] Avvio Fabric 26.2 + API 0.161.0+26.2: nessun errore in latest.log.
- [ ] Spotify classico: titolo/artista/copertina corretti, widget in alto a sinistra.
- [ ] Spotify Microsoft Store: stessa verifica.
- [ ] Pausa/ripresa, seek avanti/indietro, cambio brano rapido, ripetizione brano:
      tempo coerente e nessun testo/copertina del brano precedente.
- [ ] Spotify chiuso e riaperto; bridge terminato manualmente: stato e riconnessione.
- [ ] Durata e copertina mancanti: placeholder, nessun crash.
- [ ] LRC disponibile: attuale + successiva, con silenzi e offset.
- [ ] Solo testo semplice: scorrimento automatico e manuale, pausa lo sospende.
- [ ] Testo non disponibile/strumentale: messaggio nelle due righe riservate.
- [ ] Internet offline, HTTP 429/500: Minecraft non si blocca, retry distanziati.
- [ ] `lyricsEnabled=false`: nessuna connessione a LRCLIB.
- [ ] F8, F1, tasti rimappati, scala GUI e ridimensionamento finestra.
- [ ] Titolo molto lungo, caratteri Unicode, finestra piccola: nessuna sovrapposizione.
- [ ] Uscita dal gioco: nessun processo PowerShell Spoticraft residuo.
- [ ] Linux/macOS: stato non supportato, nessun tentativo di avviare PowerShell.

Il bridge può essere provato separatamente, senza Minecraft:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\main\resources\native\spotify-session.ps1
```

Deve emettere una riga JSON al secondo circa. Premi Ctrl+C per chiuderlo.
Non pubblicare output contenente brani personali senza volerlo.

## Procedura automatica OTTIENI-JAR (aggiunta successiva)

Riconfermati in sandbox: Java assente e Fabric Maven non raggiungibile (errore TLS).
Nessun test di esecuzione PowerShell disponibile in questo ambiente Linux.
Verificati staticamente riferimenti ai file e integrità dello ZIP aggiornato.

Da verificare su Windows x64:

- [ ] Senza Java: download Temurin 25, checksum, estrazione e build.
- [ ] Con JAVA_HOME valido o JDK 25 in PATH: nessun download JDK.
- [ ] Secondo avvio: riutilizzo `.tools/jdk-25`.
- [ ] JDK diverso da 25: acquisizione della versione richiesta.
- [ ] Checksum errato o download interrotto: niente esecuzione del pacchetto.
- [ ] Percorso del progetto con spazi: build e apertura Esplora file corretti.
- [ ] Rete assente o test falliti: messaggio di errore, nessuna conferma di successo.
- [ ] A fine esecuzione nessuna modifica permanente a JAVA_HOME o PATH.

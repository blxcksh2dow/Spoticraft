# Spoticraft · 26.2

Widget Spotify per **Minecraft Java 26.2**, **Fabric Loader 0.19.3+**,
**Fabric API 0.161.0+26.2**, **Windows 10 (1809+) / Windows 11**.
La versione della mod resta **26.2**.

## Nuova architettura: niente script durante il gioco

La precedente build con PowerShell/compilazione C# in memoria è stata segnalata
come `Trojan:Script/Wacatac.B!ml` da Defender sul PC di un utente. **Non ripristinare
quella build dalla quarantena. Il rilevamento non è stato certificato come falso positivo.**

La nuova implementazione **elimina** quel meccanismo, non lo nasconde:

- Nessun avvio di PowerShell, nessun `ExecutionPolicy Bypass` durante il gioco.
- Nessun compilatore, sorgente C#, BAT o script contenuto nel JAR installabile.
- Un piccolo **`Spoticraft.Bridge.exe` precompilato** è incluso nel JAR. È un
  programma .NET Framework di sola lettura, senza rete, installazione, elevazione
  o ricezione di comandi. Non esegue script e non scarica altro codice.
- Il sorgente è in [`native/src`](native/src). Il componente viene compilato nella
  build Windows e dialoga con Java solo attraverso stdout JSON.
- L'helper richiede il .NET Framework di Windows (4.8 consigliato, normalmente
  presente sui sistemi aggiornati), non .NET SDK, PowerShell o Visual Studio all'avvio.
- Java verifica lo SHA-256 del componente prima dell'esecuzione. Se il file è
  alterato o il sistema ne impedisce l'avvio, si ferma senza aggirare la protezione.
- Copertine, titolo, artista e posizione sono letti tramite le API Windows GSMTC;
  non sono necessari login Spotify, cookie, password o token.

I test e le scansioni della **build preliminare senza script** sono riusciti:
https://github.com/blxcksh2dow/Spoticraft/actions/runs/36240369093

**Una scansione pulita non è una garanzia di sicurezza né di accettazione su ogni
PC.** Il componente non è firmato Authenticode. Se Defender/SmartScreen blocca
anche la nuova build, fermati e condividi il nuovo rilevamento: non aggiungere
esclusioni e non ripristinare un file segnalato.

## Download e installazione

**[Scarica il nuovo JAR senza script runtime](https://github.com/blxcksh2dow/Spoticraft/raw/71b69f0f7fc3610c6dac2662cbfc25bb869a4811/download/spoticraft-26.2.jar)**

Build pubblicata e verificata: https://github.com/blxcksh2dow/Spoticraft/actions/runs/36240553688


La cartella [`download`](download/LEGGIMI.md) contiene il JAR pubblicato e, per la
nuova architettura, **`spoticraft-26.2-verification.json`** con hash, scansioni e link
all'esecuzione CI. Prima di usare una build controlla che il rapporto sia presente
e riporti `precompiled-windows-helper-no-runtime-scripts`.

1. Chiudi Minecraft e rimuovi la vecchia copia di Spoticraft dalla cartella `mods`.
2. Scarica il **nuovo JAR verificato** indicato nella cartella download. Non
   recuperare il vecchio file bloccato da Defender; non tenere due copie della mod.
3. Inserisci il JAR in `mods`, insieme a Fabric API per Minecraft 26.2.
4. Avvia il profilo Fabric Loader **0.19.3 o successivo** per Minecraft 26.2.
5. Apri **Spotify desktop** e riproduci un brano, poi entra in un mondo.

Non serve eseguire i BAT, il programma `.exe` manualmente o un installer della mod.
L'helper viene estratto in `config/spoticraft/bridge/<sha256>/`. I vecchi file
`spotify-session.ps1` e `SpotifyBridge.cs` generati in `config/spoticraft/` vengono
rimossi, se possibile, e **non vengono mai eseguiti** dalla nuova versione.

Il codice e le build sono sul branch **`arena/01a0dd20-spoticraft`**, non in `main`.

## Widget

Posizione predefinita: **in alto a sinistra**, coordinate GUI `(8, 8)`.

- Titolo e artista, miniatura autentica del brano (pixel-art 48×48).
- Durata, tempo trascorso e barra di avanzamento; interpolazione indipendente dai tick.
- Stato riproduzione/pausa e messaggio quando Spotify è chiuso.
- **Due righe riservate al testo**: attuale + successiva quando LRCLIB restituisce LRC.
- Se è disponibile soltanto testo semplice, scorrimento automatico ogni 6 secondi
  durante la riproduzione e scorrimento manuale. Non viene inventata una sincronizzazione.
- Copertina o timeline mancanti non nascondono più titolo e artista.
- Stati distinti per testi assenti, strumentali, offline ed errori delle API Windows.

| Tasto predefinito | Funzione |
| --- | --- |
| F8 | Mostra/nascondi il widget per la sessione |
| `]` | Due righe successive del testo non sincronizzato |
| `[` | Due righe precedenti del testo non sincronizzato |

Tasti rimappabili in **Opzioni → Comandi → Assegnazione tasti → Spoticraft**;
su tastiere italiane è consigliabile rimappare le parentesi. F1 nasconde l'HUD.
Il widget non compare nel menu iniziale.

## Configurazione e privacy

`config/spoticraft/widget.properties`, creato al primo avvio:

```properties
x=8
y=8
width=280
enabled=true
lyricsEnabled=true
plainScrollSeconds=6
```

Modifica a gioco chiuso. Coordinate e larghezza seguono la scala GUI e vengono
limitate alla finestra. `plainScrollSeconds=0` lascia solo lo scorrimento manuale.
`enabled=false` nasconde inizialmente il widget ma non ferma il servizio testi.

**Con `lyricsEnabled=true`, titolo, artista, album e durata vengono inviati a
`https://lrclib.net/api/get`**, che vede anche l'IP. `lyricsEnabled=false` disabilita
quelle richieste. La cache testi resta solo in memoria, con limite di 64 brani.
Il componente Windows non effettua richieste di rete. Non ci sono porte in
ascolto, server locali, credenziali memorizzate o cronologia brani su disco.

L'eseguibile è avviato senza shell e viene chiuso all'uscita del client; termina
anche quando la pipe stdout si chiude. Dopo ripetuti arresti Java smette di
riavviarlo. Nessuna ricreazione automatica in ciclo di file rimossi dall'antivirus.

## Diagnostica e limiti

- Gli errori sono in `logs/latest.log`, nelle righe **`Spoticraft Windows bridge`**,
  con fase/HRESULT. Errori ripetuti sono limitati a uno al minuto per tipo.
- Condividi solo le righe pertinenti, controllando eventuali informazioni personali.
- Windows può non esporre durata, copertina o posizione per certe versioni di
  Spotify: in quel caso compaiono placeholder, non dati inventati.
- Spotify Web Player, Linux e macOS non sono supportati da questo bridge.
- Testi live/remix/podcast/pubblicità possono non essere disponibili in LRCLIB;
  i versi lunghi vengono troncati alla larghezza del widget.
- Il polling è circa ogni secondo. Pausa, seek e cambio brano possono avere un ritardo.
- Test nativi e Java su Windows non sostituiscono una prova interattiva completa
  con Minecraft/Spotify sul PC dell'utente.

## Sorgenti e compilazione (solo sviluppatori)

Serve **Windows**, JDK 25, .NET Framework e accesso ai repository delle dipendenze.
Il wrapper Gradle 9.5.1 è incluso; Loom segue il template Fabric 26.2.

```powershell
.\gradlew.bat --no-daemon clean downloadMod
powershell.exe -NoProfile -File .\scripts\test-windows-bridge.ps1
python scripts/verify-artifact.py
```

`CREA-MOD.bat` e `OTTIENI-JAR.bat` restano strumenti di sviluppo: non sono inclusi
nel JAR né necessari per installarlo. I loro script e `build-native.ps1` usano
PowerShell **soltanto durante la compilazione**, non nel runtime della mod.
La task `compileNativeBridge` compila helper e test C# sul disco di build; il JAR
include soltanto l'eseguibile di produzione e il checksum. Nessun offuscamento.

La CI esegue test Java, test WinRT (anche con stream reali), avvio del vero helper,
controllo del JAR senza script e scansioni Defender separate di helper e JAR.
Se scansione, test o verifiche falliscono, non pubblica il risultato. I rapporti
si riferiscono sempre agli hash effettivi dell'artefatto generato in quell'esecuzione.

Vedi [`TESTING.md`](TESTING.md) e [`SECURITY-REVIEW.md`](SECURITY-REVIEW.md).
Progetto non affiliato a Spotify, Mojang o Microsoft. Testi e immagini appartengono
ai rispettivi titolari e non sono inclusi nei sorgenti.

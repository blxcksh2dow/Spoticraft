# Spoticraft · 26.2

> **DISTRIBUZIONE SOSPESA — ANCHE LA BUILD PRECOMPILATA È STATA SEGNALATA.**
> Il 26 settembre 2026 Defender sul PC dell'utente ha rilevato
> `Trojan:Script/Wacatac.B!ml` anche sul JAR del commit `71b69f0`, mostrando
> lo stato **Attivo**. Non installare, ripristinare o escludere dalla scansione
> nessuna delle due build segnalate. Il precedente consiglio di installare
> la nuova build è ritirato. Una scansione pulita in CI non risolve il caso.
> Dettagli in `SECURITY-REVIEW.md`. Sorgenti e artefatti rimangono per l'analisi,
> **non come raccomandazione d'uso**.


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

## Download e installazione sospesi

Anche la build senza script runtime, pubblicata nel commit `71b69f0`, è stata
segnalata da Defender sul PC dell'utente. **Non installarla.** Il rapporto
`download/spoticraft-26.2-verification.json` registra soltanto il precedente
esito sul runner CI: non è un certificato di sicurezza né annulla il rilevamento.

La pubblicazione automatica è nuovamente bloccata da `download/SECURITY-HOLD.txt`.
Gli artefatti storici non sono stati riclassificati come falsi positivi. Non è
stata effettuata una submission a Microsoft in questa sessione. È necessaria
una valutazione del campione da parte del fornitore antivirus, non un'altra
variante del file per cercare di evitare il rilevamento.

Le descrizioni tecniche seguenti restano disponibili per l'analisi dei sorgenti.

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

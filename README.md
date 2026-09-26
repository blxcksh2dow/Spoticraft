# Spoticraft · 26.2

> **AVVISO SICUREZZA — non installare il JAR attuale.**
> Microsoft Defender ha segnalato `Trojan:Script/Wacatac.B!ml` sul download della
> build WinRT (`SHA-256 d242a29429aa2b2547bc701052b1807927ab666fbe25b25285053ee4ceb3f313`).
> Il rilevamento è in verifica: **non è stato accertato un falso positivo**.
> Non ripristinare il file, non disabilitare Defender e non aggiungere esclusioni.
> I link e gli artefatti sottostanti identificano la build segnalata, non una
> versione raccomandata per l'installazione. Anche ricompilarla non certifica la sicurezza.
> Esiti e limiti delle verifiche: [rapporto di sicurezza](SECURITY-REVIEW.md).


Mod **client Fabric**, versione **26.2**, destinata a **Minecraft Java 26.2** e
**Windows 10 (1809+) / Windows 11**, con Spotify desktop (classico o Microsoft Store).
Nessun account Spotify da collegare alla mod, Client ID o token richiesto.

## Scarica il JAR compilato

**[Download diretto Spoticraft 26.2](https://github.com/blxcksh2dow/Spoticraft/raw/refs/heads/arena/01a0dd20-spoticraft/download/spoticraft-26.2.jar)**

Il file è anche in **`download/spoticraft-26.2.jar`** nel repository.
Non serve eseguire i BAT per installare questa build: copia il JAR nella cartella
`mods` insieme a Fabric API per Minecraft 26.2.

> **Stato: compilazione e test riusciti su Windows con JDK 25 tramite GitHub Actions.**
> [Build verificata](https://github.com/blxcksh2dow/Spoticraft/actions/runs/36238976276).
> Ricompilata con dipendenza vincolata a **Fabric Loader 0.19.3**; requisito minimo
> nel JAR: `>=0.19.3`. Sostituisci il vecchio JAR, senza conservarne due copie.
> Corretto il bridge Windows: accesso WinRT tipizzato in C#, errori opzionali isolati
> e diagnostica in `logs/latest.log`. Superati 18 controlli nativi su Windows
> (inclusi stream WinRT reali) e un test JSON, oltre ai test Java.
> Corretto il riferimento non valido a `Options.hideGui` per Minecraft 26.2.
> Verificati integrità del JAR, classi, risorse e metadati. La prova in gioco
> con Spotify resta da eseguire. Il progetto e il JAR sono pubblicati nel branch
> `arena/01a0dd20-spoticraft`, non in `main`.

## Widget

Posizione predefinita: **in alto a sinistra**, coordinate GUI `(8, 8)`.

- Titolo, artista e copertina del brano fornita dalla sessione Spotify.
- Tempo trascorso, durata totale e barra di avanzamento.
- Indicazione riproduzione/pausa; avanzamento basato sul tempo reale, non sui tick.
- **Esattamente due righe** sotto il brano: riga attuale e successiva per i testi LRC.
- Se esiste solo testo semplice, due righe con scorrimento automatico ogni 6 secondi,
  sospeso durante la pausa, e scorrimento manuale. Non viene simulata una falsa
  sincronizzazione temporale; i versi lunghi vengono troncati alla larghezza del widget.
- Stati espliciti per Spotify chiuso, assenza di testo, brano strumentale, rete assente
  o API Windows non disponibili. Le due righe rimangono riservate durante l'ascolto.
- Copertina pixel-art 48×48; icona musicale se assente. Non è un'immagine generata:
  viene letta dalla miniatura che Spotify espone a Windows.

## Ottenere il JAR con doppio clic (Windows x64)

1. Scarica `download/spoticraft-26.2-source.zip` ed **estrai tutto lo ZIP**.
2. Apri **`OTTIENI-JAR.bat`** nella cartella estratta, non dentro lo ZIP.
3. Attendi: lo script usa un JDK 25 esistente oppure scarica **Eclipse Temurin 25**
   portatile in `.tools/jdk-25`, controllandone lo SHA-256 tramite i metadati HTTPS
   di Adoptium. Poi esegue la build e i test.
4. **Solo se la build riesce**, apre Esplora file su
   **`download/spoticraft-26.2.jar`**, pronto da copiare in `mods`.

Questa procedura serve a ricompilare il sorgente sul tuo PC; per il JAR già
compilato usa invece il link in cima alla pagina. Non richiede installare Java manualmente o diritti amministratore e
non modifica permanentemente `JAVA_HOME`, `PATH` o la policy PowerShell.
Il download automatico del JDK supporta Windows x64; su altre architetture va
fornito un JDK 25 compatibile tramite `JAVA_HOME`.

Servono Internet, spazio per le dipendenze e accesso a Adoptium, ai suoi mirror
(inclusi i download GitHub), Gradle, Fabric, Mojang e Maven Central.
Le richieste sono solo download: **nessun sorgente viene caricato su GitHub**.
Gli strumenti rimangono in `.tools` e nella cache Gradle e vengono riutilizzati.
Se rete, test o compilazione falliscono, viene mostrato un errore: nessun JAR
fittizio viene generato. Anche questa procedura **non è stata eseguita su Windows**
in questo ambiente.

## Compilare e ottenere il JAR su Windows

1. Installa un **JDK 25**, per esempio Eclipse Temurin, e configura `JAVA_HOME`.
   Il Java incorporato nel launcher Minecraft non è necessariamente accessibile al terminale.
2. Scarica/copia tutto il progetto e apri **`CREA-MOD.bat`**.
3. Attendi il download delle dipendenze, i test e la compilazione (serve Internet).
4. Se il comando termina con successo trovi **`download/spoticraft-26.2.jar`**.

Oppure da PowerShell, nella cartella del progetto:

```powershell
.\gradlew.bat --no-daemon clean downloadMod
```

La task `downloadMod` dipende da `build`: non copia un JAR se i test o la build
falliscono. Non pubblica niente su GitHub o repository Maven.
Il wrapper Gradle **9.5.1** è incluso; usa il plugin Fabric Loom del template
ufficiale 26.2 (**1.17-SNAPSHOT**), Fabric Loader **0.19.3** e Fabric API
**0.161.0+26.2**. Loom è uno snapshot, quindi la risoluzione del plugin può
cambiare a monte. Non si usano Yarn o rimappature obsolete per questa versione.

## Installazione

1. Installa Fabric Loader **0.19.3+ per Minecraft 26.2**.
2. Metti `spoticraft-26.2.jar` e **Fabric API per 26.2, versione 0.161.0+26.2 o successiva compatibile**
   nella cartella `mods` dell'istanza Minecraft.
3. Apri Spotify desktop e avvia un brano, poi entra in un mondo Minecraft.
4. Non installare la mod sul server: funziona solo sul client.

## Comandi e impostazioni

Tutti i tasti sono rimappabili in **Opzioni → Comandi → Assegnazione tasti → Spoticraft**:

| Tasto predefinito | Funzione |
| --- | --- |
| F8 | Mostra/nascondi il widget per la sessione corrente |
| `]` | Due righe successive del testo non sincronizzato |
| `[` | Due righe precedenti del testo non sincronizzato |

Per tastiere italiane è consigliabile rimappare i due tasti delle parentesi.
F1 nasconde anche il widget. Il widget non compare nel menu iniziale.

Al primo avvio viene creato `config/spoticraft/widget.properties`:

```properties
x=8
y=8
width=280
enabled=true
lyricsEnabled=true
plainScrollSeconds=6
```

Modifica il file a gioco chiuso. `x` e `y` sono coordinate GUI (quindi rispettano
la scala GUI di Minecraft); la posizione viene limitata alla finestra.
`plainScrollSeconds=0` lascia solo lo scorrimento manuale.
`lyricsEnabled=false` disabilita tutte le richieste di testi; copertina e playback
restano locali. `enabled=false` imposta il widget inizialmente nascosto, ma F8
può mostrarlo: **non** disattiva il servizio testi.

## Come funziona / privacy

- Java avvia **un solo processo Windows PowerShell 5.1**, senza profilo né finestra
  interattiva, usando le API Windows **Global System Media Transport Controls**.
- Il bridge è incluso in `src/main/resources/native/spotify-session.ps1` e
  `SpotifyBridge.cs`. Entrambi vengono copiati/aggiornati in `config/spoticraft/`
  all'avvio. PowerShell compila il piccolo helper C# in memoria con il compilatore
  .NET Framework e i metadati WinRT già presenti in Windows; non serve installare
  Visual Studio, Windows SDK o .NET SDK. Gli oggetti WinRT restano in C# e soltanto
  semplici dati .NET vengono serializzati in JSON UTF-8 verso Java.
  È di sola lettura: non invia comandi di riproduzione e non legge password/cookie.
- `-ExecutionPolicy Bypass` vale per il solo processo figlio; la policy permanente
  di Windows non viene modificata. Policy aziendali possono comunque impedirne l'avvio.
- Non ci sono server HTTP locali, porte aperte, eseguibili nativi scaricati o token.
- Se i testi sono abilitati, **titolo, artista, album e durata sono inviati a
  `https://lrclib.net/api/get`**. LRCLIB vede inoltre l'IP della connessione.
  Nessun testo viene estratto da Spotify. La disponibilità non è garantita.
- Cache testi solo in memoria (massimo 64 brani), timeout e tentativi distanziati;
  nessuna cronologia di ascolto scritta su disco. Il processo Windows viene
  chiuso all'uscita dal client e riavviato se si blocca.

## Limiti e compatibilità da verificare sul PC

- **Compilato e testato con JUnit su un runner Windows**, ma non ancora provato
  dentro Minecraft né con una sessione Spotify reale.
- Spotify Web Player non è supportato: viene selezionata solo una sessione con
  identificatore Spotify, non il browser o qualunque altro lettore multimediale.
- Alcune versioni di Spotify non espongono durata, posizione, copertina o album
  in GSMTC. Se Windows non li fornisce, la mod non può ricostruirli in modo affidabile:
  la durata è `--:--`, la barra vuota o la copertina sostituita dall'icona.
- Il polling avviene circa ogni secondo; cambio brano, seek e pausa possono avere
  un ritardo. La posizione viene interpolata tra gli aggiornamenti Windows.
- Testi non trovati, brani locali, podcast, pubblicità e versioni live/remix possono
  non avere una corrispondenza in LRCLIB. Nessuna ricerca approssimata che rischi di
  mostrare il testo di un altro brano.
- Testo e metadati sono mostrati in italiano per gli stati del widget; i nomi dei
  tasti hanno traduzioni italiana e inglese.

## Se Spotify non viene letto

La vecchia build poteva mostrare **"Sessione Spotify non disponibile"** anche
quando Spotify era rilevato: PowerShell riceveva alcuni risultati WinRT come
`System.__ComObject`, senza accesso corretto a proprietà/metodi delle interfacce.
Una lettura/chiusura fallita dello stream della copertina poteva finire nel catch
che invalidava l'intera sessione. Il test su Windows ha riprodotto il problema
COM con uno stream WinRT reale. Senza il vecchio log del PC non è possibile
attribuire con certezza ogni caso segnalato a questo solo errore.

Il nuovo bridge usa chiamate C# tipizzate. Se copertina o timeline falliscono,
conserva titolo e artista; se falliscono i metadati essenziali, segnala la fase
precisa. I dettagli compaiono in **`logs/latest.log`**, nelle righe contenenti
**`Spoticraft Windows bridge`**, con fase, tipo eccezione e HRESULT.
Messaggi ripetuti vengono limitati a uno al minuto per tipo di errore; non
vengono scritti deliberatamente titolo, artista o immagine nei messaggi diagnostici.

Chiudi Minecraft, sostituisci il vecchio JAR e riavvia: i due file bridge vengono
aggiornati automaticamente, senza dover cancellare la configurazione.
Se il problema persiste, condividi solo quelle righe di log (controllando che
non contengano informazioni personali), non l'intero log del client.

## Verifiche

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-windows-bridge.ps1
.\gradlew.bat test
.\gradlew.bat runClient
```

Test JUnit inclusi per parsing LRC, tag ripetuti, offset, Unicode, seek indietro,
righe vuote, fallback testo semplice, interpolazione/pausa/limiti del playback e
configurazione. **Eseguiti con successo su GitHub Actions Windows**; la sandbox
locale resta senza Java e con accesso limitato ai server delle dipendenze.

Vedi [`TESTING.md`](TESTING.md) per la checklist Windows e lo stato delle verifiche.

## Riferimenti tecnici

- [Template ufficiale Fabric 26.2](https://github.com/FabricMC/fabric-example-mod/tree/26.2)
- [HUD Fabric 26.2](https://docs.fabricmc.net/develop/rendering/hud)
- [GUI / GuiGraphicsExtractor](https://docs.fabricmc.net/develop/rendering/gui-graphics)
- [GSMTC Microsoft](https://learn.microsoft.com/en-us/uwp/api/windows.media.control.globalsystemmediatransportcontrolssessionmanager)
- [API LRCLIB](https://lrclib.net/docs)

Progetto non affiliato a Spotify, Mojang o Microsoft. Copertine e testi appartengono
ai rispettivi titolari e non sono inclusi nel repository.

# Verifica del rilevamento Defender — 26 settembre 2026

> La segnalazione qui descritta riguarda la **build ritirata con script runtime**.
> La nuova architettura precompilata ha un artefatto diverso; il suo rapporto
> verificabile è in [download/spoticraft-26.2-verification.json](download/spoticraft-26.2-verification.json).
> Questo non riclassifica il vecchio rilevamento come falso positivo.

## Segnalazione

Microsoft Defender sul PC dell'utente ha rimosso il download di
`spoticraft-26.2 (1).jar`, indicandolo come **Trojan:Script/Wacatac.B!ml**.
Lo screenshot riporta il download dal commit `afbc48c` di questo repository.
Non è disponibile un hash calcolato sul file rimosso dal PC dell'utente.

Campione del repository corrispondente a quel link:

```
SHA-256: d242a29429aa2b2547bc701052b1807927ab666fbe25b25285053ee4ceb3f313
```

## Verifiche effettuate

- Archivio JAR integro; script PowerShell e helper C# inclusi corrispondono ai
  sorgenti pubblicati, normalizzando le terminazioni di riga Windows/Linux.
- Il bridge avvia PowerShell con ExecutionPolicy Bypass limitato al processo
  e compila codice C# locale in memoria. Sono possibili fattori di rilevamento,
  **non una causa dimostrata** del messaggio dell'antivirus.
- Il JAR è stato scansionato senza eseguirlo su un runner Windows con Microsoft
  Defender attivo e firme aggiornate alla versione **1.459.410.0**.
- **Nessun rilevamento su quel runner**, per il SHA-256 sopra indicato.
- Esecuzione della scansione:
  https://github.com/blxcksh2dow/Spoticraft/actions/runs/36239885959
- Il controllo verifica anche minacce registrate, rimozione/modifica del campione
  e codice di uscita; un antivirus assente o inattivo non vale come esito pulito.

## Cosa NON dimostrano queste verifiche

L'esito sul runner non annulla il rilevamento sul PC dell'utente, non dimostra
che il file scaricato sia identico al campione e **non certifica un falso positivo**.
Non sono stati provati il comportamento in gioco sotto Defender, tutte le
configurazioni di protezione cloud/reputazione o ogni versione delle firme.
I precedenti test funzionali non erano scansioni antivirus.

## Misure

- Avviso di non installare la build segnalata nel README e nella cartella download.
- `download/SECURITY-HOLD.txt` blocca le nuove esecuzioni del workflow di build;
  il JAR storico resta identificabile nel repository per l'analisi.
- Il workflow è predisposto per richiedere una scansione prima delle future
  pubblicazioni; il blocco resta finché la verifica non è risolta.
- Nessuna esclusione antivirus, offuscamento o modifica per aggirare il rilevamento.

## Prossimo passo

È necessaria una valutazione del campione da parte di Microsoft tramite il portale
ufficiale: https://www.microsoft.com/en-us/wdsi/filesubmission

**Non è stata effettuata una submission in questa sessione.** Il campione può
essere fornito dal manutentore usando la copia già disponibile; l'utente non deve
ripristinarlo dalla quarantena né scaricarlo nuovamente per effettuare la verifica.
Fino al chiarimento, lasciare il file rimosso e non eseguire la mod o i suoi BAT.

## Nuova architettura: componente precompilato

La segnalazione originaria **resta irrisolta**; non si dichiara un falso positivo.
La sostituzione è un cambiamento architetturale del software legittimo, non un
aggiramento di Defender. Non vengono usati offuscamento, packer, esclusioni,
modifiche alla protezione o occultamento dell'eseguibile.

La build preliminare della nuova architettura ha completato:
https://github.com/blxcksh2dow/Spoticraft/actions/runs/36240369093

- Test Java (inclusa verifica dell'integrità del componente estratto).
- Test C# con oggetti WinRT reali e sessioni simulate.
- Avvio del vero eseguibile e lettura delle sessioni Windows con risposta JSON.
- Verifica JAR senza script, sorgenti C#, shell o compilatore runtime.
- Scansioni separate del componente precompilato e del JAR: nessun rilevamento
  sul runner con firme Defender 1.459.410.0.

Il blocco globale di pubblicazione è rimosso **solo per la nuova architettura**:
la pipeline rifiuta esplicitamente l'hash del vecchio JAR e verifica il contenuto,
poi richiede test e scansioni ad ogni build prima di pubblicare. I nuovi hash e
rapporti sono in `download/spoticraft-26.2-verification.json`; non riutilizzare
l'esito di una build per certificare un'altra build.

Il componente è compilato prima della distribuzione, non sul PC durante il gioco.
Java verifica il suo hash e lo avvia senza shell con i normali permessi utente.
In caso di blocco dell'avvio non tenta di modificare le protezioni o ricreare il
file in ciclo. Si interrompe e scrive un errore nel log.

Restano i limiti: eseguibile non firmato Authenticode, assenza di una valutazione
Microsoft del vecchio campione, possibili differenze di reputazione/protezione cloud
tra dispositivi, mancata prova interattiva completa sulla macchina dell'utente.
Se la nuova build è segnalata, non ignorare il rilevamento: serve una nuova analisi.

### Build sostitutiva pubblicata

Run: https://github.com/blxcksh2dow/Spoticraft/actions/runs/36240553688

SHA-256 del JAR:
`3f4e6d149184a01bde57c5b3e1026009bf886659099addffb0425b5fddd63bb4`

SHA-256 dell'helper incluso:
`8c65e028deba372a5744f5df71eea9f1a2f3d690972a8d16dd807f68a4483d75`

Defender engine 1.1.26080.3, firme 1.459.410.0: nessun rilevamento su entrambi
nel runner. Verificati localmente gli hash e l'assenza di script nel JAR recuperato.
Rimangono validi i limiti sopra: nessuna garanzia di accettazione sul dispositivo
utente; se bloccato, non ripristinare né aggiungere esclusioni.

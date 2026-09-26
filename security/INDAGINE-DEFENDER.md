# Spoticraft: indagine sul rilevamento Defender

**Stato: distribuzione sospesa. Nessun falso positivo accertato. Non installare o ripristinare i JAR segnalati.**

## Risultato più importante: le precedenti verifiche erano sbagliate

Ho recuperato i log delle scansioni che erano state presentate come pulite.
Contengono esplicitamente:

```text
Scan finished.
Scanning ...\Spoticraft.Bridge.exe was skipped.
Scanning ...\spoticraft-26.2.jar was skipped.
```

Il comando restituiva `0`, ma i file **non erano stati scansionati**. Il vecchio
script controllava il codice di uscita, la presenza del file e le minacce registrate,
ma non verificava scansioni saltate, esclusioni, scansione archivi e protezioni cloud.
Quindi le precedenti affermazioni di una scansione riuscita erano errate, non
semplicemente una differenza di giudizio tra due antivirus. Sono state ritirate.

Prove conservate:
- [Log della prima scansione](historical-scan-36239885959.txt)
- [Log di helper e JAR della build sostitutiva](historical-scan-36240553688.txt)

Nel runner iniziale erano disattivate scansione archivi, protezione in tempo
reale, IOAV e MAPS/cloud. Anche riattivandole, le esclusioni preimpostate della VM
facevano saltare i file. Questo spiega l'inattendibilità delle verifiche precedenti,
**non identifica la causa della classificazione Wacatac sul PC dell'utente**.

## Cosa è stato fatto adesso

Non sono stati modificati, rinominati per eludere controlli, offuscati o ricompilati
i campioni. Non è stato eseguito né il JAR né il suo helper durante l'indagine.
Il file scaricato dall'URL dello screenshot corrisponde byte per byte al campione
nel repository:

```text
JAR:    3f4e6d149184a01bde57c5b3e1026009bf886659099addffb0425b5fddd63bb4
Helper: 8c65e028deba372a5744f5df71eea9f1a2f3d690972a8d16dd807f68a4483d75
```

Solo sulla VM usa-e-getta GitHub Actions:
1. Sono state attivate le protezioni real-time, IOAV, archivi e cloud.
2. Sono state rimosse due esclusioni preimpostate del runner, **rafforzando** la protezione.
3. È stata verificata la connessione MAPS.
4. È stato controllato il file scaricato in una cartella esplicitamente **non esclusa**.
5. È stato richiesto il controllo allegati Windows tramite `IAttachmentExecute::Save`,
   senza chiamare Execute, aprire il JAR o ignorare un blocco. È presente ZoneId=3.

Risultato per la copia scaricata:

```text
... is not excluded. Exit code is 1.
Scan finished.
Scanning ...\spoticraft-26.2 (1).jar found no threats.
```

Windows Server 2025, Defender engine **1.1.26080.3**, intelligence **1.459.412.0**.
La copia nella directory di build ha avuto un controllo di esclusione incoerente:
non la uso come prova di scansione valida. Il risultato sopra riguarda soltanto
la copia scaricata nel percorso confermato non escluso.

- [Esecuzione dell'indagine](https://github.com/blxcksh2dow/Spoticraft/actions/runs/36242074542)
- [Risultati strutturati](defender-investigation-36242074542.json)
- [Inventario statico del JAR](artifact-inventory.json)

Questa volta c'è una scansione effettiva senza rilevamenti sul campione scaricato.
**Non dimostra che il rilevamento sul PC dell'utente sia un falso positivo.**
Il sistema operativo non è lo stesso, le firme del dispositivo non sono ancora
note e il test Attachment Services non equivale alla sessione reale del browser.
Il componente non è firmato Authenticode; non sappiamo se questo influenzi il
verdetto e non lo presentiamo come causa provata.

### Ripetizione conclusa con entrambi i percorsi non esclusi

Nel [test successivo](https://github.com/blxcksh2dow/Spoticraft/actions/runs/36242236760)
entrambi i percorsi sono stati confermati non esclusi e le scansioni hanno
restituito esplicitamente `found no threats`. Sono passati anche **13 test del
validatore**, incluso il caso in cui exit code 0 accompagna `was skipped`.
[Prove strutturate](defender-investigation-36242236760.json).

Questo conferma l'esito limitato al laboratorio, non risolve il rilevamento
sul dispositivo dell'utente né autorizza a ignorarlo. La mod non è stata modificata.

## Correzioni al sistema di verifica

- Una scansione saltata, esclusa, interrotta, senza un verdetto esplicito o con
  output non riconosciuto viene rifiutata, anche quando termina con codice `0`.
- Vengono richiesti controlli delle protezioni, connessione cloud ed esclusioni.
- I rapporti storici sono contrassegnati come ritirati, non riscritti come se
  le scansioni fossero state davvero eseguite.
- Test di regressione coprono esattamente il messaggio `was skipped`.
- `download/SECURITY-HOLD.txt` continua a bloccare build/pubblicazione della mod.

## Cosa serve per trovare la causa sul PC dell'utente

Senza scaricare o ripristinare la mod, raccogliere soltanto:

- Windows 10 o 11 e versione/build (visibile in `winver`).
- Browser usato per il download e versione.
- Versione di **intelligence per la sicurezza** di Defender, in Sicurezza di Windows
  → Protezione da virus e minacce → Aggiornamenti della protezione.
- Se il blocco è avvenuto solo scaricando o dopo aver avviato Minecraft con il JAR.

Non servono credenziali, esclusioni antivirus, log completi o recupero dalla quarantena.
Le differenze di reputazione/cloud/browser/firme sono ipotesi da confrontare,
non spiegazioni già dimostrate. Il nome Wacatac, da solo, non rivela la regola che
ha prodotto il rilevamento.

## Valutazione Microsoft

È pronto [un testo in inglese per la richiesta di analisi](MICROSOFT-SUBMISSION.txt),
con hash, URL immutabile, sorgenti, comportamento previsto e limiti dei test.
Portale ufficiale: https://www.microsoft.com/en-us/wdsi/filesubmission

**La richiesta non è stata inviata.** Il portale prevede interazione/verifica umana
che non ho completato da questa sessione. Non esiste ancora un submission ID o
una risposta Microsoft. L'eventuale invio del campione deve usare la copia già
disponibile in un ambiente di analisi, non richiedere all'utente di ripristinare
un file segnalato per allegarlo.

Una correzione definitiva richiede riprodurre il rilevamento o ottenere la
valutazione del fornitore. Se emerge un comportamento realmente problematico,
si corregge quel comportamento e lo si testa; se è un falso positivo confermato,
si segue la revisione Microsoft. Non si cerca una variante che sfugga all'antivirus.

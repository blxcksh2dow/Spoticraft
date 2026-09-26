# Verifica del rilevamento Defender — 26 settembre 2026

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

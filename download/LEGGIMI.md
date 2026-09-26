# Download sospesi: non installare Spoticraft

Anche la build precompilata del commit `71b69f0` è stata rilevata come
**Trojan:Script/Wacatac.B!ml** da Defender sul PC dell'utente, con stato Attivo.
Il precedente invito a installare questa versione è ritirato.

Non ripristinare i file, non selezionare "Consenti sul dispositivo" e non
aggiungere esclusioni. Chiudi Minecraft e usa Quarantena/Rimuovi in Defender.

## Campioni segnalati

- Build con script runtime: SHA-256
  `d242a29429aa2b2547bc701052b1807927ab666fbe25b25285053ee4ceb3f313`.
- Build con helper precompilato: SHA-256
  `3f4e6d149184a01bde57c5b3e1026009bf886659099addffb0425b5fddd63bb4`.

Gli hash identificano le copie del repository associate ai link negli screenshot;
non sono stati calcolati sui file del dispositivo dell'utente.

I file restano disponibili per l'analisi: **non sono raccomandati per l'installazione**.
Il rapporto `spoticraft-26.2-verification.json` è **ritirato**: i log originali
mostrano che le scansioni erano state saltate. Il precedente esito era errato,
NON un certificato di sicurezza. Il nome
"verification" non implica che il rilevamento sul PC sia stato smentito.

La pubblicazione automatica è bloccata da `SECURITY-HOLD.txt`. Vedi
[`SECURITY-REVIEW.md`](../SECURITY-REVIEW.md). Nessun falso positivo accertato.

[Indagine aggiornata con evidenze](../security/INDAGINE-DEFENDER.md).

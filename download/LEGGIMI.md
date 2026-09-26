# Spoticraft 26.2 — nuovo bridge precompilato

La vecchia build con hash
`d242a29429aa2b2547bc701052b1807927ab666fbe25b25285053ee4ceb3f313`
è stata segnalata da Defender: **non ripristinarla dalla quarantena**.
Il suo rilevamento non è stato certificato come falso positivo.

La nuova architettura non avvia PowerShell, non compila codice durante il gioco
e non include script nel JAR. Include un piccolo componente Windows precompilato,
di sola lettura. I sorgenti completi sono nel progetto.

## Quale file usare

**Nuova build pubblicata:** [scarica il JAR verificato](https://github.com/blxcksh2dow/Spoticraft/raw/71b69f0f7fc3610c6dac2662cbfc25bb869a4811/download/spoticraft-26.2.jar).

È presente **`spoticraft-26.2-verification.json`** con `architecture: precompiled-windows-helper-no-runtime-scripts`. Il suo campo
`scans` riporta lo SHA-256 del JAR e del componente, con l'esito Defender e il link CI.
Non usare una vecchia copia del JAR priva di questo rapporto.

- [JAR di questa build](https://github.com/blxcksh2dow/Spoticraft/raw/71b69f0f7fc3610c6dac2662cbfc25bb869a4811/download/spoticraft-26.2.jar)
- [Rapporto della build corrente](spoticraft-26.2-verification.json)
- [Sorgenti](spoticraft-26.2-source.zip)

## Installazione

Chiudi Minecraft, sostituisci la vecchia copia in `mods` e avvia **Minecraft 26.2**
con **Fabric Loader 0.19.3+** e **Fabric API 0.161.0+26.2**. Apri Spotify desktop.
Non eseguire BAT o l'helper `.exe` manualmente. Nessuna esclusione antivirus richiesta.

Una scansione pulita su CI non garantisce l'accettazione sul tuo PC. Se anche il
nuovo file viene bloccato, fermati e segnala il rilevamento senza ripristinarlo.
Il componente non è firmato Authenticode. La prova interattiva con Minecraft e
Spotify sul tuo PC resta necessaria.

## Verifica della build pubblicata

Run: https://github.com/blxcksh2dow/Spoticraft/actions/runs/36240553688

SHA-256 JAR:
`3f4e6d149184a01bde57c5b3e1026009bf886659099addffb0425b5fddd63bb4`

Scansioni di JAR e helper su Defender 1.459.410.0 senza rilevamenti sul runner.
20 test Java, test nativi e smoke test del vero helper superati. Non è una
certificazione di sicurezza o una verifica completa di gioco sul tuo PC.

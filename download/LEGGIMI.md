# Download Spoticraft 26.2

> **AVVISO SICUREZZA — non installare il JAR attuale.**
> Microsoft Defender ha segnalato `Trojan:Script/Wacatac.B!ml` sul download della
> build WinRT (`SHA-256 d242a29429aa2b2547bc701052b1807927ab666fbe25b25285053ee4ceb3f313`).
> Il rilevamento è in verifica: **non è stato accertato un falso positivo**.
> Non ripristinare il file, non disabilitare Defender e non aggiungere esclusioni.
> I link e gli artefatti sottostanti identificano la build segnalata, non una
> versione raccomandata per l'installazione. Anche ricompilarla non certifica la sicurezza.
> Esiti e limiti delle verifiche: [rapporto di sicurezza](../SECURITY-REVIEW.md).


**JAR compilato disponibile: [`spoticraft-26.2.jar`](spoticraft-26.2.jar).**

[Scarica direttamente da GitHub](https://github.com/blxcksh2dow/Spoticraft/raw/refs/heads/arena/01a0dd20-spoticraft/download/spoticraft-26.2.jar)

Build e test riusciti su Windows con JDK 25:
https://github.com/blxcksh2dow/Spoticraft/actions/runs/36238976276

Questa build include la correzione del bridge WinRT/PowerShell per l'errore
"Sessione Spotify non disponibile". Superati 18 controlli nativi Windows
(inclusa la lettura di uno stream WinRT reale), il test JSON e i test Java.
Mantiene compatibilità dichiarata e compilazione con **Fabric Loader 0.19.3**.
Sostituisci il vecchio JAR a gioco chiuso; non conservare due copie della mod.

## Installazione

1. Installa Fabric Loader 0.19.3 o successivo per **Minecraft 26.2**.
2. Copia **spoticraft-26.2.jar** nella cartella `mods` della tua istanza.
3. Aggiungi **Fabric API 0.161.0+26.2** o successiva compatibile con Minecraft 26.2.
4. Apri Spotify desktop su Windows 10/11 ed entra in un mondo.

Non devi compilare né eseguire i BAT per installare questo JAR.
Build e test automatici verificati; funzionamento in gioco con Spotify ancora da provare.

## Sorgenti

`spoticraft-26.2-source.zip` contiene i sorgenti aggiornati e gli script per ricompilare.
Estrai tutto lo ZIP e avvia `OTTIENI-JAR.bat` su Windows x64 solo se vuoi creare una
nuova build. Il JAR non è incluso nello ZIP dei sorgenti: scaricalo separatamente.

SHA-256 della build verificata:

```
d242a29429aa2b2547bc701052b1807927ab666fbe25b25285053ee4ceb3f313
```

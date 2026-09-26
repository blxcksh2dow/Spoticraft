# Download Spoticraft 26.2

**Il JAR installabile non è ancora presente: la build non è stata eseguita.**

Questo ambiente non dispone di Java e le connessioni ai server delle dipendenze
Fabric/Minecraft/Gradle e del JDK falliscono. Non è stato creato un JAR vuoto o
un archivio di sorgenti spacciato per mod installabile.

**Percorso automatico su Windows x64:** scarica `spoticraft-26.2-source.zip`,
estrailo e apri **`OTTIENI-JAR.bat`**. Scarica un JDK 25 portatile se necessario,
verifica il checksum, compila e apre la cartella del JAR solo in caso di successo.
È una compilazione automatica sul tuo PC, **non un download di un JAR precompilato**.
Lo script non è stato eseguito su Windows in questa sessione.

In alternativa, installa **JDK 25**, poi avvia `CREA-MOD.bat` dalla cartella principale.
Il wrapper scarica Gradle e le dipendenze, esegue i test e compila la mod.
Solo se la compilazione e i test riescono, il risultato viene copiato qui:

    download/spoticraft-26.2.jar

Metti quel JAR in `.minecraft/mods` insieme a **Fabric API per Minecraft 26.2**
e avvia il profilo **Fabric Loader 0.19.5 o successivo** per **Minecraft 26.2**.

Il file `spoticraft-26.2-sources.jar`, eventualmente presente in `build/libs`,
NON è la mod installabile. Non installare entrambi.

# P-Hslice  (DYLAN-FNF-PORTS-MOBILE · DF-PM Projects)

App de **Friday Night Funkin'** para celular (Android). Su motor por defecto se llama **PHSLICE** y junta
**Psych Engine + V-Slice + P-Slice**.

## ¿Cómo está armado?

P-Slice (github.com/Psych-Slice/P-Slice) **ya es** Psych Engine + V-Slice en un solo código, y ya compila para Android.
Por eso este repositorio NO copia esos ~100 000 renglones: el workflow descarga P-Slice en cada build (así recibes sus
arreglos) y le pone encima la capa P-Hslice (`overlay/`). Los cambios a P-Slice son parches pequeños y automáticos
(`scripts/apply_overlay.py`).

```
overlay/source/phslice/   código nuevo (Haxe): splash, menú, pestaña, controles, modo patata, mods...
overlay/java/             PHSliceNative.java: audio capturable, detección de grabación, Chrome, descargas
overlay/assets/           imágenes del splash + engines.json (perfiles de motor)
overlay/art/              ícono (imagen 1)
overlay/phslice.keystore  llave de firma (la misma en cada build, así el APK se actualiza sin desinstalar)
scripts/apply_overlay.py  copia la capa y parchea P-Slice
.github/workflows/        build-android.yml  ->  genera el APK
```

## Sacar el APK (GitHub)

1. Crea un repositorio en GitHub y sube **todo el contenido de esta carpeta** (que `.github/` quede en la raíz).
2. Pestaña **Actions → Build P-Hslice APK → Run workflow**.
3. Espera (la primera vez 40-90 min; luego es más rápido por la caché).
4. Entra a la ejecución terminada → **Artifacts → P-Hslice-APK** → descarga e instala.
5. Si falla, abre el paso rojo, copia el error y pásamelo para corregirlo.

## Qué incluye

| Función | Dónde |
|---|---|
| Animación 1: imagen 1 + "DYLAN-FNF-PORTS-MOBILE", luego animación 2: imagen 2 + "DF' -PM -Projects" (tocar = saltar) | `states/SplashState.hx` (textos en `PHSlice.hx`) |
| Nombre **P-Hslice**, ícono = imagen 1, paquete `com.dfpm.phslice` | `apply_overlay.py` + `overlay/art` |
| Elegir motor (PHSLICE / Psych Engine / V-Slice / P-Slice) en **Options → P-Hslice → Motor** | `Engines.hx`, `engines.json` |
| Jugar semanas y mods de los motores elegidos | las incluye P-Slice |
| Carpeta de mods exacta **`.P-Hslice`** (`/storage/emulated/0/.P-Hslice/mods`) | `ModPaths.hx` |
| Estilos de control: **Hitbox**, **V-Slice**, **Clásico (4 botones con flechas)**, editables (arrastrar, tamaño, alto, opacidad) | `ui/TouchControls.hx` |
| **Modo patata** (Options → Gráficos y P-Hslice): sin shaders/filtros y sin eventos pesados | `PotatoMode.hx` |
| Modo patata **automático** al grabar o transmitir | `PHSliceNative.java` + `PHSlice.hx` |
| Pestaña a la derecha del inicio: jalar a la izquierda → Chrome en GameBanana, importar mods, mis mods, patata, opciones | `ui/Drawer.hx` |
| Importar `.zip` descargados (Descargas → `.P-Hslice/mods`) | `PHSliceNative.unzip` |
| Audio del juego capturable al grabar/transmitir y sin cortarse | `PHSliceNative.setupAudio` |

## Cosas que debes saber (honestas)

* **No pude compilar aquí** (el entorno no tiene Haxe ni internet). La integración con P-Slice la probé contra una copia
  simulada, pero el primer build real puede dar algún error de compilación. Es normal: pásame el log y lo corrijo.
* **Motores = perfiles.** Psych Engine y V-Slice no corren como programas separados: P-Slice ya trae ambos y los
  perfiles cambian opciones. Los nombres de esas opciones (`vsliceFreeplay`, etc.) son una suposición: ábrelos en
  `backend/ClientPrefs.hx` de P-Slice y ajusta `overlay/assets/shared/phslice/engines.json`. Los que no existan se ignoran
  y quedan en `.P-Hslice/phslice.log`.
* **Carpeta `.P-Hslice` pública** necesita el permiso "Acceso a todos los archivos" (la app lo pide al abrir por primera
  vez). Sin él usa `Android/data/com.dfpm.phslice/files/.P-Hslice`.
* **Detección de grabación:** Android 15+ detecta grabación de pantalla; en versiones anteriores se detecta que algo graba
  audio (también puede saltar con una llamada de voz; se apaga en Opciones → Gráficos → Auto-patata).
* **Audio:** el juego declara su audio capturable y nunca cede el foco; en algunos teléfonos con "audio interno" bloqueado
  por el fabricante no hay forma de forzarlo desde la app.
* **Controles:** mandan teclas de flecha (y Escape para pausa). Si P-Slice también dibuja sus botones, ponles opacidad 0
  en sus opciones móviles.
* 7z/rar no se importan solos (solo zip); extráelos a `.P-Hslice/mods`.

## Parches manuales (si `apply_overlay.py` avisa que no encontró un ancla)

* **Main.hx** (crítico): cambia `initialState: X` por `initialState: phslice.states.SplashState` y deja en
  `source/phslice/BootTarget.hx` `return new X();`.
* **Options**: en `OptionsState.hx` añade `'P-Hslice'` a la lista y `case 'P-Hslice': openSubState(new phslice.options.PHSliceOptionsSubState());` al `switch(label)`.
* **Modo patata en Gráficos**: añade `public var potatoMode:Bool = false;` a `SaveVariables` y una `Option` con `'potatoMode'`.
* **Eventos pesados**: primera línea de `PlayState.triggerEvent`: `if (phslice.PotatoMode.shouldSkipEvent(eventName)) return;`
* **Carpeta**: que `StorageUtil.getStorageDirectory()` devuelva `phslice.ModPaths.root()`.

## Créditos y licencias

P-Slice (Apache-2.0, mikolka9144 y equipo), Psych Engine (Shadow Mario y equipo), Friday Night Funkin' (The Funkin' Crew),
extension-androidtools (MAJigsaw77). Mantén sus avisos de licencia. Los assets del juego base son de sus autores: uso no comercial.
La llave `phslice.keystore` es pública a propósito (sirve para firmar tus builds); no la uses para publicar en tiendas.

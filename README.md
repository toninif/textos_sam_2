# Valoración afectiva de textos — Set 1

Experimento jsPsych con los 40 textos del Set 1 más 2 controles de atención.
Corre en el navegador. Ahora mismo está en **modo prueba**: no manda nada a
ningún servidor y al final te ofrece descargar el CSV.

## Subirlo a GitHub Pages

1. Creá un repo **público** en GitHub. Nombre corto, por ejemplo `textos-sam`.
2. Subí el contenido de esta carpeta a la **raíz** del repo, no dentro de una
   subcarpeta. Tiene que quedar así:

       index.html
       estimulos.js
       generar_estimulos.R
       g1.html g2.html g3.html g4.html
       .nojekyll
       img/   (11 PNG)
       lib/   (7 archivos: jsPsych y plugins)

3. Settings → Pages → Source: *Deploy from a branch* → Branch `main`,
   carpeta `/ (root)` → Save.
4. Esperá uno o dos minutos y entrá a:

       https://toninif.github.io/textos-sam/?g=1

   (cambiá `textos-sam` por el nombre real del repo)

Si ves la pantalla de consentimiento, está andando. Si ves un recuadro rojo, es la
trampa de errores: pegame el mensaje.

## Los dos interruptores

Arriba del `<script>` en `index.html`:

    const DATAPIPE_ID = "CAMBIAR_POR_TU_ID";   // modo prueba mientras diga esto
    const MOSTRAR_SOLO_ID = true;              // true = muestra el id del estimulo

- `MOSTRAR_SOLO_ID = true` muestra `NEU_00101` en lugar del texto. Sirve para
  pilotear flujo y layout sin leer 40 textos. Los controles de atención se
  muestran siempre completos, porque si no no se entienden.
- `MOSTRAR_SOLO_ID = false` muestra los textos reales. Ponelo en false antes de
  recolectar, y usá esa versión para probar en celular: es la única forma de ver si
  un texto de cuatro líneas más las dos filas de muñequitos entran en un teléfono.

## Pasar a producción con OSF

1. OSF → creá el proyecto. Settings → Personal Access Tokens → generá un token.
2. `pipe.jspsych.org` → creá cuenta → Account/Settings → pegá el token.
3. *Create New Experiment* apuntando a tu proyecto. Habilitá la recolección.
4. Copiá el experiment ID y pegalo en `DATAPIPE_ID`.
5. Commiteá, esperá el redeploy, probá el link y confirmá que el CSV llegue a OSF.
6. **Cuando termines de recolectar, deshabilitá la recolección en DataPipe.**

## Links por grupo

Un solo repo, un solo `index.html`. El grupo se define por la puerta de entrada:

    https://toninif.github.io/textos-sam/g1.html
    https://toninif.github.io/textos-sam/g2.html
    https://toninif.github.io/textos-sam/g3.html
    https://toninif.github.io/textos-sam/g4.html

Cada `gN.html` redirige a `index.html?g=N`. Son links sin query string, así que
ningún cliente de mail ni WhatsApp los puede truncar. Repartí estos, no los que
llevan `?g=`.

Si falta el `?g=` o es inválido, el experimento **no arranca** y muestra un aviso.
Eso es a propósito: un default silencioso mandaría gente del set 3 a la lista del
set 1 sin que nadie se entere.

`?g=2`, `?g=3` y `?g=4` todavía no tienen estímulos. Corré `generar_estimulos.R`
con los 160 textos y los cuatro quedan andando sobre el mismo deploy.

## Datos

Una fila por pantalla. Las de la tarea (`tarea == "sam"`) traen `id_texto`,
`cuadrante`, `es_control`, `valencia`, `activacion`, `orden` (posición real de
presentación) y `rt`.

    library(dplyr)
    d <- purrr::map_dfr(list.files("datos", full.names = TRUE), readr::read_csv)

    sam <- d |> filter(tarea == "sam", is.na(es_control)) |>
      select(sujeto, set, id_texto, cuadrante, valencia, activacion, orden, rt)

    controles <- d |> filter(tarea == "sam", es_control)

Dejá preregistrada la regla de exclusión antes de recolectar: CHECK_01 espera 1 en
valencia y 9 en activación, CHECK_02 espera 5 en las dos.

## Pendientes antes de recolectar

- Reemplazar el consentimiento por el texto aprobado por el comité.
- Verificar los 20 adjetivos del PANAS contra la adaptación argentina.
- `MOSTRAR_SOLO_ID = false`.
- Piloto en celular con los textos reales.


## Carga: 200 participantes simultáneos

- **GitHub Pages** sirve archivos estáticos. 200 personas a la vez no es carga.
  El peso por participante es ~250 KB (librerías + imágenes), y después queda cacheado.
- **Las librerías están en `lib/`**, no en un CDN. Si unpkg se cae o la red del aula
  lo bloquea, el experimento igual arranca. No cambies esto por URLs de CDN.
- **El guardado reintenta 3 veces** con espera creciente (2s, 4s, 6s). Si aun así
  falla, la última pantalla ofrece descargar un `RESPALDO_*.csv` con instrucciones
  de mandarlo por mail. Ningún participante pierde su trabajo por un error de red.

Antes de una toma grupal grande, probá el link desde la red del aula, con un celular
conectado a esa wifi. El cuello de botella más probable no es el servidor: es la wifi.

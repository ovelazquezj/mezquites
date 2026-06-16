# Contenidos de "Aprender" (app del voluntario) — CR-007

> ⚠️ **BORRADOR** — todo el contenido de esta carpeta es **borrador sujeto a revisión de la
> universidad/expertos del consorcio (AU2/H4)**. **No es asesoría técnica.** El consorcio aprueba el
> texto final.

Cada `mod_*.md` es la **fuente única** del cuerpo de un módulo de la sección *Aprender*. La app del
voluntario los **bundlea** como assets (`mobile/assets/learning/<id>.md`) y los renderiza con
`flutter_markdown`. En la integración, el orquestador **copia `docs/learning/*.md` →
`mobile/assets/learning/`** (verbatim) para no duplicar la fuente.

El **stamp de "borrador"** lo pinta la **UI** (banner fijo en `learning_detail_screen.dart`), por eso
los `.md` ya **no** repiten esa línea (evita el aviso duplicado en pantalla).

## Módulos

| id (= asset) | Título | Foco |
|---|---|---|
| `mod_que_es` | ¿Qué es el mezquite? | ecología y usos de *Prosopis laevigata* |
| `mod_paxtle` | Reconocer el paxtle (heno motita) | *Tillandsia recurvata* — epífita, **no** parásita |
| `mod_cuscuta` | Reconocer la cúscuta | *Cuscuta* spp. — **sí** parásita |
| `mod_escala` | La escala de observación | niveles sano/leve/moderado/severo (autodeclarado, gate #8) |
| `mod_buena_foto` | Una buena foto | encuadre/luz/distancia, cámara nativa (gate #4) |
| `mod_ciencia_ciudadana` | ¿Por qué participar? | dataset abierto, modelo eBird/Naturalista |
| `mod_que_no_hace` | Qué hace y qué NO hace la app | límites del proyecto (gate #1) |

Gates respetados por el contenido: **#1** (no promete control/erradicación ni recetas), **#8** (especie
y nivel autodeclarados, "a ojo"), **#3** (todos los módulos siempre abiertos). Enlaces "Saber más"
curados hacia identificación/ecología/ciencia ciudadana (no a páginas de "cómo eliminar").

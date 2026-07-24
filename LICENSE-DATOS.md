# Licencia de los datos — CC BY 4.0

El **código** de este repositorio se licencia bajo **MIT** (ver [`LICENSE`](LICENSE)).
Este documento cubre algo distinto: el **dato ecológico** generado por el piloto de ciencia
ciudadana del mezquite.

## Licencia

El conjunto de datos de observaciones se publica bajo
**[Creative Commons Atribución 4.0 Internacional (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.es)**.

Eres libre de **copiar, redistribuir, transformar y construir** sobre el material, incluso con fines
comerciales, siempre que des **atribución**.

## Cómo citar

> Club Rotario Bosques Aguascalientes — *Rescatando el Mezquite: observaciones de ciencia ciudadana
> de* Prosopis laevigata *y sus parásitos visibles*. Aguascalientes, México. CC BY 4.0.
> <https://app.rescatando-el-mezquite.org>

Si tu uso se apoya en observaciones concretas, acredita también a las personas observadoras: cada
registro incluye el **`handle`** de quien lo capturó, que es su forma de crédito en el proyecto.

## Qué cubre exactamente

Cubre el **dataset de observaciones** que sirve la API pública (`GET /public/observations`,
`GET /public/grid`, `GET /public/indicators`), con estos campos por observación:

| Campo | Qué es |
|---|---|
| `handle` | Seudónimo de la persona observadora (atribución; no es dato personal) |
| `lat`, `lon` | Ubicación del árbol |
| `nivel_g4` | Nivel de afectación **autodeclarado** (`sano`/`leve`/`moderado`/`severo`) |
| `flag_cuscuta`, `flag_danio` | Presencia **autodeclarada** de cúscuta / daño visible |
| `estado`, `municipio` | Ubicación administrativa |
| `captured_at` | Fecha y hora de captura |
| `snapshot_quarter` | Trimestre del corte al que pertenece la vista |

## Qué NO cubre

- **El código** del repositorio → MIT ([`LICENSE`](LICENSE)).
- **Las fotografías** de las observaciones. No forman parte del dataset abierto ni se sirven
  públicamente: quedan en el ámbito de revisión interna.
- **La identidad gráfica** (logotipos, emblema, nombre del Club Rotario Bosques Aguascalientes). Son
  marcas de su titular y **no** se licencian bajo CC BY.
- **Los datos personales**. No los hay en el dataset: la persona voluntaria participa con un
  seudónimo y el sistema no almacena su nombre ni su correo (ver
  [`docs/legal/aviso-privacidad.md`](docs/legal/aviso-privacidad.md)).

## Advertencia sobre el origen del dato (léela antes de usarlo)

> **Datos de origen ciudadano, sin validación por expertos; especie y nivel autodeclarados.**

Esta advertencia acompaña a los indicadores que devuelve la API y es parte inseparable del dato:

- La **especie** y el **nivel de afectación** los declara la persona voluntaria a ojo, sin
  instrumentos ni capacitación obligatoria. **No** son determinaciones taxonómicas ni diagnósticos
  fitosanitarios.
- La revisión humana del equipo verifica **calidad de la evidencia** (que la foto corresponda a un
  árbol observable), no la identificación de la especie ni la severidad.
- El dataset publica las observaciones **no rechazadas**. Ausencia de rechazo no equivale a
  validación científica.
- El muestreo **no es probabilístico**: refleja dónde hay voluntarios activos, no la distribución
  real de la especie ni de sus parásitos.

Si vas a usar estos datos en investigación, trátalos como **evidencia de presencia de origen
ciudadano** y no como un inventario validado.

## Ubicación de los árboles

Las vistas públicas muestran la ubicación registrada de cada árbol. Es una decisión de gobernanza
del Club Rotario Bosques Aguascalientes, documentada en
[`docs/change-requests/CR-025-ubicacion-exacta-publica.md`](docs/change-requests/CR-025-ubicacion-exacta-publica.md).

## Contacto

<contacto@rescatando-el-mezquite.org>

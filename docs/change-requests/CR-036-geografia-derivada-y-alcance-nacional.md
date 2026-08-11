# CR-036 — El dato geográfico deja de ser una promesa del cliente

**Fecha:** 2026-08-10 · **Origen:** hallazgo del usuario (*"por vez primera se han detectado registros
fuera del estado de Aguascalientes"*) + diagnóstico en producción · **Estado:** APROBADO por el
usuario (2026-08-10), en construcción. Backend + app del voluntario + consola; **con migración
(0009)** y **backfill de datos históricos**.

---

## 1. El problema, con evidencia de producción

Medido en la VM el **2026-08-10** (solo consultas de lectura):

| Dato | Valor |
|---|---|
| Observaciones totales | **2 185** (eran 421 el 2026-08-01) |
| Cuentas con capturas | 58 · ritmo de agosto: **78–374 obs/día** |
| Revisión | 1 330 confirmadas · 488 aceptadas · 367 rechazadas |
| `estado` declarado | **`'Aguascalientes'` en las 2 185, sin una sola excepción** |
| `municipio` declarado | 4 valores: Aguascalientes (1785), Jesús María (339), Calvillo (39), Pabellón de Arteaga (22) |
| `admin_boundary` | **0 filas** |

**Los registros fuera del estado son 39.** Están al **oeste de −102.867**, que es el punto más
occidental de Aguascalientes (102°52′W): están fuera de la línea estatal **con certeza lógica**, no
por aproximación de una caja envolvente. Cluster en 21.627–21.647 N / −102.970 a −102.979 W — cae en
**Zacatecas, zona de Jalpa** (la atribución exacta es justamente lo que este CR habilita).

- Capturadas del **2026-08-06 al 08-08** por **una sola cuenta** (`obs-HZXNRC`, Global University),
  en 21 puntos distintos.
- **Las 39 están etiquetadas "Calvillo, Aguascalientes"** en la base y en todos los dashboards.
- 19 ya fueron **confirmadas** por la consola. Se revisaron las notas de los 20 rechazos: son de
  **calidad de foto** (`"solo tronco"` ×15, `"borrosa"` ×2). **Ninguno por geografía.** El error de
  etiqueta **pasó la revisión humana sin que nadie pudiera verlo**, porque la consola muestra la
  etiqueta, nunca la contrasta con la coordenada.

### La cadena de cuatro eslabones

1. **La app no puede expresar otro estado.** `mobile/lib/src/models/municipios.dart:20` →
   `kEstados = [kEstadoDefault]`: el dropdown de estado tiene **exactamente una opción**.
2. **La app etiqueta mal en silencio.** `municipioMasCercano()` (`municipios.dart:58-78`) elige el
   más cercano de 11 centroides hardcodeados por distancia euclidiana **sin techo de distancia**, y
   nunca devuelve `null` mientras el estado sea Aguascalientes. Una captura en Zacatecas recibe
   "Calvillo" automáticamente.
3. **El backend le cree al cliente.** `routers/observations.py:88-93`: si el cliente manda
   `estado`/`municipio`, se guardan tal cual — `Text` libre, **sin CHECK, sin FK, sin catálogo**
   (`models.py:222-223`).
4. **El respaldo autoritativo está muerto.** `geo.derive_estado_municipio()` (`geo.py:103-125`) hace
   `ST_Contains` contra `admin_boundary`, que tiene 0 filas: siempre devuelve `(None, None)`. Nunca
   se ejecuta porque el eslabón 3 gana.

---

## 2. Esto NO enmienda ningún gate: es cumplimiento de Q8

**Q8-D1** de la bitácora (`bitacora_sdd_mezquite.md:361-375`) ya dice, sellado:

> *"el sistema soporta cualquier estado desde el día uno […] los estados son **filtros
> geográficos** […] Toda observación es atribuible a estado y municipio **por geolocalización**"*

Y `TRACEABILITY.md:36` lleva ese criterio en **🟡 desde el Incremento 2**: *"lógica ✅; carga de
límites = dato operativo"*. Las 39 observaciones son esa deuda venciendo.

**Ninguno de los 10 gates innegociables se enmienda.** Verificado además: los textos legales
(`docs/legal/*`, `infra/compose/legal/*`) nombran Aguascalientes **solo** como nombre y domicilio del
Club responsable, nunca como límite territorial del piloto ⇒ **no requiere re-aprobación del Club**.

**Decisión de gobernanza del usuario (2026-08-10):** los registros fuera de Aguascalientes **cuentan
como participación válida** — puntos, insignias, mapa público e indicadores, sin segregación. El
piloto asume **alcance nacional**.

---

## 3. Restricción de diseño dura

**El teléfono no decide en qué estado está un árbol.** El servidor re-deriva la geografía al recibir
el POST, siempre, ignorando cualquier valor que mande el cliente. De ahí se sigue el corolario que
define la UX: **un campo cuyo valor nunca se usa debe desaparecer**, no quedarse por costumbre. Por
eso la captura pierde los dos dropdowns en vez de "mejorarlos".

Segunda restricción, heredada de **CR-031**: nada de esto puede exigir red en el momento de la
captura. Sin señal se captura igual y el servidor resuelve al recibir.

---

## 4. Decisiones tomadas (usuario, 2026-08-10)

| # | Decisión | Consecuencia |
|---|---|---|
| **D1** | Fuente de verdad = **backend**, consumido por API | `/geo/resolve` contra PostGIS propio |
| **D2** | Los límites los descarga y prepara el agente | Marco Geoestadístico **INEGI nacional** |
| **D3** | **Backfill** del histórico | Las 2 185 filas se re-derivan desde `geom` |
| **D4** | Los registros fuera del estado **cuentan** | Alcance nacional, sin segregación |
| **D5** | **Entrega única**, sin hotfix parcial previo | El parche de contención se cancela: el backfill corrige igual lo que se capture mientras tanto |
| **D6** | **Se eliminan los dropdowns** de la captura | Cero selecciones geográficas para el voluntario |
| **D7** | Etiqueta: **nombre del lugar + coordenadas en pequeño** con red; **solo coordenadas** sin red | Cero taps en ambos casos |
| **D8** | **Sí** se captura la precisión del GPS | Única señal de calidad al quitar al humano del circuito |
| **D9** | Edición de estado/municipio en la consola → **deuda**, fuera de este CR | Ver §9 |
| **D10** | Filtros estado + municipio en **Panel público** y en **Datos y descargas** | Incluye las dos descargas |

### Por qué el API es nuestro y no un geocodificador externo

| Motivo | Por qué descarta Nominatim / Google / servicios web |
|---|---|
| **Gate #6 (paridad de entornos)** | dev y QA corren **sin nube**. Una dependencia de red externa rompe el gate y la suite del backend |
| **CR-031 (captura sin conexión)** | En campo no hay señal; con PostGIS local el servidor resuelve al recibir |
| **Backfill (D3)** | Miles de llamadas externas, con rate limits y resultado no reproducible. En local es una consulta SQL |
| **Privacidad** | Mandaría la coordenada exacta de cada mezquite a un tercero. CR-025 hizo pública la ubicación; eso no es lo mismo que crear un flujo de datos hacia Google |
| **Costo y SLA** | La política de uso de Nominatim no admite este volumen; Google cobra por llamada |

---

## 5. Diseño

### 5.1 Límites (Fase 0, local)

Marco Geoestadístico **INEGI** con cobertura **nacional** (32 entidades, ~2 477 municipios; la cifra
exacta se verifica al preparar el dataset). Preparación **local** con Python puro (`shapely` +
`psycopg`) contra un PostGIS en contenedor — la máquina de desarrollo **no tiene GDAL/ogr2ogr**, y la
VM (2 vCPU / 3.8 GB) no es lugar para procesar geometría nacional, igual que no compila Flutter.

**Precisión antes que tamaño, y medido en vez de supuesto.** El plan preveía `ST_Subdivide` para
acelerar el punto-en-polígono. **Al medirlo resultó innecesario:** con los 2 478 municipios cargados
sin simplificar y el índice GiST sobre `geography`, los puntos de control resuelven en **1.7–11.4 ms**
(el máximo es la consulta en frío). La tabla ocupa **62 MB** y lleva la base de preparación a 81 MB;
en producción pasaría de 24 MB a ~86 MB, sobre **148 GB libres**. No hay ninguna razón para degradar
la geometría: **los límites se cargan a resolución original**, que es justo lo que protege la línea
Aguascalientes/Zacatecas.

**La consulta usa `ST_Intersects` sobre `geography`, no `ST_Contains` sobre `geom::geometry`.** El
`derive_estado_municipio` original casteaba a `geometry` dentro del `WHERE`, lo que **impide usar el
índice GiST**: con la tabla vacía daba igual, pero con 2 478 polígonos sería un escaneo secuencial
con un test caro por fila. Se corrige en este CR. El desempate cuando un punto cae exactamente sobre
una frontera es determinista (`ORDER BY cve_ent, cve_mun`), no arbitrario.

**Atribución:** los datos de INEGI son de libre uso citando la fuente. La atribución se agrega a
`LICENSE-DATOS.md` y al `CAVEAT` público.

### 5.2 Backend

- **Precedencia invertida** en `routers/observations.py`: el servidor deriva siempre; lo que mande el
  cliente se descarta. Los bundles PWA viejos en caché seguirán enviando "Aguascalientes"/"Calvillo"
  y **se corregirán solos con desplegar el backend**, sin esperar a que el usuario actualice la app
  (misma propiedad aprovechada en CR-030).
- **Degradación amable:** un punto que no cae en ningún polígono se guarda con estado/municipio
  `NULL` y sin claves. No se inventa etiqueta ni se rechaza la observación (gate #3).
- **Migración 0009:** `cve_ent`/`cve_mun` en `observation` y en `admin_boundary`; `gps_accuracy_m` en
  `observation`; índices.
- **Agrupar por clave, no por cadena.** Es lo que evita que un acento o un homónimo parta o funda
  categorías: **"Jesús María" existe en Aguascalientes, en Jalisco y en Nayarit**, y hoy los tres
  caerían en el mismo cubo de `summary.por_municipio`. Los nombres se siguen aceptando como filtro por
  compatibilidad; la consola usa claves.
- **API nueva:** `GET /geo/resolve?lat&lon`, `GET /geo/estados`, `GET /geo/municipios`.
- **Filtros públicos:** `municipio` se añade a `/public/observations`, `/public/indicators` y
  `/public/grid`, y a `indicators.py` (`_estado_clause`, hoy solo estado).
- **Escala:** el binning de `/public/grid` pasa de Python a SQL y **pierde el tope de 5 000**. Con
  2 185 filas y +78–374/día, ese tope se rebasa en ~3 semanas y el mapa empezaría a **truncar en
  silencio**. Deuda anotada en CR-034 que este CR liquida.

### 5.3 App del voluntario

- **Se eliminan los dos dropdowns** y el archivo `municipios.dart` completo.
- `ObservationDraft` (`models.dart:106-126`) ya tiene `estado`/`municipio` **nullable** con el
  comentario *"el backend los deriva como respaldo"*: **no hay cambio de modelo, solo se dejan de
  llenar**.
- **Etiqueta informativa** (cero taps):

  | Situación | Qué ve el voluntario |
  |---|---|
  | Con red | **Jalpa, Zacatecas** · `21.6453, −102.9731` en pequeño |
  | Sin red (CR-031) | `21.6453, −102.9731` · *"La ubicación se determinará al enviar"* |
  | Fuera de cobertura | coordenadas + *"Ubicación fuera del área con límites cargados"* |

- **Precisión del GPS (D8):** hoy la app **pide** `LocationAccuracy.best`
  (`capture_service_native.dart:42`, `capture_service_web.dart:54`) pero **nunca guarda ni envía el
  valor**. Ahora se captura y viaja en el submit. Al quitar los dropdowns ya no queda ningún humano
  que pueda notar un fix malo cerca de un límite estatal: la precisión es la única señal de calidad
  que queda, y el dispositivo ya la calcula.

### 5.4 Consola

| Pantalla | Cambio |
|---|---|
| **Panel público** | Filtros **estado + municipio** (dropdowns dependientes, desde `/geo/*`). Hoy el estado es un `TextField` libre y el municipio no existe |
| **Datos y descargas** | Filtros **estado + municipio**; **las dos descargas heredan los filtros activos**. Hoy no hay filtro de estado y el municipio es texto libre. Además el cliente **ni siquiera manda `estado`** (`api_client.dart:479-497`), pese a que el backend lo acepta desde CR-010 |
| **Datos** | Tarjeta de resumen **por estado** junto a la de municipio |
| **Mapa** | Encuadre por **`fitBounds` sobre los datos** en vez del centro fijo (`map_screen.dart:13-14`), con Aguascalientes como fallback si no hay datos; filtro por estado |
| **Revisión** | Filtro geográfico en la cola (el backend ya lo soporta; la UI no lo usaba — por eso nadie vio las 39) |
| **Monitor** | Desglose por estado |

**Advertencia honesta sobre `participacion.csv`:** una sesión de participación **no tiene geografía
propia** — la ubicación vive en las observaciones, y ese CSV usa un `FULL OUTER JOIN` justamente para
no perder los días de solo-sesión (CR-026). Al filtrar por estado, esos días **no se pueden atribuir a
ningún estado**. Se filtra solo el lado de observaciones y **se declara explícitamente en la pantalla
y en el encabezado del CSV**, en vez de inventar una atribución geográfica para las sesiones.

---

## 6. Criterios de aceptación

### Backend — verdad geográfica

| # | Criterio |
|---|---|
| **AC1** | `admin_boundary` cargada con cobertura nacional; conteo real de entidades y municipios reportado |
| **AC2** | El servidor deriva de las coordenadas **ignorando al cliente**: un POST con `estado="Yucatán"` y coordenadas de Aguascalientes se guarda como Aguascalientes |
| **AC3** | Punto fuera de todo polígono ⇒ estado/municipio `NULL`, sin claves, **sin inventar etiqueta y sin rechazar la observación** (gate #3) |
| **AC4** | `cve_ent`/`cve_mun` se persisten y son la clave de agrupación en los dashboards |
| **AC5** | Las 21 coordenadas reales del cluster resuelven a **Zacatecas** |

### Backend — API y filtros

| # | Criterio |
|---|---|
| **AC6** | `GET /geo/resolve?lat&lon` devuelve estado, municipio, claves y `resuelto` |
| **AC7** | `GET /geo/estados` y `GET /geo/municipios` devuelven el catálogo desde `admin_boundary` |
| **AC8** | `/public/observations`, `/public/indicators` y `/public/grid` aceptan `municipio` además de `estado` |
| **AC9** | `summary` devuelve `por_estado` y un `por_municipio` **desambiguado por estado** |
| **AC10** | Las 4 rutas de `/admin/analytics` filtran por estado y municipio |
| **AC11** | `participation.csv` filtra por estado/municipio en el lado de observaciones y **lo declara en el encabezado** |
| **AC12** | `/public/grid` agrega en SQL **sin tope de 5 000** (prueba con más de 5 000 filas) |

### App del voluntario

| # | Criterio |
|---|---|
| **AC13** | La pantalla de captura **no tiene** dropdown de estado ni de municipio; el draft no los llena |
| **AC14** | Con red: nombre del lugar + coordenadas en pequeño |
| **AC15** | Sin red: solo coordenadas + *"se determinará al enviar"*; **la captura offline sigue intacta** (CR-031) |
| **AC16** | La precisión del GPS se captura y viaja en el submit |
| **AC17** | `municipios.dart` eliminado; ninguna pantalla depende de un catálogo local |

### Consola

| # | Criterio |
|---|---|
| **AC18** | Panel público: filtros estado + municipio (dropdowns dependientes) |
| **AC19** | Datos: filtros estado + municipio |
| **AC20** | **Las dos descargas heredan los filtros activos** |
| **AC21** | Tarjeta de resumen por estado en Datos |
| **AC22** | El mapa encuadra por datos, con fallback a Aguascalientes cuando no hay datos |
| **AC23** | Filtro geográfico en la cola de Revisión; desglose por estado en Monitor |

### Datos históricos y documentación

| # | Criterio |
|---|---|
| **AC24** | Backfill re-deriva las 2 185 filas; **el total no cambia** (re-etiqueta, no borra) |
| **AC25** | `TRACEABILITY.md` Q8 pasa de 🟡 a ✅; bitácora anotada como **cumplimiento**, no enmienda |

---

## 7. Plan de despliegue

Infra verificada el 2026-08-10: **23 GB libres** en raíz, **148 GB** en el Cloud Volume, **2.9 GB de
RAM disponible**, **PostgreSQL 16.4 / PostGIS 3.4.3**, base de **24 MB**.

| Fase | Qué | Verificación / riesgo |
|---|---|---|
| **0. Local** | Preparar el dataset INEGI; construir backend y los dos bundles; correr las suites | Prueba de aceptación del dataset (AC5) **antes** de que salga de la máquina |
| **1. Respaldo** | `pg_dump` completo + respaldo de backend y de los dos `build/web` | Verificar que el `.gz` abre |
| **2. Esquema** | Migración 0009, aplicada por el `CMD` del contenedor | `alembic current` = 0009 |
| **3. Límites** | `scp` del dump (~20–40 MB) → restore. **La conversión nunca corre en la VM** | `/geo/resolve` sobre el cluster **antes** de tocar el backend |
| **4. Backend** | `up -d --build api` **con `--env-file .env.prod`**, desde `/opt/mezquite/infra/compose/` | Sin el `--env-file` se repite el incidente de CR-034 |
| **5. Backfill** | 🛑 **STOP-GATE** — simulacro en transacción revertida; se reporta cuántas filas cambian y qué se mueve a dónde; **no se escribe hasta el visto bueno del usuario**. Guarda transaccional que aborta si el número no cuadra | Ver §8 |
| **6. Bundles** | Se resuben **los dos**. `rsync -a --delete` **en el lugar** (un `mv` rompe el bind-mount de Caddy) + `restart caddy` | Client ID recuperado del bundle anterior |
| **7. Verificación** | Alembic 0009 · conteo de límites · `GROUP BY estado` debe dar **≥2 filas** (hoy da 1) · endpoints nuevos en el OpenAPI · 401 sin token · hash servido == VM == build local **pedido desde la VM** con `curl --resolve` · `/healthz` 200 en ambos dominios · conteo de confirmadas **cuadra exacto** | Rollback por fase |

### Rollback

| Fase | Vuelta atrás |
|---|---|
| 2 | `alembic downgrade 0008` |
| 3 | `TRUNCATE admin_boundary` ⇒ el sistema vuelve a la conducta de hoy |
| 4 | restaurar la carpeta `.bak-cr036-*` + rebuild |
| 5 | restore del `pg_dump` de la Fase 1 |
| 6 | `rsync` desde los respaldos `build/web.bak-cr036-*` |

### Trampas conocidas que se aplican

- **Todo `docker compose` lleva `--env-file .env.prod`** y se corre desde
  `/opt/mezquite/infra/compose/` (incidente CR-034).
- `rsync -a --delete` **en el lugar**; nunca `mv` (bind-mount de Caddy).
- Verificar hashes **desde la propia VM** con `curl --resolve`: bajar el `main.dart.js` desde la
  máquina de desarrollo **se trunca** (CR-030).
- Es `/healthz`, **no** `/api/v1/healthz`.
- Rama `deploy`: recuperar el bundle no tocado con `git checkout <commit> -- <app>/build/web`, y **no
  subir esa copia a la VM** (se escribe con CRLF).
- `flutter test --concurrency=2`; `pytest` del backend necesita el `PYTHONPATH` con
  `contract/python`.

---

## 7-bis. Ensayo del backfill — medido en la Fase 0, sin tocar producción

En vez de esperar al STOP-gate de la Fase 5, el ensayo se corrió **antes de desplegar nada**: se
exportaron por lectura las coordenadas de producción y se resolvieron contra los límites ya cargados
en la base local. **Cero escrituras en producción.**

Sobre **2 342 observaciones** (el dataset creció durante la propia sesión — el piloto está vivo):

| Resultado | Filas | % |
|---|---|---|
| **Sin resolver** (fuera de todo polígono) | **0** | 0 % |
| Se quedan igual | 2 107 | 90.0 % |
| **Cambian** | **235** | **10.0 %** |

Desglose completo de los cambios — son exactamente dos transiciones, ninguna otra:

| Antes (etiqueta de la app) | Después (límite real) | Filas | de ellas confirmadas |
|---|---|---|---|
| Aguascalientes / **Jesús María** | Aguascalientes / **Aguascalientes** | **196** | 144 |
| Aguascalientes / **Calvillo** | **Zacatecas / Jalpa** | **39** | 19 |

**El hallazgo grande no eran las 39.** El error de "centroide más cercano" venía mordiendo mucho más
adentro: **196 observaciones del municipio de Aguascalientes estaban contadas como Jesús María**, más
de cinco veces el cluster que disparó este CR. Con 339 filas etiquetadas "Jesús María" hoy, **el 58 %
de ese municipio en los dashboards no le corresponde**. Nadie lo habría notado nunca: a diferencia de
las 39, estas caen dentro del estado y suenan plausibles.

Distribución final por estado: **Aguascalientes 2 303 · Zacatecas 39**.

Que **0 filas queden sin resolver** confirma además que la degradación amable (AC3) es una
salvaguarda, no un caso frecuente: hoy no aplica a ninguna observación real.

---

## 8. Riesgos y lo visible el día del despliegue

- **El backfill no toca solo las 39: son 235** (ver §7-bis). El grueso son 196 relabelados dentro de
  Aguascalientes. El simulacro de la Fase 5 se repite igualmente contra la base real antes de
  escribir, como guarda contra desviaciones entre el ensayo y el momento del despliegue.
- **El mapa público muestra Zacatecas.** 19 registros confirmados aparecen con su estado real. Es el
  objetivo, pero conviene que la consola y el Club lo sepan antes, no después.
- **La app deja de preguntar la ubicación.** Los voluntarios verán un campo menos, no uno nuevo.
- `human_review` **no se toca**: `estado`/`municipio` es metadato derivado, no historia de revisión.
  **Gate #7 (log append-only) intacto.**

---

## 9. Deuda anotada

- **Edición de estado/municipio desde la consola (D9).** Al quitarle la corrección al voluntario, el
  caso raro de deriva de GPS cerca de un límite queda sin arreglo desde la UI: hoy exigiría entrar a
  la base. Candidato natural a un CR posterior, con el patrón del "Editar" de instituciones (CR-029).
- **Marca de baja precisión.** Se captura `gps_accuracy_m` (AC16) pero este CR **no** construye el
  aviso en la consola para observaciones con precisión mala cerca de un límite. El dato queda listo
  para cuando se decida.
- **Actualización de los límites INEGI.** La carga es un artefacto preparado a mano; no hay
  automatismo para cuando INEGI publique una versión nueva del marco.
- **Revocación de tokens (CR-027)** sigue abierta, ajena a este CR.

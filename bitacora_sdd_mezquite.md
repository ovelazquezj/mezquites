# Bitácora SDD — Proyecto de Ciencia Ciudadana del Mezquite

> **Destinatario:** agente Claude Code que especificará y desarrollará el **software** (app móvil +
> backend) mediante un equipo de subagentes.
> **Alcance:** esta bitácora es el brief del **software**. El **Protocolo de ciencia ciudadana** y el
> **Documento de presentación** son entregables **separados** (archivos aparte). El backend se integra
> con un **sistema externo de validación de imágenes** mediante el contrato de la §6.
> **Naturaleza:** brief ejecutable. Es la fuente de verdad. Las decisiones aquí selladas
> **no se reabren**; lo que falta está marcado como *decisión humana pendiente* o *dato por verificar*.

---

## 0. Marco del proyecto

- **Qué es:** piloto de ciencia ciudadana de **24 meses**, impulsado por un club rotario desde
  **Aguascalientes**, con vocación de escalamiento nacional. Tres etapas: concientización →
  capacitación → combate.
- **Qué NO es:** no es un proyecto académico. Su objetivo es **generar conciencia**; como valor
  agregado produce **datasets de acceso abierto** que terceros pueden usar para investigación,
  con **preproceso** y bajo **caveat explícito de origen ciudadano** (no validados por expertos).
- **Sujeto biológico:** *Prosopis laevigata* (mezquite) y sus parásitos visibles, con foco en
  *Tillandsia recurvata* (paxtle) y observación exploratoria de *Cuscuta* spp.
- **Plataforma de referencia (benchmark):** **eBird** — participación voluntaria consciente, sin
  certificación, sin gating por tier, registro abierto, dataset público con controles razonables.

### 0.1 Estatus de la evidencia

Se trabaja con la evidencia disponible (incluidas tesis y documentos técnicos 2011–2021),
etiquetando su grado de soporte. Etiquetas usadas en toda la bitácora:
`[evidencia disponible]` / `[supuesto del autor]` / `[sin soporte]`.

- *T. recurvata* como parásita estructural (anatomía, flujo de agua, fotosíntesis):
  `[evidencia disponible]` — `pereznoyola2015` (IPICYT).
- 44.91% de infestación por *T. recurvata*: `[evidencia disponible]` — `hernandezortiz2021`
  (Chapingo, Querétaro). **Referencia indicativa de región ecológicamente cercana; NO es línea
  base de Aguascalientes ni cifra generalizable.**
- *Cuscuta* spp. sobre mezquite en Aguascalientes/Bajío: `[sin soporte]`. Hipótesis a verificar en
  campo, no problema documentado localmente.

### 0.2 Alcance y entregables

**Esta bitácora = el software**, en dos clientes + backend:
- **App móvil del voluntario** + **web app de administración del consorcio** + **backend compartido**.
- El backend **se integra con un sistema externo de validación de imágenes** (ver contrato en §6).

**Entregables separados (archivos aparte, NO esta bitácora):**
- **Protocolo de ciencia ciudadana** (`protocolo_ciencia_ciudadana_mezquite.md`): el método — qué se
  observa y captura, escala de infestación, validación, roles, indicadores, salvaguardas,
  escalamiento. Esta bitácora marca con **"Protocolo."** las implicaciones que alimentan ese
  documento.
- **Documento de presentación** (`documento_presentacion_mezquite.md`): artefacto de concientización
  para el club Rotario, reutilizable ante instituciones y autoridades.

**Fuera del alcance de esta bitácora:**
- **Sistema de validación de imágenes (YOLO):** se especifica y construye en una **bitácora separada**
  (`bitacora_srs_c_yolo.md`), con agente y equipo propios, de forma interactiva humano-Claude. Aquí
  solo vive el **contrato de integración** (§6), que también está espejado en esa bitácora.

---

## 1. Decisiones estratégicas selladas

### Q1-D1 — Hipótesis de cambio
- **Decisión.** Programa de 24 meses en Aguascalientes, anclado en preparatorias y universidades,
  con **capacitación como motor principal** y **concientización como puerta de entrada**, que forma
  juventudes cuyas **observaciones georreferenciadas son evidencia transferible** que, vía
  **articulación institucional directa** (club rotario + aliados académicos), alimenta a autoridades
  y actores técnicos para que **coordinen —no ejecute el piloto—** intervenciones priorizadas.
- **Soporte:** `[supuesto del autor]`.
- **Boundary (el piloto NO promete):** (a) reducción de infestación medible; (b) control
  fitosanitario directo ejecutado por la app, voluntarios o el club; (c) recomendaciones de manejo
  químico/mecánico expedidas por la app sin validación técnica; (d) intervención sobre árboles en
  propiedad privada sin consentimiento del propietario.
- **Protocolo.** Alcance limitado a observación, capacitación y handoff técnico. Ninguna sección
  especifica intervención fitosanitaria directa.
- **Software.** Capacitación dominante: Aprendizaje y Detección son módulos pesados; la gamificación
  premia capacitación y calidad, no solo volumen.
- **Gate de aceptación (global).** Cualquier sección de cualquier SRS que prometa control
  fitosanitario directo, reducción medible de infestación o emisión autónoma de recomendaciones
  químicas/mecánicas debe ser **rechazada y devuelta para corrección**.

### Q5.A-D1 — Cadena de validación de datos
- **Decisión.**
  - Validación = **sistema externo de validación de imágenes (YOLO)**, en backend, **asíncrona y
    transparente al usuario**. El detalle del intercambio está en el **contrato de la §6**.
  - **Alcance de la validación automática:** el sistema verifica dos hechos binarios:
    **(1) es un árbol** y **(2) hay presencia de parásitos**. **NO valida especie** (que sea
    mezquite) ni el grado de infestación G4.
  - **Dos resultados posibles:**
    - **Imagen VÁLIDA** (es árbol **y** hay presencia de parásitos): se **etiqueta como válida**,
      entra al dataset y **genera puntos** (recompensa diferida).
    - **Imagen NO VÁLIDA** (no es árbol, o sin presencia de parásitos): se **etiqueta como ruido**,
      va al **dataset paralelo "no validadas"** (registro de auditoría sin uso operativo) y
      **alimenta el feedback agregado** al voluntario, sin acusación individual.
  - **Validación de especie = FUERA DE ALCANCE por ahora.** Que las observaciones sean mezquites
    se asume como **acto de buena fe**. **Riesgo registrado:** un árbol de otra especie con
    parásitos se etiquetaría como válido.
  - **Grado de infestación G4 + flags (cúscuta, daño) = autodeclarados por el voluntario y NO
    validados automáticamente por ahora.** El sistema solo confirma presencia de parásitos, no el
    nivel ordinal.
  - Plausibilidad temporal: **solo cámara nativa con EXIF geoespacial**; sin upload de galería.
  - Plausibilidad geográfica: **cualquier punto del rango natural de *P. laevigata*** (deja abierto
    el escalamiento desde el día uno).
  - Feedback al voluntario: **agregado periódico** ("de tus últimas N observaciones, M válidas"),
    sin acusación individual.
- **Soporte:** `[supuesto del autor]`.
- **Software.** Captura fuerza cámara nativa (galería deshabilitada); inyecta EXIF lat/lon/timestamp;
  fire-and-forget en submit; recibe el resultado de validación por el contrato §6; gamificación con
  recompensa base + diferida (puntos solo si **válida**); etiquetado válida/ruido en backend;
  feedback agregado; sin UI de estado de validación individual.
- **Decisiones diferidas (no implementadas en piloto):** validación automática de especie
  (mezquite); validación automática del nivel G4; auditoría muestral humana.
- **Criterios de aceptación.** El módulo de captura SOLO permite cámara nativa; cada observación
  lleva EXIF del momento de toma; la UI no muestra estado de validación individual; una imagen
  **válida** genera puntos y se etiqueta como tal; una **no válida** se etiqueta como ruido y no
  genera puntos; existe feedback agregado de tasa de validación; el submit no bloquea la UI.

### Q5.A-D2 — Bootstrap del sistema de validación (arranque en frío)
- **Decisión.** El sistema de validación se entrena **fuera de esta bitácora**
  (`bitacora_srs_c_yolo.md`), mediante **YOLO preentrenado + finetuning** sobre el **set de imágenes
  de mezquite e infestación que aporta el autor**. No se requiere una ventana de etiquetado vía app.
- **Integración mientras el sistema real no está listo.** El backend integra por el contrato §6
  contra un **mock** del validador (definido en la bitácora del sistema de validación) que cumple el
  mismo contrato. Hasta tener el sistema real, las observaciones pueden quedar en estado
  **"pendiente"** (sin recompensa diferida) o ser resueltas por el mock para pruebas de integración.
- **Soporte:** `[supuesto del autor]`. Resuelve la dependencia circular (la app produce imágenes /
  el sistema las valida) usando el set preexistente del autor como semilla.
- **Software.** Soporta estado "pendiente"; el cambio de modo (**mock → sistema real**) no requiere
  cambios de cliente, solo que el validador empiece a emitir resultados reales por el contrato §6.

### Q5.B-D1 — Custodia del dataset y handoff técnico
- **Decisión.**
  - **Custodia = híbrida (C4):** dataset vivo en infraestructura del consorcio Rotary + universidad;
    snapshots públicos. Institución concreta = *decisión humana pendiente*.
  - **Acceso = A2 + C2:** vista pública con **coordenadas obfuscadas a grid 1 km × 1 km**; vista
    restringida a **aliados firmantes** con coords exactas.
  - **Destinatarios = todos** (autoridades estatales, CONAFOR regional, universidades, municipios,
    público). Transparencia operacional.
  - **Cadencia = trimestral** (snapshots cada 3 meses).
  - **Formato = dashboards como pieza única.** NO se producen reportes técnicos narrados; los
    datasets quedan abiertos para que terceros produzcan sus análisis.
- **Soporte:** `[supuesto del autor]`.
- **Justificación de la obfuscación (amendment):** la restricción de coords exactas se sostiene por
  **protección del árbol** (tala oportunista, vandalismo), **no por privacidad del voluntario**
  (no se captura PII).
- **Protocolo.** El piloto NO produce reportes narrativos; la articulación viva ocurre vía dashboards +
  mesas formales. Define el acuerdo de uso con aliados firmantes (texto = trabajo posterior).
- **Software.** Módulo Reportes = dashboards (no PDFs/narrativa); toda vista muestra "última
  actualización: Q[N]"; obfuscación a 1 km en backend de publicación; auth por rol "aliado firmante"
  para coords exactas.
- **Criterios de aceptación.** Vista pública solo expone coords redondeadas a 1 km; vista restringida
  exige autenticación de aliado firmante; toda vista muestra fecha de snapshot; la app NO genera PDFs.

### Q5.C-D1 — Producción de contenidos formativos
- **Decisión.**
  - **Autoría = AU2:** universidad aliada + expertos forestales/fitosanitarios externos.
  - **Sin certificación de voluntarios** (alineado a eBird). Ningún tier, gating ni recompensa
    diferencial por completar módulos.
  - B2 (capacitación dominante) se manifiesta por **disponibilidad de contenido y engagement
    voluntario**, no por status acreditado.
- **Soporte:** `[supuesto del autor con benchmark eBird]`.
- **Protocolo.** Sin certificación/examen/acreditación; currículum = recurso abierto opcional; la calidad
  del dato NO depende del status formativo del voluntario.
- **Software.** Aprendizaje ofrece contenidos AU2 y mide engagement sin gatear nada; Gamificación SIN
  multiplicadores por capacitación; sin UI de "certificado"/"tier".
- **Implicación cruzada Q6.** Medir B2 NO usa "tasa de certificación"; se usan indicadores de
  engagement formativo.

### Q5.D-D1 — Ética y menores
- **Decisión.**
  - **Autoridad ética = EA3:** comité mixto Rotary + universidad + asesor externo (incidentes
    operativos, exigencias de borrado, conflictos con propietarios). Nombres = *decisión humana
    pendiente*.
  - **Menores = M1:** registro abierto eBird-style, sin verificación de tutor.
  - **Sin captura de PII.** Cuenta pseudonimizada por handle. **LFPDPPP no aplica.**
  - **Acceso abierto** a datasets con caveat de origen ciudadano.
- **Soporte:** `[supuesto del autor con benchmark eBird]`.
- **Protocolo.** Define cobertura del comité (incidentes operativos, no investigación) y el caveat de
  origen ciudadano. Reitera que no se captura PII.
- **Software.** Cuenta = handle único (sin email/teléfono/nombre real); recuperación sin PII (código de
  respaldo / QR); sin flujo de verificación de tutor; si hay módulo Comunidad con UGC, reporte al
  comité sin moderación previa; dashboard/exports muestran caveat de origen ciudadano.

### Q7-D1 — Salvaguardas (consolidación)
- **Decisión.** Recomendaciones de manejo → boundary Q1-D1. Georreferencia → Q5.B-D1 (protección del
  árbol). Menores → Q5.D-D1. PII → no se captura. **Disclaimer único al primer uso (D1):** buenas
  prácticas de campo — no entrar a propiedad privada sin permiso, atención a fauna (abejas, víboras,
  alacranes), hidratación.
- **Soporte:** `[supuesto del autor]`.
- **Protocolo.** Incluye el texto-base del disclaimer como anexo.
- **Software.** Disclaimer descartable al primer uso, persistente tras descarte, consultable desde Ayuda.
- **Criterios de aceptación.** Se muestra una sola vez tras crear cuenta; descarte con un tap;
  consultable desde Ayuda en todo momento.

### Q3-D1 — Escala ciudadana de infestación
- **Decisión.**
  - **Granularidad = G4** (4 niveles ordinales): sano / leve / moderado / severo.
  - **Anclaje = A2** (% de copa colonizada por paxtle):
    sano = 0%; leve = >0%–≤25%; moderado = >25%–≤50%; severo = >50%.
  - **Multidimensionalidad = M3** (triple etiqueta por observación): nivel de paxtle (G4) +
    flag binario *cúscuta visible* (sí/no) + flag binario *signos de daño* (defoliación/ramas
    muertas, sí/no).
- **Soporte:** `[supuesto del autor con apoyo en patrones genéricos de monitoreo ciudadano]`.
  Cortes % = propuesta inicial **refinable por AU2** sin reabrir el bloque.
- **Protocolo.** Escala = diseño inicial revisable con AU2 antes del lanzamiento; cúscuta = flag
  exploratorio (Q1 `[sin soporte]`).
- **Software.** Detección expone 4 opciones discretas con su rango % visible; sin foto de referencia en
  el selector (las fotos viven en Aprendizaje); dos toggles binarios independientes.
- **Relación con la validación automática (Q5.A-D1).** El nivel G4 y los flags son **autodeclarados
  por el voluntario y NO validados** por ahora. El sistema de validación solo confirma
  **presencia de parásitos** (binario), no el nivel ordinal ni la especie. El nivel G4 queda como
  dato ciudadano sin validación automática hasta nueva decisión.
- **Supuesto abierto.** Estimación visual de % sin foto de referencia en captura; si AU2 la considera
  insuficiente, revisar hacia A3.
- **Criterios de aceptación.** Selector con exactamente 4 opciones y rango % visible; toggles
  independientes; backend acepta la triple etiqueta.

### Q2-D1 — Variables mínimas de captura
- **Heredados (no decisionales):** ID observación; foto (cámara nativa); EXIF lat/lon/timestamp;
  nivel de infestación (G4); flag cúscuta; flag daño; handle; estado de validación (backend).
- **Decisión.**
  - **Campos adicionales = V3:** **tamaño** (dropdown: pequeño/mediano/grande/no estimable) +
    **contexto del sitio** (dropdown: campo abierto/borde de cultivo/urbano/ripario/otro).
    Sin nota libre.
  - **Revisitas = R3:** backend agrupa observaciones dentro de **radio 10 m** como mismo árbol
    (`tree_id`); si pasaron **>30 días** desde la última, entra como punto independiente de la **serie
    temporal** del árbol. Radio y ventana = defaults refinables por AU2.
  - **Atribución = I2:** **handle visible por observación** en el dataset publicado.
- **Soporte:** `[supuesto del autor con apoyo en patrones de citizen science]`.
- **Protocolo.** Vocabulario controlado de tamaño y contexto; regla de agrupamiento declarada (params
  afinables por AU2); atribución pública del handle (sin PII).
- **Software.** Dos dropdowns obligatorios; submit envía 8 etiquetas; backend asigna `tree_id`
  (nuevo/existente) y `observation_seq`; dashboard muestra handle por observación.
- **Criterios de aceptación.** Submit con 8 campos; backend asigna `tree_id` según R3; dashboard
  muestra handle por observación.

### Q4-D1 — Incentivos no monetarios
- **Decisión.**
  - **Individuales = E3:** lifelist + ranking por periodo + insignias por milestones + progresión de
    identidad ("Nuevo observador" → "Veterano del mezquite"), **sin gating funcional**.
  - **Colectivos = C2:** ranking por preparatoria/universidad.
  - **Off-app = W3:** reconocimiento público periódico (eventos Rotary, ceremonias escolares,
    menciones en redes) + tangibles no monetarios (parche/sticker, espacio en mesa con autoridades,
    mención).
  - **Disparador de nivel = L3:** observaciones **validadas** + tiempo activo. Fórmula concreta TBD
    (refinable por AU2 + diseño de gamificación).
  - **Afiliación institucional = F3:** lista cerrada administrada por **EA3** + solicitud de agregar
    (aprobada por EA3); sin afiliación = "Independiente".
- **Soporte:** `[supuesto del autor con patrones eBird-like]`.
- **Protocolo.** Declara mecánica de incentivos, flujo F3, gobernanza de la lista por EA3, operación
  off-app de W3 (producción concreta = responsabilidad del consorcio, no del software).
- **Software.** Gamificación: insignias, rankings por periodo (individual + por institución), lifelist;
  Perfil con etiqueta de identidad (sin desbloquear funciones); Cuentas con afiliación de lista +
  "solicitar agregar" (ticket a EA3); backend computa nivel L3. **Sin tier locks, sin multiplicadores
  por capacitación, sin certificados.**
- **Criterios de aceptación.** Perfil muestra etiqueta L3; ningún módulo gatea por nivel; registro
  permite elegir institución y solicitar agregar; rankings por periodo (individual + institución)
  funcionales.

### Q6-D1 — Indicadores de éxito
- **Decisión.** Set por 4 categorías; **régimen = U1 (solo seguimiento, sin umbrales/targets)**.
  - *Social:* registrados; activos (≥1 obs/30 días); observaciones totales y validadas; instituciones
    activas (F3).
  - *Educativo:* % de activos que abrieron ≥1 módulo de Aprendizaje; tiempo medio en contenido
    formativo por activo; distribución de etiquetas de identidad E3; tasa de validación promedio por
    activo.
  - *Ecológico:* árboles únicos (`tree_id`); árboles en serie temporal (≥2 obs, gap >30 días);
    cobertura geográfica (# municipios con ≥1 obs); distribución de niveles de infestación.
  - *Organizacional:* mesas formales con autoridades; aliados firmantes con coords exactas; eventos
    W3 ejecutados; menciones/coberturas mediáticas.
- **Soporte:** `[supuesto del autor]`.
- **Amendment — captura de indicadores organizacionales:** se capturan **manualmente en la web app
  de administración del consorcio** (no en la app móvil), comparten backend/dataset y alimentan el
  mismo dashboard público. **Amplía el alcance del software a dos clientes.**
- **Protocolo.** Lista los indicadores y su definición operativa; declara explícitamente que el piloto NO
  se autoevalúa contra umbrales (monitoreo y comunicación pública, no aprobación/reprobación).
- **Software.** Backend computa indicadores social/educativo/ecológico y los expone en dashboard; los
  organizacionales se capturan vía web admin.
- **Criterios de aceptación.** Dashboard expone indicadores social/educativo/ecológico calculados
  automáticamente; ningún indicador dispara lógica de aprobación/reprobación.

### Q8-D1 — Condiciones de escalamiento
- **Decisión.**
  - **Disparador = S2 (demanda orgánica):** la plausibilidad geográfica ya admite todo el rango
    natural; el sistema soporta cualquier estado desde el día uno. "Escalar" = decisión humana de
    dónde dirigir esfuerzo de articulación, no un cambio técnico.
  - **Arquitectura = RC1 (centralizada):** una app, un dataset, un backend, una web admin; los estados
    son **filtros geográficos**; los consorcios locales aportan articulación, no infraestructura.
- **Soporte:** `[supuesto del autor]`.
- **Protocolo.** Escalamiento = articulación, no re-arquitectura; "estado/región" = dimensión de filtrado
  y agregación; gobernanza (EA3/AU2/firmantes) replicable sobre infraestructura compartida.
- **Software.** Modelo de datos con dimensión geográfica (estado, municipio) derivable del EXIF;
  dashboards, rankings (C2) y lista F3 filtrables por estado/región; sin multi-tenancy de
  infraestructura, sí segmentación lógica por geografía.
- **Criterios de aceptación.** Toda observación es atribuible a estado y municipio por geolocalización;
  dashboards y rankings con filtro geográfico; agregar un estado no requiere nueva infraestructura.

---

## 2. Decisiones técnicas (Fase A)

### Transversal — Paridad de entornos
dev (local) → QA (local) → staging (nube) → producción (nube). Todo componente con dependencia de
infraestructura (storage, broker, DB) se abstrae detrás de una **interfaz conmutable por
configuración**, para que dev/QA corran sin nube. Dev/QA sobre **minikube + Rancher Desktop**
(ya disponibles); los manifiestos K8s funcionan en local sin cambios estructurales hacia stg/prod.

### T1 — Cliente móvil
- **Decisión.** **Flutter**, un solo código base. Target primario Android; iOS por el mismo código.
  Pruebas en emulador de Android Studio + dispositivos Android físicos locales.
- **Soporte:** `[supuesto del autor con apoyo en mercado MX gama media]`.
- **Criterio de aceptación.** Compila y corre en emulador y dispositivo físico Android; la captura
  inyecta lat/lon/timestamp reales del dispositivo.

### T2 — Backend
- **Decisión.** **Python + FastAPI**, API **REST** versionada; misma API sirve a app móvil y web admin.
- **Soporte:** `[supuesto del autor]`; coherente con la frontera de integración del sistema de
  validación (§6).
- **Criterio de aceptación.** Endpoints REST documentados (OpenAPI) y consumibles por ambos clientes.

### T3 — Base de datos
- **Decisión.** **PostgreSQL + PostGIS**.
- **Soporte:** `[evidencia disponible — estándar de la industria para geoespacial]`.
- **Criterio de aceptación.** Existe consulta que agrupa observaciones dentro de 10 m y consulta que
  devuelve coordenada redondeada a celda de 1 km.

### T4 — Almacenamiento de imágenes
- **Decisión.** Capa de abstracción **`StorageProvider`** con dos implementaciones conmutables por
  config: **filesystem local** (dev/QA) y **object storage S3-compatible** (stg/prod). La DB guarda
  solo clave/URL, nunca el binario.
- **Soporte:** `[supuesto del autor]`.
- **Criterio de aceptación.** Cambiar de entorno alterna disco local ↔ bucket sin tocar código de
  aplicación.

### T5 — Hosting / despliegue
- **Decisión.** Todo contenedorizado; despliegue objetivo en **Kubernetes** (agnóstico de proveedor;
  proveedor concreto = *decisión humana pendiente*). Dev local en minikube + Rancher Desktop. Cada
  componente (API, worker, DB, broker) con su contenedor y manifiestos K8s. Coherente con RC1.
- **Soporte:** `[supuesto del autor]`.
- **Criterio de aceptación.** Levanta en clúster K8s local con un solo comando; los mismos manifiestos
  parametrizan stg/prod.

### T6 — Integración con el sistema de validación de imágenes (asíncrona)
- **Decisión.** **Cola de mensajes con broker** (Redis + task queue de Python), contenedorizado y
  conmutable. La frontera **es la cola**, no una llamada síncrona; el validador es **consumidor** de
  la cola, no un endpoint que la app invoca. El detalle del intercambio es el **contrato de la §6**.
- **Soporte:** `[supuesto del autor]`; desacopla la jugabilidad de la latencia del validador
  (Q5.A-D1).
- **Criterio de aceptación.** Un `submit` retorna sin esperar al validador; un evento de resultado
  emitido por el **mock** dispara el etiquetado válida/ruido y la recompensa diferida correctos.

### T7 — UI/UX
- **Decisión.** Estética **minimalista tipo eBird**. Paleta = colores de marca **Rotary (azul royal +
  dorado)** + **verdes ecológicos**; iconografía minimalista y ecológica; baja densidad visual.
  **Design system compartido** entre app móvil y web admin (tokens de color, tipografía, iconos).
- **Soporte:** `[supuesto del autor con benchmark eBird]`.
- **Dato por verificar.** Valores hex exactos de la marca Rotary = tomar de la **guía de marca oficial
  de Rotary**. **No se fijan cifras de color aquí** (token pendiente).
- **Criterio de aceptación.** Existe design system documentado con tokens Rotary+verde; ninguna
  pantalla introduce elementos fuera del sistema.

---

## 3. Orquestación — equipo de subagentes

Flujo: **(1) especificar el software desde esta bitácora → (2) desarrollar**. 6 roles. El **Protocolo**
y el **Documento de presentación** son entregables ya producidos (archivos aparte) que sirven de
contexto. El **sistema de validación (YOLO) NO se desarrolla aquí** — track aparte (§6).

| Rol | Responsabilidad | Posee |
|---|---|---|
| **Orquestador** (lead) | Bitácora como fuente de verdad; secuencia trabajo; gestiona handoffs; verifica los **gates** (incl. boundary Q1). No escribe código de producto. | Plan de ejecución y gates |
| **Arquitecto** | Arquitectura del software + **frontera con el sistema de validación** (cola + contrato §6); modelo de datos PostGIS (`tree_id`, grid 1 km); contrato REST/OpenAPI; capa `StorageProvider`; contrato de cola; manifiestos K8s; paridad de entornos; design system. | Arquitectura y contratos |
| **Dev móvil (Flutter)** | App del voluntario: captura cámara-nativa+EXIF, Aprendizaje, Gamificación (E3/C2), Comunidad, dashboards cliente, disclaimer D1, cuentas pseudonimizadas; estado "pendiente" de observaciones (Q5.A-D2). | Cliente móvil |
| **Dev backend (FastAPI)** | API REST; auth 3 roles sin PII; lógica `tree_id`/obfuscación; productor de cola (`submit`) y consumidor del resultado de validación (§6); etiquetado válida/ruido; cómputo de indicadores Q6 y nivel L3. | Backend + API |
| **Dev web admin** | Web app del consorcio: lista F3, captura de indicadores organizacionales, gestión de aliados firmantes y permisos de coords exactas, snapshots trimestrales, dashboards público vs restringido. | Cliente de administración |
| **Tester / QA** | Traduce criterios de aceptación a pruebas (unitarias, integración, geoespaciales, asíncronas de cola, conmutación de storage); prueba en emulador + dispositivo físico Android; valida la frontera con el **mock** del validador (§6). | Suite de pruebas |
| **Documentador técnico** | Documentación del software; matriz de trazabilidad decisión→criterio→prueba; mantiene el caveat de origen ciudadano en dashboard/exports. (El Protocolo y la presentación ya existen como archivos aparte.) | Documentación del software |

- El **sistema de validación (YOLO)** se desarrolla en bitácora separada (§6). El Arquitecto define
  **solo la frontera** (cola + contrato §6); el Tester valida contra el **mock**. Ningún subagente de
  este equipo entrena ni especifica el modelo.
- Variante de equipo reducido: los tres "dev" pueden colapsar a dos (móvil + backend, con web admin
  dentro de backend).

### Gates que el Orquestador debe verificar
1. **Boundary Q1:** rechazar toda promesa de control fitosanitario directo, reducción medible de
   infestación o recomendaciones químicas/mecánicas autónomas.
2. **Sin PII:** ninguna feature exige email/teléfono/nombre real; recuperación sin PII.
3. **Sin gating:** ningún módulo bloquea funcionalidad por nivel o por capacitación.
4. **Captura:** solo cámara nativa con EXIF; galería deshabilitada.
5. **Obfuscación:** vista pública nunca expone coords más finas que grid 1 km.
6. **Paridad de entornos:** dev/QA corren sin nube (storage/broker/DB conmutables).
7. **Trazabilidad:** cada criterio de aceptación de la bitácora tiene prueba asociada.
8. **Alcance de validación:** la validación automática se limita a **es-árbol + presencia-de-parásitos**
   (Q5.A-D1); ninguna feature debe afirmar validación de especie o de nivel G4.
9. **Etiquetado válida/ruido:** solo las imágenes **válidas** generan puntos y entran al dataset;
   las **no válidas** se etiquetan como ruido (dataset "no validadas") y no generan puntos.
10. **Contrato §6:** la integración con el validador se hace exclusivamente por la cola y el contrato
    de la §6; el software debe funcionar contra el **mock** sin cambios de cliente al pasar al real.

---

## 4. Decisiones humanas pendientes (fuera del software)

| # | Pendiente | Notas |
|---|---|---|
| H1 | **Actor sustentador** de la app más allá del piloto | Candidatos: universidades aliadas + club rotario |
| H2 | **Institución concreta de custodia** del dataset | Categoría = híbrido consorcio (Q5.B-D1) |
| H3 | **Integrantes concretos de EA3** (comité ético) | Categoría = Rotary + universidad + asesor externo |
| H4 | **Universidad/expertos concretos de AU2** | Autoría de contenidos formativos |
| H5 | **Texto del acuerdo de uso** con aliados firmantes | Habilita acceso a coords exactas |
| H6 | **Proveedor cloud concreto** para stg/prod | K8s agnóstico (T5) |
| H7 | **Fórmula concreta de L3** (validadas + tiempo activo) | Refinable por AU2 + diseño de gamificación |
| H8 | **Refinamiento por AU2** de: cortes % de la escala (Q3), radio 10 m / ventana 30 días (Q2) | Antes del lanzamiento |

## 5. Pendientes metodológicos

- **Mapeo `[cite:NN]` → claves bibtex:** la propuesta usa numeración no mapeada a `bibliografia.bib` /
  `parasitos.bib`. Tarea del Documentador técnico. No bloquea decisiones de diseño.
- **Limpieza bibliográfica:** `respuestasmorofologicas2018` (typo + URL apunta a artículo 2025);
  `prosopislaevigataagrociencia` y `distribucionpotencialprosopis` sin año. Tarea del SRS
  correspondiente.

---

## 6. Contrato con el sistema de validación de imágenes

> **Este contrato está espejado en `bitacora_srs_c_yolo.md`.** Es la única frontera entre el software
> (esta bitácora) y el sistema de validación (bitácora aparte). Ninguno de los dos lados lo modifica
> unilateralmente.

### 6.1 Modelo de comunicación
- **Canal:** cola de mensajes con broker (Redis + task queue). **Asíncrono.** El validador es
  **consumidor**, nunca un endpoint que el cliente invoque de forma síncrona.
- **Productor (backend):** al recibir `submit_observation`, persiste la observación en estado
  `pendiente`, sube la imagen vía `StorageProvider` y **encola un job de validación**. Responde de
  inmediato al cliente con la recompensa base (fire-and-forget).
- **Consumidor (validador / mock):** toma el job, evalúa la imagen y **publica un resultado** en la
  cola/tópico de resultados.
- **Consumidor de resultados (backend):** al recibir el resultado, **etiqueta** la observación
  (`valida` | `ruido`), actualiza el dataset y, si es válida, **otorga la recompensa diferida**.

### 6.2 Job de validación (backend → validador)
```json
{
  "observation_id": "uuid",
  "image_ref": "storage-key-o-url",
  "captured_at": "ISO-8601",
  "lat": 0.0,
  "lon": 0.0,
  "schema_version": "1.0"
}
```

### 6.3 Resultado de validación (validador → backend)
```json
{
  "observation_id": "uuid",
  "es_arbol": true,
  "parasitos_presentes": true,
  "veredicto": "valida",          // "valida" si (es_arbol && parasitos_presentes); si no, "ruido"
  "scores": { "arbol": 0.0, "parasitos": 0.0 },
  "model_version": "string",       // o "mock" en la etapa inicial
  "schema_version": "1.0"
}
```
- **Regla de etiquetado (autoritativa en el backend):** `valida` ⟺ `es_arbol == true && parasitos_presentes == true`. En cualquier otro caso → `ruido`.
- **Válida** → puntos + entra al dataset. **Ruido** → dataset "no validadas" + feedback agregado, sin puntos.

### 6.4 Manejo del contrato
- **Idempotencia:** el resultado se aplica una sola vez por `observation_id` (reentregas de la cola no duplican puntos).
- **Reintentos / fallo del validador:** si el job no se procesa, la observación permanece `pendiente`; política de reintento y *dead-letter* definida por el backend.
- **Timeout:** sin resultado tras el umbral configurado → permanece `pendiente` (nunca se auto-etiqueta).
- **Versionado:** `schema_version` y `model_version` viajan en cada mensaje; cambios de esquema son versionados y compatibles hacia atrás.
- **Estado:** `pendiente` → (`valida` | `ruido`). No hay otros estados operativos.

### 6.5 Mock para la etapa inicial
Mientras el sistema YOLO real no está entrenado, la integración se prueba contra un **mock** que
**cumple este mismo contrato** (consume el job 6.2, publica el resultado 6.3 con `model_version:
"mock"`). El mock **vive en este repo** (`/mock-validator`). El paso **mock → real** no requiere
cambios en el software: solo cambia quién consume la cola y produce el resultado.

---

## 7. Organización del repositorio e integración

**Dos repositorios separados** (decisión cerrada):

- **`mezquite-software`** (este repo): app móvil + backend + web admin + contrato + mock + deploy.
- **`mezquite-validacion-yolo`** (repo aparte): sistema de validación de imágenes (YOLO), con su
  bitácora `bitacora_srs_c_yolo.md` y equipo propio, en modo interactivo humano-Claude.

**Frontera única = el contrato (§6).** Los dos repos no comparten DB, código de dominio ni
despliegue interno; solo el contrato de la cola.

- **Contrato canónico:** vive en este repo en **`/contract`** como **esquema de mensajes versionado**
  (`schema_version`), **fuente de verdad**. El repo YOLO lo **consume por versión** y mantiene su
  copia sincronizada; la prosa de las bitácoras solo lo describe.
- **Mock:** en este repo, **`/mock-validator`** (modos fijo/aleatorio/regla + latencia).
- **Regla de etiquetado:** **autoritativa en el backend** (`valida` ⟺ `es_arbol && parasitos_presentes`).
  El validador (real o mock) reporta hechos; el backend decide y etiqueta.

**Layout de este repo:**
```
/mobile          (Flutter — app del voluntario)
/backend         (FastAPI — API, cola, etiquetado válida/ruido)
/web-admin       (web del consorcio)
/contract        (fuente de verdad: esquema de mensajes + versión)
/mock-validator  (mock que cumple el contrato)
/deploy          (manifiestos K8s + compose para minikube/Rancher)
```

**Orquestación de la integración:**
- **dev/QA (minikube + Rancher):** `/deploy` levanta backend + DB + cola + mock; el equipo de
  software trabaja de extremo a extremo **sin** YOLO.
- **Integración real:** se despliega el *serving* del repo `mezquite-validacion-yolo` apuntando a la
  **misma cola** y se apaga el mock. **Cero cambios** en app o backend (lo garantiza el contrato).
- **Compatibilidad:** un cambio de contrato se versiona aquí (`/contract`) y el repo YOLO actualiza
  su copia antes de desplegar.

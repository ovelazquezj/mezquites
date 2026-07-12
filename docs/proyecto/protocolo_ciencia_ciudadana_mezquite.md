# Protocolo de Ciencia Ciudadana — Monitoreo del Mezquite y sus Parásitos

**Proyecto piloto (24 meses) · Aguascalientes · Club Rotario + universidades aliadas**

> Documento de método. Define **qué se observa, cómo se captura, cómo se valida, quién hace qué, cómo
> se mide el éxito y bajo qué salvaguardas**. Es entregable separado de la bitácora del software
> (`bitacora_sdd_mezquite.md`) y del sistema de validación (`bitacora_srs_c_yolo.md`).
> Cada afirmación de diseño lleva su grado de soporte: `[evidencia disponible]` /
> `[supuesto del autor]` / `[sin soporte]`.

---

## 1. Propósito y alcance

Generar, mediante participación ciudadana voluntaria, un **censo georreferenciado y abierto** del
mezquite (*Prosopis laevigata*) y de la presencia visible de parásitos —con foco en el paxtle
(*Tillandsia recurvata*)—, para **concientizar** y para producir **evidencia transferible** a
universidades y autoridades.

**El piloto NO promete** (boundary): reducción medible de infestación; control fitosanitario directo
ejecutado por la app, voluntarios o el club; recomendaciones de manejo químico/mecánico sin
validación técnica; intervención en propiedad privada sin consentimiento del propietario.
`[supuesto del autor]`

**Plataforma de referencia:** eBird — participación voluntaria consciente, registro abierto, sin
certificación ni gating, datos públicos con controles razonables.

---

## 2. Hipótesis de cambio

Con la **capacitación como motor principal** y la **concientización como puerta de entrada**, el
proyecto forma juventudes (preparatorias y universidades) cuyas **observaciones georreferenciadas**
constituyen evidencia que, vía **articulación institucional directa** (club rotario + aliados
académicos), alimenta a autoridades y actores técnicos para que **coordinen** —no ejecuta el piloto—
intervenciones priorizadas. `[supuesto del autor]`

- Sujeto primario del cambio: **juventudes**. Secundario: **autoridades y actores técnicos**.
- El piloto produce datos y narrativa; **no** ejecuta el combate fitosanitario.

---

## 3. Unidad de observación y variables capturadas

Cada **observación** corresponde a un árbol fotografiado en campo. El backend agrupa observaciones
dentro de un **radio de 10 m** como un mismo árbol (`tree_id`); si han pasado **>30 días** desde la
última, la nueva entra como punto independiente de la **serie temporal** del árbol. (Radio y ventana
= defaults **refinables por los aliados académicos** antes del lanzamiento.) `[supuesto del autor]`

**Variables por observación:**

| Variable | Tipo | Origen |
|---|---|---|
| ID de observación | uuid | automático |
| Foto | imagen | **cámara nativa** (sin galería) |
| Ubicación + fecha/hora | lat/lon/timestamp | EXIF del momento de captura |
| Nivel de infestación de paxtle | escala G4 (ver §4) | autodeclarado |
| Cúscuta visible | binario sí/no | autodeclarado |
| Signos de daño (defoliación / ramas muertas) | binario sí/no | autodeclarado |
| Tamaño del árbol | pequeño/mediano/grande/no estimable | autodeclarado |
| Contexto del sitio | campo abierto/borde de cultivo/urbano/ripario/otro | autodeclarado |
| Handle del observador | seudónimo | cuenta (sin PII) |
| Estado de validación | pendiente/válida/ruido | backend (ver §5) |

La **cúscuta** se captura como flag **exploratorio**: no hay evidencia local específica de su impacto
sobre mezquite en Aguascalientes/Bajío. `[sin soporte]`

---

## 4. Escala ciudadana de infestación

**Cuatro niveles ordinales (G4)** anclados al **% de copa colonizada por paxtle**:

| Nivel | % de copa colonizada |
|---|---|
| Sano | 0% (sin paxtle visible) |
| Leve | >0% – ≤25% |
| Moderado | >25% – ≤50% |
| Severo | >50% |

`[supuesto del autor con apoyo en patrones genéricos de monitoreo ciudadano]`. Los cortes son
propuesta inicial **revisable por los aliados académicos** antes del lanzamiento; si la estimación
visual sin foto de referencia resulta poco consistente, podrá añadirse apoyo visual en captura.

Base técnica del problema que la escala busca documentar: el paxtle actúa como **parásita
estructural** —altera la anatomía de las ramas, el flujo de agua y la eficiencia fotosintética del
mezquite—. `[evidencia disponible]` (`pereznoyola2015`, IPICYT). Como referencia indicativa de
magnitud en región cercana, un estudio en **Querétaro** reportó ~44.91% de árboles con infestación
por paxtle; **no es línea base de Aguascalientes**. `[evidencia disponible]` (`hernandezortiz2021`).

---

## 5. Validación de datos

La validación es **automática, en backend, asíncrona y transparente** al voluntario, realizada por un
**sistema externo de validación de imágenes** (especificado aparte). `[supuesto del autor]`

**Alcance de la validación automática:** verifica dos hechos binarios — **(1) es un árbol** y **(2)
hay presencia de parásitos**.
- **Imagen válida** (árbol **y** parásitos presentes): se etiqueta **válida**, entra al dataset y
  **genera puntos**.
- **Imagen no válida**: se etiqueta **ruido**, va a un dataset paralelo "no validadas" (auditoría sin
  uso operativo) y alimenta el **feedback agregado** al voluntario, sin acusación individual.

**Fuera de alcance por ahora:** validación de **especie** (que sea mezquite se asume de buena fe;
riesgo registrado: otro árbol con parásitos pasaría como válido) y validación del **nivel G4** y los
flags (autodeclarados, no verificados). `[supuesto del autor]`

**Calidad y origen del dato:** todo dato publicado es de **origen ciudadano, no validado por
expertos**; se difunde siempre con ese caveat y requiere preproceso para uso en investigación.

---

## 6. Roles de actores

- **Voluntarios (ciudadanía, juventudes):** observan y registran. Participación abierta, voluntaria,
  **sin certificación ni tiers**. `[supuesto del autor con benchmark eBird]`
- **Universidades aliadas + expertos forestales/fitosanitarios (autoría de contenidos):** producen y
  validan el material formativo; refinan escala, radios y ventanas antes del lanzamiento.
  `[supuesto del autor]`
- **Comité ético mixto (Rotary + universidad + asesor externo):** autoridad sobre incidentes
  operativos, exigencias de borrado de cuenta, conflictos con propietarios, y gobierno de la lista de
  instituciones. **No** es un comité de investigación académica. `[supuesto del autor]`
- **Aliados firmantes:** instituciones/autoridades que firman un acuerdo de uso. **CR-025:** las vistas
  públicas muestran la **ubicación exacta** del árbol (ver §10).
- **Consorcio (Rotary + universidad):** sostiene la operación, las mesas formales con autoridades y
  el reconocimiento off-app. **El actor sustentador de largo plazo es decisión humana pendiente.**

---

## 7. Incentivos y participación

Modelo de incentivos **no monetarios**, sin gating funcional: `[supuesto del autor con patrones
eBird-like]`
- **Individual:** lifelist, rankings por periodo, insignias por milestones, y una **progresión de
  identidad** ("Nuevo observador" → "Veterano del mezquite") por **observaciones válidas + tiempo
  activo** (fórmula concreta pendiente).
- **Colectivo:** ranking por preparatoria/universidad. La afiliación se elige de una **lista
  administrada** por el comité; se puede solicitar agregar una institución; sin afiliación =
  "Independiente".
- **Fuera de la app:** reconocimiento público (eventos Rotary, ceremonias escolares, menciones) y
  tangibles no monetarios (parche/sticker, espacio en mesa con autoridades). Producción a cargo del
  consorcio.

---

## 8. Indicadores de éxito

Régimen de **solo seguimiento** (sin umbrales ni metas de aprobación/reprobación): el piloto se
monitorea y comunica, no se autoevalúa contra targets. `[supuesto del autor]`

- **Social:** registrados; activos (≥1 obs/30 días); observaciones totales y válidas; instituciones
  activas.
- **Educativo:** % de activos que abren ≥1 módulo de aprendizaje; tiempo medio en contenido
  formativo; distribución de etiquetas de identidad; tasa de validación promedio por activo.
- **Ecológico:** árboles únicos; árboles en serie temporal (≥2 obs, gap >30 días); cobertura
  geográfica (municipios con ≥1 obs); distribución de niveles de infestación.
- **Organizacional:** mesas formales con autoridades; aliados firmantes; eventos de reconocimiento;
  menciones/coberturas mediáticas. (Se capturan manualmente en la web de administración del
  consorcio.)

---

## 9. Salvaguardas éticas y de datos

- **Sin captura de datos personales (PII).** Cuenta **seudonimizada** por handle; sin email/teléfono/
  nombre real; recuperación sin PII. **LFPDPPP no aplica** porque no hay datos personales que
  proteger. `[supuesto del autor]`
- **Menores:** registro abierto estilo eBird, **sin verificación de tutor**. `[supuesto del autor con
  benchmark eBird]`
- **Disclaimer de campo** al primer uso (descartable, consultable después): no entrar a propiedad
  privada sin permiso; atención a fauna (abejas, víboras, alacranes); hidratación.
- ~~**Protección del árbol:** las coordenadas exactas se restringen a aliados firmantes.~~ **Retirado por
  CR-025 (2026-07-12):** por decisión de gobernanza del Club, las vistas públicas muestran la ubicación
  exacta del árbol.

---

## 10. Custodia, acceso y publicación de datos

- **Custodia híbrida:** dataset vivo en infraestructura del consorcio (Rotary + universidad), con
  **snapshots públicos**. Institución concreta = decisión humana pendiente. `[supuesto del autor]`
- **Acceso por vista:**
  - **Pública:** **CR-025:** ubicación **exacta** del árbol (con mapa de calor agregado); abierta a todos.
  - **Restringida (aliados firmantes):** coordenadas exactas, bajo acuerdo de uso (histórico; CR-025 abre
    la ubicación exacta también al público y a todos los roles de consola).
- **Publicación:** **dashboards** como pieza única, **actualización trimestral**. No se producen
  reportes técnicos narrados por el piloto; los datasets quedan abiertos para que terceros produzcan
  sus análisis, siempre con el caveat de origen ciudadano.

---

## 11. Condiciones de escalamiento

- **Disparador = demanda orgánica:** el sistema admite cualquier punto del rango natural de
  *P. laevigata* desde el inicio; "escalar" es una decisión humana de **dónde dirigir la
  articulación** (mesas, aliados, reconocimiento), no un cambio técnico. `[supuesto del autor]`
- **Arquitectura centralizada:** una sola plataforma y un solo dataset; los estados son **filtros
  geográficos**; los consorcios locales aportan articulación, no infraestructura.

---

## 12. Decisiones humanas pendientes y supuestos abiertos

| # | Pendiente |
|---|---|
| 1 | Actor sustentador de largo plazo (candidatos: universidades + club rotario) |
| 2 | Institución concreta de custodia del dataset |
| 3 | Integrantes del comité ético |
| 4 | Universidad/expertos concretos de autoría de contenidos |
| 5 | Texto del acuerdo de uso con aliados firmantes |
| 6 | Refinamiento por aliados académicos: cortes % de la escala (§4), radio 10 m / ventana 30 días (§3) |

**Supuestos abiertos clave:** que el mecanismo educativo + evidencia + articulación mueve autoridades
en 24 meses; que la participación voluntaria se sostiene sin gating; que la validación automática
(árbol + parásitos) es suficiente sin verificar especie.

---

## 13. Nota de evidencia

- Mecanismo de daño del paxtle (parásita estructural): `[evidencia disponible]` (`pereznoyola2015`).
- ~44.91% de infestación por paxtle en **Querétaro**: `[evidencia disponible]`
  (`hernandezortiz2021`). **Referencia indicativa, NO línea base de Aguascalientes.**
- Importancia ecológica/biocultural del mezquite: `[evidencia disponible]` (`bibliografia.bib`,
  fuentes 2011–2025).
- Impacto de *Cuscuta* spp. sobre mezquite en Aguascalientes/Bajío: `[sin soporte]` — hipótesis a
  verificar en campo.

*Pendiente metodológico: mapear las citas `[cite:NN]` de la propuesta original a las claves bibtex y
verificar cada fuente antes de difusión amplia.*

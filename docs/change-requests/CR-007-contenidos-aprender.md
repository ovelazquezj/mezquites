# CR-007 — Contenidos de la sección "Aprender" (app del voluntario)

| Campo | Valor |
|---|---|
| **ID** | CR-007 |
| **Título** | Contenido educativo real en "Aprender" (mixto: texto propio offline + enlaces "Saber más" curados) |
| **Fecha** | 2026-06-16 |
| **Estado** | **Aprobado — sin codificar** |
| **Prioridad** | Media |
| **Depende de** | — (independiente; solo toca `mobile/` + `docs/learning/`) |
| **Alcance** | App del voluntario (sección Aprender). **Backend y web-admin NO se tocan.** |

---

## 1. Contexto y decisiones

Hoy "Aprender" tiene **4 módulos placeholder** (solo `id/title/summary`, sin cuerpo ni enlaces).
Decisiones del usuario:
1. **Alternativa 3 (mixta):** texto propio **breve y offline** por módulo + botón **"Saber más"** con
   **enlaces curados** a fuentes públicas autoritativas.
2. **Borrador:** el contenido se entrega marcado **BORRADOR sujeto a revisión de expertos/universidad
   (AU2/H4)** — igual que el texto legal. No es asesoría técnica.
3. **7 módulos** (amplía los 4 actuales).

## 2. Gates (no se enmienda ninguno)
- **Gate #1:** el contenido NO promete control/erradicación ni da recetas químicas/mecánicas. La
  curaduría apunta a **identificación, ecología y por qué documentar**; **NO** a páginas de "cómo
  eliminar" (vinagre/carbonato, etc.). Un módulo explícito aclara *qué NO hace la app*.
- **Gate #8:** especie y nivel G4 son **autodeclarados**; el módulo de la escala enseña a estimar "a
  ojo", sin afirmar validación.
- **Gate #3:** sin gating — todos los módulos siempre abiertos (ya es así).
- **AU2/H4 (pendiente humano):** el texto es **borrador**; el contenido final lo valida el consorcio.

## 3. Los 7 módulos (id · título · resumen · contenido · enlaces)

> Datos clave verificados: **paxtle = "heno motita" = _Tillandsia recurvata_** (epífita, NO parásita:
> compite por luz/espacio y pesa sobre las ramas). **Cúscuta = _Cuscuta_ spp.** (sí parásita: hilos
> amarillos/anaranjados que extraen savia).

| id | Título | Contenido (borrador, breve) | "Saber más" (curado) |
|---|---|---|---|
| `mod_que_es` | ¿Qué es el mezquite? | _Prosopis laevigata_: fija suelo y nitrógeno, frena erosión/desertificación, sostiene biodiversidad; usos (leña, carbón, fruto, miel). | México Desconocido; UAQ; Chapingo |
| `mod_paxtle` | Reconocer el paxtle (heno motita) | _Tillandsia recurvata_: epífita gris en "motas"; **no chupa savia** pero compite por luz y **pesa** sobre las ramas. Cómo se ve. | Pulso SLP "¿es parásita?"; TillandsIA (ciencia ciudadana) |
| `mod_cuscuta` | Reconocer la cúscuta | _Cuscuta_ spp.: **sí parásita**; hilos **amarillos/anaranjados** enroscados que extraen agua/nutrientes. | iNaturalist MX (Cuscuta); CICY "Desde el Herbario" |
| `mod_escala` | La escala de observación (G4) | Sano · leve · moderado · severo = **% de copa cubierta**, estimado **a ojo** (autodeclarado, gate #8). | (texto propio + ejemplos) |
| `mod_buena_foto` | Una buena foto | Encuadre del árbol completo, buena luz, distancia; cámara nativa (gate #4). | (texto propio) |
| `mod_ciencia_ciudadana` | ¿Por qué participar? | Tus observaciones forman un **dataset abierto** para el consorcio; modelo eBird/Naturalista. | Naturalista (CONABIO); iNaturalist México |
| `mod_que_no_hace` | Qué hace y qué NO hace la app | Documentamos y educamos; **no** controlamos plagas ni damos recomendaciones de manejo (lo deciden autoridades/expertos). (gate #1) | (texto propio) |

**URLs curadas (a incrustar como enlaces; verificar antes de publicar):**
- `https://www.mexicodesconocido.com.mx/mezquite-arbol.html`
- `https://ri-ng.uaq.mx/bitstream/123456789/644/1/RI003754.pdf`
- `https://pulsoslp.com.mx/slp/el-heno-motita-en-san-luis-potosi-es-una-planta-parasita-del-mezquite/1539631`
- `https://app.henomotita.mx/`
- `https://mexico.inaturalist.org/taxa/Cuscuta_americana`
- `https://www.cicy.mx/Documentos/CICY/Desde_Herbario/2010/2010-07-15-Tapia-Cuscuta-en-la-Peninsula-de-Yucatan.pdf`
- `https://www.biodiversidad.gob.mx/cienciaciudadana/naturalista`
- `https://mexico.inaturalist.org/`

## 4. Diseño técnico

**Fuente única de contenido:** `docs/learning/<id>.md` (markdown con texto + enlaces "Saber más").
La app **lo bundlea** como asset (`mobile/assets/learning/<id>.md`) y lo **renderiza**. (El orquestador
copia `docs/learning/` → `mobile/assets/learning/` en la integración, para no duplicar la fuente.)

- **Modelo** (`mobile/lib/src/ui/copy.dart`): `LearningModule` gana `assetPath` (ruta del `.md`) además
  de `id/title/summary`. La lista de los 7 módulos (id/título/resumen/assetPath) vive aquí o en
  `learning_content.dart`.
- **Dependencias:** `flutter_markdown` (render) + `url_launcher` (abrir enlaces externos).
- **Pantalla de detalle** (`learning_detail_screen.dart`): `BrandedAppBar` + **banner BORRADOR** +
  markdown del módulo; al tocar un enlace → `url_launcher` (externo, `mode: externalApplication`).
- **`learning_screen.dart`:** cada módulo navega a su detalle (mantiene la medición de engagement
  "abierto" y el gate #3: todos abiertos).
- **`mobile/web/`:** `url_launcher` y `flutter_markdown` compilan en web (la web del voluntario sigue OK).

## 5. Desglose por agente (2 carriles, particiones sin colisión)

| Carril | Agente | Alcance | Archivos |
|---|---|---|---|
| **A** | Documentador/contenido | Redacta los **7 `docs/learning/<id>.md`** (borrador, español, con los enlaces curados §3, banner de borrador) acorde a los gates (#1/#8). **No toca `mobile/`.** | `docs/learning/*.md` |
| **B** | Dev móvil | Motor + UI: `LearningModule` con `assetPath`, `flutter_markdown` + `url_launcher`, `learning_detail_screen.dart`, navegación en `learning_screen.dart`, banner BORRADOR, y **assets placeholder** `mobile/assets/learning/<id>.md` para dev/tests (el orquestador los reemplaza por los de A al integrar). Tests. **Solo `mobile/`.** | `mobile/lib/...`, `mobile/pubspec.yaml`, `mobile/assets/learning/`, `mobile/test/` |

> **Integración (orquestador):** merge A + B; **copiar `docs/learning/*.md` → `mobile/assets/learning/`**
> (fuente única); rebuild web; pruebas; refrescar la demo con `appctl`.

## 6. Criterios de aceptación
- AC1: Los 7 módulos aparecen en "Aprender"; cada uno abre su **detalle** con texto + **banner BORRADOR**.
- AC2: El botón/enlace **"Saber más"** abre la URL curada en el navegador (externo).
- AC3: **Gate #1** — ningún módulo promete control/erradicación ni recetas; el módulo *Qué NO hace* lo aclara.
- AC4: **Gate #8** — el módulo de la escala dice explícitamente "autodeclarado, a ojo".
- AC5: **Gate #3** — todos los módulos abren siempre (sin bloqueo). `flutter analyze` limpio; `flutter test` verde; `flutter build web` compila.
- AC6: **Backend/web-admin intactos** (`git diff` vacío fuera de `mobile/` y `docs/learning/`).

## 7. Riesgos
- **Enlaces rotos / desalineados con el gate #1** → curaduría revisada; preferir identificación/ecología/ciencia ciudadana.
- **Validación de expertos (AU2/H4) pendiente** → entregado como **borrador**; el consorcio aprueba el texto final.
- **`flutter_markdown`** mantenimiento → si se prefiere, render con `Text` enriquecido (decisión del Dev B).

## 8. Definition of Done
7 módulos con texto borrador + "Saber más" funcional; gates #1/#3/#8 respetados; banner de borrador
visible; pruebas verdes (números reales) y build web OK; backend/web-admin intactos; fuente de contenido
única (`docs/learning/` copiado a los assets).

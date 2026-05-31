# QUICKSTART — Levantar el sistema y revisar las dos UIs

Guía paso a paso para, desde cero, dejar corriendo el backend, **poblarlo con datos** y **revisar
las dos interfaces**: la **app móvil del voluntario** (Android) y el **web admin del consorcio**
(navegador). Cada paso incluye **cómo saber que se ejecutó correctamente** (✓ Verifica).

> Plataforma de referencia: **Windows + PowerShell** (los comandos usan `curl.exe`, no el alias
> `curl` de PowerShell). Si usas otra shell, adapta las comillas.

## Qué vas a tener corriendo

```
┌─ App móvil (Android, emulador)         ┐
│                                        ├──HTTP──▶ API FastAPI (http://localhost:8000)
└─ Web admin (Chrome)                    ┘                 │
                                                           ├─ PostGIS (datos)
   Cola Redis ──▶ mock-validator ──▶ result-worker ──▶ etiqueta válida/ruido + puntos
```

Todo se levanta **sin nube** con un solo `docker compose`.

## Dos advertencias de entorno (dev) que verás en esta guía

1. **CORS:** el backend aún no habilita CORS, así que el web-admin en el navegador necesita un
   pequeño workaround (Parte 3). Está documentado y **no requiere tocar código**.
2. **Bootstrap de admin:** hoy la cuenta admin se crea con `role` en el registro (un hueco de
   seguridad conocido, ver [Apéndice C](#apéndice-c--notas-de-seguridad-dev)). Sirve como bootstrap
   temporal para esta revisión local.

---

## Requisitos previos

| Herramienta | Comando para verificar | Resultado esperado |
|---|---|---|
| Docker (Rancher Desktop **abierto y corriendo**) | `docker version` | Muestra `Client` y `Server` sin error |
| Docker Compose | `docker compose version` | `Docker Compose version v2.x` |
| Flutter 3.27 | `flutter --version` | `Flutter 3.27.x … Dart 3.6.x` |
| Chrome | — | Instalado (para el web admin) |
| (Opcional) Emulador Android | `flutter emulators` | Lista al menos un emulador (para la app móvil) |

> Si `docker version` falla con "cannot connect", **abre Rancher Desktop** y espera a que el ícono
> indique que el motor está listo.

Sitúate en la raíz del repo en todos los pasos salvo donde se indique `cd`:

```powershell
cd C:\Users\ovela\OneDrive\Desktop\CIDRIA_PROJECT\Rotary\mezquites
```

---

## Parte 1 — Levantar el backend y todo el stack

### 1.1 Arranca el stack (en segundo plano)

```powershell
docker compose -f infra/compose/docker-compose.dev.yml up --build -d
```

La primera vez construye imágenes (varios minutos). Levanta 5 servicios: `redis`, `postgres`
(PostGIS), `api`, `result-worker`, `mock-validator`. El servicio `api` **aplica las migraciones
Alembic y luego arranca**.

**✓ Verifica — todos los servicios arriba:**
```powershell
docker compose -f infra/compose/docker-compose.dev.yml ps
```
Debes ver las 5 filas; `postgres` y `redis` en estado **healthy**, y `api`, `result-worker`,
`mock-validator` en **running / Up**.

### 1.2 Confirma que la API responde

```powershell
curl.exe http://localhost:8000/healthz
```
**✓ Verifica:** responde exactamente `{"status":"ok"}`.

Si tarda, las migraciones aún corren. Míralas:
```powershell
docker compose -f infra/compose/docker-compose.dev.yml logs api | Select-Object -Last 20
```
**✓ Verifica:** ves `alembic … running upgrade … 0001_initial` y luego
`Uvicorn running on http://0.0.0.0:8000`.

### 1.3 Abre la documentación interactiva de la API (Swagger)

En el navegador: **http://localhost:8000/api/v1/docs**

**✓ Verifica:** se abre Swagger UI con los grupos `auth`, `observations`, `me`, `gamification`,
`institutions`, `public`, `restricted`, `admin`. Desde aquí puedes ejecutar todos los pasos de la
Parte 2 sin escribir `curl` (botón **Try it out** en cada endpoint).

---

## Parte 2 — Poblar el sistema con datos

Haz esto **una vez** para que los dashboards tengan contenido. Puedes usar **Swagger** (recomendado,
es visual y **evita problemas de comillas**) o los `curl.exe` de abajo.

> **PowerShell + JSON:** envolvemos el JSON en **comillas simples** (`'{"k":"v"}'`). En PowerShell las
> comillas simples son literales, así que `curl.exe` recibe las comillas dobles intactas. **No** uses
> `\"` (eso es de cmd/bash y aquí fallaría). El backtick `` ` `` al final de línea continúa el comando.

### 2.1 (Opcional pero recomendado) Fuerza que todas las observaciones sean "válidas"

Por defecto el mock está en modo `regla` (≈47% válidas, realista). Para que el **dashboard público
seguro tenga datos** en la demo, ponlo en modo `fijo`:

Edita `infra/compose/docker-compose.dev.yml`, en el servicio `mock-validator`, cambia/añade:
```yaml
      MOCK_MODE: fijo
      MOCK_FIXED_ES_ARBOL: "true"
      MOCK_FIXED_PARASITOS: "true"
```
y recarga solo ese servicio:
```powershell
docker compose -f infra/compose/docker-compose.dev.yml up -d mock-validator
```
> Déjalo en `regla` si prefieres ver la mezcla realista válida/ruido.

### 2.2 Crea la cuenta de administrador (bootstrap)

```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/auth/register `
  -H "Content-Type: application/json" -d '{"role":"admin_consorcio"}'
```
**✓ Verifica:** responde un JSON como:
```json
{"handle":"colibri-azul-1234","role":"admin_consorcio","token":"eyJhbGciOi...","backup_code":"ABCD-EFGH-IJKL"}
```
**Apunta `handle` y `backup_code`** (los usarás para entrar al web admin) y `token` (alternativa).

### 2.3 Crea un voluntario

```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/auth/register `
  -H "Content-Type: application/json" -d '{"role":"voluntario"}'
```
**✓ Verifica:** otro JSON con `role":"voluntario"`. **Copia su `token`** para el siguiente paso
(lo llamaremos `TOKEN_VOL`).

### 2.4 Sube varias observaciones

Necesitas un archivo `.jpg` cualquiera (sirve cualquiera; el contenido no importa para el mock).
Repite el comando 6–8 veces cambiando un poco `lat`/`lon` (coordenadas de Aguascalientes):

```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/observations `
  -H "Authorization: Bearer TOKEN_VOL" `
  -F 'payload={"lat":21.881,"lon":-102.291,"captured_at":"2026-05-30T12:00:00Z","nivel_g4":"moderado","flag_cuscuta":false,"flag_danio":true,"tamanio":"mediano","contexto":"campo_abierto"}' `
  -F 'image=@C:\ruta\a\cualquier.jpg'
```
**✓ Verifica:** responde **HTTP 201** con el id de la observación y la **recompensa base** (5
puntos). La validación ocurre en segundo plano (la imagen pasa por el mock en < 1 s).

**✓ Verifica que el worker etiquetó:**
```powershell
docker compose -f infra/compose/docker-compose.dev.yml logs result-worker | Select-Object -Last 10
```
Debes ver líneas tipo `aplicado obs=… veredicto=valida` (o `ruido`).

### 2.5 Genera el snapshot trimestral (sello "Qn")

En Swagger: `admin → POST /admin/snapshots → Authorize con el token admin → Execute`. O por consola:
```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/admin/snapshots -H "Authorization: Bearer TOKEN_ADMIN"
```
**✓ Verifica:** responde 201 con `quarter` (p.ej. `2026-Q2`) y `observations_total`.

### 2.6 Confirma que el dataset de acceso abierto ya tiene datos

```powershell
curl.exe -s "http://localhost:8000/api/v1/public/observations"
curl.exe -s "http://localhost:8000/api/v1/public/indicators"
```
**✓ Verifica:**
- `public/observations` devuelve un arreglo con tus observaciones **válidas**, con **coordenadas
  redondeadas a celda de 1 km** (no las exactas que enviaste) y el `handle` por observación.
- `public/indicators` devuelve conteos (registrados, observaciones, válidas, etc.) y el `caveat` de
  origen ciudadano.

> Si `public/observations` sale `[]`: o ninguna observación resultó válida (modo `regla`) — sube más
> o usa el modo `fijo` del paso 2.1 — o aún no terminó la validación (espera unos segundos).

---

## Parte 3 — Revisar el **web admin** (navegador)

### 3.1 Instala dependencias (una vez)

```powershell
cd web-admin
flutter pub get
```
**✓ Verifica:** termina con `Got dependencies!` sin errores.

### 3.2 Arranca el web admin con el workaround de CORS

El backend aún no habilita CORS, así que lanzamos Chrome con la verificación de origen relajada
**solo para esta sesión de revisión** (no afecta tu Chrome normal: usa un perfil aparte):

```powershell
flutter run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 `
  --web-browser-flag="--disable-web-security" `
  --web-browser-flag="--user-data-dir=C:\temp\mezquite-chrome"
```
> Crea `C:\temp` si no existe (`New-Item -ItemType Directory C:\temp -Force`). Chrome mostrará un
> aviso amarillo de "seguridad deshabilitada" — es esperado en este modo de revisión.
>
> **Alternativa más limpia (requiere tocar código, opcional):** habilitar CORS en el backend; pídelo
> y lo aplico (ver [Apéndice C](#apéndice-c--notas-de-seguridad-dev)).

**✓ Verifica:** se abre una ventana de Chrome con la pantalla de **login** del web admin (paleta
azul Rotary + dorado, minimalista).

### 3.3 Inicia sesión como administrador

Usa el **handle** y el **código de respaldo** del admin (paso 2.2). (También hay opción de pegar el
token.)

**✓ Verifica:** entras a la consola con una barra de navegación lateral: **Instituciones**,
**Aliados firmantes**, **Indicadores organizacionales**, **Snapshots**, **Dashboard público** y
(si tu rol lo permite) **Dashboard restringido**.

### 3.4 Recorre y verifica cada módulo

| Módulo | Qué hacer | ✓ Verifica |
|---|---|---|
| **Instituciones** | Crear una institución (nombre + estado) | Aparece en la lista como "aprobada" |
| **Aliados firmantes** | Promover un `handle` de voluntario a aliado firmante | Confirma éxito; ese voluntario ahora puede ver coords exactas |
| **Indicadores organizacionales** | Capturar uno (p.ej. "mesas formales" = 2) | Se registra; no hay lógica de aprobación/umbral (solo registro) |
| **Snapshots** | Crear snapshot | Muestra el trimestre "Qn" vigente |
| **Dashboard público** | Abrir | Tabla/mapa con observaciones **obfuscadas a 1 km**, el **caveat de origen ciudadano** visible, sello "Qn" y **filtro por estado** |
| **Dashboard restringido** | (Solo si tu cuenta es aliado firmante) | Coordenadas **exactas**; con cuenta admin-pura la pestaña no aparece (es lo correcto, ver nota) |

> **Nota de diseño (no es bug):** un `admin_consorcio` **no** ve coordenadas exactas a menos que
> además sea `aliado_firmante` — la bitácora reserva las exactas a los aliados firmantes. Para ver el
> dashboard restringido, promueve un voluntario a aliado firmante (3.4) e inicia sesión con **esa**
> cuenta.

Para cerrar el web admin: en la terminal donde corre `flutter run`, presiona `q`.

---

## Parte 4 — Revisar la **app móvil** del voluntario (Android)

La app es **Android nativo** (la captura por cámara es su núcleo), por lo que necesita un **emulador
Android** o un teléfono. Si no tienes emulador, puedes omitir esta parte y revisar solo el web admin.

### 4.1 Arranca un emulador Android

Desde Android Studio (**Device Manager → ▶**) o por consola:
```powershell
flutter emulators                       # lista los emuladores disponibles
flutter emulators --launch <id>         # p.ej. Pixel_7_API_34
```
**✓ Verifica:** `flutter devices` lista el emulador como dispositivo activo.

### 4.2 Instala dependencias y corre la app

```powershell
cd mobile
flutter pub get
flutter run
```
La app usa por defecto `http://10.0.2.2:8000/api/v1`, que en el emulador Android **mapea a tu PC**
(donde corre el backend). No necesitas configurar nada más.

**✓ Verifica:** en el emulador aparece la pantalla de **Bienvenida** del mezquite (paleta Rotary).

### 4.3 Recorre el flujo del voluntario

1. **Registro:** elige una institución (o "Independiente") y crea la cuenta.
   **✓ Verifica:** te muestra el **Código de respaldo** (con QR) — es la recuperación sin PII.
2. **Disclaimer:** aparece una vez; descártalo con un tap.
   **✓ Verifica:** no vuelve a aparecer; queda consultable desde **Ayuda**.
3. **Observar (captura):** abre la cámara nativa, toma una foto y llena las 8 etiquetas
   (nivel **G4** con 4 opciones y su rango %, toggles **cúscuta**/**daño**, dropdowns
   **tamaño**/**contexto**) y envía.
   **✓ Verifica:** el envío **no bloquea** la UI; la observación queda como "pendiente" localmente
   (no se muestra veredicto individual). En el backend aparece como una observación nueva.
4. **Mapa:** muestra observaciones públicas (coords a 1 km).
5. **Perfil:** lifelist, etiqueta de identidad, **feedback agregado** ("de tus últimas N, M válidas").
   **✓ Verifica:** el feedback es agregado, nunca acusación individual.

> **Tip:** si la cámara del emulador no enfoca, usa la "escena virtual" del emulador; para que el
> EXIF lleve ubicación, fija una posición en **Extended controls → Location** del emulador.

Para cerrar la app: presiona `q` en la terminal de `flutter run`.

---

## Parte 5 — Confirmar la capa de **acceso abierto** (resumen)

Con datos cargados (Parte 2), el "acceso abierto" está vivo y es verificable de tres formas:

1. **API pública sin auth** (cualquiera): `GET /api/v1/public/observations` (coords a 1 km) y
   `GET /api/v1/public/indicators` — paso 2.6.
2. **Dashboard público** del web admin: con caveat de origen ciudadano, sello "Qn" y filtro por
   estado — paso 3.4.
3. **Acceso restringido** (coords exactas) solo para un **aliado firmante** autenticado — paso 3.4.

Esto materializa el principio del proyecto: **dataset abierto, obfuscado para proteger el árbol, con
la advertencia de origen ciudadano**; las coordenadas finas solo para aliados firmantes.

---

## Apéndice A — Detener y limpiar

```powershell
# Detener el stack (conserva los datos)
docker compose -f infra/compose/docker-compose.dev.yml down

# Detener y BORRAR los datos (empezar de cero)
docker compose -f infra/compose/docker-compose.dev.yml down -v
```

## Apéndice B — Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `docker version` falla | Rancher Desktop no está corriendo | Ábrelo y espera a que el motor esté listo |
| El web admin no carga datos / errores en consola del navegador | **CORS** | Usa el comando con `--disable-web-security` (3.2) o pide habilitar CORS en el backend |
| `healthz` no responde al inicio | Migraciones aún corriendo | Espera ~30 s; revisa `logs api` |
| `public/observations` sale `[]` | Ninguna observación válida o validación en curso | Sube más, usa modo `fijo` (2.1), o espera unos segundos |
| Puerto 8000/5432/6379 ocupado | Otro proceso usa el puerto | Detén ese proceso o cambia el mapeo de puertos en el compose |
| La app móvil no conecta | Backend caído o IP equivocada | En emulador usa `10.0.2.2`; en teléfono físico usa la IP LAN de tu PC con `--dart-define=API_BASE_URL=...` |
| `result-worker` no etiqueta | mock-validator o redis caídos | `docker compose ... ps`; revisa `logs mock-validator` |

## Apéndice C — Notas de seguridad (dev)

Esta configuración es para **revisión local**, no para producción:

- **Registro con rol (hueco gate #5):** hoy `POST /auth/register` acepta `role`, por lo que cualquiera
  podría auto-asignarse `aliado_firmante` (coords exactas) o `admin_consorcio`. Aquí lo usamos como
  bootstrap del admin, pero **debe cerrarse** antes de cualquier uso no-local (restringir el registro
  a `voluntario` + sembrar el primer admin por configuración/CLI).
- **CORS deshabilitado:** por eso el web admin se revisa con el flag de Chrome. La corrección limpia
  es habilitar `CORSMiddleware` en el backend (orígenes permitidos por entorno).
- **Secretos dev:** `AUTH_SECRET=dev-insecure-secret-change-me` y credenciales `mezquite/mezquite`
  son de juguete; cámbialos en stg/prod (ya parametrizado en los overlays de K8s).

> ¿Quieres que cierre el hueco del gate #5 y habilite CORS (dos cambios chicos, con pruebas)? Lo dejo
> anotado y lo aplico cuando me lo confirmes.

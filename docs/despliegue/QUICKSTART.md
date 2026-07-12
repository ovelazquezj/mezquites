# QUICKSTART — Levantar el sistema y revisar las dos UIs

Guía paso a paso para, desde cero, dejar corriendo el backend, **poblarlo con datos** y **revisar
las dos interfaces**: la **app móvil del voluntario** (Android) y el **web admin del consorcio**
(navegador). Cada paso incluye **cómo saber que se ejecutó correctamente** (✓ Verifica).

> Plataforma de referencia: **Windows + PowerShell** (los comandos usan `curl.exe`, no el alias
> `curl` de PowerShell). Si usas otra shell, adapta las comillas.

## Arranque rápido (TL;DR)

```powershell
# 1) Backend + cola + DB: 3 servicios (YOLO/mock inactivo) — local, sin nube
docker compose -f infra/compose/docker-compose.dev.yml up --build -d
curl.exe http://localhost:8000/healthz            # -> {"status":"ok"}

# 2) Web admin (Chrome) y app móvil (emulador), cada uno en su ventana
.\scripts\start.ps1 web
.\scripts\start.ps1 mobile
.\scripts\status.ps1                              # ver que todo esté arriba
```

¿Probar en un **teléfono real** por HTTPS? → `.\scripts\demo.ps1 start` (túnel ngrok), **Parte 4-bis**.
¿Levantarlo **en la nube** (Dev/QA/Prod)? → [`DESPLIEGUE.md`](DESPLIEGUE.md).

El resto de esta guía explica cada paso a detalle y **cómo verificar** que funcionó.

## Qué vas a tener corriendo

```
┌─ App móvil (Android)   "Entrar con Google"  ┐
│                                             ├──HTTP──▶ API FastAPI (http://localhost:8000)
└─ Web admin (Chrome)    usuario/contraseña   ┘                 │
                                                                ├─ PostGIS (datos)
   Observación ──▶ aceptada por defecto ──▶ revisión humana (web admin) ──▶ confirmada / rechazada
```

Todo se levanta **sin nube** con un solo `docker compose`. La validación automática (YOLO) quedó
**inactiva** (CR-001): la calidad la decide un humano desde el web admin.

## Dos advertencias de entorno (dev) que verás en esta guía

1. **CORS:** el backend aún no habilita CORS, así que el web-admin en el navegador necesita un
   pequeño workaround (Parte 3). Está documentado y **no requiere tocar código**.
2. **Bootstrap de admin (CR-002):** el primer administrador se siembra por **CLI** (la API ya **no**
   concede roles); el login del backend es por **usuario/contraseña** y el de la app por **Google**
   (mock en dev). Ver Parte 2.2 y [Apéndice C](#apéndice-c--notas-de-seguridad-dev).

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
cd C:\dev\mezquites
```

> **No** pongas el repo en OneDrive ni en rutas muy largas: el límite de 260 caracteres de Windows
> (MAX_PATH) rompe los builds de Android/Gradle. Mantén el checkout en una ruta corta como `C:\dev`.

---

## Parte 1 — Levantar el backend y todo el stack

### 1.1 Arranca el stack (en segundo plano)

```powershell
docker compose -f infra/compose/docker-compose.dev.yml up --build -d
```

La primera vez construye imágenes (varios minutos). Levanta el **núcleo de 3 servicios**: `postgres`
(PostGIS), `redis`, `api`. El servicio `api` **aplica las migraciones Alembic (incl. `0002`/`0003`) y
luego arranca**. La frontera §6/YOLO (`mock-validator` + `result-worker`) quedó **inactiva** (CR-001) y
solo se levanta con `--profile yolo`.

**✓ Verifica — servicios arriba:**
```powershell
docker compose -f infra/compose/docker-compose.dev.yml ps
```
Debes ver `postgres` y `redis` en estado **healthy** y `api` en **running / Up** (3 servicios por
defecto; `result-worker`/`mock-validator` solo aparecen con `--profile yolo`).

### 1.2 Confirma que la API responde

```powershell
curl.exe http://localhost:8000/healthz
```
**✓ Verifica:** responde exactamente `{"status":"ok"}`.

Si tarda, las migraciones aún corren. Míralas:
```powershell
docker compose -f infra/compose/docker-compose.dev.yml logs api | Select-Object -Last 20
```
**✓ Verifica:** ves `alembic … running upgrade … 0003_auth_identidad` (tras `0001`/`0002`) y luego
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

### 2.1 Validación (ya no aplica con CR-001)

Con **CR-001** ya **no** hay validación automática: cada observación se **acepta por defecto**
(`estado_revision='aceptada'`) y aparece de inmediato en el dataset público. La calidad la decide un
**humano** desde el web admin (sección **Revisión**, Parte 3). No hay que configurar ningún mock.

### 2.2 Crea la cuenta de administrador (bootstrap, CR-002)

El primer administrador se siembra por **CLI** (no por la API: `register` ya no concede roles).
Dentro del contenedor `api`:

```powershell
docker compose -f infra/compose/docker-compose.dev.yml exec api `
  python -m backend.app.bootstrap --username admin --password "Adm1n-Pass" --email admin@org.mx
```
**✓ Verifica:** imprime `administrador creado: username=admin ...`. Ahora obtén un token con
**usuario + contraseña**:

```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/auth/login `
  -H "Content-Type: application/json" -d '{"username":"admin","password":"Adm1n-Pass"}'
```
Responde `{"handle":"...","role":"administrador","token":"eyJhbGciOi...","must_change_password":false}`.
**Apunta el `token`** (lo usarás para el web admin y para crear evaluadores).

> El `administrador` crea evaluador/analista desde el web admin (sección **Usuarios del equipo**) o
> por `POST /admin/users` (con su token), que devuelve una **contraseña temporal**.

### 2.3 Crea un voluntario (login social con el mock)

En dev `AUTH_PROVIDER=mock`, así que el login con Google se simula con un token `mock:<sub>` (sin red):

```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/auth/google `
  -H "Content-Type: application/json" -d '{"id_token":"mock:demo"}'
```
**✓ Verifica:** JSON con `"role":"voluntario"` (solo se guarda el `sub` opaco; sin email/nombre).
**Copia su `token`** para el siguiente paso (lo llamaremos `TOKEN_VOL`).

### 2.4 Sube varias observaciones

Necesitas un archivo `.jpg` cualquiera (sirve cualquiera; el contenido no importa para el mock).
Repite el comando 6–8 veces cambiando un poco `lat`/`lon` (coordenadas de Aguascalientes):

```powershell
curl.exe -s -X POST http://localhost:8000/api/v1/observations `
  -H "Authorization: Bearer TOKEN_VOL" `
  -F 'payload={"lat":21.881,"lon":-102.291,"captured_at":"2026-05-30T12:00:00Z","nivel_g4":"moderado","flag_cuscuta":false,"flag_danio":true,"tamanio":"mediano","contexto":"campo_abierto"}' `
  -F 'image=@C:\ruta\a\cualquier.jpg'
```
**✓ Verifica:** responde **HTTP 201** con el id de la observación y los **puntos** otorgados al subir.
La observación queda `estado_revision='aceptada'` y **ya es visible** en el dataset público (sin
validación automática; CR-001). Un evaluador puede luego confirmarla o rechazarla desde el web admin.

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
- `public/observations` devuelve tus observaciones **no rechazadas** (todas las recién subidas son
  `aceptada`), con **coordenadas redondeadas a 1 km** (no las exactas) y el `handle` por observación.
- `public/indicators` devuelve conteos y el `caveat` de origen ciudadano.

> Una observación solo **sale** del dataset público si un evaluador la marca **rechazada** desde el
> web admin (Parte 3).

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

Usa el **usuario y la contraseña** del admin (paso 2.2: `admin` / `Adm1n-Pass`). (También hay opción
de pegar el token bajo "Opciones avanzadas".)

**✓ Verifica:** entras a la consola con navegación lateral. Según tu rol verás **Revisión** y
**Monitor** (evaluador/analista/administrador, CR-001), además de **Instituciones**, **Aliados
firmantes**, **Indicadores**, **Snapshots**, **Dashboard público** y (si aplica) **Dashboard restringido**.

### 3.4 Recorre y verifica cada módulo

| Módulo | Qué hacer | ✓ Verifica |
|---|---|---|
| **Revisión** (evaluador/admin) | Abrir una observación de la cola, ver la imagen, **Confirmar**/**Rechazar** + nota | El veredicto cambia `estado_revision`; rechazar la saca del público; la imagen **no** trae GPS salvo aliado firmante |
| **Monitor** (analista, solo lectura) | Ver conteos por estado y throughput | No hay botones de veredicto (solo lectura) |
| **Instituciones** | Crear una institución (nombre + estado) | Aparece en la lista como "aprobada" |
| **Aliados firmantes** | Promover un `handle` de voluntario a aliado firmante | Confirma éxito; ese voluntario ahora puede ver coords exactas |
| **Indicadores organizacionales** | Capturar uno (p.ej. "mesas formales" = 2) | Se registra; no hay lógica de aprobación/umbral (solo registro) |
| **Snapshots** | Crear snapshot | Muestra el trimestre "Qn" vigente |
| **Dashboard público** | Abrir | Tabla/mapa con observaciones de **ubicación exacta**, el **caveat de origen ciudadano** visible, sello "Qn" y **filtro por estado** |
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

**✓ Verifica:** al instalar verás el **ícono** del Proyecto Mezquite (fondo navy `#1F3A6E`) y, en
arranque en frío, el **splash** navy con el logo centrado (CR-003). En Android 12+ el splash usa la API
nativa de splash. En el emulador aparece la pantalla de **Bienvenida** con el wordmark **"Mezquite"**
en serif (Fraunces) y la **paleta oficial Mezquite** (navy/dorado/verde).

### 4.3 Recorre el flujo del voluntario

0. **Onboarding (solo el primer arranque):** aparecen **3 páginas** —*Concientizar · Capacitar ·
   Combatir*— con dots, "Saltar" y botón "Siguiente"/"Comenzar" (CR-003).
   **✓ Verifica:** es **informativo y omitible** (gate #3); al "Comenzar"/"Saltar" no vuelve a
   mostrarse (flag local sin PII). En arranques posteriores la app va directo a Bienvenida.
1. **Entrar con Google (CR-002):** la pantalla de Bienvenida ofrece **"Entrar con Google"** (en dev,
   con el mock; ya **no** hay registro por handle ni código de respaldo/QR).
   **✓ Verifica:** entras sin capturar email/nombre (la app solo usa el `sub` opaco del proveedor).
2. **Disclaimer:** aparece una vez; descártalo con un tap.
   **✓ Verifica:** no vuelve a aparecer; queda consultable desde **Ayuda**.
3. **Observar (captura):** abre la cámara nativa, toma una foto y llena las 8 etiquetas
   (nivel **G4**, toggles **cúscuta**/**daño**, dropdowns **tamaño**/**contexto**) y envía.
   **✓ Verifica:** el envío **no bloquea** la UI; queda **registrada y aceptada** (sin veredicto
   individual). En el backend aparece como observación nueva (`aceptada`).
4. **Mapa (CR-009 + CR-025):** **mapa de calor** a pantalla completa (OSM, encuadre Aguascalientes) con
   celdas coloreadas por severidad y un **toggle calor⇄exacto** que añade **pines en la ubicación exacta**
   del árbol (CR-025); **sin** indicadores ni lista en pantalla — el disclaimer + los números viven tras el
   botón **ⓘ**. Las celdas del calor son un *binning* de agregación (~300 m).
   **✓ Verifica:** desde la **Bienvenida** (sin iniciar sesión) el botón **"Ver el mapa público"** abre
   ese mismo mapa → es la **vista pública** abrible desde internet. Para ver datos, siembra con
   `docker exec compose-api-1 python -m backend.app.seed_demo` (10 obs de Aguascalientes → 9 celdas).
5. **Perfil:** lifelist, etiqueta de identidad y **resumen agregado** de tus aportaciones.
   **✓ Verifica:** el resumen es agregado, nunca acusación individual.

> **Tip:** si la cámara del emulador no enfoca, usa la "escena virtual" del emulador; para que el
> EXIF lleve ubicación, fija una posición en **Extended controls → Location** del emulador.

Para cerrar la app: presiona `q` en la terminal de `flutter run`.

---

## Parte 4-bis — Probar la app en un **teléfono real** (despliegue por ngrok)

La Parte 4 corre en el **emulador** contra `10.0.2.2`. Para probar el APK en tu **teléfono físico
desde cualquier red** (Wi-Fi o datos), exponemos el backend local por **HTTPS** con un túnel **ngrok**
de dominio fijo. Todo se administra con un solo script: **`scripts\demo.ps1`**.

```
teléfono (APK) --HTTPS--> https://<Domain> --ngrok--> http://localhost:8000 (Docker)
```

> **Por qué HTTPS:** Android (targetSdk 35) bloquea tráfico HTTP en claro en release. El túnel ngrok
> da HTTPS, así que no hay que tocar el manifiesto. La app ya envía el header
> `ngrok-skip-browser-warning` para saltarse la página intersticial de ngrok-free.

### 4b.1 Requisitos (una vez)

| Requisito | Cómo |
|---|---|
| `ngrok` en PATH | `winget install ngrok` |
| Cuenta ngrok + token | `ngrok config add-authtoken <token>` (lo copias de tu panel en ngrok.com) |
| Dominio fijo reservado | En ngrok.com → **Domains** → reserva uno (p.ej. `component-embody-sympathy.ngrok-free.dev`) |
| Teléfono con **depuración USB** | Conéctalo por USB y autoriza la PC; `adb devices` debe listarlo |

### 4b.2 Construye el APK apuntando al dominio (una vez)

La URL queda **horneada** en el build (no hay UI de configuración), así que solo se rehace si cambias
el dominio:

```powershell
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<Domain>/api/v1
```
**✓ Verifica:** termina con `✓ Built build\app\outputs\flutter-apk\app-release.apk`. Es un APK
**universal** (incluye `arm64-v8a`, la arquitectura de la mayoría de los teléfonos).

### 4b.3 Instala el APK en el teléfono

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb install -r mobile\build\app\outputs\flutter-apk\app-release.apk
```
**✓ Verifica:** responde `Success`. (Si `adb devices` sale vacío: revisa el cable, autoriza la
depuración USB en el teléfono, o reinicia con `& $adb kill-server; & $adb start-server`.)

### 4b.4 Arranca el stack de demo (backend + túnel)

```powershell
.\scripts\demo.ps1 start
```
Levanta el backend en Docker (`up --build -d`) y el túnel ngrok con tu dominio fijo. Luego:

```powershell
.\scripts\demo.ps1 status
```
**✓ Verifica:**
- `healthz local -> {"status":"ok"}` y los servicios **Up** (postgres/redis **healthy** + api; YOLO inactivo).
- `tunel: https://<Domain> -> http://localhost:8000`.
- El `healthz` público puede mostrar el **aviso intersticial de ngrok** (`ERR_NGROK_6024`) cuando se
  consulta desde un navegador — es esperado; **la app lo evita** con su header. Para comprobarlo como
  lo hace la app: `curl.exe -s -H "ngrok-skip-browser-warning: true" https://<Domain>/healthz` →
  `{"status":"ok"}`.

> Si tu dominio es el de por defecto (`component-embody-sympathy.ngrok-free.dev`) no necesitas pasar
> `-Domain`; en caso contrario: `.\scripts\demo.ps1 start -Domain mi-dominio.ngrok-free.dev` (y rehaz
> el APK del paso 4b.2 con esa URL).

### 4b.5 Abre la app en el teléfono y recorre el flujo

Abre **Mezquite** en el teléfono y sigue el mismo recorrido del voluntario de la Parte 4.3 (registro
→ captura por cámara → mapa → perfil). Ahora los datos viajan a tu backend local por el túnel.

### 4b.6 Comandos útiles del día a día

| Comando | Qué hace |
|---|---|
| `.\scripts\demo.ps1 status` | Estatus de todo + URL pública + healthz |
| `.\scripts\demo.ps1 logs api` | Logs en vivo de un servicio (`api`/`postgres`/`redis`; `result-worker`/`mock-validator` solo con perfil `yolo`) |
| `.\scripts\demo.ps1 logs ngrok` | Logs del túnel |
| `.\scripts\demo.ps1 restart backend` | Reinicia solo el backend (deja el túnel) |
| `.\scripts\demo.ps1 stop` | Detiene túnel + backend (los datos persisten en los volúmenes) |

Para **poblar datos** (admin, voluntarios, observaciones, snapshot) usa la **Parte 2** tal cual —
funciona igual con el stack de demo arriba.

---

## Parte 5 — Confirmar la capa de **acceso abierto** (resumen)

Con datos cargados (Parte 2), el "acceso abierto" está vivo y es verificable de tres formas:

1. **API pública sin auth** (cualquiera): `GET /api/v1/public/observations` (coords a 1 km) y
   `GET /api/v1/public/indicators` — paso 2.6.
2. **Dashboard público** del web admin: con caveat de origen ciudadano, sello "Qn" y filtro por
   estado — paso 3.4.
3. **Acceso restringido** (coords exactas) solo para un **aliado firmante** autenticado — paso 3.4.

Esto materializa el principio del proyecto: **dataset abierto con la advertencia de origen ciudadano**;
las vistas públicas muestran la **ubicación exacta** del árbol (CR-025), junto a un mapa de calor agregado.

---

## Parte 6 — Cuando esté desplegado (apuntar las apps a Dev/QA/Prod)

Toda la guía anterior corre contra `http://localhost:8000`. Cuando el backend viva en un entorno
desplegado (ver [`DESPLIEGUE.md`](DESPLIEGUE.md)), **lo único que cambia en los clientes es
la URL base de la API** — se **hornea** en el build (no hay UI de configuración):

```powershell
# Web admin contra un entorno desplegado
cd web-admin
flutter run -d chrome --dart-define=API_BASE_URL=https://<host-del-entorno>/api/v1

# App móvil (APK) contra un entorno desplegado
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<host-del-entorno>/api/v1
```

| Entorno | `API_BASE_URL` típico |
|---|---|
| Dev local (compose) | `http://localhost:8000/api/v1` (web) · `http://10.0.2.2:8000/api/v1` (emulador) |
| Dev teléfono real (ngrok) | `https://<tu-dominio>.ngrok-free.dev/api/v1` |
| QA (nube, overlay `stg`) | `https://<dominio-qa>/api/v1` |
| Producción (overlay `prod`) | `https://<dominio-prod>/api/v1` |

> **HTTPS en release:** Android (targetSdk 35) bloquea HTTP en claro en release. Cualquier entorno
> desplegado **debe servir por HTTPS** (QA/Prod con TLS en el ingress; en local usa el túnel ngrok).
> Para los pasos de provisión de cada entorno → [`DESPLIEGUE.md`](DESPLIEGUE.md).

---

## Apéndice A — Detener y limpiar

```powershell
# Detener el stack (conserva los datos)
docker compose -f infra/compose/docker-compose.dev.yml down

# Detener y BORRAR los datos (empezar de cero)
docker compose -f infra/compose/docker-compose.dev.yml down -v
```

Si levantaste el **despliegue por ngrok** (Parte 4-bis), detén también el túnel con un solo comando:
```powershell
.\scripts\demo.ps1 stop      # detiene túnel + backend (los datos persisten)
```

## Apéndice B — Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `docker version` falla | Rancher Desktop no está corriendo | Ábrelo y espera a que el motor esté listo |
| El web admin no carga datos / errores en consola del navegador | **CORS** | Usa el comando con `--disable-web-security` (3.2) o pide habilitar CORS en el backend |
| `healthz` no responde al inicio | Migraciones aún corriendo | Espera ~30 s; revisa `logs api` |
| `public/observations` sale `[]` | No has subido observaciones (o todas rechazadas) | Sube observaciones (2.4); las **aceptadas** aparecen de inmediato |
| Puerto 8000/5432/6379 ocupado | Otro proceso usa el puerto | Detén ese proceso o cambia el mapeo de puertos en el compose |
| La app móvil no conecta | Backend caído o IP equivocada | En emulador usa `10.0.2.2`; en teléfono físico usa la IP LAN de tu PC con `--dart-define=API_BASE_URL=...` |
| No aparece **Revisión**/**Monitor** en el web admin | Tu rol no es evaluador/analista/administrador | Inicia sesión con un usuario de revisión (2.2 crea el admin; el admin crea evaluador/analista) |

## Apéndice C — Notas de seguridad (dev)

Esta configuración es para **revisión local**, no para producción:

- **Registro con rol (hueco gate #5): CERRADO por CR-002.** `POST /auth/register` ya **no** acepta
  `role` (siempre `voluntario`); el primer administrador se siembra por CLI
  (`python -m backend.app.bootstrap`) y el admin crea evaluador/analista. Auth de la app por Sign in
  with Google (mock en dev), del backend por usuario/contraseña.
- **CORS deshabilitado:** por eso el web admin se revisa con el flag de Chrome. La corrección limpia
  es habilitar `CORSMiddleware` en el backend (orígenes permitidos por entorno).
- **Secretos dev:** `AUTH_SECRET=dev-insecure-secret-change-me` y credenciales `mezquite/mezquite`
  son de juguete; cámbialos en stg/prod (ya parametrizado en los overlays de K8s).

> ¿Quieres que cierre el hueco del gate #5 y habilite CORS (dos cambios chicos, con pruebas)? Lo dejo
> anotado y lo aplico cuando me lo confirmes.

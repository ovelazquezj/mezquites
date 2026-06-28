# `scripts/` — Administración del stack (PowerShell)

Control unificado del **backend** (Docker Compose), el **web admin** (Flutter Web/Chrome) y la
**app móvil** (Flutter en emulador Android): arrancar, detener, reiniciar y ver estatus — todo a la
vez o un componente a la vez.

> **Independiente de la ruta:** los scripts se autolocalizan con `$PSScriptRoot`, así que **siguen
> funcionando si mueves el repo** (p. ej. a `C:\dev`). No hay rutas absolutas codificadas.

---

## ⭐ `appctl` — controlador de DEMOS y PRUEBAS (front + back)

Un solo comando para **toda la app** con `start | stop | restart | status | logs`, por componente o
todo a la vez. Hay versión **PowerShell** (`appctl.ps1`) y **Bash** (`appctl.sh`) — idénticas.

```powershell
.\scripts\appctl.ps1 start            # backend + web + túnel + admin
.\scripts\appctl.ps1 status           # estado + URLs (pública y local)
.\scripts\appctl.ps1 logs web         # logs de un componente
.\scripts\appctl.ps1 restart web -Build   # reconstruye y reinicia la web
.\scripts\appctl.ps1 stop             # detiene todo (los datos del backend persisten)
```
```bash
./scripts/appctl.sh start             # idéntico en Bash (git-bash / WSL / Linux / macOS)
./scripts/appctl.sh status
./scripts/appctl.sh restart web --build
./scripts/appctl.sh logs tunnel
./scripts/appctl.sh stop
```

| Componente | Qué levanta | Dónde se abre |
|---|---|---|
| **backend** | Docker Compose: postgres + redis + api | `http://localhost:8000` (Swagger en `…/api/v1/docs`) |
| **web** | App del **voluntario** (Flutter Web) tras un **reverse-proxy** (web + API en un solo origen) | se abre por el **túnel** (ver abajo) |
| **tunnel** | Túnel **ngrok HTTPS** → el proxy | **`https://<Domain>`** ← la web del voluntario |
| **admin** | **Web-admin** del consorcio (Flutter Web estático) | `http://localhost:5001` |

| Acción | Objetivo | Qué hace |
|---|---|---|
| `start` | `all` (def) `backend` `web` `tunnel` `admin` | Arranca el/los componente(s). |
| `stop` | idem | Detiene (datos del backend persisten). |
| `restart` | idem | `stop` + `start`. |
| `status` | idem | Estado + URLs (pública y local) + healthz. |
| `logs` | un componente (`backend`/`web`/`tunnel`/`admin`) | Sigue los logs en vivo (`-NoFollow`/`--no-follow` para volcar y salir). |

**Cómo se prueba (importante):**
- La **web del voluntario** se abre por el **túnel HTTPS** (`https://<Domain>`), porque la **cámara y la
  geolocalización** del navegador **requieren contexto seguro (HTTPS)**. La 1ª vez ngrok muestra un aviso →
  toca **"Visit Site"**. (En la URL del túnel, página y API comparten origen vía el proxy: sin CORS ni
  contenido mixto.)
- El **web-admin** se abre en `http://localhost:5001` (consola del operador); inicia sesión con el
  **usuario/contraseña** del administrador (bootstrap, ver `QUICKSTART.md` 2.2).
- `-Build` / `--build` reconstruye el build web (necesario al cambiar de `-Domain` o tras cambios de UI).

**Requisitos:** Docker (Rancher Desktop), Flutter en PATH, `ngrok` autenticado (`ngrok config add-authtoken`),
Python 3 (sirve el web y el proxy). PIDs/logs en `.logs\` (ignorado por git).

> El dominio fijo por defecto es `component-embody-sympathy.ngrok-free.dev`; cámbialo con
> `-Domain mi-dominio.ngrok-free.dev` (PS) o `--domain=mi-dominio…` (Bash) y reconstruye con `-Build`.

> **`appctl` vs los de abajo:** usa **`appctl`** para demos/pruebas de la app completa por HTTPS.
> `manage.ps1` es para **desarrollo local** (web-admin en Chrome + emulador Android); `demo.ps1` es el
> controlador previo (solo backend + ngrok directo). Quedan disponibles, pero `appctl` es el recomendado.

---

## `preparar-rama-deploy.ps1` — build LOCAL + publicar la rama `deploy` (producción)

La VM del piloto (CX22, 4 GB) **no compila Flutter**. Este script, en tu **PC (Windows)**, compila los dos
bundles web y publica la rama **`deploy`** en GitHub con los compilados, lista para que el agente la
despliegue en la VM **sin Flutter** (ver `docs/despliegue/DESPLIEGUE-AGENTE.md` y `DESPLIEGUE-HETZNER.md §9`).

```powershell
.\scripts\preparar-rama-deploy.ps1                 # dominio del piloto, AUTH_MODE=firebase
.\scripts\preparar-rama-deploy.ps1 -AuthMode mock  # piloto cerrado (sin Google)
.\scripts\preparar-rama-deploy.ps1 -Dominio otro-dominio.org
```

Requisitos: **Flutter 3.27** + git en PATH; `mobile/lib/firebase_options.dart` presente (si `firebase`); tu
rama de trabajo **commiteada y empujada** (la rama `deploy` se basa en ese commit). Crea/actualiza
`deploy` = (tu rama) + `mobile/build/web` + `web-admin/build/web` y hace `git push --force origin deploy`.

---

## Uso

Desde la raíz del repo:

```powershell
.\scripts\start.ps1            # arranca TODO (backend -> web -> móvil)
.\scripts\status.ps1           # estatus de todo
.\scripts\stop.ps1             # detiene todo
.\scripts\restart.ps1          # reinicia todo

.\scripts\start.ps1 backend    # solo un componente: backend | web | mobile
.\scripts\stop.ps1 web
.\scripts\restart.ps1 mobile
.\scripts\status.ps1 backend
```

Equivale a `.\scripts\manage.ps1 <acción> <objetivo>` (los atajos solo reenvían).

| Acción | Objetivo | Qué hace |
|---|---|---|
| `start` | `all` (def) `backend` `web` `mobile` | Arranca el/los componente(s). |
| `stop` | idem | Detiene el/los componente(s). |
| `restart` | idem | `stop` + `start`. |
| `status` | idem | Muestra si está corriendo + URLs. |

### Opciones útiles (van al final)

```powershell
.\scripts\stop.ps1 all -KillEmulator     # detiene todo y APAGA el emulador Android
.\scripts\start.ps1 web -NoCorsFlag      # web sin el flag --disable-web-security
.\scripts\start.ps1 mobile -Avd Pixel_8_API_35   # elige un AVD específico
.\scripts\manage.ps1 start -ApiPort 8000 -MobileApiHost 10.0.2.2   # overrides
```

## Qué arranca cada componente

- **backend** → `docker compose up --build -d` (postgres + redis + api + result-worker +
  mock-validator). API en `http://localhost:8000`, Swagger en `…/api/v1/docs`.
- **web** → `flutter run -d chrome` apuntando a `http://localhost:8000/api/v1`. Se abre Chrome en una
  ventana nueva (con su propio perfil) y una ventana de PowerShell con los logs.
- **mobile** → asegura un **emulador Android** (lo arranca en frío con GPU por software si no hay
  ninguno), luego `flutter run -d emulator-XXXX` apuntando a `http://10.0.2.2:8000/api/v1`.

Cada UI corre en su **propia ventana** (logs en vivo + *hot reload* con `r`). `stop` cierra esa
ventana y su árbol de procesos.

## Requisitos

- **Docker** (Rancher Desktop abierto) en PATH.
- **Flutter** en PATH.
- **Android SDK** (emulador + `adb`). Se busca en `ANDROID_SDK_ROOT`/`ANDROID_HOME` o, por defecto,
  `%LOCALAPPDATA%\Android\Sdk`. Necesitas al menos un AVD creado en Android Studio.

## Notas importantes

- **CORS (web):** el backend aún no habilita CORS, así que el web admin se arranca con
  `--disable-web-security` en un perfil de Chrome aparte (no afecta tu Chrome normal). Quita esto con
  `-NoCorsFlag` si más adelante se habilita CORS en el backend.
- **OneDrive / rutas largas (móvil):** compilar Android bajo `…\OneDrive\…` falla por el límite de
  260 caracteres de Windows (MAX_PATH). Si el repo está en OneDrive, `start mobile` te lo **advierte**.
  **Solución:** mueve el repo a una ruta corta como `C:\dev` y compila ahí (los scripts ya funcionan
  desde la nueva ubicación al ser independientes de la ruta).
- **Si PowerShell bloquea los scripts** (política de ejecución):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\manage.ps1 start
  ```
  o, una vez por sesión: `Set-ExecutionPolicy -Scope Process Bypass`.
- **Estado en ejecución:** los PIDs se guardan en `.logs\*.pid` (carpeta ignorada por git). `status`
  los usa para saber qué está vivo.

## Orden recomendado para una demo

```powershell
.\scripts\start.ps1 backend     # 1) levanta API + DB + cola + mock
.\scripts\start.ps1 web         # 2) abre el web admin en Chrome
.\scripts\start.ps1 mobile      # 3) arranca emulador + app del voluntario
.\scripts\status.ps1            # ver que los tres estén arriba
```

## `demo.ps1` — despliegue por ngrok (probar en un teléfono real)

Para que la **app del teléfono** se conecte al backend de la laptop **desde cualquier red** (Wi-Fi o
datos), `demo.ps1` administra el **backend (Docker)** + un **túnel ngrok** con dominio fijo, exponiendo
la API por **HTTPS**.

```
teléfono (APK) --HTTPS--> https://<Domain> --ngrok--> http://localhost:8000 (Docker)
```

```powershell
.\scripts\demo.ps1 start              # backend + túnel ngrok
.\scripts\demo.ps1 status             # estatus + URL pública + healthz (local y público)
.\scripts\demo.ps1 logs api           # logs en vivo de un servicio (api|result-worker|mock-validator|postgres|redis)
.\scripts\demo.ps1 logs ngrok         # logs del túnel
.\scripts\demo.ps1 restart backend    # reinicia solo el backend
.\scripts\demo.ps1 stop               # detiene túnel + backend (datos persisten)
```

| Acción | Objetivo | Qué hace |
|---|---|---|
| `start` | `all` (def) `backend` `ngrok` | Levanta backend (`up --build -d`) y/o el túnel. |
| `stop` | idem | `docker compose stop` y/o mata ngrok (los datos persisten). |
| `restart` | idem | `stop` + `start`. |
| `status` | idem | `ps` + healthz local + URL pública + healthz público. |
| `logs` | `all` `ngrok` o un **servicio** | Sigue los logs en vivo (`-NoFollow` para volcar y salir). |

- **Dominio:** por defecto `component-embody-sympathy.ngrok-free.dev`; cámbialo con `-Domain`.
- **Requisito:** `ngrok` en PATH y autenticado una vez (`ngrok config add-authtoken <token>`).
- **El APK** debe construirse apuntando a ese dominio (una sola vez, porque la URL queda fija):
  ```powershell
  cd mobile
  flutter build apk --release --dart-define=API_BASE_URL=https://<Domain>/api/v1
  ```
- La app móvil ya envía el header `ngrok-skip-browser-warning` para evitar la página intersticial de
  ngrok-free.
- ngrok en background guarda sus logs en `.logs\ngrok.log`; el PID en `.logs\ngrok.pid`.

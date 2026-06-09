# `scripts/` — Administración del stack (PowerShell)

Control unificado del **backend** (Docker Compose), el **web admin** (Flutter Web/Chrome) y la
**app móvil** (Flutter en emulador Android): arrancar, detener, reiniciar y ver estatus — todo a la
vez o un componente a la vez.

> **Independiente de la ruta:** los scripts se autolocalizan con `$PSScriptRoot`, así que **siguen
> funcionando si mueves el repo** (p. ej. a `C:\dev`). No hay rutas absolutas codificadas.

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

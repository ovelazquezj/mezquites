# Runbook — Despliegue en UN SOLO SERVIDOR (piloto a producción)

> **Audiencia:** equipo de infraestructura.
> **Propósito:** desplegar **todo** el software del mezquite en **un único servidor** (una VM de
> cualquier cloud o un servidor propio/on-prem), listo para el **primer piloto a producción**.
> **Agnóstico de proveedor:** sirve para AWS/GCP/Azure/DigitalOcean/Hetzner o hierro propio; solo
> necesitas una máquina Linux con Docker y un dominio. Diseño y justificación: [`CR-014`](change-requests/CR-014-despliegue-servidor-unico.md).
> **Alternativa gestionada (sin K8s):** ruta Azure en [`CR-008`](change-requests/CR-008-despliegue-azure.md) / [`DESPLIEGUE.md`](DESPLIEGUE.md) §5-bis.

Última actualización: 2026-06-18.

---

## 1. Arquitectura (todo en un host)

```
                Internet (HTTPS 443)
                        │
              ┌─────────▼──────────┐
              │   Caddy (proxy)    │  TLS automático (Let's Encrypt)
              │  app.<dominio>     │  sirve bundle Flutter Web (voluntario)
              │  admin.<dominio>   │  sirve bundle Flutter Web (web-admin)
              └─────┬───────┬──────┘
        /api /files /healthz │  (mismo origen ⇒ sin CORS)
                    │        │
              ┌─────▼────────▼─────┐        ┌──────────────────────┐
              │  api (FastAPI)     │───────►│ postgres + PostGIS    │
              │  uvicorn :8000     │        │ (volumen pgdata)      │
              │  imágenes: /data/  │        └──────────────────────┘
              │  storage (volumen) │
              └────────────────────┘
```

- **Un solo `docker compose`** levanta los 3 servicios: `caddy`, `api`, `postgres`.
- **Imágenes** de las observaciones: filesystem local (`STORAGE_BACKEND=local`, volumen `obsdata`). La DB
  guarda **solo la clave**, nunca el binario.
- **Cola §6 (YOLO) inactiva** (CR-001): `BROKER=memory`, **sin Redis** ni workers.
- La API aplica las **migraciones Alembic al arrancar** (`alembic upgrade head`).

Archivos del paquete (en `infra/compose/`): [`docker-compose.prod.yml`](../infra/compose/docker-compose.prod.yml) ·
[`Caddyfile`](../infra/compose/Caddyfile) · [`.env.prod.example`](../infra/compose/.env.prod.example).

---

## 2. Requerimientos de HARDWARE

| Perfil | vCPU | RAM | Disco (SSD) | Para |
|---|---|---|---|---|
| **Mínimo** | 2 | 4 GB | 40 GB | piloto chico (decenas de usuarios, decenas de capturas/día) |
| **Recomendado** | 4 | 8 GB | 80–120 GB | piloto amplio / margen de crecimiento |

- **El disco crece con las imágenes.** Regla de dedo: cada foto ≈ **1–4 MB**. Estima:
  `disco_imagenes ≈ (fotos esperadas) × 3 MB`. Ej.: 20 000 fotos ≈ **~60 GB**. Suma DB (~pocos GB para el
  piloto) + SO (~10 GB) + margen. **Prefiere disco que se pueda ampliar** (volumen elástico).
- **Red:** **IPv4 pública** alcanzable, con **puertos 80 y 443 abiertos** (TLS de Let's Encrypt necesita el 80).
- **Arquitectura:** x86-64 (amd64). En arm64 funciona pero confirma que las imágenes base estén disponibles.
- Sin GPU (la validación automática está inactiva).

---

## 3. Requerimientos de SOFTWARE

En el servidor:

- **SO:** Linux x86-64. Sugerido **Ubuntu 22.04/24.04 LTS** o Debian 12 (cualquiera con Docker sirve).
- **Docker Engine ≥ 24** + **Docker Compose v2** (plugin `docker compose`, no el viejo `docker-compose`).
- **git**, **curl**, **openssl** (para clonar, probar y generar `AUTH_SECRET`).
- **Reloj sincronizado** (NTP) y zona horaria correcta (TLS y tokens lo agradecen).

Para **compilar los bundles Flutter Web** (puedes hacerlo en el propio servidor o en una máquina de build
y copiar el resultado):

- **Flutter 3.27** (incluye Dart).
- **Node.js ≥ 18** + **Firebase CLI** (`firebase-tools`) + **FlutterFire CLI** — solo para configurar Firebase
  (ver §5).

Instalación de Docker en Ubuntu (referencia rápida):

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # reabre sesión para aplicar el grupo
docker compose version          # confirma Compose v2
```

---

## 4. Prerrequisitos externos (los provee el patrocinador/equipo)

1. **Dominio** y acceso al **DNS**. Crea dos registros **A** apuntando a la IP pública del servidor:
   - `app.<dominio>`   → IP del servidor (web del voluntario)
   - `admin.<dominio>` → IP del servidor (web-admin)
2. **Proyecto Firebase / Google Cloud** con *Sign in with Google* (ver §5). **Sin esto el público no puede
   autenticarse** (el `mock` no es para producción abierta).
3. **Aviso de privacidad publicado** (lo exige la pantalla de consentimiento de Google y la LFPDPPP).
4. **(Opcional) Proveedor SMTP** para el reset de contraseña del administrador. Si no hay, el reset degrada
   a "lo hace el administrador" (no bloquea el arranque).

---

## 5. Configuración de Firebase (Sign in with Google) — paso a paso

> Esto cubre el pendiente **CR-004 W1**. Incluye un **paso de código** (generar `firebase_options.dart`),
> normalmente a cargo del equipo de desarrollo; se documenta aquí completo para que quede reproducible.

### 5.1 Crear el proyecto y habilitar Google

1. En <https://console.firebase.google.com> → **Agregar proyecto** (anota el **Project ID**, p. ej.
   `mezquite-prod`).
2. **Build → Authentication → Get started → Sign-in method → Google → Habilitar**. Define el correo de
   soporte. Guarda.
3. **Authentication → Settings → Authorized domains:** agrega `app.<dominio>` (y `admin.<dominio>` si la
   consola también usara Google; hoy la consola entra con usuario/contraseña, así que basta `app`).
4. Configura la **pantalla de consentimiento OAuth** (Google Cloud → APIs & Services → OAuth consent screen):
   scopes `openid`, `email`, `profile`; enlaza el **aviso de privacidad** publicado (§4).

### 5.2 Registrar la app Web

1. En Firebase → **Project settings → General → Your apps → Web (</>)** → registra la app (apodo, p. ej.
   `mezquite-voluntario-web`).
2. No necesitas copiar el snippet a mano: el siguiente paso (`flutterfire configure`) trae la config.

### 5.3 Generar `firebase_options.dart` con **FlutterFire CLI** (paso de código)

Desde una máquina con Flutter y acceso al proyecto Firebase:

```bash
# 1) Herramientas (una vez)
npm install -g firebase-tools            # Firebase CLI
dart pub global activate flutterfire_cli # FlutterFire CLI
export PATH="$PATH":"$HOME/.pub-cache/bin"   # asegura el binario flutterfire en PATH

# 2) Inicia sesión con la cuenta dueña del proyecto Firebase
firebase login        # abre el navegador (en server headless: firebase login --no-localhost)

# 3) Genera la configuración DENTRO del proyecto Flutter del voluntario
cd mobile
flutterfire configure --project=<PROJECT_ID> --platforms=web,android --yes
#   ↳ crea  mobile/lib/firebase_options.dart  con la config de cada plataforma.
#   ↳ para Android también baja google-services.json (solo si harás APK nativo).
```

### 5.4 Cablear las opciones en el arranque de la app (edición de código)

`flutterfire configure` genera `firebase_options.dart`, pero hay que **pasar esas opciones** a
`Firebase.initializeApp` (hoy se llama sin argumentos, lo que basta en Android nativo pero **no** en web).
En `mobile/lib/main.dart`:

```dart
import 'firebase_options.dart'; // generado por flutterfire

// ...dentro del init condicional a AUTH_MODE=firebase:
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

> `firebase_options.dart` **no contiene secretos** (son identificadores públicos del cliente OAuth), pero
> por higiene puede quedar fuera de git si lo prefieres; lo importante es que esté presente al **compilar**.

### 5.5 Backend: confiar en ese proyecto

En `.env.prod`: `AUTH_PROVIDER=firebase` y `FIREBASE_PROJECT_ID=<PROJECT_ID>` (el backend verifica el
`aud`/`iss`/`sub` del ID token de Google contra ese proyecto). No requiere credenciales de servicio.

> **Piloto cerrado/interno sin Google:** si por tiempos lanzas a un grupo controlado, puedes poner
> `AUTH_PROVIDER=mock` (backend) y compilar la web con `--dart-define=AUTH_MODE=mock`. Documenta que NO es
> apto para público abierto y planifica el cambio a `firebase` antes de abrir.

---

## 6. Compilar las imágenes y los bundles web

En el servidor (o en una máquina de build; si es otra, copia `build/web` al servidor por `rsync`/`scp`):

```bash
git clone <REPO_URL> mezquite && cd mezquite

# Bundle del VOLUNTARIO (mismo origen ⇒ API en /api/v1 de su propio dominio)
cd mobile
flutter build web --release \
  --dart-define=API_BASE_URL=https://app.<dominio>/api/v1 \
  --dart-define=AUTH_MODE=firebase            # usa 'mock' solo en piloto cerrado
cd ..

# Bundle de la CONSOLA (web-admin)
cd web-admin
flutter build web --release \
  --dart-define=API_BASE_URL=https://admin.<dominio>/api/v1
cd ..
```

> La **imagen del backend** se construye sola al levantar el compose (`--build`); no requiere registro de
> imágenes. (Opcional: si prefieres una imagen pre-construida, haz `docker build -f backend/Dockerfile -t
> mezquite/backend:prod .`, súbela a tu registro y cambia `build:` por `image:` en el compose.)

`API_BASE_URL` y `AUTH_MODE` se **hornean en tiempo de build**: si cambias dominio o modo de auth, hay que
**recompilar** el bundle.

---

## 7. Desplegar

```bash
# 1) Configura el entorno (secretos incluidos)
cp infra/compose/.env.prod.example infra/compose/.env.prod
nano infra/compose/.env.prod          # edita dominios, contraseñas, AUTH_SECRET, FIREBASE_PROJECT_ID...
chmod 600 infra/compose/.env.prod
#   genera el secreto de tokens:  openssl rand -hex 32   → AUTH_SECRET

# 2) Levanta el stack (construye la imagen del backend la 1ª vez)
docker compose -f infra/compose/docker-compose.prod.yml --env-file infra/compose/.env.prod up -d --build

# 3) Verifica
docker compose -f infra/compose/docker-compose.prod.yml ps     # caddy/api/postgres "Up"
curl -fsS http://127.0.0.1:8000/healthz                        # -> {"status":"ok"} (local)
curl -fsS https://app.<dominio>/healthz                        # -> {"status":"ok"} (vía Caddy + TLS)
```

> El primer arranque de Caddy **emite los certificados TLS**; puede tardar unos segundos y requiere que el
> **DNS ya resuelva** a este host y los puertos 80/443 estén abiertos. Revisa `docker compose ... logs caddy`.

### 7.1 Sembrar el primer administrador (una vez)

```bash
docker compose -f infra/compose/docker-compose.prod.yml exec api \
  python -m backend.app.bootstrap --username admin --password 'CONTRASEÑA_FUERTE' --email admin@<dominio>
```

> Es **idempotente**. (Alternativa: definir `BOOTSTRAP_ADMIN_*` en `.env.prod`.) **Cambia la contraseña**
> tras el primer ingreso. Luego el administrador crea evaluador/analista desde la consola.

---

## 8. Operación

### 8.1 Backups (imprescindible antes de abrir)

```bash
# Base de datos (cron diario sugerido)
docker compose -f infra/compose/docker-compose.prod.yml exec -T postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > /backups/mezquite-$(date +%F).sql.gz

# Imágenes: respalda el volumen `obsdata` (o usa snapshots del disco del proveedor).
```

Programa retención (p. ej. 30 días) y **prueba la restauración** al menos una vez.

### 8.2 Logs y estado

```bash
docker compose -f infra/compose/docker-compose.prod.yml logs -f api      # API
docker compose -f infra/compose/docker-compose.prod.yml logs -f caddy    # TLS / proxy
docker compose -f infra/compose/docker-compose.prod.yml ps
```

### 8.3 Actualizar a una versión nueva

```bash
git pull
# recompila los bundles web si cambió el front (ver §6)
docker compose -f infra/compose/docker-compose.prod.yml --env-file infra/compose/.env.prod up -d --build
#   ↳ la API re-aplica migraciones Alembic al reiniciar (idempotentes).
```

### 8.4 Detener / reiniciar

```bash
docker compose -f infra/compose/docker-compose.prod.yml restart api
docker compose -f infra/compose/docker-compose.prod.yml down       # detiene (los volúmenes persisten)
```

---

## 9. Seguridad y gates (verificar)

- **HTTPS en todo:** Caddy fuerza TLS; la app del voluntario **requiere contexto seguro** para cámara y
  geolocalización del navegador (cubierto).
- **Secretos solo en `.env.prod`** (`chmod 600`, fuera de git: ya está en `.gitignore`). Nada en el repo.
- **CORS** (`CORS_ENV=prod` + `CORS_ALLOW_ORIGINS` con los dos dominios; **nunca** `*`). Cada web es además
  mismo-origen con su API.
- **Gate #5:** `OBFUSCATION_GRID_M=300` (celda pública mínima); coords exactas solo a `aliado_firmante`.
- **Gate #2 (PII mínima):** handle seudónimo; solo el administrador guarda email. Protege la DB y sus backups.
- **DB y API no expuestas** al exterior (la DB no publica puerto; la API solo a `127.0.0.1` para diagnóstico).
- Mantén el SO y Docker **parchados**; considera un firewall que deje pasar solo 22/80/443.

---

## 10. Smoke test (antes de declarar "listo")

- [ ] `https://app.<dominio>/healthz` → `{"status":"ok"}`.
- [ ] **Voluntario:** entrar con Google · capturar una observación (cámara + GPS del navegador) · verla
      registrada · abrir el **mapa público** (celdas ~300 m) · ver **Perfil → Acerca de** (versión `beta-2606`).
- [ ] **Consola** (`https://admin.<dominio>`): login del administrador · bandeja de **Revisión** (confirmar/
      retirar/volver a aceptada) · **Datos y descargas** (tabla + CSV) · **Mapa** · **Instituciones** ·
      **Acerca de**.
- [ ] La imagen de revisión **no expone GPS** salvo a `aliado_firmante` (gate #5).
- [ ] Backup de DB generado y **restauración probada**.

---

## 11. Cuándo migrar a la topología gestionada

El servidor único es ideal para el **piloto**. Si el proyecto crece (alta disponibilidad, escala
horizontal, RPO/RTO estrictos), migra a la ruta gestionada de **CR-008 (Azure)** o a Kubernetes
(`DESPLIEGUE.md` §4/§5). **No cambia el código:** solo flips de configuración (`STORAGE_BACKEND` local→azure_blob/s3,
`DATABASE_URL` a la DB gestionada, `BROKER` si se reactiva §6) — eso es justo lo que garantiza el gate #6.

---

*Referencias:* [`CR-014`](change-requests/CR-014-despliegue-servidor-unico.md) (diseño) ·
[`infra/compose/docker-compose.prod.yml`](../infra/compose/docker-compose.prod.yml) ·
[`infra/compose/Caddyfile`](../infra/compose/Caddyfile) ·
[`infra/compose/.env.prod.example`](../infra/compose/.env.prod.example) ·
[`backend/app/config.py`](../backend/app/config.py) (fuente de verdad de las variables) ·
[`DESPLIEGUE.md`](DESPLIEGUE.md) (Dev/QA/Prod en K8s y Azure).

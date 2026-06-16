# CR-002 — Autenticación con identidad real (Google/Firebase + usuario/contraseña)

| Campo | Valor |
|---|---|
| **ID** | CR-002 |
| **Título** | Login social (Google vía Firebase) para la app + usuario/contraseña para el backend |
| **Fecha** | 2026-06-15 |
| **Estado** | Aprobado por el usuario — **sin codificar** |
| **Prioridad** | Alta (va **después** de CR-001) |
| **Depende de** | CR-001 (roles de backend ya creados) + **prerrequisitos externos del usuario** (§7) |

---

## 1. Contexto y motivación

Hoy la auth es **seudónima sin PII** (gate #2): cuenta por handle + código de respaldo, recuperación
sin PII. El usuario decidió pasar a **identidad real**:
- **App (voluntarios):** iniciar sesión con **Google** (válida).
- **Backend (administrador/evaluador/analista):** **usuario + contraseña**, atados a una persona real
  (no anónimos).

## 2. Decisiones tomadas (del usuario)

1. **Enmendar gate #2** (autorizado): se introduce identidad real.
2. **App = mínima PII:** guardar **solo el id opaco** del proveedor (`provider` + `sub`), **sin** email
   ni nombre.
3. **Mecanismo = Firebase Auth.**
4. **Proveedores = solo Google** al inicio (Facebook después).
5. **Backend = usuario + contraseña**; **solo el `administrador` guarda email** (para **reset por
   correo**). `evaluador`/`analista` **sin email** → su reset lo hace el administrador.
6. **El administrador crea** a evaluador/analista (invitación + contraseña temporal); **no** hay
   auto-registro abierto.
7. **Cuentas móviles actuales: arranque limpio**, sin migración.

## 3. Gates — enmiendas y salvaguardas

**Se enmienda:** **Gate #2** — se permite identidad real. Documentar en la bitácora (fecha/motivo) y
acotar: en la **app** se guarda solo el `sub` opaco (sin email/nombre); en el **backend** la identidad
real es **por diseño** (usuarios reales del consorcio).

**Salvaguardas:**
- **Gate #6 (paridad):** el login social **no puede correr offline**; introducir un **proveedor de auth
  conmutable** (`AUTH_PROVIDER=mock|firebase`) — mock en dev/QA/test, real en prod. Igual que
  broker/storage.
- **Mínima PII en app:** prohibido persistir email/nombre del token de Google; solo `provider_subject`.
- **Legal/operativo (no software, del usuario):** aviso de privacidad + borrado de datos (Google/Play,
  LFPDPPP). Sin esto la app no sale de modo desarrollo.

## 4. Alcance

**Incluye:** `account` multi-método; verificación de ID token de Google/Firebase; login
usuario/contraseña con hashing; gestión de usuarios por el administrador; reset por email (admin) con
SMTP; proveedor de auth conmutable + mock; reemplazo de pantallas de auth en móvil y web-admin; config
y secretos; cierre del hueco del registro con `role`; pruebas y docs.

**No incluye:** Facebook (fase posterior); migración de cuentas viejas (arranque limpio).

## 5. Diseño técnico

### 5.1 Modelo (`backend/app/models.py` + migración `0003_auth_identidad`)

`Account` pasa a **multi-método**:
- `auth_provider` Text CHECK IN `('social_google','password')` (las viejas `handle` se descartan en el
  arranque limpio).
- `provider_subject` Text nullable, **unique** por proveedor (el `sub` opaco de Google).
- `username` Text nullable **unique** (backend).
- `password_hash` Text nullable (backend).
- `email` Text nullable — **solo** para `administrador` (reset). Validar en código que evaluador/analista
  no lo tengan.
- `recovery_hash`/`handle` actuales: revisar si se conservan para legacy o se retiran (arranque limpio
  ⇒ se pueden retirar; decisión del Arquitecto).

### 5.2 Verificación de token Google (app)

- Endpoint **`POST /auth/google`**: recibe el **ID token** de Firebase/Google, lo **verifica**
  server-side (Firebase Admin SDK **o** `google-auth` contra las llaves públicas; validar `aud`/`iss`),
  extrae `sub`, **mapea** `social_google:sub` → cuenta (la **crea** en el primer login con rol
  `voluntario` y un "Usuario" derivado), y emite **nuestro JWT** actual (ya existe en `security.py`).
- Config nueva: `GOOGLE_OAUTH_AUDIENCE` / `FIREBASE_PROJECT_ID` (no secreto) + credenciales Firebase
  Admin si se usa (secreto).

### 5.3 Usuario/contraseña (backend)

- Dependencia de hashing: **argon2-cffi** o `passlib[bcrypt]` (Arquitecto elige; `cryptography` ya está).
- **`POST /auth/login`**: `{username, password}` → verifica hash → emite JWT.
- **Gestión de usuarios (administrador):** `POST /admin/users` (crea evaluador/analista con username +
  contraseña temporal), `PATCH /admin/users/{id}` (rol/estado), `POST /admin/users/{id}/reset`
  (administrador dispara reset). Cerrar el hueco: `POST /auth/register` **deja de aceptar `role`**;
  el primer **administrador** se siembra por **config/CLI** (bootstrap).
- **Reset por email (solo admin):** `POST /auth/password-reset` → envía correo (token de un solo uso).
  Requiere **SMTP** (`SMTP_HOST/PORT/USER/PASSWORD`, secretos).

### 5.4 Proveedor de auth conmutable (gate #6)

- Abstracción `AuthProvider` con implementaciones `FirebaseAuthProvider` y `MockAuthProvider`
  (selección por `AUTH_PROVIDER`). El mock acepta un token de prueba y devuelve un `sub` fijo → dev/QA y
  pruebas corren **sin** red ni Google.

### 5.5 App móvil (`mobile/`)

- Dependencias: `firebase_core`, `firebase_auth`, `google_sign_in`; `google-services.json` en
  `android/app/` (lo provee el usuario, §7).
- **Reemplazar** las pantallas `register_screen.dart` / `recover_screen.dart` / `backup_code_screen.dart`
  por **"Entrar con Google"**; al éxito, mandar el ID token a `POST /auth/google` y guardar el JWT.
- Retirar el flujo de **código de respaldo/QR**. Ajustar copy de login (`ui/copy.dart`).

### 5.6 Web-admin (`web-admin/`)

- **Login por usuario/contraseña** (reemplaza handle+código/token oculto): `login_screen.dart`,
  `state/session.dart`, `api_client.dart`.
- **Pantalla de gestión de usuarios** (administrador): crear evaluador/analista, disparar reset.

### 5.7 Config y secretos (`config.py`, compose, k8s, `docs/DESPLIEGUE.md`)

- No secreto: `AUTH_PROVIDER`, `GOOGLE_OAUTH_AUDIENCE`/`FIREBASE_PROJECT_ID`.
- Secreto: credenciales Firebase Admin (si aplica), `SMTP_*`, `AUTH_SECRET` (ya existe).
- Documentar en `docs/DESPLIEGUE.md` los nuevos secretos por entorno.

## 6. Desglose por agente (unidades construibles)

| # | Agente | Unidad / objetivo | Archivos principales | Pruebas |
|---|---|---|---|---|
| B0 | **Arquitecto** | Decidir lib de hashing y de verificación de token; diseñar `AuthProvider`; enmendar gate #2 en bitácora | `bitacora_sdd_mezquite.md` | — |
| B1 | **Dev backend** | `account` multi-método + migración (5.1) | `models.py`, `alembic/versions/0003_*.py` | migración aplica; constraints |
| B2 | **Dev backend** | Proveedor conmutable + `POST /auth/google` (5.2, 5.4) | `auth provider`, `routers/auth.py`, `config.py` | **mock** verifica token; crea cuenta; JWT |
| B3 | **Dev backend** | `POST /auth/login` + gestión de usuarios + reset SMTP + cierre del hueco `role` (5.3) | `routers/auth.py`, `routers/admin.py`, `security.py` | login ok/ko; admin crea usuario; register sin `role` |
| B4 | **Dev móvil** | Firebase + "Entrar con Google" + retiro de código/QR (5.5) | `mobile/lib/src/ui/screens/*`, `api/api_client.dart`, `pubspec.yaml`, `android/app/` | sign-in mockeado; flujo de login |
| B5 | **Dev web-admin** | Login usuario/contraseña + gestión de usuarios (5.6) | `web-admin/lib/src/screens/*`, `state/session.dart`, `api_client.dart` | login; alta de usuario |
| B6 | **Tester/QA** | Suite completa + trazabilidad de auth | `backend/tests/*`, `*/test/*`, `TRACEABILITY.md` | todas verdes; **no PII de más** |
| B7 | **Documentador** | Bitácora (gate #2), DESPLIEGUE, QUICKSTART, README de auth | docs varios | secretos y pasos al día |

## 7. Prerrequisitos del usuario (fuera del código — bloqueantes para producción)

1. **Proyecto Firebase** (Google Cloud) con **Authentication → Google** habilitado (define **H6** para auth).
2. **App Android registrada** en Firebase: package `com.mezquite.app` + **huellas SHA-1/SHA-256**
   (debug la genera el equipo con `gradlew signingReport`; **release** la provee el usuario o confirma el
   keystore de release).
3. **`google-services.json`** colocado en `mobile/android/app/`.
4. **Pantalla de consentimiento OAuth** (scopes `openid email profile`).
5. **Aviso de privacidad** + **borrado de datos** publicados (URLs).
6. (Backend) credenciales **SMTP** para el reset por correo del administrador.

> El equipo de agentes puede implementar y probar **todo con el `MockAuthProvider`** sin estos
> prerrequisitos; la activación con Google real requiere 1–5.

## 8. Criterios de aceptación (trazables — gate #7)

- AC1: `POST /auth/google` con el **mock** crea la cuenta `voluntario` (solo `provider_subject`, **sin**
  email/nombre) y devuelve un JWT válido. *(test backend, gate #2 acotado)*
- AC2: `POST /auth/login` valida usuario/contraseña (hash) y rechaza credenciales malas. *(test backend)*
- AC3: El `administrador` crea un `evaluador` (sin email) y un segundo `administrador` (con email);
  `POST /auth/register` **ya no acepta `role`**. *(test backend, cierra hueco gate #5)*
- AC4: Persistencia **sin PII de más**: ninguna cuenta `voluntario` guarda email/nombre. *(test backend)*
- AC5: `AUTH_PROVIDER=mock` permite correr la suite **sin red** (gate #6). *(test backend)*
- AC6: La app móvil muestra **"Entrar con Google"** y completa login con el flujo mockeado; ya **no**
  hay código de respaldo/QR. *(test móvil)*
- AC7: El web-admin inicia sesión con **usuario/contraseña**; el administrador ve la pantalla de gestión
  de usuarios. *(widget tests)*
- AC8: `TRACEABILITY.md` mapea AC1–AC7; suite global verde.

## 9. Riesgos

- **Persistir PII de más** (email/nombre del token) → AC4 lo bloquea.
- **Dependencia de red en pruebas** → `MockAuthProvider` (AC5).
- **Huella SHA equivocada** → "Entrar con Google" falla solo en el teléfono real; validar con el APK de release.
- **Reset por email sin SMTP** → degradar a "reset por el administrador" si no hay SMTP configurado.

## 10. Definition of Done

Pruebas verdes (números reales), gate #2 enmendado y **acotado** en la bitácora (app = `sub` opaco;
backend = identidad real), gates #3/#4/#5/#6/#7 intactos, `AUTH_PROVIDER=mock` corriendo offline, docs
y secretos por entorno documentados en `docs/DESPLIEGUE.md`.

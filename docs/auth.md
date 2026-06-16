# Autenticación (CR-002) — identidad real con mínima PII

> Implementa el amendment Q5.D-D1 de la bitácora (gate #2 **acotado**). App = Sign in with Google;
> backend = usuario/contraseña. Proveedor de auth **conmutable** (`mock|firebase`) por paridad
> (gate #6). Para configurarlo por entorno, ver [`DESPLIEGUE.md`](DESPLIEGUE.md) §2.1–§2.3.

## Modelo de cuenta (`account`, multi-método)

| Campo | App (`voluntario`) | Backend (`administrador`/`evaluador`/`analista`) |
|---|---|---|
| `auth_provider` | `social_google` | `password` |
| `provider_subject` | el `sub` opaco de Google (único) | — |
| `username` / `password_hash` | — | usuario + hash **argon2** |
| `email` | **nunca** (gate #2 acotado) | **solo `administrador`** (reset por SMTP) |
| `handle` | identificador de presentación sin PII (derivado del `sub`) | igual |

Salvaguarda autoritativa: el CHECK `ck_account_email_only_admin` impide guardar `email` en cualquier
rol que no sea `administrador`. El JWT (firmado con `AUTH_SECRET`) lleva solo `sub`/`handle`/`role`.

## Endpoints

| Endpoint | Quién | Qué hace |
|---|---|---|
| `POST /auth/google` | app (voluntario) | Verifica el ID token (mock\|firebase), mapea `social_google:sub` → cuenta (la crea en el 1er login) y emite JWT. Guarda **solo** el `sub`. |
| `POST /auth/login` | backend | Usuario + contraseña (argon2) → JWT. |
| `POST /auth/register` | app (legado) | Alta de **voluntario** seudónimo. **Ya no acepta `role`** (cierra el hueco del gate #5). |
| `POST /auth/recover` | legado | Recuperación por código de respaldo (cuentas viejas; sin PII). |
| `POST /auth/password-reset` | administrador | Reset por correo (requiere email + SMTP; **degrada** a `delivered=false` si no hay SMTP). |
| `GET/POST /admin/users`, `PATCH /admin/users/{id}`, `POST /admin/users/{id}/reset` | **administrador** | Crea evaluador/analista/administrador (contraseña temporal), cambia rol, dispara reset. `email` solo para `administrador`. Nunca expone el email (solo `has_email`). |

## Proveedor de auth conmutable (gate #6)

`backend/app/auth_provider.py`:
- `MockAuthProvider` (`AUTH_PROVIDER=mock`, por defecto): offline. Acepta `MOCK_GOOGLE_TOKEN` (→ `sub`
  fijo) o cualquier token `mock:<sub>` (→ `sub=<sub>`). Permite correr la suite **sin red ni Google**.
- `FirebaseAuthProvider` (`AUTH_PROVIDER=firebase`): verifica el ID token con `google-auth` (firma,
  `aud`/`iss`) y extrae el `sub`. Importa `google-auth` de forma perezosa.

En la app móvil el equivalente es `AUTH_MODE` (`mock|firebase`) + `GoogleAuthService`
(`MockGoogleAuthService` / `FirebaseGoogleAuthService`). El build **no exige `google-services.json`**:
`Firebase.initializeApp()` solo se llama si `AUTH_MODE=firebase`.

## Bootstrap del primer administrador

No hay auto-registro de roles. El primer administrador se siembra por config/CLI (idempotente):

```bash
python -m backend.app.bootstrap --username admin --password 'S3cr3t!' --email admin@org.mx
# o por BOOTSTRAP_ADMIN_USERNAME / _PASSWORD / _EMAIL
```

## Activar Google real (prerrequisitos del usuario)

Proyecto Firebase + Authentication→Google · app Android `com.mezquite.app` con huellas SHA-1/SHA-256 ·
`google-services.json` en `mobile/android/app/` + plugin Gradle Google Services · consentimiento OAuth
(`openid email profile`) · aviso de privacidad + borrado de datos (Google/Play, LFPDPPP). Detalle paso
a paso en [`DESPLIEGUE.md`](DESPLIEGUE.md) §2.2.

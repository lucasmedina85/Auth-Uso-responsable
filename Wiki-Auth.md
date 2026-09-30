# Autenticación y Autorización (Fase 1 y 2)

## Flujo de Seguridad en Backend
1. **Registro:** `POST /auth/register`. Hashea la contraseña con Argon2id. Genera el usuario en estado `REGISTERED`. No se devuelve token.
2. **Login:** `POST /auth/login`. Valida el hash (resiste ataques de tiempo). En éxito, retorna `accessToken` (15m) y `refreshToken` (7d) rotativo (opaco, guardado su hash SHA-256 en base).
3. **Refresco:** `POST /auth/refresh`. Intercambia el `refreshToken` por un nuevo par. Si se detecta un reuso de un token (marcado como `used`), se borra TODA la familia de tokens del usuario (Revocación completa).
4. **Logout:** `POST /auth/logout`. Revoca el `refreshToken` borrándolo y bloquea el `jti` del `accessToken` en la tabla de `revoked_tokens` hasta su expiración real.
5. **Rate Limiting:** IP/Dispositivo con Bucket4j en el endpoint de login.

## Flujo en Frontend
- Los tokens viven ÚNICAMENTE en `flutter_secure_storage`.
- La UI se blinda por un `SessionService` local que revisa el estado `LOCALLY_VERIFIED`. Si no está verificado localmente, la ruta te fuerza a la captura DNI.
- La validación del DNI usa criptografía local (hash con pepper). Se reporta al backend mediante `POST /verification/local-result`, pero **se avisa** que este resultado no es probatorio sin validación de motor remoto.

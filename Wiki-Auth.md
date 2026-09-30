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

## Casos de Uso Avanzados de Seguridad (Fase 3 y 4)
- **CU-0026 (TTL):** El usuario puede configurar en el menú la vigencia de su sesión. Los valores se ajustan al JWT generado por backend y persisten localmente en `SharedPreferences`.
- **CU-0038 y CU-0043 (Bloqueos y Suplantación):** Si el endpoint simulado `POST /verification/local-result` detecta un hash anómalo (SPOOFING o BLOCKED), responde con un error 403 que es atrapado por un interceptor central en Dio, redireccionando de inmediato al usuario a una pantalla de Alerta Roja (`SecurityAlertScreen`) bloqueando el progreso.
- **CU-0047 y CU-0048 (Trazabilidad y Forense):** La vista del Historial de Seguridad permite al usuario o a un auditor exportar todo el registro interno a un archivo `.csv` firmado y enviarlo/compartirlo de forma nativa a través de `share_plus` para análisis forense.
- **CU-0040 (Notificaciones Push Simuladas):** A falta de un servidor FCM en desarrollo, el `NotificationService` enmascara un canal interno vía `flutter_local_notifications` para lanzar alertas push de manera local, simulando la detección de un inicio de sesión remoto u operación de riesgo detectada on-premise.

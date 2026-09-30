# Auth - Uso Responsable

Aplicación de autenticación con doble factor, validación de identidad (DNI/Liveness) y motor de riesgo.
Compuesta por una App móvil en Flutter y un backend de validación en Spring Boot.

## Arquitectura de Seguridad
- **Backend (Spring Boot):** Maneja el estado definitivo de la sesión de usuario, validando credenciales (Argon2id) y gestionando tokens JWT (Access de corta duración, Refresh Tokens rotativos con denylist `jti`).
- **Frontend (Flutter):** Almacena de manera segura únicamente los tokens de sesión usando keystore. No guarda ni manipula localmente datos de credenciales explícitas o biometría después del login/validación.

### Verificación de Identidad (`VERIFICATION_MODE`)
- **Modo Local:** El dispositivo evalúa el DNI (OCR) y prueba de vida. Es **auto-informado** y asume confianza en el cliente para fines de demostración o fases iniciales.
- **Modo Remoto (Didit/RENAPER):** La evaluación se delega a servicios terceros verificables criptográficamente en backend.

*Nota de seguridad: Los tests locales y la base H2 en memoria exponen APIs protegidas por un esquema Fail-Closed. En producción, la conexión con PostgreSQL y el manejo de JWT_SECRET deben pasarse siempre por variables de entorno seguras.*


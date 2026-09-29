# Plan de Implementación: Validación de Identidad Hospedada (Didit/Mock)

## 1. Backend (`backend_service` - Spring Boot)
Noté que el directorio `backend_service` solo contiene el `pom.xml` vacío (sin código fuente). Se creará la estructura estándar de Java (`src/main/java/com/authenticator`):

- **Configuración y Entorno:**
  - Crear `application.yml` para bindear variables como `IDENTITY_PROVIDER`, `DIDIT_API_KEY`, `DIDIT_WORKFLOW_ID`, `DIDIT_WEBHOOK_SECRET`.
  - Crear `.env.example` y añadir `.env` a `.gitignore`.
  - Añadir dependencias en `pom.xml` si faltan (ej. `resilience4j` para Circuit Breaker y Retry, `spring-boot-starter-webflux` para llamadas HTTP asíncronas).

- **Dominio / Interfaces:**
  - `IdentityVerificationProvider` (Interfaz: `startVerification`, `getResult`, `checkHealth`).
  - `VerificationResult` (DTO: `matchType`, `faceMatchScore`, `isLatestDocument`, `fieldValidations`).
  - DTOs de Request/Response de los endpoints.
  - Excepciones tipadas (`ProviderTimeoutException`, etc.) y un `@ControllerAdvice` para mapearlas a respuestas HTTP limpias.

- **Implementaciones del Proveedor:**
  - `DiditVerificationProvider`: Llama a `POST https://verification.didit.me/v3/session/` inyectando el auth por cabeceras. Aplica `CircuitBreaker` (falla abierta a los 3 errores).
  - `MockVerificationProvider`: Crea una sesión falsa y delega a un temporizador asíncrono simular el comportamiento humano, actualizando el estado de la verificación localmente tras unos segundos para emular el Webhook de Didit (ideal para las demos).
  - `OfficialVerificationProvider`: Retorna `NotImplemented`.

- **Controladores y Webhooks:**
  - `VerificationController`:
    - `POST /api/v1/verification/start` (inicia sesión, devuelve URL).
    - `GET /api/v1/verification/session/{sessionId}` (polling desde la app).
    - `POST /api/v1/verification/webhook` (Recibe la actualización de Didit, valida firma usando `DIDIT_WEBHOOK_SECRET` y actualiza la sesión en memoria/DB).

## 2. App Android (`flutter_app`)
Como el flujo ahora es *hospedado*, todo el escaneo manual de DNI y Detección Facial nativa de la App de Flutter pasa a ser responsabilidad de Didit en la web:

- **Refactorización de Flujo:**
  - Eliminar la lógica y dependencias nativas de cámara y MLKit (`camera`, `google_mlkit_face_detection`) si no se utilizan en ninguna otra parte, para reducir peso.
  - Reemplazar las pantallas `DniCaptureScreen` y `FaceLivenessScreen` por una única pantalla central `HostedVerificationScreen`.
  
- **Lógica de `HostedVerificationScreen`:**
  - Hace POST al backend `/start`. Recibe la `url`.
  - Lanza la `url` mediante `url_launcher` en modo In-App Browser (o `webview_flutter`).
  - Inicia un *polling* al endpoint `/session/{sessionId}` cada 3 segundos.
  - Al detectar estado APROBADO, se cierra el navegador in-app y avanza al CU de Huella. Si es RECHAZADO, muestra mensaje de error sin incrementar intentos locales. Si hay fallo del backend (Circuit breaker abierto), muestra "Servicio en mantenimiento".

## 3. Documentación
- Actualizar `AI_HANDOVER.md` y `WIKI.md` indicando los Casos de Uso (CU-0003, CU-0010, etc.) delegados a proveedor y cómo levantar `ngrok`/túnel para recibir los webhooks en entorno local.

---
**¿Estás de acuerdo con este plan? Si me das el OK, comienzo por la estructura y dependencias del backend de a pasos pequeños.**

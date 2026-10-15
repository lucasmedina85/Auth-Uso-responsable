# Auth - Uso Responsable

Aplicación de autenticación con doble factor, validación de identidad (DNI/Liveness), motor de riesgo y bitácora criptográfica inmutable.
Diseñada para operar en modo dual:
1. **Modo Local Autónomo (100% Offline / Demostración Docente):** Funciona íntegramente en el dispositivo móvil sin servidores, sin conexión a internet y con base de datos SQLite embebida.
2. **Modo Remoto (Cliente/Servidor):** Se conecta a los microservicios Spring Boot con PostgreSQL y servicios externos de validación (Didit / RENAPER).

---

## 📱 Modo Local Autónomo (Demostración Docente 100% Offline)

El modo local permite ejecutar y demostrar la totalidad de los flujos del sistema en un dispositivo físico o emulador **sin depender de internet ni de infraestructura externa**.

### Características Implementadas

1. **Base de Datos Embebida (SQLite / `sip_local.db`):**
   - `local_users`: Almacenamiento seguro de credenciales con salt individual y hash PBKDF2.
   - `local_devices`: Gestión de dispositivos confiables y estado de enrolamiento.
   - `local_activity_logs`: Registro cronológico y forense de accesos y eventos de seguridad.
   - `local_audit_chain`: Bitácora inmutable con encadenamiento criptográfico (CU-0050).
   - `local_linked_apps`: Registro de aplicaciones vinculadas (TOTP y OAuth).
   - `local_oauth_tokens`: Registro de tokens de acceso emitidos con estado y revocación.

2. **Criptografía Pura en Dart (Sin dependencias externas ni red):**
   - **PBKDF2-HMAC-SHA256** con 10,000 iteraciones y salt aleatorio de 16 bytes.
   - **Mitigación de Timing Attacks y Enumeración:** Si un usuario no existe, se calcula un hash ficticio para mantener el tiempo de respuesta uniforme.
   - **Bloqueo Temporal:** Tras 5 intentos fallidos se aplica un bloqueo de 60 segundos con cabecera `Retry-After`.
   - **SHA-256 y HMAC-SHA256:** Para el encadenamiento de auditoría y firma forense de exportaciones.

3. **Motor de Riesgo Local (`LocalRiskEngine`):**
   - Implementado en Dart siguiendo los mismos pesos y reglas del motor backend:
     - Detección de emulador / hardware alterado (+100 puntos -> BLOQUEAR).
     - Dispositivo comprometido o con root (+100 puntos -> BLOQUEAR).
     - DNI en lista negra (+100 puntos -> BLOQUEAR).
     - Cuenta bloqueada temporalmente (+100 puntos -> BLOQUEAR).
     - DNI no coincidente con el último ejemplar (+50 puntos -> REVISIÓN).
     - Anomalías de comportamiento y red (+10 a +20 puntos).

4. **Validación Biométrica Facial Determinística:**
   - La prueba de vida y el cotejo facial están calibrados para **triunfar siempre de forma determinística** (score 95%) en el escenario por defecto, evitando fallos de iluminación o cámara durante la exposición ante el docente.

5. **Bitácora Criptográfica Inmutable (CU-0050):**
   - Cada evento se encadena criptográficamente calculando:  
     $$\text{hash}_i = \text{SHA256}(\text{index} : \text{timestamp} : \text{eventType} : \text{payload} : \text{prev\_hash})$$  
     con la restricción $\text{prev\_hash}_i == \text{hash}_{i-1}$ y bloque génesis en $\text{index} = 0$.
   - **Pantalla de Verificación (`/audit_chain`):** Permite inspeccionar los bloques, verificar la integridad completa en tiempo real y **simular un ataque de alteración** para demostrar al profesor cómo la app detecta inmediatamente la manipulación de registros.

6. **Plataforma Externa Simulada y OAuth Playground (CU-0027):**
   - Pantalla interactiva (`/oauth_playground`) para simular la integración con terceros (ej. Casino Online / Juego Responsable).
   - Flujo de autorización completo con pantalla de consentimiento (`OauthConsentScreen`).
   - **Emisión de Tokens con Cero Datos Personales (Zero PII):** Los tokens contienen exclusivamente `sub`, `client_id`, `scope`, `iat`, `exp` y `jti`. Nunca viajan contraseñas, DNI, nombres ni emails.
   - Soporte para inspección de claims y **revocación inmediata** de tokens.

7. **Exportaciones Forenses Certificadas (CU-0048):**
   - Exportación de actividad y aplicaciones con firma digital y hash SHA-256.
   - Apertura directa del **Android Share Sheet** mediante `share_plus` sin conexión a internet.

---

## 🔑 Credenciales Precargadas (Modo Demo)

La base de datos SQLite se inicializa automáticamente con el siguiente usuario de prueba:

| Campo | Valor |
|---|---|
| **Email** | `demo@sip.local` |
| **Contraseña** | `Demo12345!` |
| **Estado** | `LOCALLY_VERIFIED` (Verificado y listo) |

> **Tip:** En la pantalla de Login se incluye un chip de acceso rápido **"Cargar credenciales demo"** que completa automáticamente los campos para agilizar la presentación.

---

## 🎭 Selector Interactivo de Escenarios Demo

En la parte superior de las pantallas principales se muestra el banner:
`MODO DEMO – datos locales y simulados`

Al presionar el botón **"Cambiar"**, se abre un menú inferior con los siguientes escenarios configurables en caliente:

1. **Éxito (Flujo normal):** Todo opera de forma óptima, el login triunfa, la biometría valida con score 95% y el motor de riesgo autoriza (0 puntos).
2. **En Revisión:** Simula un score de riesgo de 60 puntos para demostrar la derivación a revisión manual del operador.
3. **Bloqueo por Riesgo:** Simula un score de 100 puntos bloqueando el acceso de forma preventiva.
4. **Suplantación Facial:** Simula una falla en la prueba de vida (intento de spoofing con foto/video) para mostrar la alerta de seguridad.
5. **DNI Denunciado:** Simula un documento reportado como extraviado/robado en lista negra.

---

## 📦 APK Final de Demostración

El binario de producción para la demostración fue compilado con optimizaciones de Release, firmas locales y exclusión total de red:

- **Ruta del archivo:** `dist/SIP-App-demo-1.0.0+1.apk`
- **Versión:** `1.0.0+1` (VersionName: 1.0.0, VersionCode: 1)
- **Tamaño:** `158,096,127 bytes` (~151 MB)
- **Hash SHA-256:**
  ```
  214f631691f1e5c1cccd95324d9b390a63a9af1da3dc20052ec89942aad9883a
  ```
- **Copia de respaldo previa (Fase 1):** `dist/SIP-App-demo-backup-fase1.apk` (SHA-256: `d6a90bfa1eac4c84a77ccb3dd798a4bf55fd3faa133942f29b630a4ce3b19954`)

*(Nota: La carpeta `dist/` se encuentra agregada a `.gitignore` para cumplir con las mejores prácticas y no subir binarios pesados al repositorio git).*

---

## 🚀 Instrucciones de Ejecución y Compilación

### Compilar el APK de Release (Modo Local):
```bash
cd flutter_app
flutter build apk --release --dart-define=BACKEND_MODE=local
```

### Ejecutar en Dispositivo Móvil o Emulador:
```bash
cd flutter_app
flutter run --dart-define=BACKEND_MODE=local
```

### Ejecutar en Modo Remoto (Con Backend Spring Boot):
```bash
cd flutter_app
flutter run --dart-define=BACKEND_MODE=remote --dart-define=API_URL=http://tu-servidor:8080
```

### Ejecutar Suite de Tests Unitarios Offline:
```bash
cd flutter_app
flutter test test/core/ test/logic/
```

---

## 🏛 Arquitectura Original de Seguridad (Modo Remoto / Backend)

- **Backend (Spring Boot):** Maneja el estado definitivo de la sesión de usuario, validando credenciales (Argon2id) y gestionando tokens JWT (Access de corta duración, Refresh Tokens rotativos con denylist `jti`).
- **Frontend (Flutter):** Almacena de manera segura únicamente los tokens de sesión usando keystore/KeyChain. No guarda ni manipula datos de credenciales explícitas o biometría después del login/validación.
- **Fail-Closed Enforcement:** En modo local, `DioClient` intercepta cualquier intento de llamada a la red HTTP/HTTPS y lo cancela inmediatamente arrojando un error controlado sin realizar conexiones de socket.

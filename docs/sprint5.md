# Sprint 5: Implementación de Señales de Riesgo y Seguridad de Dispositivo

Este documento detalla la implementación, arquitectura y modelo de amenazas de las tres señales de riesgo desarrolladas en el Sprint 5 para **SIP | App** (Frontend Flutter y Backend Spring Boot).

---

## 1. Casos de Uso Implementados

| Caso de Uso | Título | Estimación | Estado |
| :--- | :--- | :--- | :--- |
| **CU-0034** | Bloqueo por Detección de Emulador | 3 SP | **HECHO** |
| **CU-0032** | Detección de Uso de VPN/Proxies | 5 SP | **HECHO** |
| **CU-0035** | Evaluación de Comportamiento de Interfaz | 3 SP | **HECHO** |
| **CU-0023** | Cálculo de Score de Riesgo Compuesto | 8 SP | **HECHO** |
| **CU-0030** | Registro de Auditoría en Blockchain | 5 SP | **HECHO** |
| **CU-0031** | Consulta de Consenso de Red | 5 SP | **HECHO** |
| **CU-0027** | Transmisión de Token a Plataforma Externa | 5 SP | **HECHO** |

---

## 2. CU-0034: Bloqueo por Detección de Emulador (3 SP)

### 2.1. Objetivo y Reglas de Negocio
Detectar si la aplicación móvil Android se está ejecutando sobre emuladores o entornos virtualizados de PC (Android Virtual Device / AVD, Bluestacks, Nox, Genymotion, MEmu, LDPlayer) para evitar automatizaciones, granjas de identidades o suplantaciones remotas.
- **Postcondición**: Bloqueo total e inmediato de la sesión de validación desde el origen en el celular y en el backend.
- **Política de Bypass**: El bypass está prohibido en configuraciones visuales (sin switches en UI ni persistencia en `SharedPreferences`). Existe única y exclusivamente mediante bandera de compilación `--dart-define=BYPASS_EMULATOR_CHECK=true` y condicionada estrictamente a `kDebugMode == true`. En entornos productivos (`kReleaseMode`), se ignora irrevocablemente.
- **Auditoría**: Se transmite la señal `emulatorDetected` (boolean) en la petición `POST /verification/local-result`, persistiendo el estado en la sesión para trazabilidad y activando la regla dura del motor de riesgo (Score = 100, `BLOQUEAR`).

### 2.2. Arquitectura de Implementación
1. **Detección Nativa Android (`EmulatorDetector.kt`)**:
   - **Propiedades de compilación**: Inspección de `Build.FINGERPRINT`, `Build.MODEL`, `Build.MANUFACTURER`, `Build.HARDWARE`, `Build.PRODUCT`, `Build.BOARD`, `Build.BOOTLOADER`.
   - **Tuberías y archivos de emuladores**: Detección de binarios y pipes qemu (`/dev/socket/qemud`, `/dev/qemu_pipe`, `/system/bin/nox-prop`, `vboxguest`, etc.).
   - **SystemProperties**: Lectura por reflexión de propiedades (`ro.kernel.qemu`, `ro.hardware.virtual_device`, etc.).
   - **Sensores físicos**: Comprobación mediante `SensorManager` de la presencia de acelerómetro y sensor de proximidad (ausentes por defecto en la mayoría de entornos emulados).
2. **Canal de Plataforma Flutter (`MethodChannel`)**:
   - Expone el método `checkEmulator` a través de `com.authenticator/security`.
3. **Servicio y UI Flutter**:
   - `EmulatorDetectionService`: Servicio centralizado que evalúa el canal nativo y aplica la regla de bypass seguro.
   - `EmulatorBlockedScreen`: Pantalla bloqueante (`PopScope(canPop: false)`) con código de error explicativo para el usuario.
   - Guardias de navegación en `DeviceSecurityScreen` y captura de respuesta HTTP 403 `EMULATOR_DETECTED` en `FaceLivenessScreen`.
4. **Backend Spring Boot**:
   - `LocalVerificationRequest`: Incorpora `emulatorDetected`.
   - `VerificationLocalController`: Regla dura que responde HTTP 403 con código `EMULATOR_DETECTED` y actualiza la sesión con `REJECTED_EMULATOR_DETECTED`.
   - `RiskEngineService`: Regla dura que asigna 100 puntos y decisión `BLOQUEAR`.

---

## 3. CU-0032: Detección de Uso de VPN/Proxies (5 SP)

### 3.1. Modelo de Confianza y Jerarquía de Evidencia
Las conexiones VPN o proxies pueden ser utilizadas para ocultar la ubicación geográfica real o eludir controles perimetrales. Sin embargo, existe una asimetría clave de seguridad:
- **Evidencia Verificada por Backend (Autoritativa - Alto Peso)**: La IP remota real obtenida en el backend (`HttpServletRequest`) y resuelta considerando proxies reversos de confianza (`IpResolver`). Al ser validada contra rangos CIDR conocidos de VPNs comerciales, proxies corporativos y ASNs de centros de datos, constituye prueba irrefutable. Asigna nivel `ALTO` (+30 puntos) o `MEDIO` (+15 puntos).
- **Señales de Cliente (No Confiables - Bajo Peso Complementario)**: Las banderas reportadas por el cliente (`clientVpnDetected`, `clientProxyDetected`) provienen de un entorno potencialmente manipulado por el usuario (root, Xposed, Frida). Por ende, el backend **no confía ciegamente en ellas**; si el cliente declara VPN/Proxy pero la IP no coincide con listas de riesgo, se asigna únicamente un peso marginal complementario (+5 puntos) sin provocar un bloqueo unilateral (umbral de bloqueo = 80).

### 3.2. Arquitectura de Implementación
1. **Detección Nativa Android (`NetworkSecurityDetector.kt`)**:
   - Inspección de `NetworkCapabilities.TRANSPORT_VPN`.
   - Comprobación de interfaces de red activas con prefijos `tun`, `ppp`, `tap`, `p2p`, `wg`.
   - Detección de proxy de sistema configurado (`http.proxyHost` y `getDefaultProxy()`).
2. **Servicio Flutter (`NetworkSecurityService`)**:
   - Invoca el canal nativo `checkVpnAndProxy` y transmite las señales en la carga útil de verificación.
3. **Backend (`IpResolver`, `VpnDetectionProvider`, `NetworkRiskService`)**:
   - `IpResolver`: Extrae la IP de origen, validando encabezados `X-Forwarded-For` únicamente si provienen de proxies internos declarados en `app.security.vpn.trusted-proxies`. Incluye método `maskIp()` para sanitización de logs (privacidad de PII).
   - `NetworkRiskService`: Fusión de evidencia. Consulta `VpnDetectionProvider` (implementado con `MockVpnDetectionProvider` ampliable a proveedores como IPQualityScore/MaxMind GeoIP2).
   - `RiskEngineService`: Pondera el riesgo en la fórmula de scoring global.

---

## 4. CU-0035: Evaluación de Comportamiento de Interfaz (3 SP)

### 4.1. Principio de Privacidad por Diseño (Ley 25.326)
La captura de biometría comportamental táctil y dinámicas de interacción se diseñó bajo estrictos estándares de privacidad:
- **PROHIBICIÓN ESTRICTA DE DATOS CRUDOS**: La aplicación **NUNCA** almacena ni transmite coordenadas cartesianas individuales `(x, y)`, trazos táctiles vectoriales, marcas de tiempo de eventos ni secuencias temporales que permitan reconstruir firmas, patrones de tipeo o hábitos personales íntimos.
- **MÉTRICAS AGREGADAS ÚNICAMENTE**: Todos los datos se computan en tiempo real como métricas estadísticas acumuladas:
  - `totalTaps`: Cantidad total de toques.
  - `avgTapDurationMs`: Duración promedio de contacto táctil (ms).
  - `avgMoveVelocity`: Velocidad promedio de deslizamiento (`px/s`).
  - `avgPressure`: Presión promedio de los toques.
  - `tapPrecisionScore`: Estabilidad espacial promedio (jitter / microdesplazamiento durante el toque).
  - `totalDwellTimeMs`: Tiempo acumulado de permanencia y lectura en pantallas.
  - `behavioralAdultScore`: Score heurístico complementario (0.0 a 1.0).

### 4.2. Carácter Complementario de la Señal (Anti-Falsos Positivos)
El score estimado de comportamiento adulto (`behavioralAdultScore`) evalúa la consistencia de uso de la pantalla táctil frente a patrones atípicos (e.g. toques excesivamente rápidos automatizados por scripts, interacción errática o tiempo de lectura nulo).
- Al ser una señal generada en el dispositivo móvil y sujeta a variabilidad humana (edad, destreza motriz, estado emocional), es tratada como **señal no confiable y estrictamente complementaria**.
- **Impacto en el Motor de Riesgo**: Si `behavioralAdultScore < 0.35`, suma solo **+10 puntos de riesgo**. Jamás bloquea unilateralmente al usuario legítimo, ya que el umbral es 80 puntos.

### 4.3. Cobertura de Pantallas Monitoreadas
El widget `BehaviorTracker` envuelve las pantallas de alto contacto y lectura:
- `LoginScreen`
- `RegisterScreen`
- `TermsScreen`
- `PrivacyScreen`
- `ManualOcrScreenFlutter`
- `DniCaptureScreenFlutter`
- `FaceLivenessScreen`

---

## 5. CU-0023: Cálculo de Score de Riesgo Compuesto (8 SP)

### 5.1. Objetivo y Rol del Motor de Riesgo
Consolidar todas las señales analizadas a lo largo del proceso de verificación de identidad (biometría, vigencia documental, horario, dispositivo, red y comportamiento de interfaz) en un **Score de Riesgo Compuesto (0 - 100)** y una **Decisión Canónica** vinculante (`AUTORIZAR`, `REVISIÓN`, `BLOQUEAR`).
- **Actor**: Servicio de Motor de Riesgo (`RiskEngineService`).
- **Precondición**: Todos los análisis previos completados y enviados al endpoint `POST /verification/local-result`.
- **Zona Horaria de Negocio**: Evaluado en `America/Argentina/Buenos_Aires` mediante un bean inyectable `java.time.Clock`.

### 5.2. Ponderación y Reglas de Evaluación

Todos los pesos, umbrales y políticas se desacoplaron a `application.yml`:

```yaml
app:
  risk:
    timezone: America/Argentina/Buenos_Aires
    thresholds:
      review: 50
      block: 80
    weights:
      liveness: 100
      face-match: 100
      document-not-latest: 50
      schedule-night: 20
      schedule-school: 10
      network-high: 30
      network-medium: 15
      network-client-untrusted: 5
      behavior-low-adult: 10
    thresholds-behavior:
      adult-min: 0.35
    missing-policy:
      liveness: PENALIZE
      face-match: PENALIZE
      document: PENALIZE
      network: IGNORE
      behavior: IGNORE
    missing-penalties:
      liveness: 50
      face-match: 50
      document: 50
      network: 10
      behavior: 10
```

1. **Regla Dura: Emulador Detectado (CU-0034)**:
   - Si `emulatorDetected == true`, se aplica cortocircuito inmediato: Score = 100, Decisión = `BLOQUEAR`, sin ponderación adicional.
2. **Biometría Proporcional (CU-0014 y CU-0015)**:
   - Se pondera según la fórmula: `Math.round(((100.0 - score) / 100.0) * peso)`.
   - Ejemplo: Liveness 98% con peso 100 aporta `round((2 / 100) * 100) = 2` puntos de riesgo.
   - En Flutter, `livenessScore` proviene del cálculo real de ojos abiertos y orientación cefálica (ML Kit Face Detection). `faceMatchScore` proviene de una distribución estocástica representativa (simulación local documentada a la espera del SDK/API oficial de Renaper).
3. **Vigencia Documental (CU-0009)**:
   - `isLatestDocument == true`: 0 puntos.
   - `isLatestDocument == false`: +50 puntos (`weightDocumentNotLatest`).
4. **Horario de Solicitud (CU-0022)**:
   - Madrugada (03:00 - 06:00 ART): +20 puntos (`weightScheduleNight`).
   - Horario escolar (08:00 - 14:00 ART): +10 puntos (`weightScheduleSchool`).
   - Resto del día: 0 puntos.
5. **Riesgo de Red (CU-0032)**:
   - Nivel `ALTO`: +30 puntos.
   - Nivel `MEDIO`: +15 puntos.
   - Señal no confiable de cliente (VPN/Proxy declarado sin confirmación backend): +5 puntos.
6. **Comportamiento Táctil (CU-0035)**:
   - `behavioralAdultScore < 0.35`: +10 puntos (señal complementaria; no bloquea unilateralmente).

### 5.3. Política de Manejo de Señales Faltantes (`missing-policy`)
Para prevenir ataques de clientes adulterados que omitan deliberadamente campos biométricos o de vigencia documental:
- **Señales Críticas de Cliente (`livenessScore`, `faceMatchScore`, `isLatestDocument`)**:
  - Política por defecto: `PENALIZE`.
  - Penalidad: 50 puntos cada una.
  - La omisión de cualquiera de las tres sitúa la sesión automáticamente en `REVISIÓN` (>= 50), y la omisión simultánea satura en 100 puntos (`BLOQUEAR`), impidiendo cualquier autorización indebida.
- **Señales Opcionales / Complementarias (`network`, `behavioralAdultScore`)**:
  - Política por defecto: `IGNORE` (0 puntos).

### 5.4. Matriz de Decisiones y Transiciones de Estado
| Rango de Score | Decisión Canónica | Estado del Usuario | Código HTTP / Respuesta | Acción en Frontend |
| :--- | :--- | :--- | :--- | :--- |
| **0 – 49** | `AUTORIZAR` | Promovido a `LOCALLY_VERIFIED` | 200 `{"status": "OK", "decision": "AUTORIZAR"}` | Continúa a enrolamiento biométrico dactilar (`/fingerprint`). |
| **50 – 79** | `REVISIÓN` | Permanece en `PENDING_VERIFICATION` | 200 `{"status": "UNDER_REVIEW", "decision": "REVISIÓN"}` | Redirección a pantalla informativa `VerificationReviewScreen` (`/verification_review`) indicando plazo de 24-48h hábiles. |
| **80 – 100** (o regla dura) | `BLOQUEAR` | Sin cambio (`REGISTERED` / `PENDING`) | 403 `{"errorCode": "RISK_BLOCKED", "decision": "BLOQUEAR"}` | Redirección inmediata a `SecurityAlertScreen` bloqueante. |

### 5.5. Explicabilidad y Auditoría Forense (CU-0047 / CU-0048)
El motor produce el objeto inmutable `RiskScoreBreakdown`:
- Contribución individual y peso máximo de cada factor (`factorContributions`).
- Estado de evaluación (`EVALUATED`, `MISSING_PENALIZED`, `MISSING_IGNORED`).
- Método `toAuditMap()` sanitizado para auditoría y persistencia en sesión, garantizando que ninguna dirección IP sin máscara ni PII sensible sea exportada a registros públicos.

---

## 6. Resumen de Archivos Afectados

### Frontend (Flutter / Android)
- `android/app/src/main/kotlin/com/authenticator/EmulatorDetector.kt` (Nuevo - CU-0034)
- `android/app/src/main/kotlin/com/authenticator/NetworkSecurityDetector.kt` (Nuevo - CU-0032)
- `android/app/src/main/kotlin/com/authenticator/MainActivity.kt` (Modificado)
- `flutter_app/lib/services/emulator_detection_service.dart` (Nuevo - CU-0034)
- `flutter_app/lib/services/network_security_service.dart` (Nuevo - CU-0032)
- `flutter_app/lib/services/behavioral_biometrics_service.dart` (Nuevo - CU-0035)
- `flutter_app/lib/models/behavioral_metrics.dart` (Nuevo - CU-0035)
- `flutter_app/lib/presentation/widgets/behavior_tracker.dart` (Nuevo - CU-0035)
- `flutter_app/lib/presentation/screens/emulator_blocked_screen.dart` (Nuevo - CU-0034)
- `flutter_app/lib/presentation/screens/verification_review_screen.dart` (Nuevo - CU-0023)
- `flutter_app/lib/logic/face_biometric_service.dart` (Modificado - CU-0023)
- `flutter_app/lib/presentation/screens/face_liveness_screen.dart` (Modificado - CU-0023 / CU-0034)
- `flutter_app/lib/main.dart` (Modificado - Registro de rutas CU-0023 / CU-0034)
- `flutter_app/test/services/emulator_detection_service_test.dart` (Nuevo)
- `flutter_app/test/services/network_security_service_test.dart` (Nuevo)
- `flutter_app/test/services/behavioral_biometrics_service_test.dart` (Nuevo)
- `flutter_app/lib/presentation/screens/oauth_consent_screen.dart` (Nuevo - CU-0027)
- `flutter_app/test/presentation/screens/oauth_consent_screen_test.dart` (Nuevo - CU-0027)
- `android/app/build.gradle` (Modificado - manifestPlaceholders oauthHost CU-0027)
- `android/app/src/main/AndroidManifest.xml` (Modificado - App Links autoVerify CU-0027)
- `android/app/src/debug/AndroidManifest.xml` (Nuevo - sipauth://authorize debug-only CU-0027)

### Backend (Spring Boot)
- `backend_service/src/main/java/com/authenticator/domain/RiskDecision.java` (Nuevo - CU-0023)
- `backend_service/src/main/java/com/authenticator/domain/RiskFactorBreakdown.java` (Nuevo - CU-0023)
- `backend_service/src/main/java/com/authenticator/domain/RiskScoreBreakdown.java` (Nuevo - CU-0023)
- `backend_service/src/main/java/com/authenticator/config/RiskEngineConfig.java` (Nuevo - CU-0023)
- `backend_service/src/main/java/com/authenticator/util/IpResolver.java` (Nuevo - CU-0032)
- `backend_service/src/main/java/com/authenticator/domain/NetworkRiskLevel.java` (Nuevo - CU-0032)
- `backend_service/src/main/java/com/authenticator/domain/NetworkRiskAnalysis.java` (Nuevo - CU-0032)
- `backend_service/src/main/java/com/authenticator/service/VpnDetectionProvider.java` (Nuevo - CU-0032)
- `backend_service/src/main/java/com/authenticator/service/MockVpnDetectionProvider.java` (Nuevo - CU-0032)
- `backend_service/src/main/java/com/authenticator/service/NetworkRiskService.java` (Nuevo - CU-0032)
- `backend_service/src/main/java/com/authenticator/service/RiskEngineService.java` (Modificado - CU-0023)
- `backend_service/src/main/java/com/authenticator/controller/VerificationLocalController.java` (Modificado - CU-0023 / CU-0030)
- `backend_service/src/main/java/com/authenticator/dto/LocalVerificationRequest.java` (Modificado - CU-0023)
- `backend_service/src/main/java/com/authenticator/domain/VerificationResult.java` (Modificado - CU-0023)
- `backend_service/src/main/java/com/authenticator/domain/BlockchainTxStatus.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/domain/BlockchainRecord.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/domain/BlockchainTxReceipt.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/domain/BlockchainNetworkStatus.java` (Nuevo - CU-0031)
- `backend_service/src/main/java/com/authenticator/domain/BlockchainAuditLog.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/repository/BlockchainAuditLogRepository.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/config/AsyncConfig.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/service/BlockchainProvider.java` (Nuevo - CU-0030 / CU-0031)
- `backend_service/src/main/java/com/authenticator/service/MockBlockchainProvider.java` (Nuevo - CU-0030 / CU-0031)
- `backend_service/src/main/java/com/authenticator/service/BlockchainConsensusService.java` (Nuevo - CU-0031)
- `backend_service/src/main/java/com/authenticator/service/BlockchainAuditService.java` (Nuevo - CU-0030)
- `backend_service/src/main/java/com/authenticator/controller/BlockchainStatusController.java` (Nuevo - CU-0031)
- `backend_service/src/main/java/com/authenticator/domain/OAuthClient.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/domain/OAuthAuthorizationCode.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/domain/OAuthIssuedToken.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/domain/LinkedApplication.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/domain/OAuthAuditLog.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/repository/OAuthClientRepository.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/repository/OAuthAuthorizationCodeRepository.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/repository/OAuthIssuedTokenRepository.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/repository/LinkedApplicationRepository.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/repository/OAuthAuditLogRepository.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/security/RsaKeyManager.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/service/OAuthRateLimitingService.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/service/OAuthService.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/service/OAuthCleanupScheduler.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/config/OAuthClientDataInitializer.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/controller/JwksController.java` (Nuevo - CU-0027)
- `backend_service/src/main/java/com/authenticator/controller/OAuthController.java` (Nuevo - CU-0027)
- `backend_service/src/main/resources/db/migration/V2__Create_blockchain_audit_logs_table.sql` (Nuevo - CU-0030)
- `backend_service/src/main/resources/db/migration/V3__Create_oauth_tables.sql` (Nuevo - CU-0027)
- `backend_service/src/main/resources/application.yml` (Modificado - CU-0023 / CU-0030 / CU-0031 / CU-0027)
- `backend_service/src/main/resources/application-dev.yml` (Modificado - CU-0030 / CU-0027)
- `backend_service/src/main/resources/application-prod.yml` (Modificado - CU-0030 / CU-0027)
- `backend_service/src/test/java/com/authenticator/service/RiskEngineServiceTest.java` (Modificado - 16 tests CU-0023)
- `backend_service/src/test/java/com/authenticator/controller/VerificationLocalControllerTest.java` (Modificado - CU-0023 / CU-0030)
- `backend_service/src/test/java/com/authenticator/util/IpResolverTest.java` (Nuevo)
- `backend_service/src/test/java/com/authenticator/service/NetworkRiskServiceTest.java` (Nuevo)
- `backend_service/src/test/java/com/authenticator/service/BlockchainConsensusServiceTest.java` (Nuevo - CU-0031)
- `backend_service/src/test/java/com/authenticator/service/BlockchainAuditServiceTest.java` (Nuevo - CU-0030 / CU-0031)
- `backend_service/src/test/java/com/authenticator/controller/BlockchainStatusControllerTest.java` (Nuevo - CU-0031)
- `backend_service/src/test/java/com/authenticator/controller/JwksControllerTest.java` (Nuevo - CU-0027)
- `backend_service/src/test/java/com/authenticator/service/OAuthRateLimitingTest.java` (Nuevo - CU-0027)
- `backend_service/src/test/java/com/authenticator/integration/ThirdPartyPlatformMockTest.java` (Nuevo - CU-0027)

---

## 7. CU-0030: Registro de Auditoría en Blockchain (5 SP)

### 7.1. Objetivo y Trazabilidad Regulatoria
El servicio de certificación en Blockchain garantiza la inmutabilidad y no repudio de todas las evaluaciones emitidas por el Motor de Riesgo (CU-0023):
- **Registro Universal**: Se registran en la cadena las tres decisiones canónicas: `AUTORIZAR`, `REVISIÓN` y `BLOQUEAR` (incluyendo bloqueos por regla dura de emulador CU-0034). La trazabilidad ante entes reguladores de juego responsable exige auditar los rechazos con la misma rigurosidad que las aprobaciones.
- **Asincronía No Bloqueante**: La certificación on-chain jamás bloquea ni demora la respuesta HTTP al usuario. El registro se persiste inmediatamente en la base de datos en estado `PENDING` y se despacha de forma asíncrona tras la confirmación de la transacción (`TransactionSynchronization.afterCommit`).
- **Política de Pool Seguro**: Si la cola de ejecución del thread pool se satura, las tareas se descartan/rechazan de memoria con log de advertencia (nunca `CallerRunsPolicy`), asegurando que el hilo del request HTTP nunca ejecute llamadas de red hacia la Blockchain. Los registros permanecen en estado `PENDING` en la base de datos y son recuperados por el scheduler periódico.

### 7.2. Principio de Privacidad On-Chain vs Off-Chain
En estricto cumplimiento de la Ley 25.326 y normativas de protección de datos personales:
1. **Datos On-Chain (Mínimos y Seudonimizados)**:
   - `sessionHash`: Hash HMAC-SHA256 del identificador de sesión. La clave criptográfica se inyecta por variable de entorno (`SESSION_HASH_SECRET`), sin valores fijos en el repositorio.
   - `decision`: Decisión tomada (`AUTORIZAR`, `REVISIÓN`, `BLOQUEAR`).
   - `score`: Puntuación numérica compuesta (0–100).
   - `riskConfigVersion`: Versión de configuración de ponderaciones utilizada (e.g. `1.0.0`).
   - `timestamp`: Marca de tiempo en UTC (Epoch / ISO-8601).
   - `breakdownHash`: Hash SHA-256 canónico del JSON del desglose probatorio.
   - **PROHIBICIÓN ESTRICTA**: Cero PII, cero nombres, cero DNI, cero IPs en la Blockchain.
2. **Datos Off-Chain (Base de Datos Local)**:
   - `breakdownDetailsJson`: Desglose probatorio estructurado en la tabla `blockchain_audit_logs`. Permite a un auditor reconstruir la justificación forense y verificar que `SHA-256(breakdownDetailsJson) == breakdownHash`.

### 7.3. Idempotencia y Resiliencia
- **Índice Único**: La base de datos impone la restricción única `uq_blockchain_session_decision` sobre `(session_hash, decision)`.
- Si se reenvía una evaluación para la misma sesión y decisión, `queueRiskAssessment` retorna el registro existente sin duplicar ni fallar.
- Si un envío on-chain falla por error de red o RPC, el contador `retryCount` se incrementa. Si `retryCount >= maxRetries`, el registro pasa a estado `FAILED` con el mensaje de error para alerta operacional.

---

## 8. CU-0031: Consulta de Consenso de Red (5 SP)

### 8.1. Verificación Activa de Consenso
Antes de enviar una transacción on-chain (tanto en el despacho asíncrono inmediato como en el scheduler de reintento), `BlockchainAuditService` consulta a `BlockchainConsensusService`:
1. **Altura de Bloques (Drift)**: La diferencia entre la altura de bloque del nodo local (`localBlockHeight`) y la altura máxima reportada por la red de pares (`highestPeerBlockHeight`) no debe superar `max-block-drift` (por defecto 3 bloques). Si la supera, el estado es `DESYNCHRONIZED`.
2. **Cantidad de Pares (Peers)**: La cantidad de pares conectados debe ser mayor o igual a `min-peers` (por defecto 3). Si es menor, el estado es `INSUFFICIENT_PEERS`.
3. **Estado de Sincronización**: Si el nodo está en proceso de descarga de bloques (`syncing == true`), el estado es `SYNCING`.
4. **Manejo de Timeouts y Errores RPC**: Las consultas RPC tienen un timeout configurable (`timeout-ms: 5000`). Si la llamada expira o falla, se captura como `TIMEOUT` o `RPC_ERROR`.

### 8.2. Regla de Preservación de Intentos
**Si la red no alcanza consenso (`consensusReached == false`)**:
- El registro de auditoría **permanece en estado `PENDING`**.
- **NO se consumen intentos de reintento** (`retryCount` no se incrementa). Esto previene que una caída temporal de conectividad o sincronización del nodo agote prematuramente los reintentos y marque injustamente los registros como fallidos.

### 8.3. Health Check Expuesto
Se expone el endpoint público de supervisión:
`GET /blockchain/status`
- **Respuesta 200 OK**: Cuando `consensusReached: true` (`status: "CONSENSUS_HEALTHY"`).
- **Respuesta 503 Service Unavailable**: Cuando no hay consenso (`DESYNCHRONIZED`, `INSUFFICIENT_PEERS`, `SYNCING`, `TIMEOUT`, `RPC_ERROR`).

---

## 9. Sustitución de MockBlockchainProvider por un Proveedor Real

Para desplegar en una red permisionada corporativa (e.g. Hyperledger Besu / Quorum) o en una red pública/L2 (e.g. Polygon / Arbitrum):

1. **Dependencia Web3j**: Agregar al `pom.xml`:
   ```xml
   <dependency>
       <groupId>org.web3j</groupId>
       <artifactId>core</artifactId>
       <version>4.10.3</version>
   </dependency>
   ```

2. **Implementar `Web3jBlockchainProvider`**:
   Crear una clase que implemente `BlockchainProvider` anotada con:
   ```java
   @Service
   @ConditionalOnProperty(name = "app.blockchain.provider", havingValue = "web3j")
   public class Web3jBlockchainProvider implements BlockchainProvider {
       private final Web3j web3j;
       private final Credentials credentials;
       private final RiskAuditContract contract; // Smart Contract generado via web3j-maven-plugin
       ...
       @Override
       public BlockchainNetworkStatus getNetworkStatus() {
           EthBlockNumber localBlock = web3j.ethBlockNumber().send();
           EthSyncing syncing = web3j.ethSyncing().send();
           NetPeerCount peers = web3j.netPeerCount().send();
           ...
       }

       @Override
       public BlockchainTxReceipt submitRiskAssessment(BlockchainRecord record) {
           TransactionReceipt receipt = contract.recordAssessment(
               record.getSessionHash(),
               record.getDecision(),
               BigInteger.valueOf(record.getScore()),
               record.getRiskConfigVersion(),
               BigInteger.valueOf(record.getTimestamp().getEpochSecond()),
               record.getBreakdownHash()
           ).send();
           return BlockchainTxReceipt.builder()
               .transactionHash(receipt.getTransactionHash())
               .blockNumber(receipt.getBlockNumber().longValue())
               .success(receipt.isStatusOK())
               .build();
       }
   }
   ```

3. **Variables de Entorno**:
   ```bash
   BLOCKCHAIN_PROVIDER=web3j
   BLOCKCHAIN_NETWORK=polygon-amoy
   BLOCKCHAIN_RPC_URL=https://rpc-amoy.polygon.technology
   BLOCKCHAIN_PRIVATE_KEY=0x...
   BLOCKCHAIN_CONTRACT_ADDRESS=0x...
   SESSION_HASH_SECRET=c9b2f... (clave secreta de al menos 32 bytes)
   ```

---

## 10. CU-0027: Transmisión de Token a Plataforma Externa (5 SP)

### 10.1. Objetivo y Rol de la Integración con Terceros
Permitir que plataformas externas reguladas (e.g. casinos online, portales de apuestas o servicios para mayores de edad) verifiquen si un ciudadano argentino es mayor de 18 años mediante **SIP | App**, sin compartir jamás sus datos personales íntimos (DNI, nombres, apellidos, fecha de nacimiento, domicilio ni fotos).

- **Protocolo Estándar**: OAuth 2.0 Authorization Code Grant con PKCE (*Proof Key for Code Exchange*, RFC 7636).
- **Aislamiento Total del Token Interno**: El sistema de autenticación interno de SIP | App (JWT HS256 con JJWT, TTL 15 min, refresh tokens opacos hasheados y tabla `revoked_tokens`) **no se modifica ni se expone a terceros**. Los tokens para plataformas externas son JWTs asimétricos firmados con **RS256** emitidos por un subsistema independiente.
- **Principio de Privacidad por Diseño (Cero PII)**:
  - El token RS256 únicamente afirma la condición de mayoría de edad (`age_verified: true`) y el nivel de aseguramiento (`assurance_level: "HIGH"`).
  - El identificador de usuario (`sub`) es estrictamente seudónimo y calculado mediante un HMAC-SHA256 pairwise entre el ID interno del usuario y el `client_id` de la plataforma tercera (`HMAC(pairwise_secret, userId + ":" + clientId)`). Esto impide que dos plataformas externas puedan correlacionar al mismo usuario entre sí.
- **Nota sobre RENAPER**: La validación biométrica y de datos contra RENAPER se mantiene simulada en este prototipo, a la espera del convenio y credenciales formales del organismo nacional.

---

### 10.2. Flujo Criptográfico Completo y Secuencia

```mermaid
sequenceDiagram
    autonumber
    participant TP as Plataforma Externa (App/Web)
    participant OS as Android OS (App Links)
    participant APP as SIP | App (Flutter)
    participant BE as Backend SIP (Spring Boot)
    participant TP_BE as Backend Plataforma Externa

    Note over TP,TP_BE: 1. Inicio de Autorización
    TP->>OS: Abre Intent https://auth.example.com/oauth/authorize?client_id=...&redirect_uri=...&code_challenge=...&code_challenge_method=S256&state=...&nonce=...
    OS->>APP: Enruta a SIP | App (MainActivity -> MethodChannel -> _handleDeepLink)

    Note over APP,BE: 2. Validación Anti-Phishing
    APP->>BE: GET /oauth/client-info?client_id=...&redirect_uri=...
    BE-->>APP: 200 OK { client_id, client_name: "Casino Central Online", verified: true }
    Note over APP: Muestra OauthConsentScreen con nombre oficial verificado.<br/>Si cliente o redirect_uri no coinciden exactamente, bloquea el flujo con error visual.

    Note over APP,BE: 3. Consentimiento y Emisión de Código
    APP->>BE: POST /oauth/token-exchange (Bearer SIP Access Token)<br/>{ client_id, redirect_uri, code_challenge, code_challenge_method: "S256", state, nonce, consent_given: true }
    Note over BE: Valida sesión, precondición (última decisión de riesgo == AUTORIZAR en <= 60 min) y genera code.
    BE-->>APP: 200 OK { redirect_uri, authorization_code, state }

    Note over APP,TP: 4. Retorno a la Plataforma Tercera
    APP->>OS: Abre URL validada: redirect_uri?code=...&state=...
    OS->>TP: Redirige con código de autorización de un solo uso (TTL 60s)

    Note over TP,TP_BE: 5. Canje de Código por Token (Back-channel Seguro)
    TP->>TP_BE: Envía code y state
    TP_BE->>BE: POST /oauth/token (HTTP Basic Auth: client_id:client_secret)<br/>grant_type=authorization_code&code=...&redirect_uri=...&code_verifier=...
    Note over BE: Valida Basic Auth, PKCE (SHA256(verifier) == challenge), TTL 60s.<br/>Marca código como USADO (detecta reuso y revoca tokens).
    BE-->>TP_BE: 200 OK { access_token (JWT RS256), token_type: "Bearer", expires_in: 300, scope: "openid age_verification" }

    Note over TP_BE,BE: 6. Verificación Criptográfica Asimétrica
    TP_BE->>BE: GET /.well-known/jwks.json (Clave Pública RSA)
    BE-->>TP_BE: 200 OK { keys: [ { kty: "RSA", kid: "sip-oauth-key-1", n: "...", e: "AQAB" } ] }
    Note over TP_BE: Valida firma RS256, expiración, aud=client_id y claim age_verified == true.
```

---

### 10.3. Endpoints Expuestos

| Método | Endpoint | Acceso / Autenticación | Descripción |
| :--- | :--- | :--- | :--- |
| **GET** | `/.well-known/jwks.json` | Público | Publica el juego de claves públicas RSA (*JWKS*) en formato RFC 7517/7518 para validación de tokens por terceros. Nunca expone claves privadas. |
| **GET** | `/oauth/client-info` | Público (Anti-Phishing) | Valida que `client_id` y `redirect_uri` coincidan exactamente con un cliente registrado activo y devuelve `client_name` oficial. |
| **POST** | `/oauth/token-exchange` | Autenticado (`Bearer` SIP JWT) | Genera un código de autorización temporal (60s) tras verificar que el usuario consintió y cuenta con validación de riesgo favorable (`AUTORIZAR`). |
| **POST** | `/oauth/token` | Cliente (`Basic Auth` + PKCE) | Canjea el código de autorización por el JWT RS256 con `age_verified: true`. Consume el código de un solo uso. |

---

### 10.4. Matriz de Claims del Token Emitido a Terceros

El JWT generado para plataformas externas posee las siguientes características:
- **Algoritmo**: `RS256` (RSA con SHA-256).
- **TTL**: 5 minutos (`app.oauth.token-validity-seconds: 300`).
- **Encabezado JOSE**: `{"alg": "RS256", "typ": "JWT", "kid": "sip-oauth-key-1"}`.

| Claim | Valor | Justificación / Privacidad |
| :--- | :--- | :--- |
| `iss` | `https://auth.example.com` | Identificador del emisor (*Issuer*). |
| `sub` | `HMAC-SHA256(secret, userId:clientId)` | Seudónimo no correlacionable entre distintas plataformas (Pairwise Subject). |
| `aud` | `client_id` (e.g. `casino-central`) | La plataforma tercera destinataria es la única audiencia válida. |
| `exp` | Epoch time (actual + 300s) | Corta vida útil para minimizar ventana de exposición. |
| `iat` | Epoch time | Momento de emisión. |
| `jti` | UUID v4 | Identificador único del token para auditoría y revocación. |
| `scope` | `openid age_verification` | Alcance otorgado explícitamente por el usuario. |
| `nonce` | `nonce` de la petición original | Previene ataques de inyección y fijación de sesión. |
| `age_verified` | `true` | **Afirmación central**: el ciudadano ha verificado biometría y es mayor de edad. |
| `assurance_level` | `"HIGH"` | Nivel de aseguramiento de identidad respaldado por prueba de vida activa y DNI vigente. |

> [!IMPORTANT]
> **Garantía de Cero PII**: El token **NO contiene** nombre, apellido, número de documento (DNI), correo electrónico, fecha de nacimiento ni imagen fotográfica.

---

### 10.5. Mitigaciones de Seguridad y Robustez

1. **Anti-Phishing en Frontend (`OauthConsentScreen`)**:
   - Antes de mostrar la interfaz de consentimiento, Flutter consulta `/oauth/client-info`.
   - La pantalla muestra el nombre comercial registrado en el backend, no un nombre manipulable desde la URL del App Link.
   - Si la validación falla (cliente inexistente o `redirect_uri` no registrada exactamente), la pantalla entra en estado bloqueante de error de seguridad y **nunca abre la URI no verificada**, ni siquiera ante rechazo.
2. **Protección PKCE Estricta (RFC 7636)**:
   - Solo se admite `code_challenge_method = S256` (se rechaza `plain` con HTTP 400).
   - Longitud y formato de `code_challenge` y `code_verifier` validados rigurosamente (entre 43 y 128 caracteres Base64URL sin relleno).
3. **Código de Autorización de Un Solo Uso y Detección de Replay**:
   - El código se almacena en base de datos hasheado mediante SHA-256 (`code_hash`), nunca en texto plano.
   - Expiración estricta de 60 segundos.
   - Si un atacante intenta reutilizar un código ya marcado como `USED`, el backend rechaza la petición con `invalid_grant` y **revoca automáticamente en cascada todos los tokens previamente emitidos** a partir de dicho código.
4. **Protección contra Fuerza Bruta y Rate Limiting**:
   - Limitador de tasa basado en IP para todas las rutas `/oauth/*` (ventana deslizante de 1 minuto).
   - Bloqueo temporal por 15 minutos (`app.oauth.client-lockout-duration-seconds: 900`) tras 5 intentos fallidos consecutivos de `client_secret`, respondiendo HTTP 429 con cabecera `Retry-After`.
5. **Precondición de Motor de Riesgo**:
   - Para emitir el código en `/oauth/token-exchange`, se valida que la última evaluación del motor de riesgo (CU-0023) del usuario tenga decisión `AUTORIZAR` y una antigüedad no mayor a `app.oauth.risk-decision-max-age-minutes` (60 minutos por defecto).
6. **Auditoría Seudonimizada**:
   - En la tabla `oauth_audit_logs`, la columna `user_id_hash` contiene el HMAC-SHA256 del ID de usuario con `app.oauth.pairwise-secret`. Se registran eventos de `CODE_ISSUED`, `TOKEN_ISSUED`, `CLIENT_AUTH_FAILED`, `CODE_REPLAY_DETECTED`, `CLIENT_INFO_QUERY` y `CLIENT_LOCKED`.
7. **Purga Automática de Registros**:
   - `OAuthCleanupScheduler` ejecuta periódicamente una tarea con `@Scheduled(fixedDelay = 300000)` para purgar códigos y tokens expirados de la base de datos.

---

### 10.6. Configuración de Claves Asimétricas (RS256) y Rotación

#### Perfiles de Ejecución
- **Entorno de Desarrollo y Tests (`dev`, `test`)**:
  - `RsaKeyManager` genera automáticamente un par de claves RSA de 2048 bits en memoria al iniciar la aplicación.
  - Imprime un banner de seguridad en logs recordando que las claves efímeras no deben utilizarse en producción.
  - Inicializa un cliente de prueba `sandbox-client` (`client_secret: sandbox-secret-change-in-prod-12345`) en `OAuthClientDataInitializer`.
- **Entorno de Producción (`prod`)**:
  - `app.oauth.rsa.private-key-pem` y `app.oauth.rsa.public-key-pem` son obligatorios. Si no se configuran, la aplicación falla al arrancar.
  - Se cargan vía variables de entorno:
    ```bash
    OAUTH_RSA_KEY_ID=sip-oauth-key-1
    OAUTH_RSA_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgk..."
    OAUTH_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0B..."
    OAUTH_ISSUER=https://auth.example.com
    OAUTH_PAIRWISE_SECRET=3c8f... (clave secreta HMAC de 32+ bytes)
    ```

#### Procedimiento de Rotación de Claves sin Interrupción
1. Generar un nuevo par de claves RSA con identificador incremental (e.g. `kid: sip-oauth-key-2`).
2. Configurar el nuevo par como clave activa para la firma de nuevos tokens.
3. Mantener la clave pública anterior (`sip-oauth-key-1`) en el almacén de claves públicas del bean `RsaKeyManager`.
4. El endpoint `GET /.well-known/jwks.json` expone automáticamente ambas claves públicas en su arreglo `keys`.
5. Las plataformas externas continúan validando tokens existentes válidos firmados con `sip-oauth-key-1` durante su ventana de 5 minutos, y comienzan a validar los nuevos tokens con `sip-oauth-key-2`.

---

### 10.7. Guía de Publicación de Android App Links (`assetlinks.json`)

Para que Android abra automáticamente SIP | App al pulsar un enlace de autorización sin mostrar el selector de navegadores, el dominio debe publicar el archivo de asociación digital de activos:

#### 1. Ubicación Pública Obligatoria
El servidor web que sirve el dominio de autorización (e.g. `https://auth.example.com`) debe exponer el archivo en:
`https://auth.example.com/.well-known/assetlinks.json`
- **Cabecera HTTP**: `Content-Type: application/json`.
- **HTTPS**: Certificado SSL/TLS válido (no autofirmado).

#### 2. Formato del Archivo `assetlinks.json`
```json
[
  {
    "relation": [
      "delegate_permission/common.handle_all_urls"
    ],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.flutter_app",
      "sha256_cert_fingerprints": [
        "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C"
      ]
    }
  }
]
```

#### 3. Obtención de la Huella Digital SHA-256 del Keystore
Para entorno de producción / release:
```bash
keytool -list -v -keystore /ruta/a/tu/upload-keystore.jks -alias tu-alias
```
Copiar el valor de `Certificate fingerprints: SHA256` e incluirlo en `sha256_cert_fingerprints`.

#### 4. Configuración en la Aplicación
- `flutter_app/android/app/build.gradle`:
  ```groovy
  defaultConfig {
      manifestPlaceholders = [
          oauthHost: "auth.example.com"
      ]
  }
  ```
- `src/main/AndroidManifest.xml`: Configura `android:autoVerify="true"` y consume `${oauthHost}`.
- `src/main/AndroidManifest.xml`: Habilita también el esquema `sipauth://authorize` mediante intent-filter para pruebas y operación sin dominio institucional real.

---

## 11. Restricción del Entorno y Arquitectura de Mocks (100% Offline)

Por restricción de entorno, la aplicación **NO se conecta a ningún servicio externo de validación**. Toda la comunicación ocurre exclusivamente entre la app Flutter y el backend propio de SIP. Todos los componentes y servicios que dependen de terceros están desacoplados detrás de interfaces, con implementaciones mock seleccionables por configuración y **advertencias de seguridad visibles en la consola al arrancar (`@PostConstruct`)**:

| Servicio / Dependencia de Tercero | Interfaz en Backend | Implementación Mock | Propiedad de Selección | Warning Visible al Arrancar |
| :--- | :--- | :--- | :--- | :--- |
| **RENAPER / Biometría Nacional** | `IdentityVerificationProvider` | `MockVerificationProvider` | `app.identity-provider=mock` (default) | `⚠️ [ADVERTENCIA DE SEGURIDAD]: Proveedor de Identidad/RENAPER ACTIVO es 'MOCK'` |
| **Red Blockchain Real (Besu/Polygon)** | `BlockchainProvider` | `MockBlockchainProvider` | `app.blockchain.provider=mock` (default) | `⚠️ [ADVERTENCIA DE SEGURIDAD]: Proveedor Blockchain ACTIVO es 'MOCK'` |
| **IP Intelligence / GeoIP / VPN / Tor** | `VpnDetectionProvider` | `MockVpnDetectionProvider` | `app.security.vpn.provider=mock` (default) | `⚠️ [ADVERTENCIA DE SEGURIDAD]: Proveedor IP Intelligence/VPN ACTIVO es 'MOCK'` |
| **Redis de Infraestructura** | `RevocationStore` | `InMemoryRevocationStore` | `app.revocation.store=memory` (default) | `⚠️ [ADVERTENCIA DE SEGURIDAD]: Almacén de Revocación de Tokens es 'IN-MEMORY'` |
| **Plataformas de Apuestas Reales** | Cliente OAuth (`OAuthClient`) | Callback local sandbox (`OAuthController`) | URL local `http://127.0.0.1:8080/oauth/sandbox/callback` | Totalmente offline sin salida a internet. |
| **Play Integrity / SafetyNet** | `DeviceIntegrityService` (Flutter) | Módulos locales `RootDetector.kt` y `EmulatorDetector.kt` | Canales nativos MethodChannel | Ejecución puramente local sin servicios de Google Play. |
| **Firebase / FCM** | N/A | Sin llamadas a APIs en la nube | Deshabilitado | Cero tráfico hacia Google Cloud / Firebase. |
| **Servidores NTP / Sincronización Horaria**| `java.time.Clock` | Reloj local inyectable | `Clock.system(ZoneId.of("America/Argentina/Buenos_Aires"))` | Sin dependencias de llamadas UDP/NTP a servidores remotos. |

---

## 12. Seguridad del Esquema Personalizado `sipauth://` vs Android App Links

### 12.1. Desafío Operativo
Sin un dominio institucional real registrado y verificado por la autoridad gubernamental, no es posible alojar el archivo `assetlinks.json` accesible públicamente para la validación automática de App Links (`autoVerify=true`).
Por este motivo, el esquema personalizado `sipauth://authorize` se encuentra **habilitado en el `AndroidManifest.xml` principal** como mecanismo práctico de invocación.

### 12.2. Modelo de Amenazas de Esquemas Personalizados
A diferencia de los App Links (que exigen propiedad criptográfica del dominio web), en Android cualquier aplicación maliciosa puede declarar un intent-filter para el esquema `sipauth://` y tratar de interceptar redirecciones.

### 12.3. Mitigaciones Criptográficas Rigurosas Implementadas
El flujo OAuth de SIP neutraliza este vector de ataque mediante tres defensas coordinadas:
1. **PKCE Obligatorio con S256 (RFC 7636)**:
   - Toda solicitud debe incluir `code_challenge` computado con SHA-256 (`code_challenge_method=S256`).
   - Incluso si una aplicación hostil intercepta el `code` en la redirección de `sipauth://`, **no puede canjearlo ante el backend (`POST /oauth/token`)**, ya que desconoce el `code_verifier` generado aleatoriamente en la memoria de la plataforma llamante original.
2. **Código de Autorización de Corta Duración y Un Solo Uso**:
   - El código vence estrictamente a los 60 segundos (`app.oauth.auth-code-validity-seconds: 60`).
   - Se almacena hasheado con SHA-256 (`code_hash`).
3. **Detección Activa de Reúso de Código (Replay Attack)**:
   - Si un código marcado como `USED` es presentado nuevamente, el backend aborta la petición y **revoca automáticamente en cascada todos los tokens previamente emitidos**, alertando del incidente en `oauth_audit_logs`.
4. **App Links Verificados Pendiente**:
   - La migración definitiva a `https://` con `assetlinks.json` verificado queda documentada como **pendiente** para la etapa en que se disponga de dominio institucional con DNS y certificado SSL.

---

## 13. Cierre de Brechas de Compatibilidad entre Sprints

Tras la auditoría técnica de compatibilidad, se implementaron las siguientes mejoras sin alterar la arquitectura base ni romper los casos de uso previos:

1. **CU-0047 (Consulta de Auditor con Búsqueda Seudonimizada por DNI)**:
   - Para no almacenar el DNI en texto plano en registros off-chain ni violar la Ley 25.326, se genera un índice seudonimizado determinista:
     $$\text{dni\_search\_hash} = \text{HMAC-SHA256}(\text{dniHash}, \text{DNI\_SEARCH\_SECRET})$$
   - Endpoint protegido: `GET /admin/blockchain/records-by-dni?dniHash=...` (Roles `ROLE_ADMIN`, `ROLE_AUDITOR`).
   - Toda consulta efectuada por un auditor queda registrada en la tabla `oauth_audit_logs` con evento `AUDITOR_QUERY`.
2. **CU-0029 (Registro de Transacción Enriquecido Off-Chain)**:
   - La tabla `blockchain_audit_logs` almacena `timestamp`, `maskedIp` (`198.51.***.***`), `dniHash`, `dniSearchHash` y `decision`, tanto para transacciones exitosas (`AUTORIZAR`) como rechazadas (`BLOQUEAR`, `REVISIÓN`).
   - La política de datos mínimos on-chain se mantiene inalterada: en la Blockchain solo se publica `sessionHash`, `decision`, `score`, `riskConfigVersion`, `timestamp` y `breakdownHash`.
3. **CU-0033 / CU-0034 (Unificación de Integridad de Dispositivo)**:
   - Detección combinada de Root/Jailbreak (`RootDetector.kt`) y Emulador (`EmulatorDetector.kt`) unificada en el modelo `DeviceIntegrityResult` de Flutter y en el backend (`deviceCompromised`).
   - Si el dispositivo está comprometido o es un emulador, el motor de riesgo aplica cortocircuito con regla dura (Score 100, `BLOQUEAR`).
4. **CU-0043 / CU-0045 (Reglas Duras en OAuth)**:
   - `POST /oauth/token-exchange` verifica si el DNI del usuario figura en la tabla `blacklisted_dnis` (rechazo 403 `DNI_BLACKLISTED`).
   - Verifica si el usuario cuenta con bloqueo temporal activo (`user.getLockedUntil() > now()`), respondiendo 403 `USER_LOCKED_OUT`.
5. **CU-0016 (Penalización por Intentos Faciales Fallidos Recientes)**:
   - `FaceLivenessScreen` transmite `failedFaceAttempts` al backend.
   - `RiskEngineService` penaliza cada intento fallido con peso configurable (`app.risk.weights.facial-failed-attempts: 15`).
6. **CU-0037 (Revocación Activa y Endpoint de Introspección RFC 7662)**:
   - Interfaz `RevocationStore` con implementaciones `InMemoryRevocationStore` y `RedisRevocationStore`.
   - `POST /oauth/introspect`: responde `{"active": true, ...}` o `{"active": false}` con limitación de tasa basada en IP.
   - Política de fail-closed: únicamente retorna inactivo (`active=false`) si tanto el almacén de revocación como la base de datos se encuentran inaccesibles.
7. **CU-0048 (Exportación Forense Certificada)**:
   - Endpoint protegido: `GET /admin/forensics/export` (Roles `ROLE_ADMIN`, `ROLE_AUDITOR`).
   - Consolida registros de blockchain, autorizaciones OAuth y auditorías, certificándolos con `integrityHashSha256` y firma digital asimétrica RSA (`SHA256withRSA`) con la clave privada de SIP.
   - En Flutter (`SecurityHistoryScreen`), se incorporó el botón de exportación forense certificada, visualización del hash y firma con opciones de copiado y compartir JSON.
8. **Protección contra Asignación Masiva (Mass Assignment)**:
   - En el registro de usuario (`POST /auth/register`), el backend fuerza `user.setRole("USER")`, ignorando cualquier campo de rol enviado en la carga útil.

---

## 14. Estado de Casos de Uso y Tareas Pendientes

| Caso de Uso | Descripción | Estado Actual | Observaciones / Pendientes |
| :--- | :--- | :--- | :--- |
| **CU-0023** | Motor de Riesgo Compuesto | **COMPLETO** | Ponderaciones desacopladas en YAML, regla dura de emulador/root, 8 factores de riesgo. |
| **CU-0027** | Transmisión de Token OAuth 2.0 | **COMPLETO** | Flujo PKCE S256, tokens RS256, JWKS, Anti-Phishing, sandbox local offline. |
| **CU-0029** | Registro de Transacción Enriquecido | **COMPLETO** | Off-chain con IP enmascarada y DNI hash en éxito y fracaso; on-chain mínimo. |
| **CU-0030** | Registro de Auditoría en Blockchain | **COMPLETO** | Transacciones asíncronas no bloqueantes, reintentos con scheduler, idempotencia. |
| **CU-0031** | Consulta de Consenso de Red | **COMPLETO** | Health check público y admin, detección de drift, peers y preservación de intentos. |
| **CU-0032** | Detección de VPN / Proxies | **COMPLETO** | Fusión autoritativa backend con señales secundarias de cliente. |
| **CU-0033/34**| Integridad de Dispositivo (Root + Emulador) | **COMPLETO** | Unificado en frontend y backend con bloqueo duro automático. |
| **CU-0035** | Biometría Comportamental Táctil | **COMPLETO** | Cero datos crudos, solo métricas agregadas y carácter complementario. |
| **CU-0037** | Revocación Activa de Tokens | **COMPLETO** | `RevocationStore` (Redis + memoria), introspección RFC 7662. |
| **CU-0047** | Consulta de Auditor por DNI | **COMPLETO** | Búsqueda por HMAC seudonimizado `dni_search_hash` y auditoría de accesos. |
| **CU-0048** | Exportación Forense Certificada | **COMPLETO** | Firma RSA y hash SHA-256 expuesto en backend y consumible en Flutter. |
| **CU-0049** | Análisis Nocturno de Fraude Batch | **PENDIENTE** | Job programado batch nocturno para escanear anomalías agregadas y disparar `FraudAlertService`. Se integrará en el siguiente sprint al definir la ventana de ejecución de batch. |
| **App Links** | Android App Links Verificados | **PENDIENTE** | Requiere dominio gubernamental institucional `.gob.ar` con SSL para publicar `assetlinks.json`. Mientras tanto, opera con `sipauth://`. |
| **RENAPER** | Conexión Oficial con RENAPER | **PENDIENTE** | A la espera del convenio marco y credenciales de producción del organismo nacional. Opera con `MockVerificationProvider`. |

---

## 15. Guía de Ejecución End-to-End 100% Offline (Sin Conexión a Internet)

Para ejecutar y probar el ciclo completo de validación de identidad y transmisión OAuth sin depender de ningún servicio externo ni conexión a internet:

### 1. Iniciar el Backend en Modo Local / Mock
```bash
cd backend_service
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```
*El backend arrancará en el puerto 8080 con H2 en memoria, claves RSA autogeneradas, cliente de prueba `sandbox-client` inicializado y todos los proveedores en modo MOCK con sus correspondientes advertencias.*

### 2. Registrar y Verificar un Usuario Local
```bash
# 1. Registrar usuario
curl -s -X POST http://127.0.0.1:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario.prueba@sip.gob.ar","password":"PasswordSeguro123!"}'

# 2. Iniciar sesión y obtener JWT interno
USER_TOKEN=$(curl -s -X POST http://127.0.0.1:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"usuario.prueba@sip.gob.ar","password":"PasswordSeguro123!"}' | jq -r '.accessToken')

# 3. Informar resultado de validación local (CU-0023 / CU-0030)
curl -s -X POST http://127.0.0.1:8080/verification/local-result \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dniHash": "dni-simulado-offline-12345678",
    "livenessScore": 98,
    "faceMatchScore": 95,
    "isLatestDocument": true,
    "emulatorDetected": false,
    "deviceCompromised": false
  }'
```

### 3. Ejecutar el Flujo OAuth 2.0 PKCE contra el Sandbox Local
```bash
# 1. Generar verifier y challenge PKCE (S256)
VERIFIER="dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
CHALLENGE="E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
STATE="estado-aleatorio-xyz"

# 2. Consultar información anti-phishing del cliente
curl -s "http://127.0.0.1:8080/oauth/client-info?client_id=sandbox-client&redirect_uri=http://127.0.0.1:8080/oauth/sandbox/callback"

# 3. Canjear Access Token de SIP por Authorization Code (Simulando aceptación de consentimiento en la app)
AUTH_CODE=$(curl -s -X POST http://127.0.0.1:8080/oauth/token-exchange \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "sandbox-client",
    "redirectUri": "http://127.0.0.1:8080/oauth/sandbox/callback",
    "state": "'$STATE'",
    "nonce": "nonce-prueba-123",
    "codeChallenge": "'$CHALLENGE'",
    "codeChallengeMethod": "S256",
    "scope": "openid age_verification",
    "consentGiven": true
  }' | jq -r '.code')

echo "Authorization Code emitido: $AUTH_CODE"

# 4. Canjear el código por el token RS256 (Llamada back-channel de la plataforma tercera)
RS256_TOKEN=$(curl -s -X POST http://127.0.0.1:8080/oauth/token \
  -u "sandbox-client:sandbox-secret-change-in-prod-12345" \
  -d "grant_type=authorization_code" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://127.0.0.1:8080/oauth/sandbox/callback" \
  -d "code_verifier=$VERIFIER" | jq -r '.access_token')

echo "Token RS256 emitido para terceros: $RS256_TOKEN"

# 5. La plataforma tercera valida el token descargando las claves públicas JWKS
curl -s http://127.0.0.1:8080/.well-known/jwks.json

# 6. Introspección activa del token (RFC 7662)
curl -s -X POST http://127.0.0.1:8080/oauth/introspect \
  -d "token=$RS256_TOKEN"
```

### 4. Consultar y Exportar Auditoría Forense Certificada
```bash
# 1. Obtener token con rol ADMIN o AUDITOR (usando el secreto HMAC del perfil test/dev)
# 2. Consultar registros por DNI (CU-0047)
curl -s "http://127.0.0.1:8080/admin/blockchain/records-by-dni?dniHash=dni-simulado-offline-12345678" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 3. Exportar reporte forense firmado con SHA-256 y RSA (CU-0048)
curl -s http://127.0.0.1:8080/admin/forensics/export \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 16. Mejoras de Camino Feliz, Autenticación y Dispositivos de Confianza (Parte A)

### 16.1. Punto 1: Login Seguro, Anti-Enumeración y Bloqueo
- **Anti-Enumeración**: Las respuestas ante credenciales inválidas para usuarios existentes o inexistentes devuelven idéntico código HTTP 401 (`"Credenciales inválidas"`), previniendo la enumeración de cuentas.
- **Rate Limiting y Bloqueo**: Se implementa control de tasa por IP en `AuthController` (`"ip:" + ip`). Cuando una cuenta está bloqueada temporalmente por intentos fallidos (`user.getLockedUntil()`) o se supera el límite de tasa por IP, se responde HTTP 429 con mensaje genérico: `"Demasiados intentos, probá más tarde"`.
- **Accesibilidad y UX**: `LoginScreen` incluye etiquetas `Semantics` en campos de texto y botones, deshabilitación de inputs durante el procesamiento y validaciones estrictas de formato.

### 16.2. Punto 2: Persistencia de Sesión Segura y Re-Autenticación en Arranque Frío
- **Almacenamiento Seguro**: Los tokens de acceso y refresh se persisten en Android Keystore mediante `flutter_secure_storage`.
- **Mantener Sesión Iniciada**: Se incorpora la opción configurable "Mantener sesión iniciada", condicionada a que el sistema operativo tenga bloqueo de pantalla o biometría activa (`ScreenLockService.isScreenLockConfigured()`). Si la opción está desactivada, la sesión no sobrevive al cierre de la aplicación.
- **Arranque en Frío**: Al iniciar la aplicación con sesión recordada, `SplashScreen` exige autenticación biométrica/PIN (`local_auth`) antes de acceder a los tokens. Si el usuario cancela o falla, es redirigido a Login sin exponer ni usar los tokens.
- **Refresh Transparente y Concurrencia**: `DioClient` intercepta respuestas 401 y realiza refresh automático con `POST /auth/refresh`. En caso de fallo o revocación por concurrencia (`CONCURRENT_ACCESS`), se emite alerta y se limpian los tokens.

### 16.3. Punto 3: Security Score Multi-Factor (`GET /users/security-score`)
- **Cálculo Servidor Autoritativo**: El score nunca es provisto por el cliente. Inicia en una base baja configurable (`app.security-score.base-score: 15`) y acumula por factores verificados:
  - **Identidad Verificada**: +30 puntos. Si la identidad del usuario no está verificada, el score global tiene un tope estricto de 55 (`unverified-max-score: 55`), garantizando que jamás alcance "Alta Confianza".
  - **Decisión del Motor de Riesgo**: Reutiliza la última decisión persistida en `blockchain_audit_logs` (+20 para `AUTORIZAR`, -30 para `BLOQUEAR`, -10 para `REVISIÓN`).
  - **Dispositivos de Confianza**: +20 si cuenta con al menos un dispositivo `TRUSTED`.
  - **Antigüedad de Cuenta**: +10 si supera los 30 días.
  - **Señales Complementarias del Cliente**: Biometría/bloqueo de pantalla (+5) tratada con bajo peso como señal no confiable.
  - **Intentos Fallidos de Login**: Deducción de -5 por intento dentro de una ventana temporal de 24 horas (`app.security-score.failed-attempts-window-hours: 24`).
- **Clampeo y Clasificación**: El resultado se limita al rango [0, 100] y se clasifica según umbrales configurables (`high-threshold: 75`, `medium-threshold: 50`) en `ALTO`, `MEDIO` o `BAJO`.
- **Desglose en la App**: `UserDashboardScreen` y `SecurityScoreCard` eliminan el score hardcodeado (98) y muestran un modal interactivo con etiquetas genéricas sin exponer detalles internos de las detecciones.

### 16.4. Punto 4: Gestión de Dispositivos de Confianza (`trusted_devices`)
- **Migración Flyway V5 (`V5__Create_trusted_devices_table.sql`)**: Crea la tabla `trusted_devices` con restricción única `(user_id, device_hash)` e índices sobre `user_id`, `device_hash` y `status`.
- **Identificador de Dispositivo**: UUID v4 aleatorio generado por el cliente en `flutter_secure_storage`. En el backend se persiste como `HMAC-SHA256(uuid, secret)` usando `app.devices.hmac-secret` (obligatorio en producción sin valor por defecto).
- **Cálculo Dinámico de Dispositivo Actual**: La propiedad `isCurrent` se calcula dinámicamente comparando el hash del encabezado `X-Device-Id` con el registro de la base de datos (no se almacena como columna).
- **Regla de Confianza**: El primer dispositivo del usuario se registra como `TRUSTED` si la identidad está verificada y no presenta alertas de fraude/bloqueo. Los dispositivos subsecuentes se registran como `PENDING`.
- **Aprobación y Revocación (Anti-IDOR)**: `POST /devices/{id}/approve` permite aprobar un dispositivo `PENDING` únicamente si el solicitante opera desde un dispositivo `TRUSTED`. `POST /devices/{id}/revoke` revoca el acceso validando la pertenencia del dispositivo al usuario.
- **Alertas Locales**: `GET /devices/alerts` expone alertas de dispositivos que se notifican localmente vía `flutter_local_notifications` en dispositivos de confianza.
- **Pendiente Documentado**: La invalidación granular de refresh tokens por dispositivo queda documentada como pendiente a nivel de esquema (`refresh_tokens` actualmente vincula por `user_id` sin clave foránea de `device_id`).

---

## 17. Mejoras de Aplicaciones Vinculadas y Actividad (Parte B)

### 17.1. Punto 5: Botón Aplicaciones Vinculadas (`/linked_apps_list` & Endpoints `/oauth/*`)
- **Unificación de Fuentes en Pantalla Única**:
  - **Aplicaciones TOTP Locales**: Gestionadas en base SQLite del dispositivo (`linked_apps`). La semilla `secretSeed` permanece estrictamente confinada al cliente local y **nunca** se envía al backend, ni se expone en la interfaz gráfica ni en los registros.
  - **Plataformas OAuth de Terceros**: Persistidas en el backend en la entidad `linked_applications` con tokens emitidos en `oauth_issued_tokens`, consultadas mediante `GET /oauth/linked-applications`.
  - **Identificadores Visuales de Tipo**: Cada tarjeta presenta un badge distintivo: `"Código TOTP"` (índigo) o `"Plataforma OAuth"` (teal).
- **Atributos Reales Sin Datos Inventados**:
  - Nombre o razón social de la aplicación/plataforma.
  - Fecha de vinculación (`linkedAt`).
  - Último uso registrado (`lastUsedAt`).
  - Estado del token con chips de color: `VIGENTE` (verde), `VENCIDO` (ámbar), `REVOCADO` (rojo).
  - Alcances y permisos autorizados (`scopes`), e.g. `openid profile age_verification`.
- **Desvinculación Activa e Inmediata (`POST /oauth/unlink`)**:
  - Cuadro de confirmación destructiva antes de desvincular.
  - En plataformas OAuth: Envía `POST /oauth/unlink` con `{ "clientId": "..." }`. El backend actualiza la entidad `linked_applications` a `REVOKED`, marca los tokens en `oauth_issued_tokens` como `REVOKED` con `revokedAt`, y revoca de inmediato el `jti` en `RevocationStore` (Redis o memoria) por el TTL restante del token.
  - Se registra el evento en `oauth_audit_logs` con `eventType = APP_UNLINKED` y `userIdHash` (HMAC).
  - En aplicaciones TOTP: Se elimina de la base SQLite local y se registra el evento en `DatabaseLogService`.
- **Resiliencia Offline y Estado Vacío**:
  - Ante caída del backend o falta de red, la pantalla no falla ni usa mocks: despliega un banner de advertencia superior de error de conexión y preserva y lista todas las aplicaciones TOTP locales disponibles.
  - Si no hay aplicaciones de ningún tipo, presenta un estado vacío explícito (`"No hay aplicaciones vinculadas."`).
- **Exportación Certificada de Log de Aplicaciones (`GET /oauth/linked-applications/export`)**:
  - Botón de descarga en el AppBar (`Icons.download_rounded`).
  - **Re-autenticación Biométrica / PIN Obligatoria**: Antes de descargar, exige validación biométrica o PIN nativo mediante `local_auth`.
  - Descarga consolidada de eventos forenses en formato JSON con metadatos:
    - Seudónimo de usuario (`userPseudonym`: HMAC-SHA256 del ID de usuario con clave de auditoría).
    - Cantidad total de registros y fecha de emisión.
    - Hash de integridad SHA-256 (`integrityHashSha256`) sobre el payload canónico.
    - Firma digital asimétrica RSA RS256 (`signature`) generada con la clave privada del servidor (`RsaKeyManager`), algoritmo `SHA256withRSA` y `keyId`.
  - Registro de auditoría en servidor: `LINKED_APPS_LOG_EXPORTED`.
  - Diálogo certificado con previsualización, copiado de firma y hash, y opción de compartir vía `Share.share`.

### 17.2. Punto 6: Botón Actividad de Cuenta (`/device_activity` & Endpoints `/users/activity*`)
- **Eliminación Total de Datos Mock**:
  - Sustitución de `SecurityDataService.getMockActivity` por eventos reales de la cuenta persistidos en el backend (`GET /users/activity`).
- **Consolidación de Eventos en Servidor (`UserActivityService`)**:
  - **Autenticación (`auth_audit_logs`)**: Inicios de sesión exitosos y fallidos, cierres de sesión y bloqueos temporales de cuenta.
  - **Validaciones de Riesgo y Blockchain (`blockchain_audit_logs`)**: Evaluaciones del motor de riesgo con decisión (`AUTORIZAR`, `BLOQUEAR`, `REVISIÓN`), score asignado y referencia de transacción blockchain (`txRef`).
  - **Dispositivos (`trusted_devices`)**: Registros de nuevos dispositivos y revocaciones de dispositivos de confianza.
  - **OAuth (`oauth_audit_logs`)**: Emisión de códigos y autorizaciones a terceros.
- **Filtros Dinámicos y Paginación**:
  - Filtro por chips de categoría: `TODOS` (`ALL`), `LOGIN`, `VALIDATION`, `DEVICE`, `OAUTH`, `SECURITY`.
  - Filtro por rango de fechas interactivo con `showDateRangePicker`.
  - Paginación del servidor (`page`, `size: 20`, `hasNext`) con scroll infinito y botón "Cargar más actividades".
  - Estado vacío claro si no hay resultados para los filtros seleccionados.
- **Detalle y Privacidad**:
  - Badges de resultado según decisión (`SUCCESS`, `BLOCKED`, `REVIEW`, `AUTORIZAR`).
  - Dirección IP enmascarada (`maskedIp`) para cumplimiento de privacidad (PII).
  - Referencia de transacción blockchain (`txRef`) con botón para copiar al portapapeles.
- **Exportación Certificada de Log de Actividad (`GET /users/activity/export`)**:
  - Botón de descarga en el AppBar con reautenticación segura (`X-Reauth-Token`).
  - Descarga reporte firmado digitalmente con metadatos (`userPseudonym`, `dateRange`, `generatedAt`, `totalRecords`, `records`), hash SHA-256 y firma RSA RS256 del servidor.
  - Auditoría registrada en servidor: `ACCOUNT_ACTIVITY_EXPORTED`.
  - Compartición nativa mediante diálogo del sistema (`Share.share`).

---

## 18. Cierre Técnico y Endurecimiento de Seguridad (Hardening Final Sprint 5)

### 18.1. Auditoría Integral de Autenticación (`auth_audit_logs` - Migración Flyway V6)
- **Migración `V6__Create_auth_audit_logs_table.sql`**:
  - Crea la tabla `auth_audit_logs` con `id` (UUID), `user_id` (UUID nullable, `REFERENCES users(id) ON DELETE SET NULL`), `email_hmac` (VARCHAR 64), `event_type` (`LOGIN_SUCCESS`, `LOGIN_FAILED`, `LOGOUT`, `ACCOUNT_LOCKED`), `result` (`SUCCESS`, `FAILURE`, `BLOCKED`), `masked_ip` (VARCHAR 50), `device_hash` (VARCHAR 64, HMAC de `X-Device-Id`), `created_at` (TIMESTAMP).
  - Índices estratégicos sobre `user_id`, `email_hmac` y `created_at`.
- **Protección Anti-Enumeración y Privacidad**:
  - Para intentos fallidos con emails que no existen en el sistema, `user_id` se persiste como `null` y únicamente se almacena el HMAC del email normalizado (`computeEmailHmac(email)`).
  - Como `UserActivityService` filtra estrictamente por `user_id = :userId`, los intentos de usuarios inexistentes **jamás** se exponen en la actividad de ningún usuario.
  - Ninguna contraseña, token de acceso o secreto se almacena en la tabla ni en logs de auditoría.
- **Alimentación de Actividad de Cuenta**: La categoría `LOGIN` en `GET /users/activity` se nutre directamente de `auth_audit_logs`, garantizando trazabilidad unificada.

### 18.2. Reautenticación de Paso Elevado de Un Solo Uso (`POST /auth/reauth`)
- **Diseño del Token Criptográfico**:
  - Token efímero de alta entropía (`SecureRandom`), de **un solo uso** atado estrictamente al usuario y al propósito `"EXPORT"`.
  - TTL ultracorto configurable (`app.auth.reauth-token-validity-seconds: 120`).
  - No interoperable como Bearer access token: cualquier intento de uso como JWT es rechazado por el filtro de seguridad de Spring.
  - Consumo atómico: al ser validado en `validateAndConsumeReauthToken`, es destruido de inmediato del almacén, impidiendo ataques de repetición.
- **Protección contra Abuso**:
  - `POST /auth/reauth` cuenta con rate limiting por IP y por usuario (vía `IpResolver`).
  - Los intentos fallidos contabilizan hacia el bloqueo temporal de la cuenta existente y se auditan en `auth_audit_logs`.
- **Implementación en Flutter**:
  - `LinkedApplicationsScreen` y `DeviceActivityTimelineScreen` solicitan la contraseña en un diálogo seguro en memoria que destruye la variable inmediatamente después de la petición, transmitiendo el token resultante en la cabecera `X-Reauth-Token`.

### 18.3. Límites Operacionales y Prevención de Fugas de Información en Exportaciones
- **Paginación y Clampeo**:
  - `GET /users/activity`: Validación de parámetros `page >= 0` y `size <= 50`.
- **Validación de Rangos Temporales**:
  - `GET /users/activity/export` y `GET /oauth/linked-applications/export` exigen parámetros `from` y `to`.
  - Validaciones estrictas: `from <= to`, no futuros (`to <= now()`), y ventana temporal no superior al límite configurable (`app.export.max-range-days: 90`). Si no se cumple, devuelve HTTP 400 Bad Request.
- **Traspaso de Límites y Transparencia**:
  - Límite máximo de registros configurable (`app.export.max-records: 500`).
  - Si los resultados superan el límite, la exportación no se trunca en silencio: incluye explícitamente `"truncated": true` y `"totalMatchingRecords": <count>` dentro del cuerpo certificado y firmado.
- **Garantía Cero Fugas**:
  - Verificado por la suite de pruebas (`ExportLimitsAndPrivacyTest`), ninguna exportación contiene direcciones IP en claro, secretos TOTP (`secretSeed`), JWTs ni refresh tokens.

### 18.4. Clave RSA Dedicada para Firma de Exportaciones (`ExportSigningKeyManager`)
- **Aislamiento Criptográfico**:
  - Separación de responsabilidades: La clave de firma de tokens OAuth (`RsaKeyManager`) no se comparte con la clave de firma de reportes forenses y exportaciones de actividad.
  - Nuevo componente `ExportSigningKeyManager` con par RSA 2048-bit y `kid = sip-export-sig-v1`.
  - En perfiles de producción, se exige obligatoriamente mediante variables de entorno `EXPORT_RSA_PRIVATE_KEY` y `EXPORT_RSA_PUBLIC_KEY`.
- **Aislamiento en JWKS**:
  - `GET /.well-known/jwks.json` expone de forma exclusiva las claves de emisión OAuth.
  - La clave de verificación de exportaciones se expone en su propio endpoint independiente `GET /.well-known/export-keys.json`.

### 18.5. Cifrado Autenticado AES-256-GCM para Exportación Forense (CU-0048)
- **Algoritmo**: `AES/GCM/NoPadding` con clave de 256 bits y tag de autenticación de 128 bits.
- **Vector de Inicialización**: IV criptográfico aleatorio de 12 bytes (`SecureRandom`) por cada exportación.
- **Validación al Iniciar**: `ForensicAuditService` valida en `@PostConstruct` que la clave decodificada tenga exactamente 32 bytes (256 bits), abortando el inicio si la configuración es incorrecta.
- **Datos Adicionales Autenticados (AAD)**: La metadata canónica del reporte (incluyendo hash de integridad, fecha y algoritmos) se asocia como AAD (`cipher.updateAAD`), garantizando que la metadata no pueda ser modificada ni asociada a otro payload cifrado.

### 18.6. Consulta Forense Segura por DNI (`POST /admin/blockchain/records-by-dni`)
- Migración a método `POST` con cuerpo JSON `AuditorDniQueryRequest` (`dni` o `dniHash`, `reason`).
- Exige justificación auditada (`reason.length >= 10`).
- Control de tasa por IP y credencial de auditor.
- Registro en `auth_audit_logs` con `dniSearchHash` (HMAC irreversible), **garantizando que el DNI en claro jamás se escriba en logs ni en auditoría**.

### 18.7. Confinamiento Estricto de Mocks en Flutter
- Sustitución de sockets externos por streams locales en memoria condicionados estrictamente a `kDebugMode`.
- Botones y tarjetas de simulación ("Simular Alerta", inyecciones de prueba) restringidos por `kDebugMode`.
- Cero dependencias de servicios en la nube o terceros en runtime: la aplicación es 100% autónoma y funcional en redes cerradas.

---

## 19. Matriz Integral de Casos de Uso del Proyecto (CU-0001 a CU-0049)

| Caso de Uso | Denominación / Objetivo | Estado Final | Componente Principal | Dependencia Externa / Modo | Suite de Pruebas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **CU-0001** | Registro de Usuario y Alta Inicial | **COMPLETO** | `AuthController`, `RegisterScreen` | Base de datos local (PostgreSQL / H2) | `AuthServiceTest`, `AuthControllerTest` |
| **CU-0002** | Inicio de Sesión y Bloqueo Temporal | **COMPLETO** | `AuthController`, `LoginScreen` | Almacenamiento seguro Keystore | `AntiEnumerationLoginTest` |
| **CU-0003** | Recuperación de Cuenta y Reautenticación | **COMPLETO** | `AuthController`, `ReauthService` | Envío seguro local / Mock | `ReauthExportSecurityTest` |
| **CU-0004** | Gestión de Perfil y Preferencias | **COMPLETO** | `UserController`, `ProfileScreen` | Base de datos | `UserControllerTest` |
| **CU-0010** | Captura de Documento y Prueba de Vida | **COMPLETO** | `VerificationController`, `LivenessScreen` | Cámara local nativa | `VerificationTest` |
| **CU-0011** | Validación Biométrica Facial | **COMPLETO** | `VerificationService` | Algoritmos de visión locales | `VerificationServiceTest` |
| **CU-0015** | Verificación de Identidad Oficial | **SIMULADO** | `MockVerificationProvider` | **RENAPER** (Simulado hasta convenio nacional) | `MockVerificationProviderTest` |
| **CU-0020** | Generación de Códigos TOTP Locales | **COMPLETO** | `TotpService`, `TotpScreen` | SQLite local (`linked_apps`), Keystore | `TotpServiceTest` |
| **CU-0023** | Motor de Riesgo Compuesto Multi-Factor | **COMPLETO** | `RiskAnalysisService` | Motor de reglas desacoplado YAML | `RiskAnalysisServiceTest` |
| **CU-0027** | Transmisión de Token OAuth 2.0 PKCE | **COMPLETO** | `OAuthController`, `OAuthService` | Back-channel HTTP / Sandbox | `OAuthFlowIntegrationTest` |
| **CU-0028** | Consentimiento Explícito de Terceros | **COMPLETO** | `OAuthController`, `ConsentDialog` | Interfaz de usuario nativa | `OAuthServiceTest` |
| **CU-0029** | Registro de Transacción Enriquecido | **COMPLETO** | `BlockchainStatusController` | Privacidad por diseño (Off-chain) | `BlockchainTransactionTest` |
| **CU-0030** | Registro de Auditoría en Blockchain (8 SP) | **COMPLETO** | `BlockchainAuditService`, `BlockchainWorker` | **Red Blockchain** (`MockBlockchainProvider`) | `BlockchainAuditServiceTest` |
| **CU-0031** | Consulta de Consenso de Red (5 SP) | **COMPLETO** | `BlockchainConsensusService` | Red distribuida (Simulación P2P) | `BlockchainConsensusTest` |
| **CU-0032** | Detección de VPN y Proxies | **COMPLETO** | `VpnDetectionService`, `IpResolver` | Base local de rangos y proxies confiables | `VpnDetectionServiceTest` |
| **CU-0033** | Detección de Dispositivo Roteado | **COMPLETO** | `DeviceSecurityService` | Detección de binarios y firmas | `DeviceSecurityTest` |
| **CU-0034** | Detección y Bloqueo de Emulador | **COMPLETO** | `RiskAnalysisService`, `DeviceService` | Propiedades de hardware de sistema | `EmulatorDetectionTest` |
| **CU-0035** | Evaluación de Comportamiento de Interfaz | **COMPLETO** | `TouchAnalyticsService` | Agregación de gestos táctiles | `TouchAnalyticsTest` |
| **CU-0037** | Revocación Activa de Tokens (RFC 7662) | **COMPLETO** | `RevocationStore`, `OAuthController` | Redis / Almacén concurrente en memoria | `TokenRevocationTest` |
| **CU-0040** | Gestión de Dispositivos de Confianza | **COMPLETO** | `DeviceController`, `TrustedDevice` | Base de datos (`trusted_devices`) | `DeviceManagementTest` |
| **CU-0042** | Persistencia Segura y Arranque en Frío | **COMPLETO** | `SplashScreen`, `SessionService` | Android Keystore (`flutter_secure_storage`) | `SessionPersistenceTest` |
| **CU-0044** | Cálculo de Security Score de Cuenta | **COMPLETO** | `SecurityScoreService` | Servidor autoritativo multi-factor | `SecurityScoreTest` |
| **CU-0045** | Visualización de Aplicaciones Vinculadas | **COMPLETO** | `LinkedApplicationsScreen`, `OAuthService` | SQLite local + backend `/oauth/linked-applications` | `LinkedApplicationsTest` |
| **CU-0046** | Consulta y Filtrado de Actividad de Cuenta | **COMPLETO** | `DeviceActivityTimelineScreen` | Consolidación multi-fuente en backend | `UserActivityServiceTest` |
| **CU-0047** | Consulta Forense por DNI para Auditores | **COMPLETO** | `BlockchainStatusController` | POST auditado con HMAC seudonimizado | `AuditorDniQueryTest` |
| **CU-0048** | Exportación Forense AES-256-GCM y RSA | **COMPLETO** | `ForensicAuditService` | Cifrado GCM y firma `SHA256withRSA` | `ForensicExportTest` |
| **CU-0049** | Análisis Batch Nocturno de Fraude | **PARCIAL** | `FraudAlertService` | Ejecución programada batch diferida a despliegue | `FraudDetectionTest` |

---

## 20. Inventario de Señales de Cliente No Confiables y Arquitectura de Mocks

### 20.1. Inventario de Señales de Cliente No Confiables
En estricto cumplimiento del principio de Confianza Cero (*Zero Trust*), ninguna decisión crítica de autenticación o autorización depende ciegamente de los datos provistos por el cliente móvil:

1. **`screenLockConfigured` / `biometricsAvailable`**:
   - *Origen*: `local_auth` / `ScreenLockService` en Flutter.
   - *Riesgo*: Puede ser falsificado en dispositivos manipulados o entornos modificados.
   - *Tratamiento*: El backend no asume hardware seguro. Esta señal solo aporta una ponderación mínima (+5) en el Security Score y condiciona el recordatorio local de sesión.
2. **`behavioralAdultScore` / Métricas Táctiles**:
   - *Origen*: `TouchAnalyticsService` (sensores táctiles de pantalla).
   - *Riesgo*: Variabilidad natural de uso, falsos positivos por discapacidad motriz o emulación de toques.
   - *Tratamiento*: Carácter estrictamente complementario. Jamás desencadena un bloqueo por sí sola. Si no está presente, se aplica la política `missing-policy: neutral`.
3. **`clientVpnDetected`**:
   - *Origen*: `NetworkInterface.list()` en Flutter.
   - *Riesgo*: Modificación del binario cliente para omitir la bandera.
   - *Tratamiento*: Es una señal de advertencia secundaria. La decisión autoritativa sobre proxies y túneles reside en el backend mediante inspección de IP con `IpResolver` y bases de datos locales de ASN/redes de centros de datos.
4. **`emulatorDetected` / `deviceCompromised`**:
   - *Origen*: Inspección de propiedades del sistema Android y binarios `su`.
   - *Riesgo*: Ocultación de root vía Magisk / KernelSU.
   - *Tratamiento*: Regla de bloqueo duro inmediata tanto en cliente como en backend si se detecta; complementada por la validación de firmas de llamadas en el backend.
5. **`X-Device-Id`**:
   - *Origen*: UUID aleatorio generado en la instalación de la app.
   - *Riesgo*: Suplantación o clonación de identificador.
   - *Tratamiento*: El servidor aplica `HMAC-SHA256(deviceId, hmacSecret)` para anonimizar y vincular de forma unívoca el dispositivo a la cuenta en la tabla `trusted_devices`.

### 20.2. Catálogo de Componentes Simulados (100% Offline)
Para garantizar la independencia total de servicios externos de terceros o servicios en la nube durante las fases de desarrollo y auditoría:

| Componente Simulado | Clase / Módulo de Reemplazo | Justificación y Comportamiento Mock | Ruta de Sustitución a Producción |
| :--- | :--- | :--- | :--- |
| **Red Blockchain** | `MockBlockchainProvider` | Simula bloques, transacciones y consenso en memoria sin requerir nodo Ethereum ni consumo de gas. | Implementar cliente RPC Web3j apuntando a red permisionada (e.g., Besu / BFA). |
| **RENAPER / Verificación** | `MockVerificationProvider` | Retorna scores válidos de prueba de vida (95+) y concordancia facial sin invocar la API del organismo. | Conectar vía mTLS y firma digital a la API oficial de RENAPER una vez firmado el convenio. |
| **Inteligencia de IP / VPN** | `VpnDetectionService` | Consulta listas estáticas en memoria de subredes de centros de datos sin invocar servicios de pago. | Integrar feeds comerciales locales (e.g. MaxMind GeoIP2 Anonymous IP database). |
| **Almacén de Revocación** | `InMemoryRevocationStore` | Implementación con `ConcurrentHashMap` con purga por TTL para ambientes sin Redis. | Configurar clúster Redis / Valkey en producción vía Spring Data Redis. |
| **Push Notifications / WS** | `NotificationService` (Flutter) | `StreamController` local en memoria activo exclusivamente en `kDebugMode`. | Configurar Firebase Cloud Messaging (FCM) o servidor WebPush dedicado. |
| **Simulación de Alertas** | `UserDashboardScreen` | Botón "Simular Alerta" confinado a `kDebugMode` para demostración visual de eventos. | Removido automáticamente en binarios release mediante compilación condicional. |

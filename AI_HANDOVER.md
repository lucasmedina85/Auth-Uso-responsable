
## 7. Sprint 4 - Plan de Implementación: Validación de Identidad Hospedada (Didit/Mock)
El flujo de identidad pasará de ser nativo en Flutter a un **flujo hospedado (Hosted Workflow)** delegado a un proveedor (Didit / Mock / Oficial), orquestado a través del backend. 

### Cobertura de Casos de Uso (Actualización Arquitectónica)
- **CU-0015 (Cotejo Biométrico Facial 1:1) y CU-0014 (Liveness Pasivo):** Delegados al flujo del proveedor. La app ya no procesa biometría; el backend recibe el `face_match_score` y el resultado de *liveness* a través del webhook de Didit.
- **CU-0008 (Conexión Segura con API RENAPER/DIDIT) y CU-0009 (Verificación Biográfica):** Se reducen a la creación segura de una sesión hospedada (`/v3/session/`) desde el backend y el consumo posterior del resultado vía webhook. Toda comunicación va por HTTPS.
- **CU-0010 (Recepción de Perfil Digital RENAPER/DIDIT):** Eliminado/Sustituido. Ya no hay descarga de perfil biométrico directo, se confía en el `VerificationResult`.
- **CU-0019 (Cotejo Biométrico Dactilar contra RENAPER/DIDIT):** Opcional / Fuera de alcance para este MVP según definiciones recientes.
- **CU-0023 (Cálculo de Score de Riesgo Compuesto):** El resultado del webhook (`faceMatchScore`, validez del documento) alimentará de manera centralizada el motor de riesgo del backend antes de emitir un veredicto a la app Android.
- **CU-0044 (Manejo de Caída de Servicio RENAPER/DIDIT):** Se aplicará un patrón *Circuit Breaker* en el backend al crear la sesión. Si falla N veces consecutivas, el servicio se degrada mostrando "Servicio en Mantenimiento" y rechaza nuevas verificaciones sin penalizar al usuario, utilizando `checkHealth()` para recuperarse.

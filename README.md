# Autenticador - Juego Responsable (Backend)

Servicio de verificación de identidad con biometría facial.

## Arquitectura
La aplicación provee un pipeline Standalone granular que se conecta a proveedores de identidad (por defecto Didit) y maneja las imágenes completamente en memoria.

## Privacidad y Seguridad (Ley 25.326)
**ATENCIÓN:** El uso de esta API implica capturar, procesar y enviar datos biométricos (rostro, DNI) a proveedores de terceros (Didit).
Es obligatorio que los clientes obtengan el **Consentimiento Informado explícito** del usuario antes de invocar los endpoints de verificación. 
*Privacy by Design:* Las imágenes se mantienen estrictamente en memoria (RAM) y nunca se escriben a disco. Los datos de la petición no se almacenan en el proveedor salvo que se active `DIDIT_SAVE_REQUESTS=true`. Los DNIs en los logs del sistema son enmascarados de manera irreversible.

## Matriz de Casos de Uso (CU)
| ID | Descripción | Componente Backend | Tests de Cobertura |
|---|---|---|---|
| CU-0003 | Extracción de datos del DNI | IdentityVerificationProvider.verifyDocument | StandalonePipelineTest.testHappyPath |
| CU-0005 | Verificación de Vigencia | IdentityVerificationService.executeStandalonePipeline | StandalonePipelineTest.testDocumentDeclined |
| CU-0007 | Minoridad | IdentityVerificationService.isUnderage | StandalonePipelineTest.testUnderage |
| CU-0008 | Conexión Segura | DiditVerificationProvider (x-api-key headers) | (Mockeado en capa HTTP) |
| CU-0009 | Database Validation (RENAPER) | IdentityVerificationProvider.validateRegistry | StandalonePipelineTest.testUnknownDocumentState |
| CU-0010 | Perfil Digital | VerificationResult / RegistryResult | StandalonePipelineTest |
| CU-0014 | Liveness Pasivo | IdentityVerificationProvider.checkLiveness | StandalonePipelineTest.testBusinessExceptionDoesNotTripBreaker |
| CU-0015 | Face Match 1:1 | IdentityVerificationProvider.matchFaces | StandalonePipelineTest |
| CU-0019 | Dactilar | (No soportado en Standalone Didit) | |
| CU-0022 | Horarios sospechosos | RiskEngineService | RiskEngineServiceTest |
| CU-0023 | Motor de Riesgo | RiskEngineService | RiskEngineServiceTest |
| CU-0044 | Circuit Breaker/Caídas | Resilience4j + ProviderTimeoutException | StandalonePipelineTest.testProviderTimeoutThrowsExceptionForBreaker |

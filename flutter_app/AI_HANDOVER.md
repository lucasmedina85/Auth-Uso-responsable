# Auth - Uso Responsable (Handover Log / Bitácora para IAs)

Este documento contiene el estado actual, la arquitectura, los flujos y las consideraciones técnicas del aplicativo Flutter "Auth - Uso Responsable". **Su propósito es servir como contexto base para que cualquier otra IA pueda retomar el desarrollo de este proyecto sin perder el historial de decisiones.**

## 1. Descripción General
Es una aplicación móvil de seguridad y autenticación (tipo Google Authenticator extendido) enfocada en un contexto de **Juego Responsable**. El objetivo principal es verificar de forma estricta la identidad del usuario antes de permitirle vincular una aplicación externa y generar códigos TOTP temporales para la misma.

**Stack Tecnológico:**
- **Framework:** Flutter (Dart).
- **Plataforma principal actual:** Android (testeado en dispositivo físico vía USB).
- **Paquetes principales:** `camera`, `google_mlkit_face_detection`, `permission_handler`, `local_auth`.

## 2. Arquitectura de Estado y Almacenamiento (Mock Actual)
Actualmente, el proyecto opera sin un backend real. Los datos se mantienen en memoria durante la ejecución de la app utilizando Singletons.
- **`SecurityDataService`**: Singleton en `lib/logic/security_data_service.dart`. Administra la lista en memoria de `TrustedDevice` (que incluye tanto dispositivos físicos como 'Aplicaciones Vinculadas').
- **`FaceBiometricService`**: Ubicado en `lib/logic/face_biometric_service.dart`. Maneja la detección facial y simula el cotejo con RENAPER.
- **Navegación**: Utiliza rutas nombradas (`pushNamed`, `pushNamedAndRemoveUntil`) declaradas estáticamente en `main.dart`.

## 3. Flujo Principal (Camino Feliz)
El núcleo de la seguridad del sistema es el proceso de verificación de identidad, que debe completarse **antes** de poder vincular cualquier aplicación nueva.

1. **Dashboard (`/dashboard`)**: Punto de entrada post-login. Muestra accesos rápidos. No permite agregar aplicaciones directamente si no se valida la identidad.
2. **Captura de DNI (`/dni_capture`)**: 
   - Toma foto del frente y luego del reverso.
   - Tiene un límite de **3 intentos fallidos por lado**. Si el OCR (simulado) falla 3 veces en el frente, salta al reverso. Si falla 3 veces en el reverso, fuerza la **carga manual** (`/manual_ocr`).
3. **Prueba de Vida (Liveness) (`/face_liveness`)**:
   - Usa la cámara frontal y `google_mlkit_face_detection` para asegurar que el usuario tiene los ojos abiertos.
   - Simula una consulta a RENAPER (`matchWithRenaperTemplate`) que tiene un 70% de éxito.
   - Tiene un **límite estricto de 3 intentos fallidos**. Al llegar a 3 fallos, la app se bloquea por seguridad y expulsa al usuario al Splash Screen.
4. **Validación Biométrica del Dispositivo (`/fingerprint`)**: Solicita la huella nativa del teléfono mediante `local_auth`.
5. **Éxito y Vinculación (`/authentication_success` -> `/add_application`)**: 
   - Solo al llegar aquí, el usuario es habilitado para cargar el formulario de una nueva aplicación.
   - Se guarda como un `TrustedDevice` de type `external`.
6. **Código QR y TOTP (`/application_qr` -> `/linked_apps_list`)**: Se muestra la configuración y luego la app queda listada. En los detalles de la app vinculada (`/device_details`), el componente `ApplicationCard` renderiza el código TOTP dinámico de 6 dígitos que se refresca cada 30 segundos.

## 4. Resoluciones Críticas del Sprint Actual (Reglas Duras)
Si vas a modificar el código, respeta estas correcciones que costaron horas de depuración:

- **Deadlocks de Cámara en Android**: El plugin `camera` de Flutter sufre de *deadlocks* silenciosos en Android al pasar rápidamente de la cámara trasera a la delantera, dejando la pantalla en negro de forma infinita.
  - **Solución implementada**: Todos los llamados a `availableCameras()` y `controller.initialize()` están envueltos en bloques `.timeout(Duration(seconds: 5))`.
  - En los métodos `dispose()` y al navegar de una cámara a otra, existe un `await Future.delayed(const Duration(milliseconds: 500));` obligatorio para darle tiempo de gracia al sistema operativo de liberar el hardware. **NO BORRAR ESTOS DELAYS NI LOS TIMEOUTS.**
- **Aislamiento de la vinculación**: La ruta `/add_application` fue intencionalmente eliminada de todos los menús rápidos y pantallas vacías (`AuthenticatorDashboardScreen`, `UserDashboardScreen`). La única forma de vincular una app debe ser atravesando el DNI y Liveness obligatoriamente.

## 5. Próximos Pasos (Roadmap para la próxima IA)
1. **Backend y Persistencia Real**: Reemplazar `SecurityDataService` por persistencia real (SQLite/Hive para almacenamiento local, y llamadas a API HTTP con JWT para la nube).
2. **OCR Real**: Reemplazar los delays simulados en `MockOcrProcessor` con una integración real de OCR (Tesseract, Google Cloud Vision, o AWS Textract) para parsear el PDF417 del DNI argentino.
3. **TOTP Real**: Actualmente `totp_components.dart` genera los 6 dígitos usando una semilla básica combinada con el `applicationId`. Se debe migrar al paquete `otp` o `dart_otp` usando claves secretas reales (Base32) generadas por el servidor.

## 6. Requerimientos para la Próxima Versión (Sprint 4)
Para la próxima iteración del proyecto, se ha establecido el siguiente recorrido y objetivos obligatorios a resolver:

1. **Persistencia de usuarios en almacenamiento del dispositivo:**
   - Implementar almacenamiento seguro (ej. `flutter_secure_storage` o SQLite/Hive cifrado) para guardar los perfiles de usuario, evitando perder el estado al cerrar la app.
   
2. **Conexión con otro aplicativo:**
   - Diseñar e implementar el mecanismo de Deep Linking (App Links / Universal Links) o WebSockets para la comunicación segura entre esta app (Auth) y las plataformas externas de Juego Responsable que requieran la validación del TOTP.

3. **Persistencia del código generado y visualización de dispositivos autorizados:**
   - Consolidar la persistencia física de la llave maestra (semilla TOTP) en el dispositivo. 
   - Mejorar o mantener el panel actual (`LinkedApplicationsScreen` y `TrustedDevicesScreen`) asegurando que los códigos se generen consistentemente a través de reinicios de la aplicación leyendo la semilla persistida.

4. **Captura DNI Front - Error en Código de Barras (PDF417):**
   - Refinar el algoritmo o flujo de la cámara frontal del DNI. 
   - Asegurarse de que si el escáner del código de barras falla, el mensaje de error sea claro, y el mecanismo de *fallback* a lectura de texto u OCR manual actúe de manera eficiente sin frustrar al usuario.

5. **Logs de Usuarios y Exportación CSV:**
   - Migrar la pantalla de Actividad / Log de Seguridad (`SecurityHistoryScreen`) para que lea de una tabla local persistente.
   - Implementar una funcionalidad de exportación a CSV (`csv` package) que permita al usuario (o administrador) guardar el registro de actividades (fecha, IP, evento, ubicación) en la carpeta de descargas del dispositivo.

6. **Gestión Real de Autenticación (Login y Registro):**
   - Eliminar el comportamiento actual de "mock" en `LoginScreen` y `RegisterScreen` que permite ingresar al Dashboard digitando cualquier credencial o PIN.
   - Implementar un flujo real de validación: el registro debe persistir las credenciales (localmente o en backend) de forma segura (ej. hashing con bcrypt/argon2), y el Login debe rechazar cualquier intento de acceso con datos no registrados o incorrectos, bloqueando al usuario en la pantalla de bienvenida.

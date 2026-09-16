# WIKI: AUTHENTICATOR - Plataforma de Identidad Digital

## 📖 Descripción del Proyecto
**AUTHENTICATOR** es una aplicación móvil desarrollada en **Flutter** diseñada para proveer una solución de alta seguridad para la verificación de identidad digital. El proyecto fue concebido bajo los más altos estándares de UI/UX (inspirado en plataformas Fintech/Ciberseguridad) enfocado en el cumplimiento de normativas de "Juego Responsable".

El sistema permite a los usuarios enrolarse mediante un riguroso proceso de KYC (Know Your Customer) y mantener un control estricto sobre la seguridad de su cuenta.

---

## 🏗️ Arquitectura y Tecnologías
- **Framework Frontend:** Flutter (Dart).
- **Patrón de Arquitectura:** Layered Architecture (separación por features: `core`, `presentation`, `logic`).
- **Sistema de Diseño (Design System):** Uso de **Design Tokens** (colores industriales, tipografía Montserrat/Inter, modos Claro y Oscuro dinámicos).
- **Mocks y Dependencias Temporales:** Los datos de seguridad, OCR y RENAPER están simulados mediante `SecurityDataService` para permitir una evaluación rápida de la interfaz sin depender de backends reales.

---

## 🚀 Historial de Fases Implementadas

### Fase 1: Arquitectura Base y Flujo de Accesos
- Implementación de las pantallas iniciales: Splash Screen y Welcome Screen.
- Flujo de Login y Registro de usuarios con validaciones de formulario.
- Aceptación de Términos y Condiciones Legales adaptados a normativas de privacidad.
- Chequeo de versión obligatoria de Android para bloquear dispositivos no seguros.
- [Registro del Sprint 3 (Correcciones y Ajustes)](sprint_3.md)

### 🛡️ Especificación Técnica de Casos de Uso (MVP)

#### TARJETA DNI
* **CU-0003 Extracción de Datos Biográficos mediante OCR:** Integración de la biblioteca `ZXing` portada a WebAssembly (`zxing.wasm`). `OcrProcessor` delega el puntero de memoria del array de píxeles (`HEAPU8`) a WA mediante `dart:js_util`, extrayendo la metadata del PDF417 de manera asíncrona. La UI implementa `_showDataConfirmationDialog` para pausar el flujo de estado y someterlo a validación humana.
* **CU-0003 Extracción de Datos Biográficos mediante OCR:** Se escanea el código PDF417 del DNI (frente) y el sistema levanta un modal pidiendo confirmación explícita al usuario ("¿Son correctos los datos?"). Si el frente falla 3 veces, el sistema automáticamente solicita escanear el reverso (MRZ) para extraer la información.
* **CU-0004 Extracción de Código de Trámite de DNI:** El número de trámite se extrae y se suma a la validación de seguridad visual.
* **CU-0005 Validación de Vigencia de Documento:** Si la fecha de expiración del DNI es menor a la actual, el sistema lo bloquea definitivamente e impide el alta.
* **CU-0006 Detección de Manipulación en DNI:** Si se detecta un documento de prueba (ej. `00000000`), el sistema interrumpe todo alertando posible falsificación.

#### CAPTURA DE ROSTRO Y CÁMARA
* **CU-0007 Cálculo de Mayoría de Edad:** El sistema calcula la edad real. Si el titular es menor de 18 años, se le deniega el acceso a la plataforma instantáneamente.
* **CU-0012 Captura Vectorial de Rostro:** La validación de vida ya no es invisible; exige interacción. El usuario debe sacarse una foto y certificar que su rostro salió nítido antes de enviarlo a verificar.
* **CU-0016 Verificación de Intentos Faciales Fallidos:** Si la comparación del rostro con la foto del DNI (RENAPER) falla 3 veces, el módulo se bloquea permanentemente por seguridad.
* **CU-0041 Manejo de Errores de Hardware de Cámara:** Sin cámara no hay identidad. Si se rechazan los permisos, se cancelan las opciones alternativas y se bloquea el proceso.
* **CU-0042 Procesamiento Manual de OCR Fallido:** Ante la falla del escáner en ambos lados del DNI (tras múltiples intentos), se levanta un formulario manual. Se obliga al usuario a subir una foto fotográfica real del DNI (pudiendo usar la Cámara en vivo o seleccionando desde la Galería del dispositivo) para asegurar la evidencia física y luego se ejecuta el OCR automático sobre la imagen provista.

#### FUNCIONALES Y VALIDACIONES EXTRA
* **CU-0022 Análisis de Riesgo por Franja Horaria:** Para protección, se bloquea la generación de códigos de autenticación en horario escolar (07:00 a 17:00).
* **CU-0020 Obtención de Coordenadas Geográficas:** Tras el alta exitosa, se solicitan los permisos de ubicación de Android de forma estricta (`ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION`), informando al usuario desde qué dirección exacta (Calle/Localidad) está autorizando la conexión y la generación de la Llave TOTP Maestra ("Mi Autenticador"), la cual persistirá en el flujo de agregar otras aplicaciones.
- **Historial de Seguridad:** Dashboard con logs de todas las validaciones exitosas o fallidas, incluyendo la visualización de evidencias de captura.
- **Dispositivos Confiables:** Gestión y línea de tiempo (Timeline) de actividad (IP, fechas y eventos) para cada dispositivo o aplicación vinculada.
- **Seguridad:** Interfaz de "Cambiar contraseña" con validación dinámica en tiempo real (checklist visual).

---
---

## 📦 Manual Operativo para el Entorno de Desarrollo

A continuación se detalla el paso a paso para gestionar el repositorio y probar la aplicación en dispositivos móviles físicos.

### 1. ¿Cómo subir el proyecto a GitHub?

Si el proyecto aún no está enlazado a un repositorio, abre la terminal en la raíz del proyecto (`/Auth - Aplicativo`) y ejecuta:

```bash
# 1. Inicializar el repositorio Git local
git init

# 2. Agregar todos los archivos al área de preparación
git add .

# 3. Crear el primer commit
git commit -m "feat: versión inicial completa del Authenticator (Fases 1 a 4)"

# 4. Renombrar la rama principal a 'main'
git branch -M main

# 5. Enlazar con tu repositorio remoto de GitHub
# (Reemplaza la URL con la tuya)
git remote add origin https://github.com/tu-usuario/authenticator.git

# 6. Subir el código a GitHub
git push -u origin main
```

> **Nota:** Si al ejecutar `git push` te pide credenciales, te recomendamos usar un Personal Access Token (PAT) de GitHub o autenticarte mediante SSH.

---

### 2. ¿Cómo compilar el APK para probar en Android?

El proyecto de Flutter está configurado para poder generar un instalable nativo de Android (.apk) de forma muy sencilla. 

1. Abre tu terminal.
2. Navega hasta la carpeta del entorno Flutter:
   ```bash
   cd flutter_app
   ```
3. Descarga todas las dependencias necesarias:
   ```bash
   flutter pub get
   ```
4. Ejecuta el comando de compilación para Android (Release mode):
   ```bash
   flutter build apk --release
   ```
5. **Resultado:** El proceso puede tardar unos minutos dependiendo de la máquina. Cuando finalice, la ruta del archivo generado aparecerá en la consola. Por lo general, se encuentra en:
   ```text
   flutter_app/build/app/outputs/flutter-apk/app-release.apk
   ```
6. **Prueba:** Copia el archivo `app-release.apk` a tu teléfono Android (vía cable USB, Google Drive o WhatsApp) e instálalo para probar la aplicación en modo producción en un dispositivo real.

---

### 3. ¿Cómo probar el aplicativo en modo Local (Web Simulator)?

Gracias a la integración con **WebAssembly**, podés probar el flujo completo de validaciones e identidad desde tu navegador de escritorio, simulando un dispositivo móvil (ideal para testing de UI y OCR rápido).

1. Abre la terminal y ubícate en la carpeta `flutter_app`:
   ```bash
   cd flutter_app
   ```
2. Limpia caché y descarga dependencias:
   ```bash
   flutter clean
   flutter pub get
   ```
3. Inicia el servidor web local en el puerto 8080:
   ```bash
   flutter run -d web-server --web-port 8080
   ```
4. **Instrucciones para visualización móvil en el navegador:**
   - Ingresa a **`http://localhost:8080`** en Google Chrome.
   - Presiona `F12` para abrir las DevTools.
   - Activa el **Modo Dispositivo** presionando `Ctrl + Shift + M`.
   - Selecciona un celular de la lista desplegable (ej. *iPhone 12 Pro* o *Pixel 7*) y presiona `F5` para recargar.
   - *Nota: Si la cámara te pide permisos en el navegador, dáselos o modifícalo haciendo clic en el candado de la URL.*

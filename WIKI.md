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

### Fase 2: Módulo KYC (Validación de Identidad)
- **Captura de DNI:** Interfaz de cámara con guías visuales (overlay) para captura del anverso y reverso del DNI argentino.
- **Biometría Facial:** Proceso simulado de Liveness y captura vectorial del rostro.
- **Revisión de OCR:** Pantalla de confirmación de extracción de datos del DNI simulando conexión con la base del RENAPER.

### Fase 3: Módulo TOTP (Autenticador)
- Implementación de un generador de códigos de 6 dígitos basados en tiempo (Time-Based One-Time Password).
- Indicadores visuales de seguridad y temporizadores circulares al estilo Google/Microsoft Authenticator.

### Fase 4: Auditoría y Dispositivos Confiables
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

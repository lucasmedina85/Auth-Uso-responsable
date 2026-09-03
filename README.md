<<<<<<< HEAD
# Auth-Uso-responsable
Seminario de Integracion Profesional  - Proyecto inicial
=======
# 🛡️ AUTHENTICATOR | Juego Responsable

> **Web Service de Autenticación Externa, Validación Biométrica y Control Preventivo contra la Ludopatía Infantil**

---

## 📌 1. Contexto y Problemática Social

A partir de un exhaustivo relevamiento realizado con equipos pedagógicos del conurbano bonaerense, se identificó la urgente necesidad de combatir la creciente **ludopatía infantil en plataformas de apuestas digitales**, una problemática crítica de las adolescencias actuales que se encuentran atravesadas y vulneradas por el alcance de las tecnologías digitales.

Para abordar este desafío, desarrollamos un **Web Service de Autenticación Externa** que certifica la identidad del usuario de forma 100% independiente del operador de juegos de azar.

### 🌟 Pilares del Ecosistema

- 👤 **Validación Biométrica de Alta Precisión:** Previene el acceso de menores de edad y detecta el uso fraudulento de cuentas pertenecientes a terceros.
- 🏛️ **Validación en Tiempo Real contra RENAPER:** Verificación biográfica y vectorial asistida por Inteligencia Artificial conectada a las bases oficiales.
- ⛓️ **Trazabilidad Blockchain:** Registro inalterable de cada intento de acceso en una red Blockchain para garantizar auditorías transparentes e infalsificables.
- 🔑 **Vinculación con Adulto Responsable:** Uso de tokens temporales y temporizadores de sesión estrictamente vinculados al DNI del adulto responsable.
- 🚨 **Alertas Tempranas y Horario Escolar:** Emisión de alertas instantáneas ante patrones de riesgo o intentos de ingreso dentro de la jornada escolar, permitiendo una intervención humana inmediata.

---

## ⚠️ 2. Alcance y Límites del Sistema

El alcance de este desarrollo se limita **estrictamente** a las funciones de autenticación, verificación de identidad y control preventivo descritas.

> [!IMPORTANT]
> Estas herramientas tecnológicas operan como soporte preventivo y **no sustituyen el juicio de profesionales pedagógicos o de salud**, quienes conservan la autoridad final y la toma de decisiones sobre las acciones a seguir con el menor.

---

## 🏗️ 3. Arquitectura del Proyecto

El sistema está diseñado bajo una arquitectura modular y distribuida, garantizando alta disponibilidad, seguridad nativa en dispositivos móviles y backend microservicios:

```text
Auth - Aplicativo/
├── android_module/               # Módulo nativo Android (Jetpack Compose, CameraX, OpenCV, BiometricPrompt)
│   ├── build.gradle.kts          # Configuración Gradle Kotlin DSL
│   └── src/main/java/com/authenticator/
│       ├── biometric/            # Wrapper nativo BiometricPrompt (CU-0017 / CU-0018)
│       └── ui/                   # Pantallas nativas en Jetpack Compose (Captura DNI, Fallback OCR)
├── flutter_app/                  # Aplicación Móvil Principal (Flutter / Dart)
│   ├── pubspec.yaml              # Dependencias (Montserrat, camera, local_auth, permission_handler)
│   └── lib/
│       ├── core/                 # Tema, Tokens de Diseño, Permisos y Seguridad de pantalla
│       ├── logic/                # Procesador OCR local, Validador de Documento y Cálculo de Edad (18+)
│       └── presentation/         # Pantallas (KYC, Liveness, TOTP, Dashboard auditoría, Dispositivos)
├── backend_service/              # Microservicio Backend de Certificación (Spring Boot / Java)
│   ├── pom.xml                   # Configuración Maven (Spring Security, JWT, Validation)
│   └── src/main/java/com/authenticator/backend/
├── Plan de Implementacion/       # Documentación técnica detallada del MVP
└── WIKI.md                       # Wiki general y manuales operativos
```

### 🛠️ Tecnologías Utilizadas

- **Frontend Móvil:** Flutter (Dart) & Jetpack Compose (Kotlin Nativo).
- **Biometría Nausea & Liveness:** CameraX + OpenCV + `BiometricPrompt` + Redes de IA biométrica.
- **Backend Service:** Java Spring Boot, Spring Security, JWT Tokens.
- **Validaciones Externas:** API RENAPER & Smart Contracts Blockchain.
- **Patrones de Diseño:** Layered Architecture, Clean Architecture, BLoC/Provider para estado.

---

## 📋 4. Plan de Implementación: MVP 30% (15 Casos de Uso)

El plan de implementación inicial cubre las capacidades críticas de autenticación, validación documental y biometría:

| Categoría | ID & Caso de Uso | Descripción y Responsabilidades |
|---|---|---|
| **Setup & UI Security** | **CU-0036**: Dynamic Permissions Request<br>**CU-0021**: Screen Lock Validation<br>**CU-0046**: Mandatory Update UI | Gestión dinámica de permisos de Cámara/Ubicación; verificación de bloqueo de pantalla del dispositivo (PIN/Patrón/Biometría); bloqueo por versión obsoleta. |
| **DNI Capture Flow** | **CU-0001**: DNI Front Capture<br>**CU-0002**: DNI Back Capture<br>**CU-0041**: Camera Hardware Error Handling<br>**CU-0042**: Manual OCR Fallback UI | Captura guiada con overlay interactivo para frente y dorso del DNI; manejo de excepciones de hardware; formulario manual de respaldo para OCR. |
| **Local DNI Logic** | **CU-0003**: OCR Data Extraction<br>**CU-0005**: Document Validity Check<br>**CU-0007**: Legal Age Calculation (18+) | Extracción de datos biográficos (Nombre, Apellido, Fecha de Nacimiento, Vencimiento); validación de vigencia; verificación de edad mínima (>= 18 años). |
| **Facial Biometrics UI** | **CU-0011**: Facial Interface Init<br>**CU-0012**: Facial Vector Capture<br>**CU-0013**: Active Liveness Detection | Inicialización de cámara frontal con guía oval; mapeo vectorial de rostro; prueba activa de vida con desafíos aleatorios (guiño, girar cabeza, sonrisa). |
| **Fingerprint UI & Native** | **CU-0017**: BiometricPrompt Init<br>**CU-0018**: Local Fingerprint Capture | Integración nativa con `BiometricPrompt` de Android y Bridge Flutter; captura e historial de validación dactilar. |

---

## 🎨 5. Sistema de Diseño (Design System)

Para cumplir con altos estándares de ciberseguridad e industria Fintech / Seguridad Industrial, el sistema utiliza un sistema de **Design Tokens** riguroso:

- **Tipografía:** Montserrat (`Montserrat-Bold`, `Montserrat-SemiBold`, `Montserrat-Medium`, `Montserrat-Regular`).
- **Paleta de Colores Oficial:**
  - 🟦 **Primary Call to Action:** Industrial Safety Blue (`#0288D1`)
  - ⬛ **Text & Dark Containers:** Deep Graphite Mine (`#263238`)
  - 🟩 **Success / Validation:** Validation Green (`#2E7D32`)
  - 🟨 **Warning / Moderate Risk:** Warning Yellow (`#FBC02D`)
  - 🟥 **Alerts / Fraud / Block:** Fraud Red (`#C62828`)
  - ⬜ **Backgrounds:** White (`#FFFFFF`) & Light Neutral Gray (`#F5F7F8`)
- **Geometría y Elevación:** Border Radius uniforme de **8px** (`RoundedCornerShape(8.dp)` / `BorderRadius.circular(8)`).

---

## 🚀 6. Historial de Fases Desarrolladas (Wiki Summary)

- **Fase 1: Arquitectura Base y Flujo de Accesos**
  - Screens de Splash y bienvenida.
  - Login y registro con términos y condiciones legales orientados a protección de menores.
  - Validación obligatoria de versión mínima de Android.

- **Fase 2: Módulo KYC (Know Your Customer)**
  - Captura asistida de frente/dorso de DNI argentino.
  - Módulo facial con prueba de vida (Liveness Test) y extracción de vectores.
  - Extracción OCR y mock de contraste contra RENAPER.

- **Fase 3: Módulo TOTP (Autenticador Temporal)**
  - Generación de códigos dinámicos de 6 dígitos basados en tiempo (Time-based OTP).
  - Temporizador circular de seguridad alineado a la sesión del adulto responsable.

- **Fase 4: Auditoría y Dispositivos Confiables**
  - Dashboard de historial de intentos de acceso con evidencia biométrica registrada.
  - Timeline de dispositivos vinculados (IPs, fechas y eventos de riesgo).
  - Gestión de credenciales con checklist dinámico de complejidad.

---

## 📦 7. Manual Operativo para Desarrollo

### 🔹 7.1. Subir el proyecto a GitHub

```bash
# 1. Inicializar repositorio Git local (en la raíz del proyecto)
git init

# 2. Agregar todos los archivos
git add .

# 3. Registrar commit inicial
git commit -m "feat: versión inicial completa del Authenticator (Fases 1 a 4 y Plan MVP)"

# 4. Establecer rama principal
git branch -M main

# 5. Vincular con el repositorio remoto
git remote add origin https://github.com/tu-usuario/authenticator.git

# 6. Subir cambios a GitHub
git push -u origin main
```

### 🔹 7.2. Compilar el APK para Android

1. Abrir la terminal en la carpeta del proyecto Flutter:
   ```bash
   cd flutter_app
   ```
2. Obtener las dependencias:
   ```bash
   flutter pub get
   ```
3. Generar el paquete nativo para Android (Release mode):
   ```bash
   flutter build apk --release
   ```
4. Ubicación del instalable generado:
   ```text
   flutter_app/build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 🧪 8. Plan de Verificación y Pruebas

- **Pruebas Estáticas:** Análisis de código con `flutter analyze`, linter de Kotlin y validación del esquema Maven (`pom.xml`).
- **Pruebas Biométricas y KYC:**
  - Verificación de rechazo a menores de 18 años mediante cálculo de fecha de nacimiento (`CU-0007`).
  - Detección de documentos vencidos (`CU-0005`).
  - Simulación de desafío Liveness facial interactivo (`CU-0013`).
- **Pruebas de Usabilidad UI/UX:** Verificación de contraste cromático según normas WCAG y tipografía Montserrat.

---

<p align="center">
  <b>AUTHENTICATOR | Plataforma de Seguridad e Identidad Digital</b><br>
  <i>Tecnología al servicio de la protección de la infancia y las adolescencias.</i>
</p>
<<<<<<< HEAD
>>>>>>> 19b5d12366 (First commit - MVP Authenticator Juego Responsable)
=======
r
>>>>>>> 17d5c38dc5 (init)

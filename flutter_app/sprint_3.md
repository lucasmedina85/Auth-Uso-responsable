# Sprint 3: Correcciones de Flujo, Permisos y Estabilidad

## Resumen del Sprint
Durante este sprint nos enfocamos en pulir el "camino feliz" del registro de usuario, solucionar errores de interfaz (UI), manejar de forma robusta los permisos nativos de Android y arreglar un bloqueo crítico en el hardware de la cámara.

## Tareas Completadas (Backlog)
- **Flujo de Fallback en Escaneo de DNI (CU-0003, CU-0042)**: Se limitó a 3 intentos máximos tanto para el frente como para el reverso del DNI. Al superar los intentos, la app deriva automáticamente a la carga manual.
- **Mejora en Ingreso Manual de DNI**: Se añadieron botones claros para elegir entre "Cámara" y "Galería" al momento de subir la imagen.
- **Corrección de Permisos de Ubicación (CU-0020)**: Se resolvió el error "No se puede obtener la ubicación" en la pantalla de *Identidad Verificada* añadiendo los permisos de `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION` en el *AndroidManifest*.
- **Correcciones Visuales (UI)**: 
  - Se solucionaron errores de *RenderFlex Overflow* en pantallas de detalles del dispositivo y aplicaciones vinculadas envolviendo textos en widgets `Expanded`.
  - Se corrigió el desbordamiento de texto en los Términos y Condiciones de la Pantalla de Inicio utilizando el widget `Wrap`.
  - Se ajustó el color de la fuente de "Mi Autenticador" en modo oscuro para mejorar la legibilidad.
  - Se arregló un error de interpolación de variables en el modal de confirmación de datos (`$label:`).
- **Persistencia de la Llave Maestra**: Se integró el generador de códigos TOTP ("Mi Autenticador") en la pantalla de *Agregar Aplicación* para que el usuario pueda ver su llave de acceso durante la vinculación.
- **Control de Linterna (Flash)**: Se forzó el apagado del flash (`FlashMode.off`) en todas las instancias de cámara por defecto.

## Dificultades Encontradas y Soluciones
1. **Problema**: *Pantalla negra y cuelgue infinito en "Preparando Cámara..." durante la biometría facial.*
   - **Causa**: Al pasar rápidamente de la captura del reverso del DNI (cámara trasera) a la validación facial (cámara frontal), el sistema operativo Android sufría un *deadlock*. La cámara frontal intentaba encenderse mientras la trasera aún estaba liberando memoria (`dispose`).
   - **Solución**: Se implementó una función asíncrona (`_cleanupAndNavigate`) en la pantalla del DNI que fuerza a la aplicación a usar `await _cameraController!.dispose()` de manera estricta antes de realizar el salto a la pantalla de Liveness. Además, se añadió manejo de errores visuales en caso de denegación de permisos de cámara.

2. **Problema**: *Errores al inicializar cámara frontal intentando apagar la linterna.*
   - **Causa**: Muchas cámaras frontales no tienen flash de hardware. Ordenarles apagar la linterna lanzaba una excepción silenciosa que detenía la ejecución.
   - **Solución**: Se envolvió el comando `setFlashMode(FlashMode.off)` en un bloque `try-catch` que ignora el error si el dispositivo no soporta flash frontal, permitiendo que la cámara encienda con normalidad.


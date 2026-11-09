# DopamiND

Aplicación Flutter para Android con tareas, recordatorios, sesiones de atención plena, enfoque, diario y logros.

## Versión actual

**1.1.1 (código 3)**. Incluye correcciones de navegación, respiración, almacenamiento de fotos y notificaciones en el APK release.

- [Descargar APK 1.1.1](https://github.com/Juancode747/dopamind/releases/tag/v1.1.1)
- [Manual de usuario visual en PDF](docs/Manual_de_usuario.pdf)
- [Cambios y comprobaciones de la versión](docs/CAMBIOS_1.1.1.txt)

## Funciones

- Barra de navegación disponible en las secciones principales.
- Tareas con fecha y hora, aviso y alarma opcional.
- Captura o selección de fotos, vista previa y confirmación antes de completar la tarea.
- Reconocimiento local de objetos con ML Kit. No distingue de forma fiable loza limpia/sucia ni demuestra que una tarea se haya realizado.
- Respiración de 4 segundos de inhalación y 6 de exhalación, con pausa y reanudación.
- Sesiones de enfoque, diario personal y logros.

## Ejecutar

Compilado con Flutter 3.47.7, Dart 3.13.5 y Java 17. Android utiliza compileSdk/targetSdk 36 y NDK 28.2.13676358.

```sh
flutter pub get
flutter test
flutter run
```

## Generar APK

```sh
flutter build apk --release
```

Salida: `build/app/outputs/flutter-apk/app-release.apk`.

El proyecto utiliza la firma de pruebas local. Las claves no están en este repositorio: para actualizar una instalación sin perder los datos hay que conservar la clave usada para firmar su APK anterior. No desinstales la app para intentar resolver un conflicto de firma sin respaldar sus datos.

## Validación

- 15 pruebas automatizadas aprobadas en la versión 1.1.1.
- `flutter analyze`: sin errores ni advertencias; 54 notas informativas de estilo y APIs obsoletas.
- Metadatos genéricos de Gson verificados en el APK release, necesarios para leer y cancelar recordatorios.
- Cámara física, entrega de avisos y precisión del detector pendientes de comprobar en dispositivos reales.

Comprobación adicional del APK con Python 3:

```sh
python tool/check_apk_signatures.py build/app/outputs/flutter-apk/app-release.apk
```

## Límites actuales

Las fotos se procesan localmente. El reconocimiento identifica objetos; la finalización sigue requiriendo confirmación del usuario. El interruptor No Molestar de Enfoque no cambia el ajuste del sistema Android: debe activarse desde el teléfono.

Los datos se guardan localmente. El repositorio no contiene fotos, tareas personales, bases de datos ni credenciales.


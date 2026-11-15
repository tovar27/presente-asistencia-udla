# Presente (`presente_movil`) — Sistema de Control y Gestión de Asistencia Académica

Aplicación móvil multiplataforma desarrollada en **Flutter** y **Firebase** para la gestión, validación en aula y seguimiento reglamentario de asistencia académica en la **Universidad de la Amazonia** (Sede Florencia, Caquetá).

---

## 1. Reglas de Negocio y Marco Reglamentario (Uniamazonia)

El sistema implementa las políticas de presencialidad del Reglamento Estudiantil de la Universidad de la Amazonia:

- **Porcentaje mínimo de asistencia exigida:** `80%` de la intensidad horaria semestral de la asignatura.
- **Causal de pérdida por inasistencias:** Superar el `20%` de horas falladas respecto a la intensidad horaria total (`horasFaltadas > intensidadHoras * 0.20`).
  | Intensidad Semestral | Límite Máximo (20%) | Pérdida de Asignatura (sesiones de 2h) |
  | :---: | :---: | :---: |
  | **32 horas** | 6.4 horas | A partir de **8 horas** (4 clases) |
 
- **Control de puntualidad:** Ventana de tolerancia configurable por el docente al abrir sesión (por defecto `15 minutos`), Tambien estan las opciones de 10 y 20 minutos. Las marcaciones dentro del límite se clasifican como **A tiempo** y las posteriores como **Tardanza**, para los que no se le asigna nada, como ausente
- **Plazo para justificaciones:** Ventana de hasta `3 días hábiles` para radicar excusas médicas o calamidades académicas ante el docente.(Falta de implementar)

---

## 2. Arquitectura del Sistema y Estructura de Archivos

La aplicación sigue una arquitectura cliente-servidor *serverless* basada en **Flutter (Material Design 3)** y **Firebase (Auth + Cloud Firestore)**, separando completamente los flujos e identidades visuales por rol:
- **Rol Docente:** Identidad visual en Verde Institucional (`#00382A`).
- **Rol Estudiante:** Identidad visual en Rojo Institucional (`#B02A37`).

```text
lib/
├── main.dart                                       # Inicialización de Firebase y enrutamiento inicial
└── pantallas/
    ├── pantalla_inicio_sesion.dart                 # Autenticación unificada y redirección por rol
    ├── recuperar_clave/                            # Flujo de restablecimiento de contraseña
    │   ├── recuperar_clave_paso1.dart              # Validación de correo institucional
    │   └── recuperar_clave_paso2.dart              # Confirmación y envío de enlace de recuperación
    ├── docente/                                    # Módulo completo del rol Docente (11 vistas)
    │   ├── registro_docente.dart                   # Registro institucional docente (Paso 1: datos básicos)
    │   ├── registro_docente_paso2.dart             # Registro institucional docente (Paso 2: departamento y credenciales)
    │   ├── navegacion_docente.dart                 # Barra de navegación inferior del docente
    │   ├── home_docente.dart                       # Panel principal, agenda y acceso a cursos
    │   ├── registrar_curso.dart                    # Creación de asignaturas, salones, días, los salones que estan son temporales, pronto le actualizo todos los salones reales
    │   ├── resumen_asistencia.dart                 # Control de sesión activa, por si quieres modificar algo, sale  la lista de estudiantes, al presionar puedes modificar su asistencia
    │   ├── lista_manual.dart                       # Llamado a lista y marcación manual por el docente(arriba tarde, derecha presente, izquierda ausente)
    │   ├── revisar_justificaciones.dart            # Bandeja de revisión y aprobación de excusas()falta implementar su uncionalidad, pero como se muestra en la aplicacion se va a mirar proximamente
    │   ├── lista_cursos_reporte.dart               # Selector de asignaturas para analítica
    │   ├── reporte_curso.dart                      # Reporte detallado de asistencia por curso
    │   └── perfil_docente.dart                     # Perfil, carga académica calculada en vivo y cierre de sesión
    └── estudiante/                                 # Módulo completo del rol Estudiante (9 vistas)
        ├── registro_estudiante.dart                # Registro institucional estudiante (Paso 1: identidad)
        ├── registro_estudiante_paso2.dart          # Registro institucional estudiante (Paso 2: credenciales)
        ├── navegacion_estudiante.dart              # Barra de navegación inferior (Cursos, Asistencia, Historial, Perfil)
        ├── home_estudiante.dart                    # Detección de clase en curso en vivo y cursos inscritos
        ├── detalle_curso_estudiante.dart           # Ficha del curso, reglamento y progreso de presencialidad
        ├── escaner_qr_estudiante.dart              # Escáner de cámara QR con linterna y salto a respaldo, es decir codigo de token
        ├── asistencia_estudiante.dart              # Respaldo manual por token de 6 dígitos y tolerancia
        ├── historial_estudiante.dart               # Vista dual (Lista de sesiones / Calendario) y excusas
        └── perfil_estudiante.dart                  # Informacion personaledición de contacto y cierre de sesión
```

---

## 3. Modelo de Datos en Cloud Firestore

### Colecciones Activas en Producción
1. **`usuarios/{uid}`**
   - Almacena los datos base de cada cuenta autenticada: `nombre`, `correo`, `tipo_documento`, `documento`, `telefono`, `rol` (`Docente` / `Estudiante`), `departamento` (docentes).
2. **`cursos/{cursoId}`**
   - Documentos de cada asignatura creada por el docente: `nombreAsignatura`, `codigo`, `salon`, `bloque`, `horario`, `diasSemana` (lista de días), `intensidadHoras`, `docenteUid` y `requiereGPS`.
3. **`cursos/{cursoId}/estudiantes/{estudianteId}`**
   - Nómina de estudiantes matriculados en cada asignatura (`documento`, `codigo`, `programa`, `nombre`). El módulo estudiante consulta dinámicamente sus cursos mediante `collectionGroup('estudiantes')` filtrando por su `documento`.
4. **`cursos/{cursoId}/sesiones/{sesionId}`**
   - Sesiones de clase creadas por el docente: `estado` (`activa`, `abierta`, `finalizada`), `codigoQR`, `horaInicioRegistro` (`Timestamp`) y `tolerancia` (minutos).

### Esquema Proyectado para la Siguiente Fase
5. **`cursos/{cursoId}/sesiones/{sesionId}/asistencias/{documento}`** *(Por implementar)*
   - Registro individual por sesión y estudiante: `horaMarcacion`, `metodo` (`QR` o `Token`), `estado` (`a_tiempo`, `tardanza`, `ausente`, `justificada`) y `minutosRetraso`.
6. **`cursos/{cursoId}/justificaciones/{justificacionId}`** *(Por implementar)*
   - Solicitudes radicadas desde el historial del estudiante vinculadas a la bandeja `revisar_justificaciones.dart` del docente.

---

## 4. Estado Actual de Implementación

### A. Funcionalidades Terminadas y Conectadas en Tiempo Real
- **Autenticación y Ciclo de Cuenta:** Inicio de sesión con enrutamiento automático por rol, registro guiado en 2 pasos para Docentes y Estudiantes, recuperación de contraseña y cierre de sesión seguro con diálogo de confirmación en ambos módulos.
- **Gestión Académica Docente:** Creación de cursos, vinculación de estudiantes por documento y cálculo en tiempo real en `PerfilDocenteScreen` del número de cursos activos, total de estudiantes a cargo y horas semanales de cátedra (`diasSemana.length * 2`).
- **Detección de Clase en Vivo (Estudiante):** `HomeEstudiante` escucha en tiempo real las sesiones con estado `activa` o `abierta`, habilitando automáticamente el botón **Marcar Asistencia Ahora** y mostrando el límite de tolerancia.
- **Doble Flujo de Validación de Asistencia:**
  - *Vía Principal (QR):* `EscanerQrEstudiante` utiliza `mobile_scanner` para leer el código proyectado por el docente, verifica coincidencia con `codigoQR` de la sesión y calcula, pero en estos momentos solamente arroja el token proyectado en pantalla, falta de modificacion.
  - *Vía de Respaldo (Token):* Si la cámara o el QR fallan, redirige directamente a `AsistenciaEstudiante` para ingresar el token numérico de 6 dígitos con validación de tolerancia.
- **Perfil Estudiantil Reactivo:** `PerfilEstudiante` combina datos de `usuarios/{uid}` y `collectionGroup('estudiantes')` para mostrar código estudiantil (con botón de copiado), programa académico, actualización persistente de teléfono móvil en Firestore y sincronización del interruptor de alertas.

### B. Funcionalidades Maquetadas Pendientes de Persistencia y Cálculos Acumulados
- **Guardado definitivo de marcación:** Al validar exitosamente el QR o el token de 6 dígitos, falta escribir el documento de asistencia del estudiante dentro de la sesión en Firestore.
- **Contadores y métricas acumuladas:** Las tarjetas resumen en `DetalleCursoEstudiante`, `HistorialEstudiante`, `PerfilEstudiante` y reportes docentes están estructuradas e inicializadas limpiamente en `0`, listas para alimentarse de las consultas reales de asistencia.
- **Cálculo automático de pérdida académica:** Evaluar en tiempo real la regla `horasFaltadas > intensidadHoras * 0.20` para alertar riesgo o pérdida por fallas.
- **Persistencia de justificaciones:** Conectar el formulario modal de `HistorialEstudiante` con la colección de justificaciones para que el docente las apruebe o rechace en `RevisarJustificaciones`.
- **Geolocalización GPS en aula:** Incorporar verificación por coordenadas del campus cuando `requiereGPS` esté activo en el curso.

---

## 5. Guía de Instalación y Revisión Académica

### Requisitos
- **Flutter SDK** `>= 3.x` y **Dart SDK** compatibles.
- Dispositivo físico Android (recomendado para probar la cámara en el escáner QR) o emulador Android configurado.
- Permiso de cámara declarado en `android/app/src/main/AndroidManifest.xml` (`android.permission.CAMERA`).

### Ejecución Local
```bash
# 1. Clonar el repositorio
git clone <URL_DEL_REPOSITORIO>
cd presente_movil

# 2. Descargar dependencias (incluyendo firebase_core, firebase_auth, cloud_firestore y mobile_scanner)
flutter pub get

# 3. Ejecutar en dispositivo conectado
flutter run
```

### Escenario de Prueba Recomendado
1. **Como Docente:** Iniciar sesión, crear o abrir un curso, iniciar una sesión de asistencia para generar el código QR/token y revisar las métricas dinámicas en **Mi Perfil**. lo visual, o lo que podra ver, es como va a quedar, posiblemente hayan algunos datos quemados o estaticos, pendientes por cambiar, pero tal como esta, se mirara con todo conectado en la base de datos
2. **Como Estudiante:** Iniciar sesión con un usuario cuyo número de documento esté matriculado en dicho curso; verificar en **Inicio** la tarjeta de *Clase en curso ahora*, abrir el **Escáner QR** y probar también el botón **Ingresar Token de 6 Dígitos** para comprobar el respaldo manual y el cálculo de tolerancia.
3. **Navegación Estudiantil:** Revisar **Detalle del Curso** (reglamento y avance), **Historial** (alternancia entre *Lista de sesiones* y *Calendario mensual*, más diálogo de solicitud de justificación) y **Perfil** (copiado de código estudiantil, edición de teléfono en Firestore y diálogo de cierre de sesión).
4. **Tiempo real en las asignaturas** Las asignaturas tienen un rango, por ejemplo, de 12 a 2 pm, si esta dentro de ese rango la tarjeta de ese curso cambaiara, ya sea para estudiante o para docente, y si esta en fuera del rango, aparecera la tarjeta de diferete estilo, menos llamativa a comparacion de la anterior.

Daros para docente: correo. jho.tovar@udla.edu.co   contraseña: Udla2026*
Datos para estudiante: correo: vane.tam@udla.edu.co contraseña: Udla2026*

Son los dos usuarios registrados solamente, si intentas iniciar sesion como estudiante y agregas el de docente, te dia que no pertenece a ese rol, y asi al contrario igualmente

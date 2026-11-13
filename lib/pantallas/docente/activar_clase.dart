import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import 'lista_manual.dart';

import 'dart:async';
import 'dart:math';

class ActivarClase extends StatefulWidget {
  final String cursoId;
  final String titulo;
  final String grupo;
  final String horario;
  final String salon;

  const ActivarClase({
    super.key,
    required this.cursoId,
    required this.titulo,
    required this.grupo,
    required this.horario,
    required this.salon,
  });

  @override
  State<ActivarClase> createState() => _ActivarClaseState();
}

class _ActivarClaseState extends State<ActivarClase> {
  final Color _colorPrimario = const Color(0xFF00382A);
  final Color _colorFondo = const Color(0xFFF8F9FE);

  Timer? _timer;
  int _segundosTranscurridos = 0;
  String _fechaHoy = "";
  Timer? _timerRotacion;
  int _segundosRotacion = 9;
  bool _registroPausado = false;

  late DocumentReference _sesionRef;
  late CollectionReference _asistenciasRef;

  // Variable para almacenar el total de estudiantes del curso y datos extra
  int _totalMatriculados = 0;
  String _detallesSalonProfesor = "Cargando detalles...";

  @override
  void initState() {
    super.initState();
    DateTime ahora = DateTime.now();
    _fechaHoy =
        "${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}";

    _sesionRef = FirebaseFirestore.instance
        .collection('cursos')
        .doc(widget.cursoId)
        .collection('sesiones')
        .doc(_fechaHoy);
    _asistenciasRef = _sesionRef.collection('asistencias');

    _cargarDatosCurso();
    _inicializarSesion();
    _iniciarTimerRotacion();
  }

  // Carga los datos fijos del curso y el nombre real del profesor logueado
  Future<void> _cargarDatosCurso() async {
    try {
      // 1. Obtener datos del curso
      DocumentSnapshot cursoDoc = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.cursoId)
          .get();

      String salon = 'Salón N/A';
      String bloque = 'Bloque N/A';
      if (cursoDoc.exists) {
        var datos = cursoDoc.data() as Map<String, dynamic>;
        setState(() {
          _totalMatriculados = datos['totalEstudiantes'] ?? 0;
          salon = datos['salon'] ?? 'Salón N/A';
          bloque = datos['bloque'] ?? 'Bloque N/A';
        });
      }

      // 2. Obtener el nombre real del docente logueado actualmente
      final usuarioActivo = FirebaseAuth.instance.currentUser;
      String nombreDocente = 'Docente';

      if (usuarioActivo != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(usuarioActivo.uid)
            .get();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String nombreReal =
              userData['nombre']?.toString() ??
              usuarioActivo.displayName ??
              'Docente';
          if (nombreReal.isNotEmpty) {
            nombreReal = nombreReal[0].toUpperCase() + nombreReal.substring(1);
          }
          nombreDocente = 'Prof. $nombreReal';
        } else {
          nombreDocente = 'Prof. ${usuarioActivo.displayName ?? 'Docente'}';
        }
      }

      // 3. Unir todo para mostrarlo en el encabezado
      setState(() {
        _detallesSalonProfesor = "$bloque • $salon • $nombreDocente";
      });
    } catch (e) {
      print("Error al cargar datos del curso y profesor: $e");
    }
  }

  Future<void> _inicializarSesion() async {
    DocumentSnapshot sesion = await _sesionRef.get();

    if (!sesion.exists) {
      String codigoGenerado =
          "${Random().nextInt(900) + 100} - ${Random().nextInt(900) + 100}";
      await _sesionRef.set({
        'codigoQR': codigoGenerado,
        'horaInicioRegistro': FieldValue.serverTimestamp(),
        'tolerancia': 15,
        'estado': 'activa',
      });
    }
  }

  void _iniciarTemporizador(Timestamp? horaInicioBD) {
    if (horaInicioBD == null) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          Duration diferencia = DateTime.now().difference(
            horaInicioBD.toDate(),
          );
          _segundosTranscurridos = diferencia.inSeconds > 0
              ? diferencia.inSeconds
              : 0;
        });
      }
    });
  }

  void _iniciarTimerRotacion() {
    _timerRotacion?.cancel();
    _timerRotacion = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_segundosRotacion > 1) {
            _segundosRotacion--; // Resta un segundo
          } else {
            _segundosRotacion = 9; // Reinicia el contador

            // Genera un nuevo código aleatorio
            String nuevoCodigo =
                "${Random().nextInt(900) + 100} - ${Random().nextInt(900) + 100}";

            // ¡Actualiza Firebase! (Esto recarga el QR y el texto automáticamente)
            _sesionRef.update({'codigoQR': nuevoCodigo});
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerRotacion?.cancel();
    super.dispose();
  }

  String _formatearTiempo(int segundosTotales) {
    int horas = segundosTotales ~/ 3600;
    int minutos = (segundosTotales % 3600) ~/ 60;
    int segundos = segundosTotales % 60;
    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _sesionRef.snapshots(),
        builder: (context, snapshotSesion) {
          if (!snapshotSesion.hasData || !snapshotSesion.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          var datosSesion = snapshotSesion.data!.data() as Map<String, dynamic>;
          String codigoReal = datosSesion['codigoQR'] ?? '--- - ---';
          int toleranciaReal = datosSesion['tolerancia'] ?? 15;
          Timestamp? horaInicioBD = datosSesion['horaInicioRegistro'];

          if (_timer == null || !_timer!.isActive) {
            _iniciarTemporizador(horaInicioBD);
          }

          // SEGUNDO STREAM: Escucha los estudiantes que van registrando asistencia
          return StreamBuilder<QuerySnapshot>(
            stream: _asistenciasRef
                .orderBy('horaRegistro', descending: true)
                .snapshots(),
            builder: (context, snapshotAsistencias) {
              List<QueryDocumentSnapshot> registros =
                  snapshotAsistencias.hasData
                  ? snapshotAsistencias.data!.docs
                  : [];

              // Cálculos en tiempo real
              int presentes = registros
                  .where((doc) => (doc.data() as Map)['estado'] == 'presente')
                  .length;
              int retardos = registros
                  .where((doc) => (doc.data() as Map)['estado'] == 'retardo')
                  .length;
              int ausentes = _totalMatriculados - (presentes + retardos);
              if (ausentes < 0) ausentes = 0; // Por si hay errores de conteo

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construirEncabezadoClase(),
                    const SizedBox(height: 16),
                    _construirTemporizador(),
                    const SizedBox(height: 16),
                    _construirTarjetaCodigoLive(codigoReal),
                    const SizedBox(height: 16),
                    _construirSeccionTolerancia(toleranciaReal),
                    const SizedBox(height: 16),

                    // MONITOREO DINÁMICO
                    _construirMonitoreoTiempoReal(
                      presentes,
                      retardos,
                      ausentes,
                    ),
                    const SizedBox(height: 16),

                    // LISTA DINÁMICA
                    _construirListaRegistrosRecientes(registros),
                    const SizedBox(height: 24),

                    _construirBotonesAccion(),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Image.asset(
            'recursos/imagenes/logo_presente.png',
            height: 20,
            errorBuilder: (c, e, s) =>
                Icon(Icons.hourglass_bottom, color: _colorPrimario, size: 20),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Presente',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Universidad de la Amazonia',
                style: TextStyle(color: Colors.black54, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {},
        ),
      ], // <-- Fíjate que aquí ya no está el Padding ni el icono del reloj de arena
    );
  }

  Widget _construirEncabezadoClase() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'CLASE EN CURSO',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_fixed, size: 12, color: Color(0xFF2B5B84)),
                    SizedBox(width: 4),
                    Text(
                      'GPS ±15m',
                      style: TextStyle(
                        color: Color(0xFF2B5B84),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _detallesSalonProfesor,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: _colorPrimario,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Perímetro Campus Florencia asegurado',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Activo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _colorPrimario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTemporizador() {
    String horaInicioTxt = widget.horario.split('-').isNotEmpty
        ? widget.horario.split('-')[0].trim()
        : '--:--';
    String horaFinTxt = widget.horario.split('-').length > 1
        ? widget.horario.split('-')[1].trim()
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: (_segundosTranscurridos / 7200).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(_colorPrimario),
                ),
              ),
              Column(
                children: [
                  const Text(
                    'TRANSCURRIDO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatearTiempo(_segundosTranscurridos),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Color(0xFF2B5B84),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Límite 2h 00m',
                          style: TextStyle(
                            color: Color(0xFF2B5B84),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _construirInfoHora('Hora Inicio', horaInicioTxt),
              Container(width: 1, height: 24, color: Colors.grey[300]),
              _construirInfoHora('Cierre de Sesión', horaFinTxt),
              Container(width: 1, height: 24, color: Colors.grey[300]),

              // Buscamos la tolerancia actual directamente de Firestore
              StreamBuilder<DocumentSnapshot>(
                stream: _sesionRef.snapshots(),
                builder: (context, snapshot) {
                  int tol = 15;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    tol = (snapshot.data!.data() as Map)['tolerancia'] ?? 15;
                  }
                  return _construirInfoHora('Tolerancia', '$tol min');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirInfoHora(String titulo, String valor) {
    return Column(
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaCodigoLive(String codigoReal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colorPrimario,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'CÓDIGO DE AULA EN VIVO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  // <-- Le quitamos el const a la fila
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 12,
                    ), // <-- const aquí
                    const SizedBox(width: 4), // <-- const aquí
                    Text(
                      '${_segundosRotacion}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Muestra el PIN numérico generado en Firebase
              Text(
                codigoReal,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigoReal));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // ¡AQUÍ ESTÁ LA MAGIA! Generamos el QR real usando el código de Firebase
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: codigoReal, // El QR contendrá el PIN actual
                    version: QrVersions.auto,
                    size: 48.0, // Tamaño adaptado a tu diseño
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proyectar Código QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Optimizado para escaneo a distancia',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _mostrarQRAmpliado(
                      context,
                      codigoReal,
                    ); // <-- AQUÍ LLAMAMOS A LA FUNCIÓN
                  },
                  icon: const Icon(
                    Icons.fullscreen,
                    size: 16,
                    color: Color(0xFF00382A),
                  ),
                  label: const Text(
                    'Ampliar',
                    style: TextStyle(
                      color: Color(0xFF00382A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB4E3C9),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionTolerancia(int toleranciaActual) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 16, color: Colors.black54),
                  SizedBox(width: 8),
                  Text(
                    'Tolerancia de Entrada',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$toleranciaActual minutos',
                  style: const TextStyle(
                    color: Color(0xFF2B5B84),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Estudiantes registrados luego del minuto fijado se contabilizarán como Tarde / Fuera de tiempo.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _construirBotonTolerancia(10, toleranciaActual),
              const SizedBox(width: 12),
              _construirBotonTolerancia(15, toleranciaActual),
              const SizedBox(width: 12),
              _construirBotonTolerancia(20, toleranciaActual),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirBotonTolerancia(int minutos, int toleranciaActual) {
    bool seleccionado = toleranciaActual == minutos;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _sesionRef.update({'tolerancia': minutos});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: seleccionado ? _colorPrimario : const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? _colorPrimario : Colors.grey[200]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: seleccionado ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                '$minutos min',
                style: TextStyle(
                  color: seleccionado ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirMonitoreoTiempoReal(
    int presentes,
    int retardos,
    int ausentes,
  ) {
    int total = presentes + retardos + ausentes;
    if (total == 0) total = 1; // Evitar división por cero visualmente

    int flexPresentes = ((presentes / total) * 100).toInt();
    int flexRetardos = ((retardos / total) * 100).toInt();
    int flexAusentes = ((ausentes / total) * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    size: 16,
                    color: Colors.black87,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Monitoreo en Tiempo Real',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '$_totalMatriculados Matriculados',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (flexPresentes > 0)
                  Expanded(
                    flex: flexPresentes,
                    child: Container(height: 8, color: _colorPrimario),
                  ),
                if (flexRetardos > 0)
                  Expanded(
                    flex: flexRetardos,
                    child: Container(height: 8, color: const Color(0xFFF43F5E)),
                  ),
                if (flexAusentes > 0 ||
                    (flexPresentes == 0 && flexRetardos == 0))
                  Expanded(
                    flex: flexAusentes == 0 ? 1 : flexAusentes,
                    child: Container(height: 8, color: const Color(0xFFE2E8F0)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _construirStatMonitoreo(
                presentes.toString(),
                'Presentes',
                _colorPrimario,
              ),
              _construirStatMonitoreo(
                retardos.toString(),
                'Retardos',
                const Color(0xFFF43F5E),
              ),
              _construirStatMonitoreo(
                ausentes.toString(),
                'Ausentes',
                Colors.black87,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirStatMonitoreo(String valor, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 6, color: color),
                const SizedBox(width: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirListaRegistrosRecientes(
    List<QueryDocumentSnapshot> registros,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'ÚLTIMOS REGISTROS AUTOMÁTICOS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ),

        if (registros.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Nadie ha registrado asistencia aún.',
                style: TextStyle(color: Colors.black45),
              ),
            ),
          ),

        // Mapeamos los documentos reales de Firebase a los items de la lista
        ...registros.take(5).map((doc) {
          var datos = doc.data() as Map<String, dynamic>;
          String nombre = datos['nombre'] ?? 'Desconocido';
          String codigo = datos['codigo'] ?? 'N/A';
          String estado = datos['estado'] ?? 'presente';

          Timestamp? horaRegistro = datos['horaRegistro'];
          String horaTexto = "--:--";
          if (horaRegistro != null) {
            DateTime d = horaRegistro.toDate();
            horaTexto =
                "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}";
          }

          bool aTiempo = estado == 'presente';
          String estadoTexto = aTiempo ? 'A tiempo' : 'Retardo';

          // Extraer las iniciales del nombre real
          List<String> partesNombre = nombre.split(' ');
          String iniciales = "";
          if (partesNombre.isNotEmpty)
            iniciales += partesNombre[0][0].toUpperCase();
          if (partesNombre.length > 1)
            iniciales += partesNombre[1][0].toUpperCase();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _construirItemRegistro(
              nombre,
              codigo,
              horaTexto,
              estadoTexto,
              aTiempo,
              iniciales,
            ),
          );
        }),
      ],
    );
  }

  Widget _construirItemRegistro(
    String nombre,
    String codigo,
    String hora,
    String estado,
    bool aTiempo,
    String iniciales,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: aTiempo
                ? const Color(0xFFE8F5EE)
                : const Color(0xFFF0F4FA),
            radius: 16,
            child: Text(
              iniciales,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: aTiempo ? _colorPrimario : const Color(0xFF2B5B84),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Código: $codigo • $hora',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: aTiempo
                  ? const Color(0xFFE8F5EE)
                  : const Color(0xFFFFEAEA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              estado,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: aTiempo ? _colorPrimario : const Color(0xFFB02A37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonesAccion() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // 1. Generamos el ID de la sesión con la fecha de hoy (AAAA-MM-DD)
              DateTime ahora = DateTime.now();
              String idDeHoy =
                  "${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}";

              // 2. Navegación real a nuestra nueva Fase 1
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListaManual(
                    cursoId: widget.cursoId,
                    nombreAsignatura: widget.titulo,
                    salon: widget.salon,
                    sesionId: idDeHoy, // <-- ¡AQUÍ ESTÁ LA MAGIA!
                  ),
                ),
              );
            },
            icon: const Icon(Icons.checklist_rtl, size: 18),
            // Mantenemos el FittedBox para evitar el error rojo de los píxeles
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Pasar Lista Manual',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.transparent),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _alternarPausaRegistro,
            icon: Icon(
              _registroPausado
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
              size: 18,
            ),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _registroPausado
                    ? 'Reanudar Registro'
                    : 'Pausar Registro Temporalmente',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _registroPausado
                  ? const Color(0xFFFFF3CD)
                  : const Color(0xFFF4F6F9),
              foregroundColor: _registroPausado
                  ? const Color(0xFF856404)
                  : const Color(0xFF2B5B84),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _finalizarClase,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Finalizar Clase y Consolidar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00382A), // Ajusta al color primario si tienes la variable _colorPrimario
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =================================================================
  // FUNCIONES DE CONTROL DE CLASE (PAUSA Y CIERRE)
  // =================================================================
  void _alternarPausaRegistro() {
    setState(() {
      _registroPausado = !_registroPausado;
    });

    if (_registroPausado) {
      _timerRotacion?.cancel(); // Detiene el reloj de 9s
      _sesionRef.update({'estado': 'pausado'}); // Informa a Firebase
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro pausado. El código ya no cambiará.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      _iniciarTimerRotacion(); // Arranca el reloj de nuevo
      _sesionRef.update({'estado': 'activa'}); // Informa a Firebase
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro reanudado.'),
          backgroundColor: Color(0xFF00382A),
        ),
      );
    }
  }

  void _finalizarClase() {
    // 1. Detenemos todos los cronómetros
    _timer?.cancel();
    _timerRotacion?.cancel();

    // 2. Cerramos la puerta en Firebase para que nadie más entre
    _sesionRef.update({
      'estado': 'finalizada',
      'horaCierreReal': FieldValue.serverTimestamp(),
    });

    // 3. Mostramos mensaje de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clase finalizada y consolidada con éxito.'),
        backgroundColor: Color(0xFF00382A),
      ),
    );

    // 4. Devolvemos al profesor a la pantalla de inicio (Home)
    Navigator.pop(context);
  }

  // =================================================================
  // FUNCIÓN PARA AMPLIAR EL QR EN PANTALLA COMPLETA
  // =================================================================
  void _mostrarQRAmpliado(BuildContext context, String codigoReal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: _colorPrimario,
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Encabezado con botón de cerrar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PROYECCIÓN EN AULA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // QR Gigante
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: codigoReal,
                    version: QrVersions.auto,
                    size: 260.0, // Tamaño gigante
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // PIN Gigante
                Text(
                  codigoReal,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Escanea el código o ingresa el PIN en la app',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

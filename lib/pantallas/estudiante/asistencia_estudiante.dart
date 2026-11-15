import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AsistenciaEstudiante extends StatefulWidget {
  final VoidCallback? onVerHistorial;

  const AsistenciaEstudiante({super.key, this.onVerHistorial});

  @override
  State<AsistenciaEstudiante> createState() => _EstadoAsistenciaEstudiante();
}

class _EstadoAsistenciaEstudiante extends State<AsistenciaEstudiante> {
  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorFondo = Color(0xFFF8F9FA);
  static const Color _colorVerdeOscuro = Color(0xFF0F5132);
  static const Color _colorVerdeSuave = Color(0xFFE8F5EE);
  static const Color _colorTarjetaLila = Color(0xFFEEF0F8);

  final User? _usuarioActual = FirebaseAuth.instance.currentUser;

  final List<TextEditingController> _controladoresToken = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodosToken = List.generate(6, (_) => FocusNode());

  String _documentoEstudiante = '';
  bool _cargandoPerfil = true;

  // Estado visual de validación local (listo para conectar escritura en Firestore)
  bool _asistenciaValidada = false;
  bool _fueTardanza = false;
  String _horaMarcacionTexto = '';

  @override
  void initState() {
    super.initState();
    _cargarDocumentoEstudiante();
  }

  @override
  void dispose() {
    for (final c in _controladoresToken) {
      c.dispose();
    }
    for (final f in _nodosToken) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDocumentoEstudiante() async {
    if (_usuarioActual == null) {
      setState(() => _cargandoPerfil = false);
      return;
    }

    try {
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_usuarioActual.uid)
          .get();

      if (doc.exists && mounted) {
        final Map<String, dynamic>? datos = doc.data() as Map<String, dynamic>?;
        setState(() {
          _documentoEstudiante = (datos?['documento'] ?? '').toString().trim();
          _cargandoPerfil = false;
        });
      } else if (mounted) {
        setState(() => _cargandoPerfil = false);
      }
    } catch (e) {
      debugPrint('Error al cargar documento del estudiante: $e');
      if (mounted) setState(() => _cargandoPerfil = false);
    }
  }

  String _formatearHora12h(DateTime fecha) {
    final int hora24 = fecha.hour;
    final String periodo = hora24 >= 12 ? 'PM' : 'AM';
    int hora12 = hora24 % 12;
    if (hora12 == 0) hora12 = 12;
    final String horaStr = hora12.toString().padLeft(2, '0');
    final String minStr = fecha.minute.toString().padLeft(2, '0');
    return '$horaStr:$minStr $periodo';
  }

  String _calcularHoraLimiteTolerancia(Map<String, dynamic>? datosSesion) {
    if (datosSesion == null) return '08:15 AM';
    final dynamic rawInicio = datosSesion['horaInicioRegistro'];
    final int toleranciaMin = (datosSesion['tolerancia'] is num)
        ? (datosSesion['tolerancia'] as num).toInt()
        : 15;

    if (rawInicio is Timestamp) {
      final DateTime limite = rawInicio.toDate().add(
        Duration(minutes: toleranciaMin),
      );
      return _formatearHora12h(limite);
    }
    return '08:15 AM';
  }

  void _validarToken({
    required bool haySesionActiva,
    required Map<String, dynamic>? datosSesion,
    required String nombreAsignatura,
  }) {
    final String tokenIngresado = _controladoresToken
        .map((c) => c.text.trim())
        .join();

    if (tokenIngresado.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa los 6 dígitos del token entregado por el docente',
          ),
          backgroundColor: _colorEstudiante,
        ),
      );
      return;
    }

    if (haySesionActiva && datosSesion != null) {
      final String codigoReal = (datosSesion['codigoQR'] ?? '')
          .toString()
          .replaceAll(RegExp(r'[^0-9]'), '');

      if (codigoReal.isNotEmpty && tokenIngresado != codigoReal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Token incorrecto. Verifica el código proyectado por el docente.',
            ),
            backgroundColor: _colorEstudiante,
          ),
        );
        return;
      }
    }

    // Calcular si está dentro de la tolerancia
    final DateTime ahora = DateTime.now();
    bool tardanza = false;

    if (datosSesion != null && datosSesion['horaInicioRegistro'] is Timestamp) {
      final DateTime inicio = (datosSesion['horaInicioRegistro'] as Timestamp)
          .toDate();
      final int toleranciaMin = (datosSesion['tolerancia'] is num)
          ? (datosSesion['tolerancia'] as num).toInt()
          : 15;
      final DateTime limite = inicio.add(Duration(minutes: toleranciaMin));
      tardanza = ahora.isAfter(limite);
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _asistenciaValidada = true;
      _fueTardanza = tardanza;
      _horaMarcacionTexto = _formatearHora12h(ahora);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tardanza
              ? 'Asistencia validada con tardanza en $nombreAsignatura'
              : '¡Asistencia validada a tiempo en $nombreAsignatura!',
        ),
        backgroundColor: tardanza ? _colorEstudiante : _colorVerdeOscuro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: SafeArea(
        child: _cargandoPerfil
            ? const Center(
                child: CircularProgressIndicator(color: _colorEstudiante),
              )
            : _documentoEstudiante.isEmpty
            ? _construirContenidoSinCurso()
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('estudiantes')
                    .where('documento', isEqualTo: _documentoEstudiante)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _colorEstudiante),
                    );
                  }

                  final List<QueryDocumentSnapshot> inscripciones =
                      snapshot.data?.docs ?? [];

                  if (inscripciones.isEmpty) {
                    return _construirContenidoSinCurso();
                  }

                  final DocumentReference? refCurso =
                      inscripciones.first.reference.parent.parent;

                  if (refCurso == null) {
                    return _construirContenidoSinCurso();
                  }

                  return _construirVistaConCurso(refCurso);
                },
              ),
      ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      titleSpacing: 16,
      title: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: _colorEstudiante, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presente',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Universidad de la Amazonia',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_outlined,
            color: Colors.black87,
          ),
          onPressed: () {},
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16, left: 4),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, size: 18, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _construirContenidoSinCurso() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _construirTarjetaValidacionToken(
            nombreAsignatura: 'Sin curso activo asignado',
            salon: 'Salón por definir',
            bloque: '',
            docenteUid: '',
            requiereGPS: true,
            haySesionActiva: false,
            datosSesion: null,
          ),
          const SizedBox(height: 16),
          _construirTarjetaEstadoMarcacion(datosSesion: null),
          const SizedBox(height: 16),
          _construirTarjetaUltimasSesiones(refCurso: null),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _construirVistaConCurso(DocumentReference refCurso) {
    return StreamBuilder<DocumentSnapshot>(
      stream: refCurso.snapshots(),
      builder: (context, cursoSnap) {
        final Map<String, dynamic> datosCurso =
            (cursoSnap.hasData && cursoSnap.data!.exists)
            ? (cursoSnap.data!.data() as Map<String, dynamic>)
            : {};

        final String nombreAsignatura =
            (datosCurso['nombreAsignatura'] ?? 'Asignatura').toString();
        final String salon = (datosCurso['salon'] ?? 'Salón por definir')
            .toString();
        final String bloque = (datosCurso['bloque'] ?? '').toString();
        final String docenteUid = (datosCurso['docenteUid'] ?? '').toString();
        final bool requiereGPS = datosCurso['requiereGPS'] is bool
            ? datosCurso['requiereGPS'] as bool
            : true;

        return StreamBuilder<QuerySnapshot>(
          stream: refCurso
              .collection('sesiones')
              .where('estado', whereIn: ['activa', 'abierta'])
              .limit(1)
              .snapshots(),
          builder: (context, sesionSnap) {
            final bool haySesionActiva =
                sesionSnap.hasData && sesionSnap.data!.docs.isNotEmpty;
            final Map<String, dynamic>? datosSesion = haySesionActiva
                ? (sesionSnap.data!.docs.first.data() as Map<String, dynamic>)
                : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _construirTarjetaValidacionToken(
                    nombreAsignatura: nombreAsignatura,
                    salon: salon,
                    bloque: bloque,
                    docenteUid: docenteUid,
                    requiereGPS: requiereGPS,
                    haySesionActiva: haySesionActiva,
                    datosSesion: datosSesion,
                  ),
                  const SizedBox(height: 16),
                  _construirTarjetaEstadoMarcacion(datosSesion: datosSesion),
                  const SizedBox(height: 16),
                  _construirTarjetaUltimasSesiones(refCurso: refCurso),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirTarjetaValidacionToken({
    required String nombreAsignatura,
    required String salon,
    required String bloque,
    required String docenteUid,
    required bool requiereGPS,
    required bool haySesionActiva,
    required Map<String, dynamic>? datosSesion,
  }) {
    final String ubicacionTexto = bloque.isNotEmpty
        ? '$salon • $bloque'
        : salon;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorTarjetaLila,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Píldora Estudiante + Sesión en Vivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 13,
                      color: _colorEstudiante,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Estudiante',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _colorEstudiante,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (haySesionActiva) ...[
                    const Icon(Icons.circle, size: 8, color: _colorEstudiante),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    haySesionActiva ? 'Sesión en Vivo' : 'Esperando Sesión',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _colorEstudiante,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nombre de la asignatura
          Text(
            nombreAsignatura,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // Salón + Bloque + Docente
          FutureBuilder<DocumentSnapshot>(
            future: docenteUid.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(docenteUid)
                      .get()
                : null,
            builder: (context, docSnap) {
              String nombreDocente = 'Docente asignado';
              if (docSnap.hasData &&
                  docSnap.data != null &&
                  docSnap.data!.exists) {
                final Map<String, dynamic>? data =
                    docSnap.data!.data() as Map<String, dynamic>?;
                final String rawNombre = (data?['nombre'] ?? '')
                    .toString()
                    .trim();
                if (rawNombre.isNotEmpty) {
                  nombreDocente = 'Prof. $rawNombre';
                }
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: _colorEstudiante,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$ubicacionTexto • Docente: $nombreDocente',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Barra blanca: Ubicación confirmada
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1E7DD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location,
                    size: 15,
                    color: _colorVerdeOscuro,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    requiereGPS
                        ? 'Ubicación confirmada: Campus Florencia (Uniamazonia)'
                        : 'Validación por código habilitada en aula',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _colorVerdeOscuro,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Subtarjeta blanca: Respaldo con Token de 6 dígitos
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.location_off_outlined,
                        size: 16,
                        color: _colorEstudiante,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '¿Problemas con el GPS o ubicación?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Respaldo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _colorEstudiante,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 6 cajas individuales para el token del docente
                Row(
                  children: List.generate(6, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index < 5 ? 6 : 0),
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _controladoresToken[index],
                            focusNode: _nodosToken[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '•',
                              hintStyle: const TextStyle(
                                fontSize: 18,
                                color: Colors.black54,
                              ),
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: const Color(0xFFFAFAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _colorEstudiante,
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onChanged: (valor) {
                              if (valor.isNotEmpty && index < 5) {
                                _nodosToken[index + 1].requestFocus();
                              } else if (valor.isEmpty && index > 0) {
                                _nodosToken[index - 1].requestFocus();
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),

                // Botón Validar Token de Docente
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _validarToken(
                      haySesionActiva: haySesionActiva,
                      datosSesion: datosSesion,
                      nombreAsignatura: nombreAsignatura,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorEstudiante,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.pin_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                    label: const Text(
                      'Validar Token de Docente',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaEstadoMarcacion({
    required Map<String, dynamic>? datosSesion,
  }) {
    final int toleranciaMin = (datosSesion?['tolerancia'] is num)
        ? (datosSesion!['tolerancia'] as num).toInt()
        : 15;
    final String horaLimiteTexto = _calcularHoraLimiteTolerancia(datosSesion);

    final bool mostrarTardanza = _asistenciaValidada && _fueTardanza;
    final String tituloEstado = !_asistenciaValidada
        ? 'Pendiente por registrar asistencia'
        : (mostrarTardanza
              ? '¡Asistencia registrada con tardanza!'
              : '¡Asistencia registrada a tiempo!');

    final String subtituloEstado = !_asistenciaValidada
        ? 'Ingresa el token de 6 dígitos • Tolerancia de $toleranciaMin min'
        : '$_horaMarcacionTexto • ${mostrarTardanza ? 'Fuera de tolerancia' : 'Dentro de la tolerancia de $toleranciaMin min'}';

    final String badgeTexto = !_asistenciaValidada
        ? 'En espera'
        : (mostrarTardanza ? 'Tardanza' : 'A tiempo');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorVerdeSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mostrarTardanza ? _colorEstudiante : _colorVerdeOscuro,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _asistenciaValidada
                      ? Icons.check_circle_outline
                      : Icons.hourglass_bottom_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloEstado,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: mostrarTardanza
                            ? _colorEstudiante
                            : _colorVerdeOscuro,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtituloEstado,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _colorVerdeOscuro,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: mostrarTardanza ? _colorEstudiante : _colorVerdeOscuro,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      badgeTexto,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFC5E1D2)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.access_time,
                  size: 14,
                  color: _colorEstudiante,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'Tolerancia límite: '),
                      TextSpan(
                        text: '$horaLimiteTexto. ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'Marcaciones posteriores registrarán como ',
                      ),
                      const TextSpan(
                        text: 'Fuera de tolerancia.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaUltimasSesiones({
    required DocumentReference? refCurso,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Últimas 3 sesiones',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: widget.onVerHistorial,
                child: const Text(
                  'Ver historial completo',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _colorEstudiante,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (refCurso == null)
            _construirEstadoVacioSesiones()
          else
            StreamBuilder<QuerySnapshot>(
              stream: refCurso.collection('sesiones').limit(3).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: _colorEstudiante),
                    ),
                  );
                }

                final List<QueryDocumentSnapshot> docs =
                    snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _construirEstadoVacioSesiones();
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final QueryDocumentSnapshot doc = docs[index];
                    final Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    final String fechaSesion = doc.id;
                    final String estadoSesion = (data['estado'] ?? 'finalizada')
                        .toString();

                    String horaTexto = 'Sesión programada';
                    if (data['horaInicioRegistro'] is Timestamp) {
                      horaTexto = _formatearHora12h(
                        (data['horaInicioRegistro'] as Timestamp).toDate(),
                      );
                    }

                    final bool esActiva =
                        estadoSesion == 'activa' || estadoSesion == 'abierta';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: esActiva
                                ? _colorVerdeOscuro
                                : _colorEstudiante,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sesión • $fechaSesion',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  horaTexto,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: esActiva
                                  ? const Color(0xFFD1E7DD)
                                  : const Color(0xFFFDECEE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              esActiva ? 'En curso' : 'Sin marcar',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: esActiva
                                    ? _colorVerdeOscuro
                                    : _colorEstudiante,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _construirEstadoVacioSesiones() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Aún no hay sesiones anteriores registradas en este curso.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}

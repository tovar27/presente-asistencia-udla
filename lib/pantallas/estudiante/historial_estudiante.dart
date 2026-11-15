import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialEstudiante extends StatefulWidget {
  final String? cursoIdInicial;

  const HistorialEstudiante({super.key, this.cursoIdInicial});

  @override
  State<HistorialEstudiante> createState() => _EstadoHistorialEstudiante();
}

class _EstadoHistorialEstudiante extends State<HistorialEstudiante> {
  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorFondo = Color(0xFFF8F9FA);
  static const Color _colorVerdeOscuro = Color(0xFF0F5132);
  static const Color _colorVerdeSuave = Color(0xFFD1E7DD);
  static const Color _colorAmbar = Color(0xFFD97706);
  static const Color _colorJustificada = Color(0xFF3949AB);

  static const List<String> _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  final User? _usuarioActual = FirebaseAuth.instance.currentUser;

  String _documentoEstudiante = '';
  bool _cargandoPerfil = true;
  String? _cursoSeleccionadoId;
  bool _mostrarCalendario = true;
  DateTime _mesVisible = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _cursoSeleccionadoId = widget.cursoIdInicial;
    _cargarDocumentoEstudiante();
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
      debugPrint('Error al cargar documento en historial: $e');
      if (mounted) setState(() => _cargandoPerfil = false);
    }
  }

  String _nombreMesAnio(DateTime fecha) {
    return '${_meses[fecha.month - 1]} ${fecha.year}';
  }

  String _formatearHora12h(DateTime fecha) {
    final int hora24 = fecha.hour;
    final String periodo = hora24 >= 12 ? 'PM' : 'AM';
    int hora12 = hora24 % 12;
    if (hora12 == 0) hora12 = 12;
    return '${hora12.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} $periodo';
  }

  String _formatearFechaCorta(DateTime fecha) {
    final String mesAbrev = _meses[fecha.month - 1].substring(0, 3);
    final DateTime hoy = DateTime.now();
    final bool esHoy =
        fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final String base =
        '${fecha.day.toString().padLeft(2, '0')} $mesAbrev ${fecha.year}';
    return esHoy ? 'Hoy, $base' : base;
  }

  DateTime? _parsearFechaSesion(String docId, Map<String, dynamic> data) {
    if (data['horaInicioRegistro'] is Timestamp) {
      return (data['horaInicioRegistro'] as Timestamp).toDate();
    }
    if (data['fecha'] is Timestamp) {
      return (data['fecha'] as Timestamp).toDate();
    }
    final RegExp regex = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final Match? match = regex.firstMatch(docId);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    return null;
  }

  void _mostrarDialogoJustificacion(String fechaSesionTexto) {
    final TextEditingController motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: _colorEstudiante),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Solicitar Justificación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesión: $fechaSesionTexto',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe el motivo (ej. Incapacidad médica, calamidad doméstica)...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Solicitud preparada (se enviará al conectar el módulo de justificaciones)',
                  ),
                  backgroundColor: _colorEstudiante,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _colorEstudiante,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeVolver = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(puedeVolver),
      body: SafeArea(
        child: _cargandoPerfil
            ? const Center(
                child: CircularProgressIndicator(color: _colorEstudiante),
              )
            : _documentoEstudiante.isEmpty
            ? const Center(
                child: Text(
                  'No se encontró el documento del estudiante.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
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
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aún no estás inscrito en ningún curso activo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    );
                  }

                  final List<DocumentReference> refsCursos = inscripciones
                      .map((doc) => doc.reference.parent.parent)
                      .whereType<DocumentReference>()
                      .toList();

                  if (refsCursos.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final String idActivo =
                      (_cursoSeleccionadoId != null &&
                          refsCursos.any((r) => r.id == _cursoSeleccionadoId))
                      ? _cursoSeleccionadoId!
                      : refsCursos.first.id;

                  final DocumentReference refCursoActivo = refsCursos
                      .firstWhere((r) => r.id == idActivo);

                  return _construirContenidoHistorial(
                    refsCursos: refsCursos,
                    refCursoActivo: refCursoActivo,
                  );
                },
              ),
      ),
    );
  }

  PreferredSizeWidget _construirAppBar(bool puedeVolver) {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: puedeVolver ? 0 : 16,
      leading: puedeVolver
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'Historial de Asistencia',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Estudiante',
                  style: TextStyle(
                    color: _colorEstudiante,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Presente • Uniamazonia',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.black87, size: 22),
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

  Widget _construirContenidoHistorial({
    required List<DocumentReference> refsCursos,
    required DocumentReference refCursoActivo,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: refCursoActivo.snapshots(),
      builder: (context, cursoSnap) {
        final Map<String, dynamic> datosCurso =
            (cursoSnap.hasData && cursoSnap.data!.exists)
            ? (cursoSnap.data!.data() as Map<String, dynamic>)
            : {};

        return StreamBuilder<QuerySnapshot>(
          stream: refCursoActivo.collection('sesiones').snapshots(),
          builder: (context, sesionesSnap) {
            final List<QueryDocumentSnapshot> sesionesDocs =
                sesionesSnap.data?.docs ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (refsCursos.length > 1) ...[
                    _construirSelectorCursos(
                      refsCursos: refsCursos,
                      cursoActivoId: refCursoActivo.id,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _construirTarjetaResumenCurso(datosCurso),
                  const SizedBox(height: 14),
                  _construirInterruptorVista(),
                  const SizedBox(height: 14),
                  if (_mostrarCalendario) ...[
                    _construirTarjetaCalendario(sesionesDocs),
                    const SizedBox(height: 18),
                  ],
                  _construirSeccionRegistroSesiones(sesionesDocs),
                  const SizedBox(height: 18),
                  _construirTarjetaDiscrepancia(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirSelectorCursos({
    required List<DocumentReference> refsCursos,
    required String cursoActivoId,
  }) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: refsCursos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final DocumentReference ref = refsCursos[index];
          final bool seleccionado = ref.id == cursoActivoId;

          return FutureBuilder<DocumentSnapshot>(
            future: ref.get(),
            builder: (context, snap) {
              String etiqueta = 'Curso ${index + 1}';
              if (snap.hasData && snap.data != null && snap.data!.exists) {
                final Map<String, dynamic>? d =
                    snap.data!.data() as Map<String, dynamic>?;
                etiqueta = (d?['nombreAsignatura'] ?? etiqueta).toString();
              }

              return ChoiceChip(
                label: Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: seleccionado ? Colors.white : Colors.black87,
                  ),
                ),
                selected: seleccionado,
                selectedColor: _colorEstudiante,
                backgroundColor: Colors.white,
                onSelected: (_) {
                  setState(() => _cursoSeleccionadoId = ref.id);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _construirTarjetaResumenCurso(Map<String, dynamic> datosCurso) {
    final String codigo = (datosCurso['codigo'] ?? 'ASIG').toString().trim();
    final String nombreAsignatura =
        (datosCurso['nombreAsignatura'] ?? 'Asignatura').toString();
    final String salon = (datosCurso['salon'] ?? 'Salón por definir')
        .toString()
        .trim();
    final String bloque = (datosCurso['bloque'] ?? '').toString().trim();
    final int intensidadHoras = (datosCurso['intensidadHoras'] is num)
        ? (datosCurso['intensidadHoras'] as num).toInt()
        : 36;

    final String ubicacion = bloque.isNotEmpty
        ? '$salon • $bloque • Campus Florencia'
        : '$salon • Campus Florencia';

    // Contadores preparados en 0 hasta conectar la escritura de asistencias
    const int asistidas = 0;
    const int tardanzas = 0;
    const int ausentes = 0;
    const int justificadas = 0;
    const int porcentajeAsistencia = 0;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Código: $codigo',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _colorEstudiante,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 12,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '$intensidadHoras hrs',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nombreAsignatura,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: _colorEstudiante,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ubicacion,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '$porcentajeAsistencia%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _colorEstudiante,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'ASISTENCIA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra segmentada de estados
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 6,
              width: double.infinity,
              color: const Color(0xFFE5E7EB),
              child: const Row(
                children: [
                  Expanded(
                    flex: asistidas,
                    child: ColoredBox(color: _colorVerdeOscuro),
                  ),
                  Expanded(
                    flex: tardanzas,
                    child: ColoredBox(color: _colorAmbar),
                  ),
                  Expanded(
                    flex: ausentes,
                    child: ColoredBox(color: _colorEstudiante),
                  ),
                  Expanded(
                    flex: justificadas,
                    child: ColoredBox(color: _colorJustificada),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4 cajas de resumen
          Row(
            children: [
              _construirMiniCajaEstado(
                colorPunto: _colorVerdeOscuro,
                valor: '$asistidas',
                etiqueta: 'Asistidas',
              ),
              const SizedBox(width: 6),
              _construirMiniCajaEstado(
                colorPunto: _colorAmbar,
                valor: '$tardanzas',
                etiqueta: 'Tardanza',
              ),
              const SizedBox(width: 6),
              _construirMiniCajaEstado(
                colorPunto: _colorEstudiante,
                valor: '$ausentes',
                etiqueta: 'Ausente',
              ),
              const SizedBox(width: 6),
              _construirMiniCajaEstado(
                colorPunto: _colorJustificada,
                valor: '$justificadas',
                etiqueta: 'Justificada',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirMiniCajaEstado({
    required Color colorPunto,
    required String valor,
    required String etiqueta,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 7, color: colorPunto),
                const SizedBox(width: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirInterruptorVista() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mostrarCalendario = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !_mostrarCalendario
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.format_list_bulleted,
                      size: 16,
                      color: !_mostrarCalendario
                          ? _colorEstudiante
                          : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lista de sesiones',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_mostrarCalendario
                            ? _colorEstudiante
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mostrarCalendario = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _mostrarCalendario ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: _mostrarCalendario
                          ? _colorEstudiante
                          : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _nombreMesAnio(_mesVisible),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _mostrarCalendario
                              ? _colorEstudiante
                              : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaCalendario(List<QueryDocumentSnapshot> sesionesDocs) {
    final DateTime hoy = DateTime.now();
    final DateTime primerDiaMes = DateTime(
      _mesVisible.year,
      _mesVisible.month,
      1,
    );
    final int diasEnMes = DateTime(
      _mesVisible.year,
      _mesVisible.month + 1,
      0,
    ).day;
    final int offsetInicio = primerDiaMes.weekday - 1; // Lunes = 0
    final int totalCeldas = ((offsetInicio + diasEnMes) / 7).ceil() * 7;

    // Mapear días con sesión en el mes visible
    final Map<int, String> estadoPorDia = {};
    for (final doc in sesionesDocs) {
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final DateTime? fecha = _parsearFechaSesion(doc.id, data);
      if (fecha != null &&
          fecha.year == _mesVisible.year &&
          fecha.month == _mesVisible.month) {
        estadoPorDia[fecha.day] = (data['estado'] ?? 'sin_marcar').toString();
      }
    }

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
        children: [
          // Encabezado del calendario
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _mesVisible = DateTime(
                          _mesVisible.year,
                          _mesVisible.month - 1,
                        );
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _nombreMesAnio(_mesVisible),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _mesVisible = DateTime(
                          _mesVisible.year,
                          _mesVisible.month + 1,
                        );
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.chevron_right, size: 20),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Semestre 2026-2',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _colorJustificada,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cabecera días de la semana
          const Row(
            children: [
              _EtiquetaDiaSemana('L'),
              _EtiquetaDiaSemana('M'),
              _EtiquetaDiaSemana('M'),
              _EtiquetaDiaSemana('J'),
              _EtiquetaDiaSemana('V'),
              _EtiquetaDiaSemana('S'),
              _EtiquetaDiaSemana('D'),
            ],
          ),
          const SizedBox(height: 8),

          // Grilla de días
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCeldas,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final int numeroDia = index - offsetInicio + 1;
              if (numeroDia < 1 || numeroDia > diasEnMes) {
                return const SizedBox.shrink();
              }

              final bool esHoy =
                  hoy.year == _mesVisible.year &&
                  hoy.month == _mesVisible.month &&
                  hoy.day == numeroDia;

              final String? estadoDia = estadoPorDia[numeroDia];

              Color fondoCelda = Colors.transparent;
              Color colorTexto = Colors.black87;
              if (esHoy) {
                fondoCelda = _colorVerdeOscuro;
                colorTexto = Colors.white;
              } else if (estadoDia == 'activa' || estadoDia == 'abierta') {
                fondoCelda = _colorVerdeSuave;
                colorTexto = _colorVerdeOscuro;
              } else if (estadoDia != null) {
                fondoCelda = const Color(0xFFFDECEE);
                colorTexto = _colorEstudiante;
              }

              return Container(
                decoration: BoxDecoration(
                  color: fondoCelda,
                  borderRadius: BorderRadius.circular(10),
                  border: esHoy
                      ? Border.all(color: _colorVerdeOscuro, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$numeroDia',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: esHoy || estadoDia != null
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: colorTexto,
                      ),
                    ),
                    if (esHoy)
                      const Text(
                        'HOY',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),

          // Leyenda de estados
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemLeyendaCalendario(
                      color: _colorVerdeOscuro,
                      texto: 'Presente (verde)',
                    ),
                    SizedBox(height: 4),
                    _ItemLeyendaCalendario(
                      color: _colorEstudiante,
                      texto: 'Ausente (rojo)',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemLeyendaCalendario(
                      color: _colorAmbar,
                      texto: 'Tardanza (naranja)',
                    ),
                    SizedBox(height: 4),
                    _ItemLeyendaCalendario(
                      color: _colorJustificada,
                      texto: 'Justificada (morado/azul)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionRegistroSesiones(
    List<QueryDocumentSnapshot> sesionesDocs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Registro por sesión',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Total: ${sesionesDocs.length} programadas',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sesionesDocs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Aún no hay sesiones registradas en este curso. Cuando el docente inicie clase, aparecerá el historial aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sesionesDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final QueryDocumentSnapshot doc = sesionesDocs[index];
              final Map<String, dynamic> data =
                  doc.data() as Map<String, dynamic>;
              final int numeroSesion = sesionesDocs.length - index;
              final DateTime? fechaSesion = _parsearFechaSesion(doc.id, data);
              final String fechaTexto = fechaSesion != null
                  ? _formatearFechaCorta(fechaSesion)
                  : doc.id;
              final String horaTexto = fechaSesion != null
                  ? _formatearHora12h(fechaSesion)
                  : '--:--';
              final String estadoDoc = (data['estado'] ?? 'finalizada')
                  .toString();
              final bool esActiva =
                  estadoDoc == 'activa' || estadoDoc == 'abierta';

              // Estado visual base (listo para conectar con el registro individual del estudiante)
              final Color colorBorde = esActiva
                  ? _colorVerdeOscuro
                  : _colorEstudiante;
              final Color colorBadgeFondo = esActiva
                  ? _colorVerdeSuave
                  : const Color(0xFFFDECEE);
              final Color colorBadgeTexto = esActiva
                  ? _colorVerdeOscuro
                  : _colorEstudiante;
              final String textoBadge = esActiva ? 'En curso' : 'Sin registro';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5, color: colorBorde),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F6F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$numeroSesion',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fechaTexto,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            esActiva
                                                ? '$horaTexto • Sesión abierta'
                                                : 'Sin registro de marcaje ($horaTexto)',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                                        color: colorBadgeFondo,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            esActiva
                                                ? Icons.check_circle_outline
                                                : Icons.cancel_outlined,
                                            size: 13,
                                            color: colorBadgeTexto,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            textoBadge,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: colorBadgeTexto,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (!esActiva) ...[
                                  const SizedBox(height: 10),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 13,
                                        color: _colorEstudiante,
                                      ),
                                      SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Inasistencia sin justificar • Pendiente de validar',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: _colorEstudiante,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _mostrarDialogoJustificacion(
                                            fechaTexto,
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _colorEstudiante,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(
                                        Icons.note_add_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Solicitar Justificación',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _construirTarjetaDiscrepancia() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: _colorEstudiante,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Notas alguna discrepancia?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _colorEstudiante,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: 'Recuerda que según el estatuto de la Uniamazonia tienes hasta ',
                      ),
                      TextSpan(
                        text: '3 días hábiles',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _colorEstudiante,
                        ),
                      ),
                      TextSpan(
                        text: ' para radicar tu excusa médica o solicitar aclaración al docente.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaDiaSemana extends StatelessWidget {
  final String texto;
  const _EtiquetaDiaSemana(this.texto);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black45,
          ),
        ),
      ),
    );
  }
}

class _ItemLeyendaCalendario extends StatelessWidget {
  final Color color;
  final String texto;

  const _ItemLeyendaCalendario({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 10.5, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

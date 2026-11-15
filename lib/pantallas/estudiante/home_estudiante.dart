import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'detalle_curso_estudiante.dart';
import 'escaner_qr_estudiante.dart';

class HomeEstudiante extends StatefulWidget {
  const HomeEstudiante({super.key});

  @override
  State<HomeEstudiante> createState() => _EstadoHomeEstudiante();
}

class _EstadoHomeEstudiante extends State<HomeEstudiante> {
  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorFondo = Color(0xFFF8F9FA);

  final User? _usuarioActual = FirebaseAuth.instance.currentUser;

  String _nombreEstudiante = 'Cargando...';
  String _documentoEstudiante = '';
  bool _cargando = true;
  Timer? _relojTimer;

  @override
  void initState() {
    super.initState();
    _obtenerDatosEstudiante();
    // Actualiza la vista cada 15 segundos para detectar automáticamente el inicio de clase
    _relojTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    super.dispose();
  }

  // Fase 1: Perfil dinámico (nombre visible + documento interno)
  Future<void> _obtenerDatosEstudiante() async {
    if (_usuarioActual != null) {
      try {
        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_usuarioActual.uid)
            .get();

        if (doc.exists && mounted) {
          final Map<String, dynamic>? datos =
              doc.data() as Map<String, dynamic>?;
          setState(() {
            _nombreEstudiante = datos?['nombre'] ?? 'Estudiante';
            _documentoEstudiante = (datos?['documento'] ?? '')
                .toString()
                .trim();
            _cargando = false;
          });
        } else if (mounted) {
          setState(() => _cargando = false);
        }
      } catch (e) {
        debugPrint('Error al obtener datos del estudiante: $e');
        if (mounted) setState(() => _cargando = false);
      }
    } else {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: _colorEstudiante),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construirTarjetaPerfil(),
                    const SizedBox(height: 16),
                    _construirContenidoCursosYSesiones(),
                    const SizedBox(height: 24),
                  ],
                ),
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

  Widget _construirTarjetaPerfil() {
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
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFF4F6F9),
                child: Icon(Icons.person, color: Colors.black26, size: 28),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF198754),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreEstudiante,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingeniería de Sistemas',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFDECEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: _colorEstudiante,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirContenidoCursosYSesiones() {
    if (_documentoEstudiante.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirCabeceraCursos(),
          const SizedBox(height: 16),
          _construirEstadoVacioCursos(
            mensaje: 'No encontramos tu número de documento en tu perfil para vincular tus materias.',
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('estudiantes')
          .where('documento', isEqualTo: _documentoEstudiante)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: _colorEstudiante),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error en StreamBuilder de cursos: ${snapshot.error}');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _construirCabeceraCursos(),
              const SizedBox(height: 16),
              _construirEstadoVacioCursos(
                mensaje: 'No se pudieron cargar los cursos en este momento.',
              ),
            ],
          );
        }

        final inscripciones = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fase 4: Detecta si alguna clase ya inició por horario o tiene sesión abierta
            if (inscripciones.isNotEmpty)
              _construirDetectorClasesEnCurso(inscripciones),

            const SizedBox(height: 8),
            _construirCabeceraCursos(),
            const SizedBox(height: 16),

            // Fase 2: Listado dinámico de cursos activos
            if (inscripciones.isEmpty)
              _construirEstadoVacioCursos(
                mensaje: 'Aún no estás inscrito en ningún curso activo. Cuando un docente te agregue, aparecerá aquí.',
              )
            else
              _construirListaCursos(inscripciones),
          ],
        );
      },
    );
  }

  // --- FASE 4: DETECCIÓN POR HORARIO ASIGNADO + SESIÓN ABIERTA ---

  String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  String _nombreDiaHoyNormalizado(DateTime ahora) {
    const Map<int, String> dias = {
      DateTime.monday: 'lunes',
      DateTime.tuesday: 'martes',
      DateTime.wednesday: 'miercoles',
      DateTime.thursday: 'jueves',
      DateTime.friday: 'viernes',
      DateTime.saturday: 'sabado',
      DateTime.sunday: 'domingo',
    };
    return dias[ahora.weekday] ?? '';
  }

  int? _parsearMinutosDelDia(String horaTexto) {
    final String limpio = horaTexto.trim().toUpperCase();
    final RegExp regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$');
    final Match? match = regex.firstMatch(limpio);
    if (match == null) return null;

    int hora = int.parse(match.group(1)!);
    final int minuto = int.parse(match.group(2)!);
    final String? periodo = match.group(3);

    if (periodo == 'PM' && hora != 12) {
      hora += 12;
    } else if (periodo == 'AM' && hora == 12) {
      hora = 0;
    }

    return (hora * 60) + minuto;
  }

  bool _estaEnHorarioDeClase(Map<String, dynamic> datosCurso) {
    final DateTime ahora = DateTime.now();

    // 1. Verificar si hoy está dentro de diasSemana
    final dynamic rawDias = datosCurso['diasSemana'];
    if (rawDias is! List || rawDias.isEmpty) return false;

    final String hoyNormalizado = _nombreDiaHoyNormalizado(ahora);
    final bool coincideDia = rawDias.any(
      (dia) => _normalizarTexto(dia.toString()) == hoyNormalizado,
    );
    if (!coincideDia) return false;

    // 2. Verificar si la hora actual está dentro del rango de horario (ej. "12:00 PM - 02:00 PM (Tarde)")
    final String horarioRaw = (datosCurso['horario'] ?? '').toString();
    final String rangoLimpio = horarioRaw.split('(').first.trim();
    final List<String> partes = rangoLimpio.split('-');
    if (partes.length != 2) return false;

    final int? inicioMin = _parsearMinutosDelDia(partes[0]);
    final int? finMin = _parsearMinutosDelDia(partes[1]);
    if (inicioMin == null || finMin == null) return false;

    final int ahoraMin = (ahora.hour * 60) + ahora.minute;
    return ahoraMin >= inicioMin && ahoraMin < finMin;
  }

  Widget _construirDetectorClasesEnCurso(
    List<QueryDocumentSnapshot> inscripciones,
  ) {
    return Column(
      children: inscripciones.map((inscripcion) {
        final DocumentReference? refCurso = inscripcion.reference.parent.parent;
        if (refCurso == null) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot>(
          stream: refCurso.snapshots(),
          builder: (context, cursoSnap) {
            if (!cursoSnap.hasData || !cursoSnap.data!.exists) {
              return const SizedBox.shrink();
            }

            final Map<String, dynamic> datosCurso =
                cursoSnap.data!.data() as Map<String, dynamic>;

            return StreamBuilder<QuerySnapshot>(
              stream: refCurso
                  .collection('sesiones')
                  .where('estado', whereIn: ['activa', 'abierta'])
                  .limit(1)
                  .snapshots(),
              builder: (context, sesionSnap) {
                final bool enHorario = _estaEnHorarioDeClase(datosCurso);
                final bool registroAbierto =
                    sesionSnap.hasData && sesionSnap.data!.docs.isNotEmpty;

                // Solo mostramos el banner si ya llegó la hora de clase O si el docente abrió sesión
                if (!enHorario && !registroAbierto) {
                  return const SizedBox.shrink();
                }

                final DocumentSnapshot? docSesion = registroAbierto
                    ? sesionSnap.data!.docs.first
                    : null;
                final Map<String, dynamic>? datosSesion =
                    docSesion?.data() as Map<String, dynamic>?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _construirTarjetaClaseEnCurso(
                    cursoId: refCurso.id,
                    sesionId: docSesion?.id,
                    datosCurso: datosCurso,
                    datosSesion: datosSesion,
                    registroAbierto: registroAbierto,
                  ),
                );
              },
            );
          },
        );
      }).toList(),
    );
  }

  String _calcularTextoTolerancia(Map<String, dynamic> datosSesion) {
    final dynamic rawInicio = datosSesion['horaInicioRegistro'];
    final int toleranciaMin = (datosSesion['tolerancia'] is num)
        ? (datosSesion['tolerancia'] as num).toInt()
        : 15;

    if (rawInicio is Timestamp) {
      final DateTime inicio = rawInicio.toDate();
      final DateTime limite = inicio.add(Duration(minutes: toleranciaMin));
      final int restantes = limite.difference(DateTime.now()).inMinutes;

      if (restantes > 0) {
        return 'Quedan $restantes min de tolerancia';
      } else {
        return 'Tiempo de tolerancia vencido';
      }
    }
    return 'Tolerancia: $toleranciaMin min';
  }

  Widget _construirTarjetaClaseEnCurso({
    required String cursoId,
    required String? sesionId,
    required Map<String, dynamic> datosCurso,
    required Map<String, dynamic>? datosSesion,
    required bool registroAbierto,
  }) {
    final String nombreAsignatura =
        datosCurso['nombreAsignatura'] ?? 'Asignatura en curso';
    final String salon = datosCurso['salon'] ?? 'Salón por definir';
    final String horarioCompleto =
        datosCurso['horario'] ?? 'En horario de clase';
    final String horarioLimpio = horarioCompleto.split('(').first.trim();
    final String docenteUid = datosCurso['docenteUid'] ?? '';
    final String textoTolerancia = (registroAbierto && datosSesion != null)
        ? _calcularTextoTolerancia(datosSesion)
        : 'Esperando al docente';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
              color: _colorEstudiante,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _colorEstudiante,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Clase en curso ahora',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _colorEstudiante,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: _colorEstudiante,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              horarioLimpio,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _colorEstudiante,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'ASIGNATURA EN CURSO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _colorEstudiante,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nombreAsignatura,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.hub_outlined,
                        color: _colorEstudiante,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      final data =
                          docSnap.data!.data() as Map<String, dynamic>?;
                      if (data?['nombre'] != null) {
                        nombreDocente = 'Prof. ${data!['nombre']}';
                      }
                    }
                    return Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nombreDocente,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        salon,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Estado del registro (abierto por el docente vs. clase iniciada en espera)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: registroAbierto
                        ? const Color(0xFFE8EAF6)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        registroAbierto ? Icons.alarm : Icons.schedule,
                        size: 18,
                        color: registroAbierto
                            ? _colorEstudiante
                            : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        registroAbierto ? 'Registro abierto' : 'Clase iniciada',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          textoTolerancia,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: registroAbierto
                                ? _colorEstudiante
                                : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        (registroAbierto &&
                            sesionId != null &&
                            datosSesion != null)
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EscanerQrEstudiante(
                                  cursoId: cursoId,
                                  sesionId: sesionId,
                                  datosCurso: datosCurso,
                                  datosSesion: datosSesion,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorEstudiante,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          registroAbierto
                              ? Icons.near_me_outlined
                              : Icons.lock_clock_outlined,
                          color: registroAbierto
                              ? Colors.white
                              : Colors.black45,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          registroAbierto
                              ? 'Marcar Asistencia Ahora'
                              : 'Registro aún no habilitado',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: registroAbierto
                                ? Colors.white
                                : Colors.black54,
                          ),
                        ),
                      ],
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

  // --- FASE 2: LISTA DE CURSOS INSCRITOS ---
  Widget _construirListaCursos(List<QueryDocumentSnapshot> inscripciones) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: inscripciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final DocumentReference? refCurso =
            inscripciones[index].reference.parent.parent;
        if (refCurso == null) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot>(
          stream: refCurso.snapshots(),
          builder: (context, cursoSnap) {
            if (!cursoSnap.hasData || !cursoSnap.data!.exists) {
              return const SizedBox.shrink();
            }

            final Map<String, dynamic> datosCurso =
                cursoSnap.data!.data() as Map<String, dynamic>;

            final String nombreAsignatura =
                datosCurso['nombreAsignatura'] ?? 'Asignatura sin nombre';
            final String salon = datosCurso['salon'] ?? 'Salón por definir';
            final String grupo = datosCurso['grupo'] ?? '';
            final int intensidadHoras = (datosCurso['intensidadHoras'] is num)
                ? (datosCurso['intensidadHoras'] as num).toInt()
                : 36;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleCursoEstudiante(
                      cursoId: refCurso.id,
                      datosCurso: datosCurso,
                    ),
                  ),
                );
              },
              child: _construirTarjetaCursoDinamica(
                nombreAsignatura: nombreAsignatura,
                salon: salon,
                grupo: grupo,
                intensidadHoras: intensidadHoras,
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirEstadoVacioCursos({required String mensaje}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFDECEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: _colorEstudiante,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin cursos registrados',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaCursoDinamica({
    required String nombreAsignatura,
    required String salon,
    required String grupo,
    required int intensidadHoras,
  }) {
    final int metaMinima = (intensidadHoras * 0.8).ceil();

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: _colorEstudiante,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreAsignatura,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grupo.isNotEmpty ? '$salon • $grupo' : salon,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1E7DD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF0F5132)),
                    SizedBox(width: 6),
                    Text(
                      'Al día / Cumple',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F5132),
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
              const Text(
                'Intensidad semestral',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '0 / $intensidadHoras hrs',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0.0,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF198754)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Meta mínima: $metaMinima hrs (80% de $intensidadHoras hrs)',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Restan $intensidadHoras hrs por dictar',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirCabeceraCursos() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sus Cursos Activos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Mínimo reglamentario: 80% de 36 horas lectivas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFE8EAF6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.school_outlined,
            size: 18,
            color: Color(0xFF3949AB),
          ),
        ),
      ],
    );
  }
}

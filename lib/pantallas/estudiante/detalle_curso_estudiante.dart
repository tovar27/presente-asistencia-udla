import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'historial_estudiante.dart';

class DetalleCursoEstudiante extends StatelessWidget {
  final String cursoId;
  final Map<String, dynamic> datosCurso;

  const DetalleCursoEstudiante({
    super.key,
    required this.cursoId,
    required this.datosCurso,
  });

  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorFondo = Color(0xFFF8F9FA);
  static const Color _colorVerdeOscuro = Color(0xFF0F5132);
  static const Color _colorVerdeFondo = Color(0xFFD1E7DD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(context),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cursos')
              .doc(cursoId)
              .snapshots(),
          builder: (context, snapshot) {
            final Map<String, dynamic> cursoActual =
                (snapshot.hasData && snapshot.data!.exists)
                ? (snapshot.data!.data() as Map<String, dynamic>)
                : datosCurso;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _construirTarjetaInfoCurso(cursoActual),
                  const SizedBox(height: 16),
                  _construirBannerClaseEnCurso(context),
                  const SizedBox(height: 16),
                  _construirTarjetaAvanceAsistencia(cursoActual),
                  const SizedBox(height: 16),
                  _construirBotonHistorial(context),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _construirAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'Detalle del Curso',
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

  String _formatearDiasYHorario(Map<String, dynamic> curso) {
    final dynamic rawDias = curso['diasSemana'];
    final String horarioRaw = (curso['horario'] ?? 'Horario por definir')
        .toString();
    final String horarioLimpio = horarioRaw.split('(').first.trim();

    if (rawDias is List && rawDias.isNotEmpty) {
      final List<String> dias = rawDias.map((d) => d.toString()).toList();
      final String textoDias = dias.length == 1
          ? dias.first
          : '${dias.sublist(0, dias.length - 1).join(', ')} y ${dias.last}';
      final int horasSemanales = dias.length * 2;
      return '$textoDias • $horarioLimpio ($horasSemanales hrs/sem)';
    }

    return horarioLimpio;
  }

  String _formatearUbicacion(Map<String, dynamic> curso) {
    final String salon = (curso['salon'] ?? 'Salón por definir')
        .toString()
        .trim();
    final String bloque = (curso['bloque'] ?? '').toString().trim();

    if (bloque.isNotEmpty) {
      return '$salon • $bloque (Campus Florencia)';
    }
    return '$salon (Campus Florencia)';
  }

  String _obtenerIniciales(String nombre) {
    final List<String> partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return 'DC';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }

  Widget _construirTarjetaInfoCurso(Map<String, dynamic> curso) {
    // Campos exactos del mockup: codigo, grupo, nombreAsignatura, diasSemana, horario, salon, bloque, docenteUid
    final String codigo = (curso['codigo'] ?? 'ASIG').toString().trim();
    final String grupo = (curso['grupo'] ?? 'Grupo 01').toString().trim();
    final String nombreAsignatura =
        (curso['nombreAsignatura'] ?? 'Asignatura sin nombre').toString();
    final String docenteUid = (curso['docenteUid'] ?? '').toString().trim();
    final String textoHorario = _formatearDiasYHorario(curso);
    final String textoUbicacion = _formatearUbicacion(curso);

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
                            codigo,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _colorEstudiante,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              grupo,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      nombreAsignatura,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ingeniería de Sistemas • Uniamazonia',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: _colorEstudiante,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: _colorEstudiante,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    textoHorario,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.business_outlined,
                  size: 16,
                  color: _colorEstudiante,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    textoUbicacion,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 14),
          FutureBuilder<DocumentSnapshot>(
            future: docenteUid.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(docenteUid)
                      .get()
                : null,
            builder: (context, docSnap) {
              String nombreDocente = 'Docente asignado';
              String correoDocente = 'docente@udla.edu.co';
              String iniciales = 'DC';

              if (docSnap.hasData &&
                  docSnap.data != null &&
                  docSnap.data!.exists) {
                final Map<String, dynamic>? data =
                    docSnap.data!.data() as Map<String, dynamic>?;
                final String rawNombre = (data?['nombre'] ?? '')
                    .toString()
                    .trim();
                final String rawCorreo = (data?['correo'] ?? '')
                    .toString()
                    .trim();

                if (rawNombre.isNotEmpty) {
                  nombreDocente = 'Prof. $rawNombre';
                  iniciales = _obtenerIniciales(rawNombre);
                }
                if (rawCorreo.isNotEmpty) {
                  correoDocente = rawCorreo;
                }
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _colorEstudiante,
                    child: Text(
                      iniciales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreDocente,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          correoDocente,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _construirBannerClaseEnCurso(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFDECEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.circle,
                size: 10,
                color: _colorEstudiante,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hay una clase en curso ahora',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ve a Inicio para marcar tu asistencia',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Sesión en vivo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaAvanceAsistencia(Map<String, dynamic> curso) {
    final int intensidadHoras = (curso['intensidadHoras'] is num)
        ? (curso['intensidadHoras'] as num).toInt()
        : 36;
    final double metaMinimaHoras = intensidadHoras * 0.8;
    final String textoMeta = metaMinimaHoras % 1 == 0
        ? '${metaMinimaHoras.toInt()}h'
        : '${metaMinimaHoras.toStringAsFixed(1)}h';

    // Variables base listas para conectar con el registro de asistencias
    const int horasAsistidas = 0;
    const int asistidas = 0;
    const int tardanzas = 0;
    const int faltas = 0;
    final double porcentaje = intensidadHoras > 0
        ? (horasAsistidas / intensidadHoras) * 100
        : 0.0;

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
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.assessment_outlined,
                      size: 18,
                      color: _colorVerdeOscuro,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Mi Avance de Asistencia',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _colorVerdeFondo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Al día',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _colorVerdeOscuro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: '$horasAsistidas ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(
                      text: '/ $intensidadHoras hrs',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${porcentaje.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Meta mín: 80% ($textoMeta)',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: intensidadHoras > 0
                  ? (horasAsistidas / intensidadHoras).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                _colorVerdeOscuro,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '80% mín',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              SizedBox(width: 24),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _construirCajaMetrica(
                valor: '$asistidas',
                etiqueta: 'Asistidas',
                colorValor: _colorVerdeOscuro,
              ),
              const SizedBox(width: 10),
              _construirCajaMetrica(
                valor: '$tardanzas',
                etiqueta: 'Tardanza',
                colorValor: _colorEstudiante,
              ),
              const SizedBox(width: 10),
              _construirCajaMetrica(
                valor: '$faltas',
                etiqueta: 'Faltas',
                colorValor: Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.balance_outlined,
                    size: 18,
                    color: Color(0xFF3949AB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Reglamento Estudiantil Uniamazonía: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: 'Se exige un mínimo de '),
                        TextSpan(
                          text: '80% de presencialidad',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' computada para tener derecho a presentar la evaluación final ordinaria.',
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

  Widget _construirCajaMetrica({
    required String valor,
    required String etiqueta,
    required Color colorValor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorValor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirBotonHistorial(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistorialEstudiante(cursoIdInicial: cursoId),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFFDECEE),
                  child: Icon(Icons.history, size: 18, color: _colorEstudiante),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ver Historial Completo de Sesiones',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class RevisarJustificacionesScreen extends StatefulWidget {
  final String cursoId;
  final String nombreAsignatura;
  final String codigo;

  const RevisarJustificacionesScreen({
    super.key,
    required this.cursoId,
    required this.nombreAsignatura,
    required this.codigo,
  });

  @override
  State<RevisarJustificacionesScreen> createState() =>
      _RevisarJustificacionesScreenState();
}

class _RevisarJustificacionesScreenState
    extends State<RevisarJustificacionesScreen> {
  final TextEditingController _controladorBusqueda = TextEditingController();
  String _textoBusqueda = "";
  String _filtroActual =
      "Pendientes"; // Todos, Pendientes, Aprobadas, Rechazadas

  // Colores del sistema Uniamazonia
  final Color _colorPrimario = const Color(0xFF00382A);
  final Color _colorFondo = const Color(0xFFF9F9FF);
  final Color _colorTarjetaClara = const Color(0xFFEEF0FF);

  // Datos simulados idénticos a tu mockup para maquetar
  List<Map<String, dynamic>> _justificaciones = [
    {
      'id': '1',
      'nombre': 'Mariana Castro Vargas',
      'documento': '1001234567',
      'iniciales': 'MC',
      'fechaFalla': '21 Nov 2023',
      'horaFalla': '08:00 - 10:00 AM',
      'motivoCorto': 'Cita Médica',
      'mensaje': '"Presento incapacidad expedida por Bienestar Universitario (IPS) por fuerte dolor agudo (Cólicos). Debido a ello estuve inasistiendo y solicito amablemente me sea justificada la falla."',
      'archivoNombre': 'INCAPACIDAD_MARIAN...',
      'estado': 'Pendiente', // Pendiente, Aprobada, Rechazada
    },
    {
      'id': '2',
      'nombre': 'Juan David Cuellar V.',
      'documento': '1112456789',
      'iniciales': 'JC',
      'fechaFalla': '03 Nov 2023',
      'horaFalla': '08:00 - 10:00 AM',
      'motivoCorto': 'Calamidad Doméstica',
      'mensaje': '"Convocatoria con la selección de fútbol de la Universidad de la Amazonia en la fase regional ASCUN 2023. Adjunto carta oficial de la Vicerrectoría de Bienestar."',
      'archivoNombre': 'CONVOCATORIA_ASCU...',
      'estado': 'Pendiente',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Lógica de filtrado
    List<Map<String, dynamic>> justificacionesFiltradas = _justificaciones
        .where((just) {
          final coincideBusqueda =
              just['nombre'].toString().toLowerCase().contains(
                _textoBusqueda.toLowerCase(),
              ) ||
              just['documento'].toString().contains(_textoBusqueda);

          final coincideFiltro =
              _filtroActual == 'Todos' || just['estado'] == _filtroActual;

          return coincideBusqueda && coincideFiltro;
        })
        .toList();

    int pendientes = _justificaciones
        .where((j) => j['estado'] == 'Pendiente')
        .length;
    int aprobadas = _justificaciones
        .where((j) => j['estado'] == 'Aprobada')
        .length;
    int rechazadas = _justificaciones
        .where((j) => j['estado'] == 'Rechazada')
        .length;

    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _construirCabeceraCurso(),
          const SizedBox(height: 20),
          _construirContadores(pendientes, aprobadas, rechazadas),
          const SizedBox(height: 20),
          _construirBarraBusqueda(),
          const SizedBox(height: 16),
          _construirFiltros(),
          const SizedBox(height: 20),

          if (justificacionesFiltradas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No hay justificaciones en esta categoría.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...justificacionesFiltradas.map(
              (just) => _construirTarjetaJustificacion(just),
            ),

          const SizedBox(height: 16),
          _construirBannerReglamento(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Justificaciones',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'UNIVERSIDAD DE LA AMAZONIA',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            backgroundColor: _colorTarjetaClara,
            child: const Icon(Icons.school, color: Color(0xFF00382A), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _construirCabeceraCurso() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.library_books_outlined,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GESTIÓN DE AUSENCIAS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorTarjetaClara,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Semestre 2024-1',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B3B6D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.nombreAsignatura,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Código: ${widget.codigo}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _construirContadores(int pendientes, int aprobadas, int rechazadas) {
    return Row(
      children: [
        Expanded(
          child: _cuadroContador(
            'Pendientes',
            pendientes.toString(),
            const Color(0xFFFFF4E5),
            const Color(0xFFE68A00),
            Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _cuadroContador(
            'Aprobadas',
            aprobadas.toString(),
            const Color(0xFFE8F5EE),
            const Color(0xFF008040),
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _cuadroContador(
            'Rechazadas',
            rechazadas.toString(),
            const Color(0xFFFFEAEA),
            const Color(0xFFCC0000),
            Icons.cancel_outlined,
          ),
        ),
      ],
    );
  }

  Widget _cuadroContador(
    String titulo,
    String valor,
    Color bgColor,
    Color textColor,
    IconData icono,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Icon(icono, size: 14, color: textColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBarraBusqueda() {
    return TextField(
      controller: _controladorBusqueda,
      onChanged: (v) => setState(() => _textoBusqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar por estudiante o código...',
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: Colors.black45),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  Widget _construirFiltros() {
    List<String> opciones = ['Todos', 'Pendientes', 'Aprobadas', 'Rechazadas'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opciones.map((opcion) {
          bool activo = _filtroActual == opcion;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => setState(() => _filtroActual = opcion),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: activo ? _colorPrimario : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: activo
                      ? null
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  opcion,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: activo ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _construirTarjetaJustificacion(Map<String, dynamic> just) {
    bool esPendiente = just['estado'] == 'Pendiente';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera Usuario
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _colorPrimario,
                    radius: 18,
                    child: Text(
                      just['iniciales'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        just['nombre'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Doc: ${just['documento']}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: esPendiente
                      ? const Color(0xFFFFF4E5)
                      : (just['estado'] == 'Aprobada'
                            ? const Color(0xFFE8F5EE)
                            : const Color(0xFFFFEAEA)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  just['estado'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: esPendiente
                        ? const Color(0xFFE68A00)
                        : (just['estado'] == 'Aprobada'
                              ? const Color(0xFF008040)
                              : const Color(0xFFCC0000)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Detalle de Falla
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _colorTarjetaClara,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Color(0xFF3B3B6D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${just['fechaFalla']} • Falla en BD',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B3B6D),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      just['horaFalla'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFF3B3B6D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Motivo: ${just['motivoCorto']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3B3B6D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Mensaje
          const Text(
            'MENSAJE ENVIADO POR EL ESTUDIANTE:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            just['mensaje'],
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),

          // Archivo Adjunto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        just['archivoNombre'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '1.2 MB • Documento adjunto original',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.visibility,
                    size: 14,
                    color: Color(0xFF00382A),
                  ),
                  label: const Text(
                    'Ver',
                    style: TextStyle(
                      color: Color(0xFF00382A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5EE),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),

          if (esPendiente) ...[
            const SizedBox(height: 16),
            const Text(
              'COMENTARIOS PARA EL ESTUDIANTE (OPCIONAL)',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.black45,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                hintText: 'Ej: Se aprueba la entrega del taller a más tardar este 25 de mayo...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                filled: true,
                fillColor: _colorFondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: () => _cambiarEstado(just['id'], 'Rechazada'),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFFCC0000),
                    ),
                    label: const Text(
                      'Rechazar',
                      style: TextStyle(color: Color(0xFFCC0000)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCC0000)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _cambiarEstado(just['id'], 'Aprobada'),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(
                      'Aprobar Justificación',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorPrimario,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: just['estado'] == 'Aprobada'
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFFFEAEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    just['estado'] == 'Aprobada'
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: just['estado'] == 'Aprobada'
                        ? const Color(0xFF008040)
                        : const Color(0xFFCC0000),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Justificación ${just['estado'].toLowerCase()} por el docente.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: just['estado'] == 'Aprobada'
                          ? const Color(0xFF008040)
                          : const Color(0xFFCC0000),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirBannerReglamento() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, color: Color(0xFF00382A), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reglamento Estudiantil • Acuerdo 025',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00382A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Las justificaciones deben ser presentadas dentro de los 5 días hábiles posteriores a la inasistencia. Si un estudiante acumula el 20% de fallas, reprueba por inasistencia.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Función para simular el cambio de estado al presionar los botones
  void _cambiarEstado(String id, String nuevoEstado) {
    setState(() {
      final index = _justificaciones.indexWhere((j) => j['id'] == id);
      if (index != -1) {
        _justificaciones[index]['estado'] = nuevoEstado;
      }
    });
  }
}

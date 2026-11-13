import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResumenAsistenciaScreen extends StatefulWidget {
  final String cursoId;
  final String nombreAsignatura;
  final String salon;
  final List<Map<String, dynamic>> estudiantes;
  final Map<String, String> registroPrevio;
  final String sesionId;

  const ResumenAsistenciaScreen({
    super.key,
    required this.cursoId,
    required this.nombreAsignatura,
    required this.salon,
    required this.estudiantes,
    required this.registroPrevio,
    required this.sesionId,
  });

  @override
  State<ResumenAsistenciaScreen> createState() =>
      _ResumenAsistenciaScreenState();
}

class _ResumenAsistenciaScreenState extends State<ResumenAsistenciaScreen> {
  // Aquí guardaremos el estado final editable de la asistencia
  late Map<String, String> _estadoAsistencia;
  bool _isSaving = false;
  String _filtroActual = 'Todos';

  @override
  void initState() {
    super.initState();
    _estadoAsistencia = Map.from(widget.registroPrevio);

    // Si algún estudiante no fue evaluado en las tarjetas, se marca como 'Pendiente'
    for (var est in widget.estudiantes) {
      if (!_estadoAsistencia.containsKey(est['id_firebase'])) {
        _estadoAsistencia[est['id_firebase']] = 'Pendiente';
      }
    }
  }

  // Lógica para el "Toque Corto" (Alterna entre Presente y Ausente)
  void _toqueCorto(String id) {
    setState(() {
      if (_estadoAsistencia[id] == 'Presente') {
        _estadoAsistencia[id] = 'Ausente';
      } else {
        _estadoAsistencia[id] = 'Presente';
      }
    });
  }

  // Lógica para el "Toque Largo" (Menú Avanzado)
  void _mostrarMenuAvanzado(String id, String nombre) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B303A), // Color oscuro del menú
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _botonOpcionMenu(
                    id,
                    'Presente',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _botonOpcionMenu(id, 'Ausente', Icons.cancel, Colors.red),
                  _botonOpcionMenu(
                    id,
                    'Tarde',
                    Icons.watch_later,
                    Colors.orange,
                  ),
                  _botonOpcionMenu(id, 'Excusa', Icons.assignment, Colors.grey),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _botonOpcionMenu(
    String id,
    String estado,
    IconData icono,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() => _estadoAsistencia[id] = estado);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icono, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            estado,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // =============== LÓGICA DE FIREBASE (GUARDAR Y CONSOLIDAR) ===============
  Future<void> _guardarYConsolidar() async {
    setState(() => _isSaving = true);
    try {
      // 1. Apuntamos al documento EXACTO que ya se creó al iniciar la clase
      DocumentReference sesionRef = FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.cursoId)
          .collection('sesiones')
          .doc(widget.sesionId);

      // 2. Usamos set con merge: true para ACTUALIZAR sin borrar lo que ya existía (ej. código QR)
      await sesionRef.set({
        'registrosAsistencia':
            _estadoAsistencia, // { 'id_alumno' : 'Presente' }
        'totalPresentes': _estadoAsistencia.values
            .where((e) => e == 'Presente')
            .length,
        'totalAusentes': _estadoAsistencia.values
            .where((e) => e == 'Ausente')
            .length,
        'totalTardes': _estadoAsistencia.values
            .where((e) => e == 'Tarde')
            .length,
        'estado': 'finalizada', // Marcamos la sesión como cerrada
      }, SetOptions(merge: true)); // ¡CLAVE PARA NO BORRAR DATOS PREVIOS!

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Asistencia consolidada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );

      // Cierra las pantallas y vuelve al inicio del profesor
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentes = _estadoAsistencia.values
        .where((e) => e == 'Presente')
        .length;
    int ausentes = _estadoAsistencia.values.where((e) => e == 'Ausente').length;
    int tardes = _estadoAsistencia.values.where((e) => e == 'Tarde').length;
    int pendientes = _estadoAsistencia.values
        .where((e) => e == 'Pendiente')
        .length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Docente – Lista Manual (Resumen)',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.nombreAsignatura} - ${widget.salon}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00382A)),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nuevo texto verde arriba del título
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Color(0xFF00382A),
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Fase de Lista Manual',
                                        style: TextStyle(
                                          color: Color(0xFF00382A),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Resumen de Asistencia',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0C1D36),
                                    ),
                                  ), // Color oscuro original
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.nombreAsignatura} • ${widget.salon} • ${widget.estudiantes.length} matriculados',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // El nuevo icono de grupo de personas
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(
                                0xFFBCECD4,
                              ), // Verde claro de tu diseño
                              child: Icon(
                                Icons.people,
                                color: Color(0xFF00382A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Cajas de Estadísticas
                        Row(
                          children: [
                            _statBox(
                              'Presentes',
                              presentes,
                              const Color(0xFFE8F5EE),
                              Colors.green,
                              Icons.check_circle_outline,
                            ),
                            const SizedBox(width: 8),
                            _statBox(
                              'Ausentes',
                              ausentes,
                              const Color(0xFFFFEAEA),
                              Colors.red,
                              Icons.cancel_outlined,
                            ),
                            const SizedBox(width: 8),
                            _statBox(
                              'Tardes',
                              tardes,
                              const Color(0xFFFFF4E5),
                              Colors.orange,
                              Icons.watch_later_outlined,
                            ),
                            const SizedBox(width: 8),
                            _statBox(
                              'Pendiente',
                              pendientes,
                              const Color(0xFFF0F0FF),
                              Colors.deepPurple,
                              Icons.info_outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Banner Informativo
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 20,
                                color: Color(0xFF2B5B84),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Toque corto: Alterna P ⇄ A • Toque largo: Menú avanzado',
                                  style: TextStyle(
                                    color: Color(0xFF2B5B84),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ==========================================
                        // NUEVA FILA DE FILTROS DESLIZABLES
                        // ==========================================
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filtroChip(
                                'Todos',
                                widget.estudiantes.length,
                                isSelected: _filtroActual == 'Todos',
                              ),
                              const SizedBox(width: 8),
                              _filtroChip(
                                'Presentes',
                                presentes,
                                colorNumero: Colors.green,
                                isSelected: _filtroActual == 'Presentes',
                              ),
                              const SizedBox(width: 8),
                              _filtroChip(
                                'Ausentes',
                                ausentes,
                                colorNumero: Colors.red,
                                isSelected: _filtroActual == 'Ausentes',
                              ),
                              const SizedBox(width: 8),
                              _filtroChip(
                                'Tardes',
                                tardes,
                                colorNumero: Colors.orange,
                                isSelected: _filtroActual == 'Tardes',
                              ),
                              const SizedBox(width: 8),
                              _filtroChip(
                                'Pendientes',
                                pendientes,
                                colorNumero: Colors.deepPurple,
                                isSelected: _filtroActual == 'Pendientes',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ==========================================
                        // CUADRÍCULA DE ASISTENCIA (CONTROLADA POR FILTROS)
                        // ==========================================
                        const Text(
                          'Distribución de Asistencia Rápida',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Builder(
                          builder: (context) {
                            // Filtramos los estudiantes según el botón seleccionado arriba
                            List<Map<String, dynamic>> estudiantesFiltrados =
                                widget.estudiantes.where((est) {
                                  if (_filtroActual == 'Todos') return true;
                                  String estado =
                                      _estadoAsistencia[est['id_firebase']] ??
                                      'Pendiente';
                                  if (_filtroActual == 'Presentes' &&
                                      estado == 'Presente')
                                    return true;
                                  if (_filtroActual == 'Ausentes' &&
                                      estado == 'Ausente')
                                    return true;
                                  if (_filtroActual == 'Tardes' &&
                                      estado == 'Tarde')
                                    return true;
                                  if (_filtroActual == 'Pendientes' &&
                                      estado == 'Pendiente')
                                    return true;
                                  return false;
                                }).toList();

                            if (estudiantesFiltrados.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(30.0),
                                  child: Text(
                                    'No hay estudiantes en esta categoría',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: estudiantesFiltrados.length,
                              itemBuilder: (context, index) {
                                var est = estudiantesFiltrados[index];
                                String id = est['id_firebase'];
                                String estado =
                                    _estadoAsistencia[id] ?? 'Pendiente';

                                String primerNombre = est['nombre']
                                    .toString()
                                    .split(' ')[0];

                                return GestureDetector(
                                  onTap: () => _toqueCorto(id),
                                  onLongPress: () =>
                                      _mostrarMenuAvanzado(id, est['nombre']),
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: _getColorFondo(
                                              estado,
                                            ),
                                            child: Text(
                                              est['iniciales'],
                                              style: TextStyle(
                                                color: _getColorTexto(estado),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: -2,
                                            right: -2,
                                            child: CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.white,
                                              child: Icon(
                                                _getIcono(estado),
                                                size: 14,
                                                color: _getColorIcono(estado),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        primerNombre,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 30),
                        const SizedBox(height: 24),

                        // Leyenda final
                        const Text(
                          'Convenciones de Asistencia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0C1D36),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FC),
                            borderRadius: BorderRadius.circular(10),
                          ), // Azul clarito
                          child: const Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Presente a tiempo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2B5B84),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.circle,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ausente (Falla)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2B5B84),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Colors.orange,
                                    size: 12,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Retardo justificado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2B5B84),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  // ¡AQUÍ ESTÁ EL CAMBIO DE COLOR A MORADO!
                                  Icon(
                                    Icons.circle,
                                    color: Colors.deepPurple,
                                    size: 12,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pendiente de marcar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2B5B84),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Divider(
                                color: Colors.black12,
                                height: 1,
                              ), // Línea separadora
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: Color(0xFF384358),
                                    child: Icon(
                                      Icons.description,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  // ¡AQUÍ ESTÁ EL EXPANDED PARA QUITAR LA CINTA DE PELIGRO!
                                  Expanded(
                                    child: Text(
                                      'Excusa médica / justificación solicitada (en revisión)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2B5B84),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón Guardar Final
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00382A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _guardarYConsolidar,
                          child: const Text(
                            'Guardar y Consolidar Asistencia',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.style,
                          color: Colors.black54,
                          size: 18,
                        ),
                        label: const Text(
                          'Volver a modo tarjetas',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Funciones auxiliares de diseño
  Widget _statBox(
    String label,
    int count,
    Color bgColor,
    Color textColor,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: textColor),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Color _getColorFondo(String estado) {
    switch (estado) {
      case 'Presente':
        return const Color(0xFFE8F5EE);
      case 'Ausente':
        return const Color(0xFFFFEAEA);
      case 'Tarde':
        return const Color(0xFFFFF4E5);
      case 'Excusa':
        return Colors.grey.shade200;
      default:
        return const Color(0xFFF0F0FF);
    }
  }

  Color _getColorTexto(String estado) {
    switch (estado) {
      case 'Presente':
        return Colors.green;
      case 'Ausente':
        return Colors.red;
      case 'Tarde':
        return Colors.orange;
      case 'Excusa':
        return Colors.grey.shade600;
      default:
        return Colors.deepPurple;
    }
  }

  IconData _getIcono(String estado) {
    switch (estado) {
      case 'Presente':
        return Icons.check_circle;
      case 'Ausente':
        return Icons.cancel;
      case 'Tarde':
        return Icons.watch_later;
      case 'Excusa':
        return Icons.assignment;
      default:
        return Icons.help;
    }
  }

  Color _getColorIcono(String estado) {
    return _getColorTexto(estado);
  }

  // Función para construir los botones de filtro ovalados
  Widget _filtroChip(
    String texto,
    int cantidad, {
    Color? colorNumero,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtroActual = texto; // Cambiamos el filtro activo
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00382A) : const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              texto,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              cantidad.toString(),
              style: TextStyle(
                color: isSelected
                    ? Colors.white70
                    : (colorNumero ?? Colors.black54),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

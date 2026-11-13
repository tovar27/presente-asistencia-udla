import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'resumen_asistencia.dart';

class ListaManual extends StatefulWidget {
  final String cursoId;
  final String nombreAsignatura;
  final String salon;
  final String sesionId;

  const ListaManual({
    super.key,
    required this.cursoId,
    required this.nombreAsignatura,
    required this.salon,
    required this.sesionId,
  });

  @override
  State<ListaManual> createState() => _ListaManualState();
}

class _ListaManualState extends State<ListaManual> {
  final CardSwiperController _swiperController = CardSwiperController();

  // Reemplazamos los datos de prueba por los reales
  List<Map<String, dynamic>> _estudiantesReales = [];
  // Variables para llevar el conteo en tiempo real
  int _presentes = 0;
  int _ausentes = 0;
  int _tardes = 0;
  int _tarjetasEvaluadas = 0;

  // Aquí guardaremos el resultado final para enviarlo a Firebase
  Map<String, String> _registroAsistencia = {};
  bool _isLoading =
      true; // Para mostrar un circulito de carga mientras bajan los datos

  @override
  void initState() {
    super.initState();
    _cargarEstudiantes(); // Llamamos a Firebase apenas se abre la pantalla
  }

  // Función mágica que trae los estudiantes de Firebase
  Future<void> _cargarEstudiantes() async {
    try {
      // 1. Buscamos en la ruta exacta que me mostraste en la foto
      final snapshot = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.cursoId)
          .collection('estudiantes')
          .get();

      final List<Map<String, dynamic>> estudiantesTemp = [];

      // 2. Recorremos cada estudiante que descargamos
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // 3. Adaptamos los datos de Firebase al diseño de nuestra tarjeta
        estudiantesTemp.add({
          'id_firebase':
              doc.id, // Guardamos el ID para luego guardar su asistencia
          'nombre': data['nombreCompleto'] ?? 'Sin nombre',
          'iniciales': _obtenerIniciales(data['nombreCompleto'] ?? 'SN'),
          'codigo': data['codigo'] ?? 'Sin código',

          // NOTA: Si en tu base de datos aún no tienes el semestre, programa o asistencia histórica,
          // los dejamos con valores por defecto para que la tarjeta no se rompa visualmente.
          'semestre': data['semestre'] ?? 'Semestre N/A',
          'programa': data['programa'] ?? 'Ingeniería de Sistemas',
          'asistencia': '100%',
          'horas': '0 de 0',
          'estado': 'Al día',
          'colorEstado': const Color(0xFFE8F5EE),
          'colorTextoEstado': const Color(0xFF00382A),
        });
      }

      // 4. Actualizamos la pantalla con los datos reales
      setState(() {
        _estudiantesReales = estudiantesTemp;
        _isLoading = false;
      });
    } catch (e) {
      print("Error cargando estudiantes: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función auxiliar para sacar las iniciales (Ej: Juan Perez -> JP)
  String _obtenerIniciales(String nombre) {
    List<String> partes = nombre.trim().split(' ');
    if (partes.isEmpty) return 'SN';
    if (partes.length == 1) return partes[0].substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Docente – Lista Manual (Tarjetas)',
              style: TextStyle(
                color: Colors.black87,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 1. CABECERA (Progreso y contadores - DINÁMICO)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PROGRESO DE LISTA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.grid_view,
                              size: 12,
                              color: Color(0xFF2B5B84),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ver resumen',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B5B84),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Fila sin el "const" para permitir variables dinámicas
                  Row(
                    children: [
                      Text(
                        '$_tarjetasEvaluadas', // <-- Contador dinámico
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' de ${_estudiantesReales.length} estudiantes', // <-- Total real
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    // Evita división por cero si aún no cargan los datos
                    value: _estudiantesReales.isEmpty
                        ? 0
                        : (_tarjetasEvaluadas / _estudiantesReales.length),
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF00382A),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _construirChipContador(
                          'Presentes: $_presentes', // <-- Variable
                          const Color(0xFFE8F5EE),
                          const Color(0xFF00382A),
                        ),
                        const SizedBox(width: 8),
                        _construirChipContador(
                          'Ausentes: $_ausentes', // <-- Variable
                          const Color(0xFFFFEAEA),
                          const Color(0xFFB02A37),
                        ),
                        const SizedBox(width: 8),
                        _construirChipContador(
                          'Tardes: $_tardes', // <-- Variable
                          const Color(0xFFEFF0FB),
                          const Color(0xFF5C5C96),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. MOTOR DE TARJETAS (ESTRICTAMENTE COMO FUNCIONABA)
            // ==========================================
            Expanded(
              // Si está cargando, mostramos el circulito verde
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00382A),
                      ),
                    )
                  // Si ya cargó pero no hay alumnos, mostramos un mensaje
                  : _estudiantesReales.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay estudiantes matriculados en este curso',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  // Usamos un Stack para poner el mensaje de finalización en el fondo
                  : Stack(
                      children: [
                        // 1. Mensaje de finalización (se revela al terminar las tarjetas)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '¡Lista terminada!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Presiona "Finalizar y Ver Resumen" para guardar.\nSi te equivocaste, puedes presionar "Deshacer".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. El motor de tarjetas encima
                        CardSwiper(
                          controller: _swiperController,
                          isLoop: false, // <-- ¡LA MAGIA QUE DETIENE EL CICLO INFINITO!
                          cardsCount: _estudiantesReales.length,
                          numberOfCardsDisplayed: _estudiantesReales.length == 1
                              ? 1
                              : 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 10.0,
                          ),

                          onSwipe: (previousIndex, currentIndex, direction) {
                            // Rebote automático si tira hacia abajo
                            if (direction == CardSwiperDirection.bottom) {
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  _swiperController.undo();
                                },
                              );
                              return true;
                            }

                            // Lógica matemática al deslizar
                            setState(() {
                              _tarjetasEvaluadas++;
                              String idEstudiante =
                                  _estudiantesReales[previousIndex]['id_firebase'];

                              if (direction == CardSwiperDirection.right) {
                                _presentes++;
                                _registroAsistencia[idEstudiante] = 'Presente';
                              } else if (direction ==
                                  CardSwiperDirection.left) {
                                _ausentes++;
                                _registroAsistencia[idEstudiante] = 'Ausente';
                              } else if (direction == CardSwiperDirection.top) {
                                _tardes++;
                                _registroAsistencia[idEstudiante] = 'Tarde';
                              }
                            });

                            return true;
                          },

                          onUndo: (previousIndex, currentIndex, direction) {
                            setState(() {
                              String idEstudiante =
                                  _estudiantesReales[currentIndex]['id_firebase'];

                              // 🔥 LA SOLUCIÓN: Si el estudiante nunca fue evaluado (ej. rebote hacia abajo),
                              // cancelamos la acción para que no reste números a la fuerza.
                              if (!_registroAsistencia.containsKey(
                                idEstudiante,
                              )) {
                                return;
                              }

                              _tarjetasEvaluadas--;
                              _registroAsistencia.remove(
                                idEstudiante,
                              ); // Borramos el registro previo

                              if (direction == CardSwiperDirection.right) {
                                _presentes--;
                              } else if (direction ==
                                  CardSwiperDirection.left) {
                                _ausentes--;
                              } else if (direction == CardSwiperDirection.top) {
                                _tardes--;
                              }
                            });
                            return true;
                          },

                          cardBuilder:
                              (
                                context,
                                index,
                                horizontalOffsetPercentage,
                                verticalOffsetPercentage,
                              ) {
                                return _construirTarjetaEstudiante(
                                  _estudiantesReales[index],
                                  index + 1,
                                );
                              },
                        ),
                      ],
                    ),
            ),

            // ==========================================
            // 3. BOTONES INFERIORES (DISEÑO ORIGINAL RESTAURADO)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón Rojo -> Ausente (Izquierda)
                      _construirBotonAccion(
                        Icons.close,
                        const Color(0xFFB02A37),
                        'Ausente',
                        () {
                          _swiperController.swipe(CardSwiperDirection.left);
                        },
                      ),

                      // Botón Morado -> Tarde (Arriba - RESTAURADO)
                      _construirBotonAccion(
                        Icons.access_time,
                        const Color(0xFF5C5C96),
                        'Tarde',
                        () {
                          _swiperController.swipe(CardSwiperDirection.top);
                        },
                      ),

                      // Botón Verde -> Presente (Derecha)
                      _construirBotonAccion(
                        Icons.check,
                        const Color(0xFF00382A),
                        'Presente',
                        () {
                          _swiperController.swipe(CardSwiperDirection.right);
                        },
                        esPrincipal: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botones Deshacer y Finalizar (RESTAURADOS AL DISEÑO ORIGINAL)
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _swiperController
                                .undo(); // ¡Ahora sí debe funcionar!
                          },
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text(
                            'Deshacer',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          // Reemplaza el onPressed de tu botón "Finalizar y Ver Resumen" por este:
                          onPressed: () {
                            // Borramos el mensaje de prueba de la Fase 5 y navegamos al resumen real
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResumenAsistenciaScreen(
                                  cursoId: widget.cursoId,
                                  nombreAsignatura: widget.nombreAsignatura,
                                  salon: widget.salon,
                                  sesionId: widget.sesionId, // <-- Pasa el ID de hoy (2026-10-28)
                                  estudiantes: _estudiantesReales,
                                  registroPrevio: _registroAsistencia, // Pasa lo que el profe deslizó
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Finalizar y Ver Resumen',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00382A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
    );
  }

  // =========================================================================
  // MÉTODOS DE DIBUJO (TARJETA Y COMPONENTES NUEVOS)
  // =========================================================================

  Widget _construirTarjetaEstudiante(
    Map<String, dynamic> estudiante,
    int numeroTurno,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16), // Reducido de 20 a 16
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: Color(0xFF2B5B84)),
                    SizedBox(width: 4),
                    Text(
                      'U. de la Amazonia',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5B84),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#$numeroTurno en turno',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Cambiado Spacer por SizedBox
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 38, // Reducido de 45 a 38
                backgroundColor: const Color(0xFF00382A),
                child: Text(
                  estudiante['iniciales'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 14,
                  color: Color(0xFF00382A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Reducido de 16 a 12
          Text(
            estudiante['nombre'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cód. ${estudiante['codigo']}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Text(
            estudiante['programa'],
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Spacer(), // Este Spacer ya no causará conflicto
          Container(
            padding: const EdgeInsets.all(10), // Reducido de 12 a 10
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pie_chart_outline,
                  color: Color(0xFF00382A),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${estudiante['asistencia']} asistencia',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${estudiante['horas']} horas',
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: estudiante['colorEstado'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estudiante['estado'],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: estudiante['colorTextoEstado'],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12), // Reducido de 16 a 12
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.arrow_back, size: 14, color: Colors.black45),
                  SizedBox(width: 4),
                  Text(
                    'Izquierda:\nAusente',
                    style: TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Derecha:\nPresente',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Colors.black45),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirChipContador(
    String texto,
    Color colorFondo,
    Color colorTexto,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: colorTexto),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonAccion(
    IconData icono,
    Color color,
    String etiqueta,
    VoidCallback accion, {
    bool esPrincipal = false,
  }) {
    return Column(
      children: [
        Container(
          width: esPrincipal ? 65 : 55,
          height: esPrincipal ? 65 : 55,
          decoration: BoxDecoration(
            color: esPrincipal ? color : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
            border: esPrincipal
                ? null
                : Border.all(color: Colors.grey.shade200),
          ),
          child: IconButton(
            icon: Icon(
              icono,
              color: esPrincipal ? Colors.white : color,
              size: esPrincipal ? 30 : 24,
            ),
            onPressed: accion, // Aquí conectamos la acción real
          ),
        ),
        const SizedBox(height: 8),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 11,
            color: esPrincipal ? color : Colors.black54,
            fontWeight: esPrincipal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

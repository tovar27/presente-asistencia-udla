import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'gestionar_estudiantes.dart';
import 'activar_clase.dart';

class HomeDocente extends StatefulWidget {
  const HomeDocente({super.key});

  @override
  State<HomeDocente> createState() => _EstadoHomeDocente();
}

class _EstadoHomeDocente extends State<HomeDocente> {
  int _diaSeleccionado = 0; // 0 = Lunes, 1 = Martes, etc.
  final Color _colorTema = const Color(0xFF00382A);

  late DateTime _fechaLunesActual;
  final List<String> _nombresDiasBD = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];
  final List<String> _etiquetasDias = [
    'LUN',
    'MAR',
    'MIÉ',
    'JUE',
    'VIE',
    'SÁB',
  ];
  final List<String> _meses = [
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

  @override
  void initState() {
    super.initState();
    _calcularSemanaActual();
  }

  void _calcularSemanaActual() {
    DateTime hoy = DateTime.now();
    int diaSemana = hoy.weekday;
    if (diaSemana == 7) diaSemana = 1;

    _fechaLunesActual = hoy.subtract(Duration(days: diaSemana - 1));
    _diaSeleccionado = hoy.weekday == 7 ? 0 : hoy.weekday - 1;
  }

  // =====================================================================
  // NUEVA LÓGICA ROBUSTA PARA DETECTAR LA HORA DE LA CLASE
  // =====================================================================
  bool _estaEnClase(String horarioCurso) {
    if (horarioCurso.isEmpty || !horarioCurso.contains('-')) return false;

    try {
      final ahora = DateTime.now();
      final horaActualDecimal = ahora.hour + (ahora.minute / 60.0);

      List<String> partes = horarioCurso.split('-');
      double inicioDec = _convertirHoraADecimal(partes[0]);
      double finDec = _convertirHoraADecimal(partes[1]);

      // Corrección automática si se guardó algo como "11:00 AM - 01:00 PM" sin el PM claro
      if (inicioDec > finDec && finDec < 12) {
        finDec += 12;
      }

      return horaActualDecimal >= inicioDec && horaActualDecimal <= finDec;
    } catch (e) {
      return false;
    }
  }

  double _convertirHoraADecimal(String horaStr) {
    String textoLimpio = horaStr.trim().toUpperCase();
    bool esPM = textoLimpio.contains('PM');
    bool esAM = textoLimpio.contains('AM');

    // Extraer solo números y dos puntos
    String soloNumeros = textoLimpio.replaceAll(RegExp(r'[^0-9:]'), '');
    List<String> partes = soloNumeros.split(':');

    if (partes.isEmpty || partes[0].isEmpty) return 0.0;

    int hora = int.parse(partes[0]);
    int minutos = partes.length > 1 ? int.parse(partes[1]) : 0;

    // Convertir a formato 24 horas
    if (esPM && hora != 12) {
      hora += 12;
    } else if (esAM && hora == 12) {
      hora = 0;
    } else if (!esPM && !esAM) {
      // Si el usuario olvidó poner AM/PM y pone una hora pequeña (ej. 2:00), asumimos que es de la tarde (14:00)
      if (hora >= 1 && hora <= 6) hora += 12;
    }

    return hora + (minutos / 60.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _construirAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _construirInfoDocente(),
              const SizedBox(height: 24),
              _construirCalendarioSemanal(),
              const SizedBox(height: 24),
              _construirSeccionDinamicaCursos(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Image.asset(
            'recursos/imagenes/logo_presente.png',
            height: 24,
            errorBuilder: (c, e, s) =>
                const Icon(Icons.hourglass_bottom, color: Color(0xFF00382A)),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Presente',
                style: TextStyle(
                  color: Color(0xFF00382A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                'Universidad de la Amazonia',
                style: TextStyle(color: Colors.black54, fontSize: 10),
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
        const Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _construirInfoDocente() {
    final usuarioActivo = FirebaseAuth.instance.currentUser;
    if (usuarioActivo == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioActivo.uid)
          .get(),
      builder: (context, snapshot) {
        String nombreDocente = 'Cargando...';
        String detallesDocente = 'Cargando...';

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data!.exists) {
            var datos = snapshot.data!.data() as Map<String, dynamic>;
            String nombreReal =
                datos['nombre']?.toString() ??
                usuarioActivo.displayName ??
                'Docente';
            if (nombreReal.isNotEmpty) {
              nombreReal =
                  nombreReal[0].toUpperCase() + nombreReal.substring(1);
            }
            nombreDocente = 'Prof. $nombreReal';

            String rol = datos['rol']?.toString() ?? 'Docente Planta';
            if (rol.isNotEmpty) rol = rol[0].toUpperCase() + rol.substring(1);

            String departamento =
                datos['departamento']?.toString() ?? 'Ingeniería de Sistemas';
            detallesDocente = '$rol • $departamento';
          } else {
            nombreDocente = 'Prof. ${usuarioActivo.displayName ?? 'Docente'}';
            detallesDocente = 'Docente Planta • Universidad de la Amazonia';
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreDocente,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 14,
                  color: Colors.black54,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    detallesDocente,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _construirCalendarioSemanal() {
    String mesActual =
        '${_meses[_fechaLunesActual.month - 1]} ${_fechaLunesActual.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Calendario Semanal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              mesActual,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _colorTema,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            DateTime fechaDia = _fechaLunesActual.add(Duration(days: index));
            bool esHoy =
                fechaDia.day == DateTime.now().day &&
                fechaDia.month == DateTime.now().month;
            return _construirDiaCalendario(
              index,
              _etiquetasDias[index],
              '${fechaDia.day}',
              esHoy: esHoy,
            );
          }),
        ),
      ],
    );
  }

  Widget _construirDiaCalendario(
    int indice,
    String diaSemana,
    String numeroDia, {
    bool esHoy = false,
  }) {
    bool estaSeleccionado = _diaSeleccionado == indice;

    return GestureDetector(
      onTap: () => setState(() => _diaSeleccionado = indice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: estaSeleccionado ? _colorTema : const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: estaSeleccionado
              ? [
                  BoxShadow(
                    color: _colorTema.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              diaSemana,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: estaSeleccionado ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              numeroDia,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: estaSeleccionado ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            if (esHoy && estaSeleccionado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Hoy',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else if (!estaSeleccionado)
              const Icon(Icons.circle, size: 4, color: Colors.black26)
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _construirSeccionDinamicaCursos() {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return const Text('Sin sesión activa.');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cursos')
          .where('docenteUid', isEqualTo: usuario.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        String diaFiltro = _nombresDiasBD[_diaSeleccionado];
        List<QueryDocumentSnapshot> cursosDelDia = [];

        if (snapshot.hasData) {
          cursosDelDia = snapshot.data!.docs.where((doc) {
            List<dynamic> dias =
                (doc.data() as Map<String, dynamic>)['diasSemana'] ?? [];
            return dias.contains(diaFiltro);
          }).toList();
        }

        int totalEstudiantesHoy = 0;
        int totalHorasHoy = cursosDelDia.length * 2;

        for (var doc in cursosDelDia) {
          totalEstudiantesHoy +=
              ((doc.data() as Map<String, dynamic>)['totalEstudiantes'] ?? 0)
                  as int;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _construirTarjetasResumen(
              totalEstudiantesHoy.toString(),
              '${totalHorasHoy}h',
            ),
            const SizedBox(height: 24),
            _construirEncabezadoCursos(cursosDelDia.length),
            const SizedBox(height: 16),
            _construirListaCursosDinamica(cursosDelDia),
          ],
        );
      },
    );
  }

  Widget _construirTarjetasResumen(String estudiantes, String horas) {
    bool esHoy =
        _diaSeleccionado ==
        (DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday - 1);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB4E3C9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFF00382A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esHoy ? 'Estudiantes Hoy' : 'Estudiantes del Día',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$estudiantes inscritos',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Color(0xFF2B5B84),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Horas Cátedra',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$horas totales',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirEncabezadoCursos(int cantidadCursos) {
    bool esHoy =
        _diaSeleccionado ==
        (DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday - 1);
    String titulo = esHoy ? 'Cursos Activos (Hoy)' : 'Cursos Programados';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF00382A),
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (cantidadCursos > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF0FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$cantidadCursos Sesiones',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C5C96),
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirListaCursosDinamica(List<QueryDocumentSnapshot> cursos) {
    if (cursos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text(
          'No tienes clases programadas para este día en la base de datos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black45),
        ),
      );
    }

    return Column(
      children: cursos.map((doc) {
        var datos = doc.data() as Map<String, dynamic>;

        String horarioText = datos['horario'] ?? 'Sin horario';
        bool esHoyReal =
            _diaSeleccionado ==
            (DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday - 1);

        // Validamos si temporalmente estamos dentro del rango de la clase
        bool claseActivaPorTiempo = esHoyReal && _estaEnClase(horarioText);

        // Escuchamos Firebase CONSTANTEMENTE para este curso específico
        // Escuchamos Firebase CONSTANTEMENTE en la ruta correcta (Sub-colección)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cursos')
              .doc(doc.id) // Entramos al curso específico
              .collection('sesiones') // Buscamos en su carpeta de sesiones
              .snapshots(),
          builder: (context, snapshot) {
            bool estaFinalizada = false;

            // Verificamos de forma sencilla si existe alguna sesión marcada como finalizada
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              for (var sesionDoc in snapshot.data!.docs) {
                var dataSesion = sesionDoc.data() as Map<String, dynamic>;
                // Si el estado es finalizada, activamos la bandera
                if (dataSesion['estado'] == 'finalizada' ||
                    dataSesion['estado'] == 'Finalizada') {
                  estaFinalizada = true;
                  break;
                }
              }
            }

            // ==========================================
            // REGLA 1: Si el profesor ya oprimió "Finalizar"
            // ==========================================
            if (estaFinalizada) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _construirTarjetaNormal(
                  cursoId: doc.id,
                  grupo: datos['grupo'] ?? 'N/A',
                  codigo: datos['codigo'] ?? 'N/A',
                  titulo: datos['nombreAsignatura'] ?? 'Sin nombre',
                  iconoEstado: Icons.check_circle_outline, // Iconito de check
                  textoEstado: 'Finalizada',
                  colorFondoEstado: const Color(0xFFE8F5EE), // Verde clarito
                  colorTextoEstado: const Color(0xFF00382A), // Verde oscuro
                  aula: datos['salon'] ?? 'Sin salón',
                  bloque: datos['bloque'] ?? '',
                  horario: horarioText,
                  tiempoFaltante: 'Clase completada',
                  estudiantes: (datos['totalEstudiantes'] ?? 0).toString(),
                ),
              );
            }
            // ==========================================
            // REGLA 2: No ha finalizado y ESTAMOS EN LA HORA
            // ==========================================
            else if (claseActivaPorTiempo) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _construirTarjetaActiva(
                  cursoId: doc.id,
                  grupo: datos['grupo'] ?? 'N/A',
                  codigo: datos['codigo'] ?? 'N/A',
                  titulo: datos['nombreAsignatura'] ?? 'Sin nombre',
                  aula: datos['salon'] ?? 'Sin salón',
                  bloque: datos['bloque'] ?? '',
                  horario: horarioText,
                  totalEstudiantes: (datos['totalEstudiantes'] ?? 0).toString(),
                ),
              );
            }
            // ==========================================
            // REGLA 3: No ha finalizado y NO ES LA HORA (antes o después)
            // ==========================================
            else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _construirTarjetaNormal(
                  cursoId: doc.id,
                  grupo: datos['grupo'] ?? 'N/A',
                  codigo: datos['codigo'] ?? 'N/A',
                  titulo: datos['nombreAsignatura'] ?? 'Sin nombre',
                  iconoEstado: Icons.access_time,
                  textoEstado: 'Programada',
                  colorFondoEstado: const Color(0xFFEFF0FB),
                  colorTextoEstado: const Color(0xFF5C5C96),
                  aula: datos['salon'] ?? 'Sin salón',
                  bloque: datos['bloque'] ?? '',
                  horario: horarioText,
                  tiempoFaltante: 'Pendiente',
                  estudiantes: (datos['totalEstudiantes'] ?? 0).toString(),
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  Widget _construirCuadroInfo({
    required IconData icono1,
    required String label1,
    required String titulo1,
    required String subtitulo1,
    required IconData icono2,
    required String label2,
    required String titulo2,
    required String subtitulo2,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono1, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label1,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titulo1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitulo1,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono2, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label2,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titulo2,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitulo2,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _construirTarjetaActiva({
    required String cursoId,
    required String grupo,
    required String codigo,
    required String titulo,
    required String aula,
    required String bloque,
    required String horario,
    required String totalEstudiantes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF00382A), width: 6),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$grupo • Código: $codigo',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'En Clase',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB02A37),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _construirCuadroInfo(
                icono1: Icons.door_front_door_outlined,
                label1: 'Ubicación',
                titulo1: aula,
                subtitulo1: bloque,
                icono2: Icons.access_time,
                label2: 'Horario',
                titulo2: horario,
                subtitulo2: 'Sesión Activa',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.fact_check_outlined,
                        size: 14,
                        color: Colors.black54,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Asistencia en Vivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '0/$totalEstudiantes estudiantes ',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const TextSpan(
                          text: '(0%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00382A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00382A)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  // CONEXIÓN LISTA: Navega a la pantalla ActivarClase al hacer tap
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActivarClase(
                          cursoId: cursoId,
                          titulo: titulo,
                          grupo: grupo,
                          horario: horario,
                          salon: aula,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_box_outlined, size: 18),
                  label: const Text(
                    'Gestionar Asistencia en Vivo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorTema,
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
        ),
      ),
    );
  }

  Widget _construirTarjetaNormal({
    required String cursoId,
    required String grupo,
    required String codigo,
    required String titulo,
    required IconData iconoEstado,
    required String textoEstado,
    required Color colorFondoEstado,
    required Color colorTextoEstado,
    required String aula,
    required String bloque,
    required String horario,
    required String tiempoFaltante,
    required String estudiantes,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Text(
                '$grupo • Código: $codigo',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorFondoEstado,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(iconoEstado, size: 12, color: colorTextoEstado),
                    const SizedBox(width: 4),
                    Text(
                      textoEstado,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorTextoEstado,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _construirCuadroInfo(
            icono1: Icons.location_on_outlined,
            label1: 'Aula',
            titulo1: aula,
            subtitulo1: bloque,
            icono2: Icons.access_time,
            label2: 'Horario',
            titulo2: horario,
            subtitulo2: tiempoFaltante,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$estudiantes estudiantes matriculados',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GestionarEstudiantes(
                        cursoId: cursoId,
                        nombreAsignatura: titulo,
                        grupo: grupo,
                        salon: aula,
                        bloque: bloque,
                        horario: horario,
                      ),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'Detalles',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00382A),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF00382A),
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
}

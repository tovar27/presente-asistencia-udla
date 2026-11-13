import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistrarCurso extends StatefulWidget {
  const RegistrarCurso({super.key});

  @override
  State<RegistrarCurso> createState() => _EstadoRegistrarCurso();
}

class _EstadoRegistrarCurso extends State<RegistrarCurso> {
  final Color _colorTema = const Color(0xFF00382A);

  // Controladores
  final TextEditingController _controladorNombre = TextEditingController();
  final TextEditingController _controladorCodigo = TextEditingController(
    text: 'SIS-402',
  );
  final TextEditingController _controladorGrupo = TextEditingController(
    text: 'Grupo A',
  );

  // Asignaturas recientes desde Firestore
  List<String> _asignaturasRecientes = [];
  String? _asignaturaSeleccionadaChip;
  bool _cargandoRecientes = true;

  // Selecciones de Ubicación y Horarios
  String _bloqueSeleccionado = 'Bloque 7 (Edificio de dos pisos)';
  String _salonSeleccionado = 'Salón 7001 (Piso 1 - Lab Redes)';
  String _horarioSeleccionado = '08:00 AM - 10:00 AM (Mañana)';

  // Días seleccionados [L, M, M, J, V, S]
  final List<String> _etiquetasDias = ['L', 'M', 'M', 'J', 'V', 'S'];
  final List<String> _nombresDias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];
  final Set<int> _indicesDiasSeleccionados = {
    1,
    3,
  }; // Martes y Jueves seleccionados por defecto

  bool _requiereGPS = true;
  bool _cargando = false;

  final List<String> _opcionesBloques = [
    'Bloque 7 (Edificio de dos pisos)',
    'Bloque 1 (Edificio Central)',
    'Bloque 3 (Laboratorios)',
  ];

  final List<String> _opcionesSalones = [
    'Salón 7001 (Piso 1 - Lab Redes)',
    'Salón 7002 (Piso 2 - Aula Magistral)',
    'Salón 1001 (Bloque 1)',
    'Laboratorio 3 (Bloque 3)',
  ];

  final List<String> _opcionesHorarios = [
    '07:00 AM - 09:00 AM (Mañana)',
    '08:00 AM - 10:00 AM (Mañana)',
    '10:00 AM - 12:00 PM (Mañana)',
    '12:00 PM - 02:00 PM (Tarde)',
    '02:00 PM - 04:00 PM (Tarde)',
    '04:00 PM - 06:00 PM (Tarde)',
    '06:00 PM - 08:00 PM (Noche)',
    '08:00 PM - 10:00 PM (Noche)',
  ];

  @override
  void initState() {
    super.initState();
    _cargarAsignaturasRecientes();
  }

  // Cargar asignaturas creadas previamente por este docente en Firestore
  Future<void> _cargarAsignaturasRecientes() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      if (mounted) setState(() => _cargandoRecientes = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cursos')
          .where('docenteUid', isEqualTo: usuario.uid)
          .get();

      // Extraer nombres únicos
      final Set<String> nombresUnicos = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('nombreAsignatura') &&
            data['nombreAsignatura'] != null) {
          nombresUnicos.add(data['nombreAsignatura'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _asignaturasRecientes = nombresUnicos.toList();
          if (_asignaturasRecientes.isNotEmpty) {
            _asignaturaSeleccionadaChip = _asignaturasRecientes.first;
            _controladorNombre.text = _asignaturasRecientes.first;
          } else {
            // Valores sugeridos por defecto si es la primera vez
            _asignaturasRecientes = [
              'Estructura de Datos II',
              'Lógica y Algoritmos II',
            ];
            _asignaturaSeleccionadaChip = 'Estructura de Datos II';
            _controladorNombre.text = 'Estructura de Datos II';
          }
          _cargandoRecientes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _asignaturasRecientes = [
            'Estructura de Datos II',
            'Lógica y Algoritmos II',
          ];
          _asignaturaSeleccionadaChip = 'Estructura de Datos II';
          _controladorNombre.text = 'Estructura de Datos II';
          _cargandoRecientes = false;
        });
      }
    }
  }

  // GUARDADO REAL EN CLOUD FIRESTORE
  Future<void> _guardarCursoEnFirestore() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      _mostrarMensaje(
        'Sesión no encontrada. Inicia sesión nuevamente.',
        esError: true,
      );
      return;
    }

    if (_controladorNombre.text.trim().isEmpty ||
        _controladorCodigo.text.trim().isEmpty ||
        _controladorGrupo.text.trim().isEmpty ||
        _indicesDiasSeleccionados.isEmpty) {
      _mostrarMensaje(
        'Por favor completa todos los campos obligatorios.',
        esError: true,
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      List<String> diasFinales = _indicesDiasSeleccionados
          .map((index) => _nombresDias[index])
          .toList();

      await FirebaseFirestore.instance.collection('cursos').add({
        'docenteUid': usuario.uid,
        'nombreAsignatura': _controladorNombre.text.trim(),
        'codigo': _controladorCodigo.text.trim().toUpperCase(),
        'grupo': _controladorGrupo.text.trim(),
        'intensidadHoras': 36,
        'bloque': _bloqueSeleccionado,
        'salon': _salonSeleccionado,
        'diasSemana': diasFinales,
        'horario': _horarioSeleccionado,
        'requiereGPS': _requiereGPS,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _mostrarMensaje('¡Asignatura guardada y programada con éxito!');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al conectar con Firestore.', esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: esError ? const Color(0xFFB3261E) : _colorTema,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFF),
      appBar: _construirAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _construirSeccionCurricular(),
              const SizedBox(height: 24),
              _construirSeccionUbicacion(),
              const SizedBox(height: 24),
              _construirSeccionHorario(),
              const SizedBox(height: 24),
              _construirSeccionGPS(),
              const SizedBox(height: 32),
              _construirBotonGuardar(),
              const SizedBox(height: 24),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalle Asignatura',
            style: TextStyle(
              color: Colors.black87,
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Image.asset('recursos/imagenes/logo_presente.png', height: 28),
        ),
      ],
    );
  }

  Widget _construirSeccionCurricular() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 18,
                color: Color(0xFF00382A),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Datos Curriculares',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ingeniería de Sistemas',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00382A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tus Asignaturas Recientes',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),

          // LISTA DE CHIPS DINÁMICOS Y SELECCIONABLES
          if (_cargandoRecientes)
            const SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_asignaturasRecientes.isEmpty)
            const Text(
              'Aún no tienes asignaturas registradas.',
              style: TextStyle(fontSize: 11, color: Colors.black38),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _asignaturasRecientes.map((nombre) {
                  bool seleccionada = _asignaturaSeleccionadaChip == nombre;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _asignaturaSeleccionadaChip = nombre;
                          _controladorNombre.text = nombre;
                        });
                      },
                      child: _construirChipAsignatura(
                        nombre,
                        seleccionada: seleccionada,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controladorNombre,
                  onChanged: (val) {
                    if (_asignaturaSeleccionadaChip != val) {
                      setState(() => _asignaturaSeleccionadaChip = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Escribe el nombre de una asignatura...',
                    prefixIcon: const Icon(
                      Icons.short_text,
                      color: Colors.black45,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF4F6F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final texto = _controladorNombre.text.trim();
                  if (texto.isNotEmpty &&
                      !_asignaturasRecientes.contains(texto)) {
                    setState(() {
                      _asignaturasRecientes.add(texto);
                      _asignaturaSeleccionadaChip = texto;
                    });
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Agregar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorTema,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Código Asignatura',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controladorCodigo,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grupo Asignado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controladorGrupo,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Intensidad Semestral',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _colorTema,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '36 horas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: Colors.black54,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reglamento estudiantil: requiere mínimo 80% (28.8 horas) de asistencia presencial para derecho a examen final.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          height: 1.3,
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
    );
  }

  Widget _construirChipAsignatura(String texto, {required bool seleccionada}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: seleccionada ? _colorTema : const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            seleccionada ? Icons.check_circle : Icons.school_outlined,
            size: 14,
            color: seleccionada ? Colors.white : Colors.black54,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: seleccionada ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionUbicacion() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: Color(0xFF00382A),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ubicación Campus Florencia',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Bloque Institucional',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _bloqueSeleccionado,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF4F6F9),
              prefixIcon: const Icon(Icons.apartment, color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _opcionesBloques
                .map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(
                      b,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _bloqueSeleccionado = val!),
          ),
          const SizedBox(height: 16),
          const Text(
            'Espacio Académico (Salón)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _salonSeleccionado,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF4F6F9),
              prefixIcon: const Icon(
                Icons.meeting_room_outlined,
                color: Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _opcionesSalones
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _salonSeleccionado = val!),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionHorario() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: Color(0xFF00382A),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Frecuencia y Horario Semanal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '2 hrs / sesión',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Días de Cátedra',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_etiquetasDias.length, (index) {
              bool seleccionado = _indicesDiasSeleccionados.contains(index);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (seleccionado) {
                      _indicesDiasSeleccionados.remove(index);
                    } else {
                      _indicesDiasSeleccionados.add(index);
                    }
                  });
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: seleccionado
                      ? _colorTema
                      : const Color(0xFFF4F6F9),
                  child: Text(
                    _etiquetasDias[index],
                    style: TextStyle(
                      color: seleccionado ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text(
            'Franja Horaria',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _horarioSeleccionado,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF4F6F9),
              suffixIcon: const Icon(Icons.access_time, color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _opcionesHorarios
                .map(
                  (h) => DropdownMenuItem(
                    value: h,
                    child: Text(
                      h,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _horarioSeleccionado = val!),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionGPS() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: SwitchListTile(
        activeColor: _colorTema,
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.my_location,
            color: Color(0xFF00382A),
            size: 20,
          ),
        ),
        title: const Text(
          'Validación Georreferenciada',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: const Text(
          'Requerir GPS en campus Florencia (radio 150m)',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        value: _requiereGPS,
        onChanged: (val) => setState(() => _requiereGPS = val),
      ),
    );
  }

  Widget _construirBotonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _cargando ? null : _guardarCursoEnFirestore,
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorTema,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.calendar_today_outlined, size: 18),
        label: Text(
          _cargando ? 'Guardando...' : 'Guardar y Programar Asignatura',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

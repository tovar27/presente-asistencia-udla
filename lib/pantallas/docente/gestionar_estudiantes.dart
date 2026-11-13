import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

class EstudianteModelo {
  String id;
  String codigo;
  String nombreCompleto;
  String correoInst;
  String documento;
  String programa;
  String telefono;

  EstudianteModelo({
    required this.id,
    required this.codigo,
    required this.nombreCompleto,
    required this.correoInst,
    required this.documento,
    this.programa = 'INGENIERIA DE SISTEMAS',
    this.telefono = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'nombreCompleto': nombreCompleto,
      'correoInst': correoInst,
      'documento': documento,
      'programa': programa,
      'telefono': telefono,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  factory EstudianteModelo.fromMap(String id, Map<String, dynamic> map) {
    return EstudianteModelo(
      id: id,
      codigo: map['codigo'] ?? '',
      nombreCompleto: map['nombreCompleto'] ?? '',
      correoInst: map['correoInst'] ?? '',
      documento: map['documento'] ?? '',
      programa: map['programa'] ?? 'INGENIERIA DE SISTEMAS',
      telefono: map['telefono'] ?? '',
    );
  }
}

class GestionarEstudiantes extends StatefulWidget {
  final String? cursoId;
  final String nombreAsignatura;
  final String grupo;
  final String salon;
  final String bloque;
  final String horario;

  const GestionarEstudiantes({
    super.key,
    this.cursoId,
    this.nombreAsignatura = 'Cargando...',
    this.grupo = '...',
    this.salon = '...',
    this.bloque = '...',
    this.horario = '...',
  });

  @override
  State<GestionarEstudiantes> createState() => _EstadoGestionarEstudiantes();
}

class _EstadoGestionarEstudiantes extends State<GestionarEstudiantes> {
  final Color _colorTema = const Color(0xFF00382A);
  bool _cargando = true; // Inicia en true para no mostrar vacío de inmediato
  bool _sincronizado = true;
  String _nombreArchivo = 'Ningún archivo seleccionado'; // Cero datos quemados

  // LISTA COMPLETAMENTE VACÍA. Cero datos quemados.
  final List<EstudianteModelo> _estudiantes = [];

  @override
  void initState() {
    super.initState();
    if (widget.cursoId != null) {
      _cargarEstudiantesDesdeFirestore();
    } else {
      _cargando = false;
    }
  }

  Future<void> _cargarEstudiantesDesdeFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.cursoId)
          .collection('estudiantes')
          .get();

      if (mounted) {
        setState(() {
          _estudiantes.clear();
          for (var doc in snapshot.docs) {
            _estudiantes.add(EstudianteModelo.fromMap(doc.id, doc.data()));
          }
        });

        // Corrige y fuerza el valor real en la base de datos al cargar
        await FirebaseFirestore.instance
            .collection('cursos')
            .doc(widget.cursoId)
            .update({'totalEstudiantes': _estudiantes.length});
      }
    } catch (e) {
      debugPrint("Error al cargar estudiantes: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarCambiosEnFirestore() async {
    if (widget.cursoId == null) {
      _mostrarMensaje('Modo prueba: No hay ID de curso.');
      return;
    }

    setState(() => _cargando = true);

    try {
      final coleccionRef = FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.cursoId)
          .collection('estudiantes');

      // 1. Borrar datos actuales (limpieza antes de sincronizar)
      final snapshotExistente = await coleccionRef.get();
      for (var doc in snapshotExistente.docs) {
        await doc.reference.delete();
      }

      // 2. Subir nueva lista
      for (var estudiante in _estudiantes) {
        await coleccionRef.add(estudiante.toMap());
      }

      // 3. Actualizar el contador en la materia principal
      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.cursoId)
          .update({'totalEstudiantes': _estudiantes.length});

      if (!mounted) return;
      setState(() => _sincronizado = true);
      _mostrarMensaje('¡Lista de estudiantes sincronizada con éxito!');
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al sincronizar con Firestore.', esError: true);
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

  void _mostrarDialogoAgregarEstudiante() {
    final controllerNombre = TextEditingController();
    final controllerCodigo = TextEditingController();
    final controllerCorreo = TextEditingController();
    final controllerDocumento = TextEditingController();
    final controllerTelefono = TextEditingController();
    bool guardandoModal = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFE8F5EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined, color: _colorTema),
              const SizedBox(width: 8),
              const Text(
                'Agregar Estudiante',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controllerNombre,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo (Apellidos Nombres)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerCodigo,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Código Estudiante',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerCorreo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Institucional',
                    hintText: 'usuario@udla.edu.co',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerDocumento,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'No. Documento (Cédula/TI)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerTelefono,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardandoModal ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorTema,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: guardandoModal
                  ? null
                  : () async {
                      String nombre = controllerNombre.text.trim();
                      String codigo = controllerCodigo.text.trim();
                      String correo = controllerCorreo.text.trim();

                      if (nombre.isEmpty || codigo.isEmpty) {
                        _mostrarMensaje(
                          'Nombre y Código son obligatorios.',
                          esError: true,
                        );
                        return;
                      }

                      // --- NUEVA VALIDACIÓN DE DUPLICADOS ---
                      String documentoDigitado = controllerDocumento.text
                          .trim();

                      if (documentoDigitado.isNotEmpty) {
                        bool yaExiste = _estudiantes.any(
                          (e) => e.documento == documentoDigitado,
                        );
                        if (yaExiste) {
                          _mostrarMensaje(
                            'El documento $documentoDigitado ya está registrado.',
                            esError: true,
                          );
                          return; // Bloquea el guardado
                        }
                      }
                      // --------------------------------------

                      if (correo.isNotEmpty) {
                        if (!correo.contains('@')) {
                          correo += '@udla.edu.co';
                        } else if (!correo.endsWith('@udla.edu.co')) {
                          _mostrarMensaje(
                            'El correo debe terminar en @udla.edu.co',
                            esError: true,
                          );
                          return;
                        }
                      }

                      setModalState(() => guardandoModal = true);

                      try {
                        EstudianteModelo nuevoEstudiante = EstudianteModelo(
                          id: '',
                          codigo: codigo,
                          nombreCompleto: nombre,
                          correoInst: correo,
                          documento: controllerDocumento.text.trim(),
                          telefono: controllerTelefono.text.trim(),
                        );

                        if (widget.cursoId != null) {
                          // 1. Guardar estudiante en la subcolección
                          DocumentReference docRef = await FirebaseFirestore
                              .instance
                              .collection('cursos')
                              .doc(widget.cursoId)
                              .collection('estudiantes')
                              .add(nuevoEstudiante.toMap());

                          nuevoEstudiante.id = docRef.id;

                          // 2. Actualizar la lista local
                          setState(() {
                            _estudiantes.add(nuevoEstudiante);
                            _sincronizado = true;
                          });

                          // 3. Sobreescribir el contador con la cantidad exacta actual
                          await FirebaseFirestore.instance
                              .collection('cursos')
                              .doc(widget.cursoId)
                              .update({
                                'totalEstudiantes': _estudiantes.length,
                              });
                        } else {
                          nuevoEstudiante.id = DateTime.now()
                              .millisecondsSinceEpoch
                              .toString();
                          setState(() {
                            _estudiantes.add(nuevoEstudiante);
                          });
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          _mostrarMensaje('Estudiante guardado exitosamente');
                        }
                      } catch (e) {
                        setModalState(() => guardandoModal = false);
                        _mostrarMensaje('Error al guardar: $e', esError: true);
                      }
                    },
              child: guardandoModal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Agregar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _obtenerIniciales(String nombre) {
    List<String> partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    } else if (partes.isNotEmpty && partes[0].isNotEmpty) {
      return partes[0][0].toUpperCase();
    }
    return 'E';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFF),
      appBar: _construirAppBar(),
      body: SafeArea(
        child: _cargando && _estudiantes.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00382A)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construirTarjetaEncabezadoCurso(),
                    const SizedBox(height: 16),
                    _construirTarjetaCargaMasiva(),
                    const SizedBox(height: 16),
                    _construirSeccionListaEstudiantes(),
                    const SizedBox(height: 24),
                    _construirBotonGuardarCambios(),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Docente – Gestionar Estudiantes',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis, // Solución overflow
          ),
          Text(
            '${widget.nombreAsignatura} - ${widget.salon}',
            style: const TextStyle(color: Colors.black54, fontSize: 11),
            overflow: TextOverflow.ellipsis, // Solución overflow
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _construirTarjetaEncabezadoCurso() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_outlined, color: _colorTema, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _colorTema,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.grupo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.nombreAsignatura,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow:
                                TextOverflow.ellipsis, // Solución overflow
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ingeniería de Sistemas', // Dinámico o genérico sin fechas quemadas
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_estudiantes.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _colorTema,
                      ),
                    ),
                    Text(
                      'inscritos',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _colorTema,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.door_front_door_outlined,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${widget.salon} • ${widget.bloque}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis, // Solución overflow
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.horario,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
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

  Widget _construirTarjetaCargaMasiva() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.upload_file_outlined,
                        color: Color(0xFF00382A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Carga Masiva de\nEstudiantes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _sincronizado
                      ? const Color(0xFFD1F4E2)
                      : const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sincronizado ? Icons.check_circle_outlined : Icons.sync,
                      size: 12,
                      color: _sincronizado
                          ? const Color(0xFF00382A)
                          : const Color(0xFF856404),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sincronizado ? 'Sincronizado' : 'Pendiente',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _sincronizado
                            ? const Color(0xFF00382A)
                            : const Color(0xFF856404),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _colorTema,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.table_chart_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: _colorTema),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_estudiantes.length} estudiantes cargados', // Conteo real de la lista
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow:
                                  TextOverflow.ellipsis, // Solución overflow
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _nombreArchivo, // Variable dinámica en vez de texto quemado
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: _cargarArchivoExcel, // <-- Conecta la función real
                  icon: const Icon(
                    Icons.sync,
                    size: 14,
                    color: Color(0xFF5C5C96),
                  ),
                  label: Text(
                    _estudiantes.isEmpty ? 'Cargar' : 'Cambiar',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C5C96),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF0FB),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
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

  Widget _construirSeccionListaEstudiantes() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.people_alt_outlined,
                        color: _colorTema,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Estudiantes\nInscritos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _mostrarDialogoAgregarEstudiante,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Agregar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorTema,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ESTADO VACÍO DINÁMICO
          if (_estudiantes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'No hay estudiantes inscritos aún.\nAgrega uno o carga un archivo Excel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _estudiantes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final estudiante = _estudiantes[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFD6E4F5),
                        child: Text(
                          _obtenerIniciales(estudiante.nombreCompleto),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5B84),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estudiante.nombreCompleto,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  estudiante.codigo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _colorTema,
                                  ),
                                ),
                                if (estudiante.correoInst.isNotEmpty) ...[
                                  const Text(
                                    ' • ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black38,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      estudiante.correoInst,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- AQUÍ ESTÁN LOS DOS BOTONES AGRUPADOS (EDITAR Y ELIMINAR) ---
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              _mostrarDialogoEditarEstudiante(
                                estudiante,
                                index,
                              );
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFB02A37),
                            ),
                            onPressed: () async {
                              try {
                                if (widget.cursoId != null &&
                                    estudiante.id.isNotEmpty) {
                                  // 1. Borrar documento en la subcolección
                                  await FirebaseFirestore.instance
                                      .collection('cursos')
                                      .doc(widget.cursoId)
                                      .collection('estudiantes')
                                      .doc(estudiante.id)
                                      .delete();

                                  // 2. Quitar de la lista local
                                  setState(() {
                                    _estudiantes.removeAt(index);
                                  });

                                  // 3. Guardar el tamaño real exacto (garantizando mínimo 0)
                                  int totalReal = _estudiantes.length < 0
                                      ? 0
                                      : _estudiantes.length;
                                  await FirebaseFirestore.instance
                                      .collection('cursos')
                                      .doc(widget.cursoId)
                                      .update({'totalEstudiantes': totalReal});
                                } else {
                                  setState(() {
                                    _estudiantes.removeAt(index);
                                  });
                                }
                                _mostrarMensaje(
                                  'Estudiante eliminado correctamente',
                                );
                              } catch (e) {
                                _mostrarMensaje(
                                  'Error al eliminar estudiante: $e',
                                  esError: true,
                                );
                              }
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                        ],
                      ),

                      // -------------------------------------------------------------
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _construirBotonGuardarCambios() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón de eliminar todos (Solo aparece si hay estudiantes en la lista)
        if (_estudiantes.isNotEmpty) ...[
          TextButton.icon(
            onPressed: _mostrarDialogoEliminarTodos,
            icon: const Icon(
              Icons.delete_forever,
              color: Color(0xFFB02A37),
              size: 18,
            ),
            label: const Text(
              'Eliminar todos los estudiantes',
              style: TextStyle(
                color: Color(0xFFB02A37),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Tu botón actual de Guardar Cambios
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _cargando ? null : _guardarCambiosEnFirestore,
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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _cargando ? 'Sincronizando...' : 'Guardar cambios',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cargarArchivoExcel() async {
    try {
      fp.PlatformFile? archivo = await fp.FilePicker.pickFile(
        type: fp.FileType.custom,
        allowedExtensions: [
          'xlsx',
        ], // Solo permitimos .xlsx para evitar errores
      );

      if (archivo != null) {
        var bytes = await archivo.readAsBytes();
        var excel = Excel.decodeBytes(bytes);

        List<EstudianteModelo> nuevosEstudiantes = [];
        int duplicadosOmitidos = 0;

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet == null) continue;

          for (int i = 1; i < sheet.maxRows; i++) {
            var row = sheet.rows[i];
            if (row.isEmpty) continue;

            String codigo = (row.length > 1 && row[1] != null)
                ? row[1]!.value.toString().trim()
                : '';
            String correo = (row.length > 3 && row[3] != null)
                ? row[3]!.value.toString().trim()
                : '';
            String documento = (row.length > 4 && row[4] != null)
                ? row[4]!.value.toString().trim()
                : '';
            String nombre = (row.length > 5 && row[5] != null)
                ? row[5]!.value.toString().trim()
                : '';
            String telefono = (row.length > 7 && row[7] != null)
                ? row[7]!.value.toString().trim()
                : '';

            if (nombre.isEmpty || codigo.isEmpty) continue;

            bool existe =
                _estudiantes.any((e) => e.documento == documento) ||
                nuevosEstudiantes.any((e) => e.documento == documento);

            if (existe) {
              duplicadosOmitidos++;
              continue;
            }

            if (correo.isNotEmpty) {
              if (!correo.contains('@')) {
                correo += '@udla.edu.co';
              } else if (!correo.endsWith('@udla.edu.co')) {
                continue;
              }
            }

            nuevosEstudiantes.add(
              EstudianteModelo(
                id: '',
                codigo: codigo,
                nombreCompleto: nombre,
                correoInst: correo,
                documento: documento,
                telefono: telefono,
              ),
            );
          }
          break;
        }

        if (nuevosEstudiantes.isNotEmpty) {
          setState(() {
            _estudiantes.addAll(nuevosEstudiantes);
            _nombreArchivo = archivo.name;
            _sincronizado = false;
          });

          String mensaje =
              'Se agregaron ${nuevosEstudiantes.length} estudiantes nuevos.';
          if (duplicadosOmitidos > 0) {
            mensaje += ' Se omitieron $duplicadosOmitidos duplicados.';
          }
          _mostrarMensaje(mensaje);
        } else if (duplicadosOmitidos > 0) {
          _mostrarMensaje(
            'Todos los estudiantes del archivo ya están en la lista.',
            esError: true,
          );
        } else {
          _mostrarMensaje(
            'No se encontraron filas válidas en el archivo.',
            esError: true,
          );
        }
      }
    } catch (e) {
      _mostrarMensaje('Error al procesar el archivo Excel: $e', esError: true);
    }
  }

  void _mostrarDialogoEditarEstudiante(EstudianteModelo estudiante, int index) {
    // 1. Inicializamos los controladores con los datos actuales del estudiante
    final controllerNombre = TextEditingController(
      text: estudiante.nombreCompleto,
    );
    final controllerCodigo = TextEditingController(text: estudiante.codigo);
    final controllerCorreo = TextEditingController(text: estudiante.correoInst);
    final controllerDocumento = TextEditingController(
      text: estudiante.documento,
    );
    final controllerTelefono = TextEditingController(text: estudiante.telefono);
    bool guardandoModal = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFE8F5EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_document, color: _colorTema),
              const SizedBox(width: 8),
              const Text(
                'Editar Estudiante',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controllerNombre,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerCodigo,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Código Estudiante',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerCorreo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Institucional',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerDocumento,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'No. Documento (Cédula/TI)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controllerTelefono,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardandoModal ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorTema,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: guardandoModal
                  ? null
                  : () async {
                      String nombre = controllerNombre.text.trim();
                      String codigo = controllerCodigo.text.trim();
                      String correo = controllerCorreo.text.trim();

                      if (nombre.isEmpty || codigo.isEmpty) {
                        _mostrarMensaje(
                          'Nombre y Código son obligatorios.',
                          esError: true,
                        );
                        return;
                      }

                      if (correo.isNotEmpty) {
                        if (!correo.contains('@')) {
                          correo += '@udla.edu.co';
                        } else if (!correo.endsWith('@udla.edu.co')) {
                          _mostrarMensaje(
                            'El correo debe terminar en @udla.edu.co',
                            esError: true,
                          );
                          return;
                        }
                      }

                      setModalState(() => guardandoModal = true);

                      try {
                        // 2. Creamos el objeto actualizado manteniendo el mismo ID
                        EstudianteModelo estudianteActualizado =
                            EstudianteModelo(
                              id: estudiante.id,
                              codigo: codigo,
                              nombreCompleto: nombre,
                              correoInst: correo,
                              documento: controllerDocumento.text.trim(),
                              telefono: controllerTelefono.text.trim(),
                            );

                        // 3. Actualizamos en Firestore si ya existe en la base de datos
                        if (widget.cursoId != null &&
                            estudiante.id.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('cursos')
                              .doc(widget.cursoId)
                              .collection('estudiantes')
                              .doc(estudiante.id)
                              .update(estudianteActualizado.toMap());
                        }

                        // 4. Actualizamos la lista local y cerramos
                        if (mounted) {
                          setState(() {
                            _estudiantes[index] = estudianteActualizado;
                            _sincronizado = true;
                          });
                          Navigator.pop(context);
                          _mostrarMensaje(
                            'Estudiante actualizado exitosamente',
                          );
                        }
                      } catch (e) {
                        setModalState(() => guardandoModal = false);
                        _mostrarMensaje(
                          'Error al actualizar: $e',
                          esError: true,
                        );
                      }
                    },
              child: guardandoModal
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEliminarTodos() {
    if (_estudiantes.isEmpty) return;

    final TextEditingController _confirmacionController =
        TextEditingController();
    bool eliminando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(
            0xFFFBE9E7,
          ), // Fondo rojizo claro de advertencia
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB02A37)),
              SizedBox(width: 8),
              Text(
                'Precaución',
                style: TextStyle(
                  color: Color(0xFFB02A37),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de que deseas eliminar TODOS los estudiantes de este curso? Esta acción borrará los registros en la base de datos y no se puede deshacer.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escribe "ELIMINAR" para confirmar:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmacionController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'ELIMINAR',
                ),
                onChanged: (value) {
                  setModalState(() {}); // Actualiza la vista para habilitar el botón cuando escriba
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: eliminando ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB02A37),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // El botón se habilita SOLO si escribió la palabra exacta en mayúsculas
              onPressed:
                  (_confirmacionController.text.trim() != 'ELIMINAR' ||
                      eliminando)
                  ? null
                  : () async {
                      setModalState(() => eliminando = true);

                      try {
                        if (widget.cursoId != null) {
                          // 1. Obtener todos los documentos de los estudiantes
                          var snapshot = await FirebaseFirestore.instance
                              .collection('cursos')
                              .doc(widget.cursoId)
                              .collection('estudiantes')
                              .get();

                          // 2. Crear un WriteBatch (Lote de escritura masiva)
                          var batch = FirebaseFirestore.instance.batch();

                          // 3. Añadir cada estudiante al lote para ser eliminado
                          for (var doc in snapshot.docs) {
                            batch.delete(doc.reference);
                          }

                          // 4. Añadir la actualización del contador a 0 en el mismo lote
                          var cursoRef = FirebaseFirestore.instance
                              .collection('cursos')
                              .doc(widget.cursoId);
                          batch.update(cursoRef, {'totalEstudiantes': 0});

                          // 5. ¡Ejecutar todo de un solo golpe en Firebase!
                          await batch.commit();
                        }

                        // 6. Limpiar la lista local de la pantalla
                        if (mounted) {
                          setState(() {
                            _estudiantes.clear();
                            _sincronizado =
                                true; // Ya no hay cambios pendientes
                          });
                          Navigator.pop(context);
                          _mostrarMensaje(
                            'Todos los estudiantes han sido eliminados del curso.',
                          );
                        }
                      } catch (e) {
                        setModalState(() => eliminando = false);
                        _mostrarMensaje(
                          'Error al vaciar la lista: $e',
                          esError: true,
                        );
                      }
                    },
              child: eliminando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Vaciar Curso',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

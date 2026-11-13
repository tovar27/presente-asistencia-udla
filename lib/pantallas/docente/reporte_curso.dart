import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:io';

import 'package:excel/excel.dart' hide TextSpan, Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReporteCursoScreen extends StatefulWidget {
  final String cursoId;
  final String nombreAsignatura;

  const ReporteCursoScreen({
    Key? key,
    required this.cursoId,
    required this.nombreAsignatura,
  }) : super(key: key);

  @override
  State<ReporteCursoScreen> createState() => _ReporteCursoScreenState();
}

class _ReporteCursoScreenState extends State<ReporteCursoScreen> {
  final TextEditingController _controladorBusqueda = TextEditingController();

  List<Map<String, dynamic>> _todosLosEstudiantes = [];
  List<Map<String, dynamic>> _estudiantesFiltrados = [];

  bool _cargando = true;
  int _totalMatriculados = 0;
  double _promedioGeneral = 0.0;
  int _cumplen = 0;
  int _enRiesgo = 0;
  int _reprobados = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosDesdeFirebase();
  }

  Future<void> _exportarAExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando reporte Excel...'),
          backgroundColor: Color(0xFF00382A),
        ),
      );

      // 1. Crear el documento Excel y la hoja
      var excel = Excel.createExcel();
      Sheet sheet = excel['Reporte de Asistencia'];
      excel.setDefaultSheet('Reporte de Asistencia');

      // 2. Crear las cabeceras (Fila 1)
      sheet.appendRow([
        TextCellValue('Nombre Completo'),
        TextCellValue('ID / Documento'),
        TextCellValue('Estado'),
        TextCellValue('Horas'),
        TextCellValue('Porcentaje'),
      ]);

      // 3. Llenar los datos con la lista de estudiantes
      for (var est in _todosLosEstudiantes) {
        sheet.appendRow([
          TextCellValue(est['nombre'].toString()),
          TextCellValue(est['id'].toString()),
          TextCellValue(est['estado'].toString()),
          TextCellValue(est['horas'].toString()),
          TextCellValue(est['porcentaje'].toString()),
        ]);
      }

      // 4. Generar los bytes del archivo
      var fileBytes = excel.save();
      if (fileBytes == null) return;

      // 5. Guardar temporalmente en el caché del celular
      final directory = await getTemporaryDirectory();
      // Limpiamos el nombre de la materia para que sea un nombre de archivo válido
      String nombreArchivo = widget.nombreAsignatura.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final filePath = '${directory.path}/Reporte_$nombreArchivo.xlsx';

      File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // 6. Abrir el menú nativo para compartir/guardar
      if (mounted) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Reporte Semestral de Asistencia - ${widget.nombreAsignatura}',
        );
      }
    } catch (e) {
      debugPrint('Error exportando Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hubo un error al generar el archivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarDatosDesdeFirebase() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Obtener estudiantes del curso actual
      final estudiantesSnap = await firestore
          .collection('cursos')
          .doc(widget.cursoId)
          .collection('estudiantes')
          .get();

      // 2. Obtener sesiones dictadas en este curso
      final sesionesSnap = await firestore
          .collection('cursos')
          .doc(widget.cursoId)
          .collection('sesiones')
          .get();

      List<Map<String, dynamic>> listaTemporal = [];
      const int totalHorasCurso = 36;
      const int limiteFallasHoras = 7; // Más de 7 hrs de falla reprueba (< 80%)

      double sumaPorcentajes = 0.0;
      int contCumplen = 0;
      int contRiesgo = 0;
      int contReprobados = 0;

      // 3. Procesar cada estudiante y calcular sus fallas reales
      for (var estDoc in estudiantesSnap.docs) {
        final Map<String, dynamic> data = estDoc.data();
        final String idEstudiante = estDoc.id;
        final String nombre = data['nombreCompleto'] ?? 'Sin nombre';
        final String codigo = data['codigo'] ?? data['documento'] ?? 'Sin ID';

        int fallasHoras = 0;

        // Iterar sobre las sesiones registradas
        for (var sesionDoc in sesionesSnap.docs) {
          final Map<String, dynamic> sesionData = sesionDoc.data();
          final Map<String, dynamic> registros = Map<String, dynamic>.from(
            sesionData['registrosAsistencia'] ?? {},
          );

          final String estadoEnClase = registros[idEstudiante] ?? 'Ausente';

          // Asumiendo 2 horas académicas por sesión
          if (estadoEnClase == 'Ausente' || estadoEnClase == 'Pendiente') {
            fallasHoras += 2;
          }
        }

        int horasAsistidas = totalHorasCurso - fallasHoras;
        if (horasAsistidas < 0) horasAsistidas = 0;

        double porcentaje = (horasAsistidas / totalHorasCurso) * 100.0;
        sumaPorcentajes += porcentaje;

        // Categorización según la regla del 80%
        String estado;
        Color colorEstado;
        String textoProgreso;

        if (fallasHoras > limiteFallasHoras) {
          estado = 'Reprobada';
          colorEstado = Colors.red;
          textoProgreso = 'Reprobada por inasistencia:';
          contReprobados++;
        } else if (fallasHoras >= 6) {
          estado = 'Riesgo';
          colorEstado = Colors.orange.shade700;
          textoProgreso =
              'Falta ${limiteFallasHoras - fallasHoras + 1} hr para 80%:';
          contRiesgo++;
        } else {
          estado = 'Cumple';
          colorEstado = Colors.green;
          textoProgreso = 'Registro presencial:';
          contCumplen++;
        }

        listaTemporal.add({
          'nombre': nombre,
          'id': codigo,
          'estado': estado,
          'textoProgreso': textoProgreso,
          'horas': '$horasAsistidas/$totalHorasCurso horas',
          'porcentaje': '(${porcentaje.toStringAsFixed(1)}%)',
          'colorEstado': colorEstado,
          'urlFoto':
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nombre)}&background=E5E7EB&color=00382A',
        });
      }

      setState(() {
        _todosLosEstudiantes = listaTemporal;
        _estudiantesFiltrados = List.from(_todosLosEstudiantes);
        _totalMatriculados = _todosLosEstudiantes.length;
        _cumplen = contCumplen;
        _enRiesgo = contRiesgo;
        _reprobados = contReprobados;
        _promedioGeneral = _totalMatriculados > 0
            ? (sumaPorcentajes / _totalMatriculados)
            : 0.0;
        _cargando = false;
      });
    } catch (e) {
      debugPrint("Error cargando datos de asistencia: $e");
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _filtrarEstudiantes(String texto) {
    setState(() {
      if (texto.trim().isEmpty) {
        _estudiantesFiltrados = List.from(_todosLosEstudiantes);
      } else {
        final busquedaLower = texto.toLowerCase();
        _estudiantesFiltrados = _todosLosEstudiantes.where((est) {
          final nombreLower = est['nombre'].toString().toLowerCase();
          final idLower = est['id'].toString().toLowerCase();
          return nombreLower.contains(busquedaLower) ||
              idLower.contains(busquedaLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Presente',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Universidad de la Amazonia',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.transparent, // Fondo transparente
              backgroundImage: AssetImage(
                'recursos/imagenes/logo_presente.png',
              ),
              radius: 18, // Un poco más grande para mejor visibilidad
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00382A)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CABECERA VERDE DEL CURSO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00382A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INGENIERÍA DE SISTEMAS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.nombreAsignatura,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '36 horas\nsemestrales',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 24),
                            const Icon(
                              Icons.people_outline,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_totalMatriculados estudiantes\nmatriculados',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. MÉTRICAS GLOBALES DE ASISTENCIA
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Métricas Globales de Asistencia',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(Icons.insights, color: Colors.black54),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            // Gráfica Circular Dinámica
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: CircularProgressIndicator(
                                      value: (_promedioGeneral / 100.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      strokeWidth: 10,
                                      backgroundColor: Colors.grey.shade200,
                                      color: const Color(0xFF00382A),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${_promedioGeneral.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'Promedio',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Leyenda de Estados
                            Expanded(
                              child: Column(
                                children: [
                                  _construirFilaLeyenda(
                                    'Cumplen regla 80%',
                                    '$_cumplen',
                                    const Color(0xFF00382A),
                                  ),
                                  const SizedBox(height: 10),
                                  _construirFilaLeyenda(
                                    'En riesgo preventivo',
                                    '$_enRiesgo',
                                    Colors.orange.shade700,
                                  ),
                                  const SizedBox(height: 10),
                                  _construirFilaLeyenda(
                                    'Reprobando por fallas',
                                    '$_reprobados',
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Banner Requisito de Permanencia
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF2B5B84),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Requisito de permanencia',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF2B5B84),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Mínimo 80% de asistencia presencial sobre 36 horas totales (29 horas mínimas obligatorias).',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. BOTÓN EXPORTAR A EXCEL
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _exportarAExcel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00382A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Exportar a Excel (.xlsx)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. BARRA DE BÚSQUEDA
                  TextField(
                    controller: _controladorBusqueda,
                    onChanged: _filtrarEstudiantes,
                    decoration: InputDecoration(
                      hintText: 'Filtrar por estudiante o ID...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. ENCABEZADO DE LA LISTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Listado Detallado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_estudiantesFiltrados.length} de ${_todosLosEstudiantes.length} estudiantes',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 6. LISTA DINÁMICA DE ESTUDIANTES
                  _estudiantesFiltrados.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(
                            child: Text(
                              'No se encontraron estudiantes',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _estudiantesFiltrados.length,
                          itemBuilder: (context, index) {
                            final est = _estudiantesFiltrados[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _construirTarjetaEstudiante(
                                nombre: est['nombre'],
                                id: est['id'],
                                estado: est['estado'],
                                textoProgreso: est['textoProgreso'],
                                horas: est['horas'],
                                porcentaje: est['porcentaje'],
                                colorEstado: est['colorEstado'],
                                urlFoto: est['urlFoto'],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _construirFilaLeyenda(String texto, String valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaEstudiante({
    required String nombre,
    required String id,
    required String estado,
    required String textoProgreso,
    required String horas,
    required String porcentaje,
    required Color colorEstado,
    required String urlFoto,
  }) {
    Color colorFondoInferior;
    Color colorTextoInferior;

    if (estado == 'Reprobada') {
      colorFondoInferior = const Color(0xFFFFF4F4);
      colorTextoInferior = Colors.red.shade700;
    } else if (estado == 'Riesgo') {
      colorFondoInferior = const Color(0xFFFFF8EE);
      colorTextoInferior = Colors.orange.shade800;
    } else {
      colorFondoInferior = const Color(0xFFF8F9FA);
      colorTextoInferior = Colors.black54;
    }

    Color colorHoras = estado == 'Reprobada'
        ? Colors.red
        : (estado == 'Riesgo'
              ? Colors.orange.shade700
              : const Color(0xFF00382A));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: NetworkImage(urlFoto),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0C1D36),
                      ),
                    ),
                    Text(
                      'ID: $id',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorEstado.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: colorEstado),
                    const SizedBox(width: 4),
                    Text(
                      estado,
                      style: TextStyle(
                        color: colorEstado,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorFondoInferior,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  textoProgreso,
                  style: TextStyle(
                    color: colorTextoInferior,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF0C1D36),
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: horas,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colorHoras,
                        ),
                      ),
                      TextSpan(
                        text: ' $porcentaje',
                        style: const TextStyle(fontWeight: FontWeight.w500),
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

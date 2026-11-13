import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reporte_curso.dart';
import 'revisar_justificaciones.dart';

class ListaCursosReporte extends StatefulWidget {
  const ListaCursosReporte({super.key});

  @override
  State<ListaCursosReporte> createState() => _ListaCursosReporteState();
}

class _ListaCursosReporteState extends State<ListaCursosReporte> {
  final TextEditingController _controladorBusqueda = TextEditingController();
  String _textoBusqueda = "";

  final Color _colorPrimario = const Color(0xFF00382A);
  final Color _colorFondo = const Color(0xFFF9F9FF);
  final Color _colorTarjetaClara = const Color(0xFFEEF0FF);

  Stream<QuerySnapshot>? _streamCursos;

  @override
  void initState() {
    super.initState();
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      _streamCursos = FirebaseFirestore.instance
          .collection('cursos')
          .where('docenteUid', isEqualTo: usuario.uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: _streamCursos == null
          ? const Center(child: Text('Sin sesión activa'))
          : StreamBuilder<QuerySnapshot>(
              stream: _streamCursos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _colorPrimario),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay cursos registrados.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final todosLosCursos = snapshot.data!.docs;

                // Filtro local solo para la barra de búsqueda
                final cursosFiltrados = todosLosCursos.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombreAsignatura'] ?? '').toLowerCase();
                  final codigo = (data['codigo'] ?? '').toLowerCase();
                  final busqueda = _textoBusqueda.toLowerCase();

                  return nombre.contains(busqueda) || codigo.contains(busqueda);
                }).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    _construirCabecera(todosLosCursos.length),
                    const SizedBox(height: 20),
                    _construirBarraBusqueda(),
                    const SizedBox(
                      height: 24,
                    ), // Espaciado directo a las tarjetas

                    if (cursosFiltrados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No se encontraron cursos',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...cursosFiltrados.map(
                        (curso) => _construirTarjetaCurso(curso),
                      ),

                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _colorPrimario,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hourglass_top,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UNIAMAZONIA',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Reportes',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {
            // Navegación temporal para probar la pantalla
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RevisarJustificacionesScreen(
                  cursoId: '123',
                  nombreAsignatura: 'Estructura de Datos II',
                  codigo: 'SIS-401',
                ),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage('recursos/imagenes/logo_presente.png'),
            radius: 18,
          ),
        ),
      ],
    );
  }

  Widget _construirCabecera(int totalCursos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Mis Cursos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 36.0, top: 4),
          child: Text(
            'Selecciona un curso para ver su reporte',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _colorTarjetaClara,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _colorPrimario,
                  borderRadius: BorderRadius.circular(12),
                  // Opcional: Aquí puedes poner tu logo pequeño
                  // image: const DecorationImage(image: AssetImage('ruta/logo.png')),
                ),
                child: const Icon(Icons.bar_chart, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RESUMEN SEMESTRAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C5C96),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalCursos Cursos registrados',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirBarraBusqueda() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controladorBusqueda,
        onChanged: (valor) {
          setState(() {
            _textoBusqueda = valor;
          });
        },
        decoration: InputDecoration(
          hintText: 'Buscar por materia o código...',
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.black45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _construirTarjetaCurso(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final cursoId = doc.id;
    final titulo = data['nombreAsignatura'] ?? 'Asignatura';
    final codigo = data['codigo'] ?? 'SIS-000';
    final grupo = data['grupo'] ?? 'Grupo A';
    final aula = data['salon'] ?? 'Sin asignar';
    final horario = data['horario'] ?? 'Sin horario';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorTarjetaClara,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  codigo,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B3B6D),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  $grupo',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.door_front_door_outlined,
                size: 16,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                aula,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                size: 16,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                horario,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReporteCursoScreen(
                      cursoId: cursoId,
                      nombreAsignatura: titulo,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _colorTarjetaClara,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver reporte',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B3B6D),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF3B3B6D),
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
}

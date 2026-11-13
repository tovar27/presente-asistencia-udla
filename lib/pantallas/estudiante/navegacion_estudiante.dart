import 'package:flutter/material.dart';

class NavegacionEstudiante extends StatefulWidget {
  const NavegacionEstudiante({super.key});

  @override
  State<NavegacionEstudiante> createState() => _EstadoNavegacionEstudiante();
}

class _EstadoNavegacionEstudiante extends State<NavegacionEstudiante> {
  int _indiceActual = 0;
  static const Color _colorEstudiante = Color(0xFFB02A37);

  // Aquí irán las 4 pantallas reales del estudiante (por ahora son textos de relleno)
  final List<Widget> _pantallas = const [
    Center(child: Text('Pantalla: Cursos Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    Center(child: Text('Pantalla: Marcar Asistencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    Center(child: Text('Pantalla: Historial y Justificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    Center(child: Text('Pantalla: Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      body: _pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Obligatorio para más de 3 botones
        currentIndex: _indiceActual,
        onTap: (indice) => setState(() => _indiceActual = indice),
        selectedItemColor: _colorEstudiante,
        unselectedItemColor: Colors.black54,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Cursos'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), activeIcon: Icon(Icons.location_on), label: 'Asistencia'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
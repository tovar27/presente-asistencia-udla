import 'package:flutter/material.dart';

import 'home_docente.dart'; // Importamos la pantalla real del Home
import 'registrar_curso.dart';
import 'lista_cursos_reporte.dart';
import 'perfil_docente.dart';

class NavegacionDocente extends StatefulWidget {
  const NavegacionDocente({super.key});

  @override
  State<NavegacionDocente> createState() => _EstadoNavegacionDocente();
}

class _EstadoNavegacionDocente extends State<NavegacionDocente> {
  int _indiceActual = 0;
  static const Color _colorDocente = Color(0xFF00382A);

  // Reemplazamos el primer texto de relleno por la pantalla real HomeDocente()
  final List<Widget> _pantallas = const [
    HomeDocente(),
    Center(
      child: Text(
        'Pantalla: Activar Clase',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),

    ListaCursosReporte(),

    Center(
      child: Text(
        'Pantalla: Asistencia Manual',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),

    PerfilDocenteScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      // IndexedStack mantiene vivas las pantallas para que no se recarguen al cambiar de pestaña
      body: IndexedStack(index: _indiceActual, children: _pantallas),

      // El botón flotante central de "Nueva Sesión" (Va en el cascarón principal)
      // El botón flotante central de "Nueva Sesión" solo visible en la pestaña Cursos (índice 0)
      floatingActionButton: _indiceActual == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistrarCurso(),
                  ),
                );
              },
              backgroundColor: _colorDocente,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nueva Sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null, // Si no estamos en la pestaña 0, el botón no se dibuja

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _indiceActual,
        onTap: (indice) => setState(() => _indiceActual = indice),
        selectedItemColor: _colorDocente,
        unselectedItemColor: Colors.black54,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Cursos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_fill),
            label: 'Activar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: 'Asistencia',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

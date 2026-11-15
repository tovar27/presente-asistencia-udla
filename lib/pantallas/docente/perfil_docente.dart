import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importación de tu pantalla de login
import '../pantalla_inicio_sesion.dart';

class PerfilDocenteScreen extends StatefulWidget {
  const PerfilDocenteScreen({super.key});

  @override
  State<PerfilDocenteScreen> createState() => _PerfilDocenteScreenState();
}

class _PerfilDocenteScreenState extends State<PerfilDocenteScreen> {
  // Variables de estado para los interruptores
  bool _alertasClase = true;
  bool _recordatorioJustificaciones = true;

  // Colores del sistema
  final Color _colorPrimario = const Color(0xFF00382A);
  final Color _colorFondo = const Color(0xFFF9F9FF);
  final Color _colorTarjeta = Colors.white;

  // Usuario actual de Firebase Auth
  final User? _usuarioActual = FirebaseAuth.instance.currentUser;

  // Variables dinámicas para los datos del profesor desde Firestore
  String _nombreDocente = 'Cargando...';
  String _correoDocente = '';
  String _documentoIdentidad = 'Cargando...';
  String _departamento = 'Cargando...';
  String _telefono = 'Cargando...';

  // Nuevas variables dinámicas para los contadores
  int _cantidadCursos = 0;
  int _totalEstudiantes = 0;
  int _horasSemanales = 0;

  bool _cargandoDatos = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosDocenteDesdeFirestore();
  }

  // Consulta a la colección 'usuarios' y 'cursos' en Firestore
  Future<void> _cargarDatosDocenteDesdeFirestore() async {
    try {
      if (_usuarioActual != null) {
        // 1. Obtener datos del perfil del usuario (Esto ya funcionaba bien)
        final docSnapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_usuarioActual.uid)
            .get();

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data()!;
          setState(() {
            _nombreDocente = data['nombre'] ?? 'Sin nombre registrado';
            _correoDocente = data['correo'] ?? _usuarioActual.email ?? '';
            _documentoIdentidad =
                '${data['tipo_documento'] ?? 'C.C.'} ${data['documento'] ?? ''}';
            _departamento = data['departamento'] ?? 'Sin departamento';
            _telefono = data['telefono'] ?? 'No registrado';
          });
        }

        // 2. Obtener estadísticas (cursos, estudiantes, horas)
        int cursosCount = 0;
        int estudiantesCount = 0;
        int horasCount = 0; // Nueva variable para sumar las horas reales

        // Consultar la colección 'cursos' filtrando por 'docenteUid'
        final cursosSnapshot = await FirebaseFirestore.instance
            .collection('cursos')
            .where('docenteUid', isEqualTo: _usuarioActual.uid)
            .get();

        cursosCount = cursosSnapshot.docs.length;

        // Recorrer cada curso para sumar estudiantes y horas
        for (var cursoDoc in cursosSnapshot.docs) {
          // A) Sumar los estudiantes consultando la subcolección 'estudiantes'
          final estudiantesSnapshot = await cursoDoc.reference
              .collection('estudiantes')
              .get();

          estudiantesCount += estudiantesSnapshot.docs.length;

          // B) Calcular horas: contar cuántos días a la semana tiene el curso y multiplicar por 2 horas
          final data = cursoDoc.data();
          if (data.containsKey('diasSemana') && data['diasSemana'] is List) {
            int diasClase = (data['diasSemana'] as List).length;
            horasCount += (diasClase * 2); // 2 horas por cada día de clase
          }
        }

        // Actualizar el estado general al finalizar todas las consultas
        setState(() {
          _cantidadCursos = cursosCount;
          _totalEstudiantes = estudiantesCount;
          _horasSemanales = horasCount; // Suma dinámica real
          _cargandoDatos = false;
        });

        return;
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
    }

    // Valores por defecto si la lectura falla o aún no existe el documento
    setState(() {
      _nombreDocente = _usuarioActual?.displayName ?? 'Docente Uniamazonia';
      _correoDocente = _usuarioActual?.email ?? '';
      _cargandoDatos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: _cargandoDatos
          ? Center(child: CircularProgressIndicator(color: _colorPrimario))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _construirTarjetaPrincipal(),
                const SizedBox(height: 16),
                _construirEstadisticas(),
                const SizedBox(height: 24),
                _construirDatosInstitucionales(),
                const SizedBox(height: 16),
                _construirDatosContacto(),
                const SizedBox(height: 16),
                _construirPreferencias(),
                const SizedBox(height: 24),
                _construirBotonCerrarSesion(context),
                const SizedBox(height: 16),
                _construirFooter(),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi Perfil',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'UNIVERSIDAD DE LA AMAZONIA • SEDE FLOREN...',
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
            backgroundColor: Colors
                .transparent, // Fondo transparente para que el logo resalte
            radius: 18, // Un poco más grande para que se vea mejor
            backgroundImage: const AssetImage(
              'recursos/imagenes/logo_presente.png',
            ), // Cámbialo a 'assets/images/logo.png' si lo tienes en otra subcarpeta
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaPrincipal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colorPrimario,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape
                      .circle, // Esto garantiza que sea perfectamente redondo
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 45, color: Colors.black26),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _colorPrimario, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _nombreDocente,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 6),
                Text(
                  'Docente Planta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$_departamento • Facultad de Ingeniería',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_outlined,
                  color: Colors.white.withOpacity(0.9),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _correoDocente,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, color: Colors.white, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadisticas() {
    return Row(
      children: [
        Expanded(
          child: _cuadroEstadistica(
            Icons.menu_book,
            '$_cantidadCursos', // Variable en lugar del dato quemado
            'Cursos Activos',
            'Grupo A, B y C',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _cuadroEstadistica(
            Icons.people_alt_outlined,
            '$_totalEstudiantes', // Variable en lugar del dato quemado
            'Estudiantes',
            'A cargo este\nciclo',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _cuadroEstadistica(
            Icons.access_time,
            '${_horasSemanales}h', // Variable en lugar del dato quemado
            'Horas / Sem.',
            'Cátedra\ndirecta',
          ),
        ),
      ],
    );
  }

  Widget _cuadroEstadistica(
    IconData icono,
    String valor,
    String titulo,
    String subtitulo,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _colorTarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF0FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: const Color(0xFF3B3B6D), size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.black54,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirDatosInstitucionales() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorTarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF00382A),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Datos Institucionales',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Oficial',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B3B6D),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _itemDato(
            Icons.fingerprint,
            'Documento de Identidad',
            _documentoIdentidad,
            trailing: const Icon(
              Icons.shield_outlined,
              size: 16,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          _itemDato(
            Icons.alternate_email,
            'Dominio Institucional',
            _correoDocente,
            trailing: _badgeActivo(),
          ),
          const SizedBox(height: 16),
          _itemDato(
            Icons.account_tree_outlined,
            'Departamento Académico',
            _departamento,
          ),
          const SizedBox(height: 16),
          _itemDato(
            Icons.business,
            'Sede / Ubicación Física',
            'Sede Florencia • Bloque 7, Oficina 7204',
          ),
        ],
      ),
    );
  }

  Widget _construirDatosContacto() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorTarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.contact_phone_outlined,
                color: Color(0xFF00382A),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Datos de Contacto',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _itemDato(
            Icons.phone_iphone,
            'Móvil Personal',
            _telefono,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 12, color: Color(0xFF3B3B6D)),
                  SizedBox(width: 4),
                  Text(
                    'Editar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B3B6D),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _itemDato(
            Icons.email_outlined,
            'Correo Principal Verificado',
            _correoDocente,
            trailing: const Icon(
              Icons.verified_user,
              size: 18,
              color: Color(0xFF00382A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemDato(
    IconData icono,
    String titulo,
    String valor, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icono, size: 18, color: Colors.black45),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _badgeActivo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: Color(0xFF008040)),
          SizedBox(width: 4),
          Text(
            'Activo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF008040),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPreferencias() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorTarjeta,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF00382A),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Preferencias y Notificaciones',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alertas de inicio de clase',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notificación 15 minutos antes de iniciar cada sesión programada para proyectar QR o pasar lista.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _alertasClase,
                activeColor: Colors.white,
                activeTrackColor: _colorPrimario,
                onChanged: (val) => setState(() => _alertasClase = val),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recordatorio de justificaciones',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aviso cuando un estudiante radique una excusa médica o justificación reglamentaria.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _recordatorioJustificaciones,
                activeColor: Colors.white,
                activeTrackColor: _colorPrimario,
                onChanged: (val) =>
                    setState(() => _recordatorioJustificaciones = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirBotonCerrarSesion(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _confirmarCerrarSesion,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Cerrar Sesión Segura',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorPrimario,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _construirFooter() {
    return const Center(
      child: Text(
        'Presente v1.0.0 • Universidad de la Amazonia • Florencia,\nCaquetá',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Colors.black45, height: 1.5),
      ),
    );
  }

  Future<void> _confirmarCerrarSesion() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir de tu cuenta institucional?',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _colorPrimario,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            Center(child: CircularProgressIndicator(color: _colorPrimario)),
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaInicioSesion()),
        (route) => false,
      );
    }
  }
}

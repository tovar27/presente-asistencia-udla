import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pantalla_inicio_sesion.dart';

class PerfilEstudiante extends StatefulWidget {
  const PerfilEstudiante({super.key});

  @override
  State<PerfilEstudiante> createState() => _EstadoPerfilEstudiante();
}

class _EstadoPerfilEstudiante extends State<PerfilEstudiante> {
  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorEstudianteOscuro = Color(0xFF8A1C26);
  static const Color _colorFondo = Color(0xFFF8F9FA);

  final User? _usuarioActual = FirebaseAuth.instance.currentUser;

  void _copiarCodigo(String codigo) {
    if (codigo.isEmpty || codigo == 'Sin asignar') return;
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código estudiantil copiado al portapapeles'),
        backgroundColor: _colorEstudiante,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _mostrarDialogoEditarTelefono(String telefonoActual) {
    final TextEditingController controlador = TextEditingController(
      text: telefonoActual == 'Sin registrar' ? '' : telefonoActual,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Actualizar teléfono móvil',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controlador,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Número de celular',
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: _colorEstudiante,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final String nuevo = controlador.text.trim();
              if (nuevo.isNotEmpty && _usuarioActual != null) {
                Navigator.pop(dialogContext);
                try {
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(_usuarioActual.uid)
                      .update({'telefono': nuevo});
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Teléfono actualizado correctamente'),
                      backgroundColor: Color(0xFF198754),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar teléfono: $e'),
                      backgroundColor: _colorEstudiante,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _colorEstudiante,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarPreferenciaAlertas(bool valor) async {
    if (_usuarioActual == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_usuarioActual.uid)
          .set({'alertasClases': valor}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error al guardar preferencia de alertas: $e');
    }
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
              backgroundColor: _colorEstudiante,
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
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaInicioSesion()),
        (route) => false,
      );
    }
  }

  String _formatearPrograma(String raw) {
    if (raw.isEmpty) return 'Ingeniería de Sistemas';
    final List<String> conectores = [
      'de',
      'del',
      'la',
      'las',
      'los',
      'y',
      'en',
    ];
    return raw
        .toLowerCase()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map((entry) {
          final palabra = entry.value;
          if (entry.key > 0 && conectores.contains(palabra)) return palabra;
          return '${palabra[0].toUpperCase()}${palabra.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarioActual == null) {
      return const Scaffold(
        backgroundColor: _colorFondo,
        body: Center(child: Text('No hay una sesión activa')),
      );
    }

    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_usuarioActual.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _colorEstudiante),
              );
            }

            final Map<String, dynamic> datos =
                (snapshot.hasData && snapshot.data!.exists)
                ? (snapshot.data!.data() as Map<String, dynamic>)
                : {};

            final String nombre = (datos['nombre'] ?? 'Estudiante')
                .toString()
                .trim();
            final String correo =
                (datos['correo'] ?? _usuarioActual.email ?? 'Sin correo')
                    .toString()
                    .trim();
            final String tipoDocumento = (datos['tipo_documento'] ?? 'C.C.')
                .toString()
                .trim();
            final String documento = (datos['documento'] ?? '')
                .toString()
                .trim();
            final String telefono =
                (datos['telefono'] ?? '').toString().trim().isNotEmpty
                ? datos['telefono'].toString().trim()
                : 'Sin registrar';
            final String codigoDirecto =
                (datos['codigo'] ?? datos['codigoEstudiantil'] ?? '')
                    .toString()
                    .trim();
            final String programaDirecto = (datos['programa'] ?? '')
                .toString()
                .trim();
            final bool alertasActivas = datos['alertasClases'] is bool
                ? datos['alertasClases'] as bool
                : true;

            // Si código o programa no están en usuarios/{uid}, los consultamos desde su ficha en estudiantes
            return FutureBuilder<QuerySnapshot>(
              future:
                  (codigoDirecto.isEmpty || programaDirecto.isEmpty) &&
                      documento.isNotEmpty
                  ? FirebaseFirestore.instance
                        .collectionGroup('estudiantes')
                        .where('documento', isEqualTo: documento)
                        .limit(1)
                        .get()
                  : null,
              builder: (context, estSnap) {
                Map<String, dynamic> datosInscripcion = {};
                if (estSnap.hasData &&
                    estSnap.data != null &&
                    estSnap.data!.docs.isNotEmpty) {
                  datosInscripcion =
                      estSnap.data!.docs.first.data() as Map<String, dynamic>;
                }

                final String codigoFinal = codigoDirecto.isNotEmpty
                    ? codigoDirecto
                    : (datosInscripcion['codigo'] ?? 'Sin asignar')
                          .toString()
                          .trim();

                final String programaRaw = programaDirecto.isNotEmpty
                    ? programaDirecto
                    : (datosInscripcion['programa'] ?? 'Ingeniería de Sistemas')
                          .toString()
                          .trim();
                final String programaFinal = _formatearPrograma(programaRaw);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _construirTarjetaCabeceraRoja(
                        nombre: nombre,
                        programa: programaFinal,
                        correo: correo,
                      ),
                      const SizedBox(height: 16),
                      _construirFilaMetricas(),
                      const SizedBox(height: 16),
                      _construirTarjetaDatosInstitucionales(
                        codigoEstudiantil: codigoFinal,
                        tipoDocumento: tipoDocumento,
                        documento: documento.isNotEmpty
                            ? documento
                            : 'Sin documento',
                        correo: correo,
                        programa: programaFinal,
                      ),
                      const SizedBox(height: 16),
                      _construirTarjetaDatosContacto(telefono: telefono),
                      const SizedBox(height: 16),
                      _construirTarjetaPreferencias(
                        alertasActivas: alertasActivas,
                      ),
                      const SizedBox(height: 20),
                      _construirBotonCerrarSesion(),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Presente v1.0.0 • Universidad de la Amazonia • Florencia, Caquetá',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _colorFondo,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _colorEstudiante,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
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
                    const Flexible(
                      child: Text(
                        'Estudiante Perfil',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Estudiante',
                        style: TextStyle(
                          color: _colorEstudiante,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Uniamazonia',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_outlined,
            color: Colors.black87,
          ),
          onPressed: () {},
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16, left: 4),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFFDECEE),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              size: 17,
              color: _colorEstudiante,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaCabeceraRoja({
    required String nombre,
    required String programa,
    required String correo,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_colorEstudianteOscuro, _colorEstudiante],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _colorEstudiante.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2.5,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFFDECEE),
                  child: Icon(Icons.person, size: 46, color: _colorEstudiante),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Actualizar foto de perfil'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 15,
                      color: _colorEstudiante,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            programa,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Estudiante Activo • 2026-2',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Florencia (Principal)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.alternate_email,
                size: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  correo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirFilaMetricas() {
    // Contadores preparados en 0 hasta conectar la estructura de asistencias
    return Row(
      children: [
        _construirTarjetaMetricaIndividual(
          icono: Icons.speed_outlined,
          valor: '0%',
          colorValor: Colors.black87,
          titulo: 'Puntualidad',
          subtitulo: 'Promedio ciclo',
        ),
        const SizedBox(width: 10),
        _construirTarjetaMetricaIndividual(
          icono: Icons.event_available_outlined,
          valor: '0/0',
          colorValor: Colors.black87,
          titulo: 'Clases',
          subtitulo: 'Asistidas',
        ),
        const SizedBox(width: 10),
        _construirTarjetaMetricaIndividual(
          icono: Icons.warning_amber_rounded,
          valor: '0',
          colorValor: _colorEstudiante,
          titulo: 'Faltas',
          subtitulo: 'No justificadas',
        ),
      ],
    );
  }

  Widget _construirTarjetaMetricaIndividual({
    required IconData icono,
    required String valor,
    required Color colorValor,
    required String titulo,
    required String subtitulo,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFFFDECEE),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 16, color: _colorEstudiante),
            ),
            const SizedBox(height: 10),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorValor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitulo,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaDatosInstitucionales({
    required String codigoEstudiantil,
    required String tipoDocumento,
    required String documento,
    required String correo,
    required String programa,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: _colorEstudiante,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Datos Institucionales',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SIA Validado',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _colorEstudiante,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _construirIconoCampo(Icons.badge_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CÓDIGO ESTUDIANTIL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black45,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      codigoEstudiantil,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _copiarCodigo(codigoEstudiantil),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 13, color: Colors.black54),
                      SizedBox(width: 4),
                      Text(
                        'Copiar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _construirFilaDatoInstitucional(
            icono: Icons.fingerprint,
            etiqueta: 'DOCUMENTO DE IDENTIDAD',
            valor: '$tipoDocumento $documento',
          ),
          const SizedBox(height: 14),
          _construirFilaDatoInstitucional(
            icono: Icons.alternate_email,
            etiqueta: 'CORREO ELECTRÓNICO INSTITUCIONAL',
            valor: correo,
          ),
          const SizedBox(height: 14),
          _construirFilaDatoInstitucional(
            icono: Icons.account_balance_outlined,
            etiqueta: 'PROGRAMA ACADÉMICO',
            valor: programa,
            subvalor: 'Facultad de Ingeniería • Sede Florencia',
          ),
        ],
      ),
    );
  }

  Widget _construirIconoCampo(IconData icono) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icono, size: 18, color: Colors.black54),
    );
  }

  Widget _construirFilaDatoInstitucional({
    required IconData icono,
    required String etiqueta,
    required String valor,
    String? subvalor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirIconoCampo(icono),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (subvalor != null) ...[
                const SizedBox(height: 2),
                Text(
                  subvalor,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaDatosContacto({required String telefono}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                Icons.contact_phone_outlined,
                size: 18,
                color: _colorEstudiante,
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
          const SizedBox(height: 14),
          Row(
            children: [
              _construirIconoCampo(Icons.phone_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TELÉFONO MÓVIL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black45,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      telefono,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _mostrarDialogoEditarTelefono(telefono),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDECEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: _colorEstudiante,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaPreferencias({required bool alertasActivas}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              Icon(Icons.tune_rounded, size: 18, color: _colorEstudiante),
              SizedBox(width: 8),
              Text(
                'Preferencias y Asistencia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _construirIconoCampo(Icons.notifications_active_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alertas de Clases y Asistencia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Aviso 10 min antes de que inicie la clase',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: alertasActivas,
                activeTrackColor: _colorEstudiante,
                activeThumbColor: Colors.white,
                onChanged: _actualizarPreferenciaAlertas,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirBotonCerrarSesion() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _confirmarCerrarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorEstudianteOscuro,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Cerrar Sesión Segura',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

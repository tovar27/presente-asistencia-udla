import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'docente/registro_docente.dart';
import 'estudiante/registro_estudiante.dart';
import 'recuperar_clave/recuperar_clave_paso1.dart';
import 'docente/navegacion_docente.dart';
import 'estudiante/navegacion_estudiante.dart';

class PantallaInicioSesion extends StatefulWidget {
  const PantallaInicioSesion({super.key});

  @override
  State<PantallaInicioSesion> createState() => _EstadoPantallaInicioSesion();
}

class _EstadoPantallaInicioSesion extends State<PantallaInicioSesion> {
  // Rol elegido en el selector: 'docente' o 'estudiante'
  String _rolSeleccionado = 'docente';

  // Controladores para leer lo que el usuario escribe
  final TextEditingController _controladorCorreo = TextEditingController();
  final TextEditingController _controladorClave = TextEditingController();

  // Controla si la contraseña se ve u oculta
  bool _ocultarClave = true;

  // Controla la casilla "Recordar sesión"
  bool _recordarSesion = true;
  // Indica si se está validando el inicio de sesión
  bool _cargando = false;

  static const Color _colorDocente = Color(0xFF00382A);
  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorError = Color(0xFFB3261E);

  // Color que cambia según el rol seleccionado
  Color get _colorDelRol =>
      _rolSeleccionado == 'docente' ? _colorDocente : _colorEstudiante;

  // El correo es válido solo si pertenece al dominio institucional
  bool get _correoValido {
    final String correo = _controladorCorreo.text.trim().toLowerCase();
    return RegExp(r'^[a-z0-9._\-+]+@udla\.edu\.co$').hasMatch(correo);
  }

  // El error se muestra solo si ya escribió algo y no es válido
  bool get _mostrarErrorCorreo =>
      _controladorCorreo.text.trim().isNotEmpty && !_correoValido;

  @override
  void dispose() {
    _controladorCorreo.dispose();
    _controladorClave.dispose();
    super.dispose();
  }

  // Paso 1: autenticar con correo y contraseña; devuelve el UID
  Future<String> _autenticar() async {
    final UserCredential credencial = await FirebaseAuth.instance
        .signInWithEmailAndPassword(
          email: _controladorCorreo.text.trim().toLowerCase(),
          password: _controladorClave.text,
        );
    return credencial.user!.uid;
  }

  // Paso 2: leer el documento del usuario (su ID es el UID)
  Future<Map<String, dynamic>?> _leerDatosUsuario(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> documento =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    return documento.data();
  }

  // Paso 3: inicio de sesión completo
  Future<void> _intentarIniciarSesion() async {
    if (!_correoValido || _controladorClave.text.isEmpty) {
      _mostrarMensaje(
        'Ingresa un correo institucional válido y tu contraseña.',
        esError: true,
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      final String uid = await _autenticar();
      final Map<String, dynamic>? datos = await _leerDatosUsuario(uid);
      final String? rolGuardado = datos?['rol'];

      if (rolGuardado != _rolSeleccionado) {
        await FirebaseAuth.instance.signOut();
        _mostrarMensaje(
          'Esta cuenta no tiene el rol de $_rolSeleccionado.',
          esError: true,
        );
        return;
      }

      // VALIDACIÓN CRÍTICA DEL ESTADO DEL CORREO
      User? usuarioActual = FirebaseAuth.instance.currentUser;
      if (usuarioActual != null && !usuarioActual.emailVerified) {
        await FirebaseAuth.instance.signOut();
        _mostrarMensaje(
          'Debes verificar tu correo institucional antes de ingresar.',
          esError: true,
        );
        return;
      }

      // Actualizamos estado si estaba pendiente en la base de datos
      if (datos?['estado'] == 'pendiente') {
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).update(
          {'estado': 'activo'},
        );
      }

      _mostrarMensaje('Bienvenido, ${datos?['nombre'] ?? ''} ($rolGuardado)');

      if (!mounted) return;

      if (rolGuardado == 'docente') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NavegacionDocente()),
        );
      } else if (rolGuardado == 'estudiante') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NavegacionEstudiante()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _mostrarMensaje(_traducirErrorAuth(e.code), esError: true);
    } on FirebaseException {
      _mostrarMensaje('No se pudo leer el rol del usuario.', esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Aviso inferior: del color del rol, o rojo si es un error
  void _mostrarMensaje(String texto, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: esError ? _colorError : _colorDelRol,
        ),
      );
  }

  // Traduce los códigos de error de Firebase Authentication
  String _traducirErrorAuth(String codigo) {
    switch (codigo) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta de nuevo en unos minutos.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red.';
      default:
        return 'No se pudo iniciar sesión. Intenta de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                _construirLogo(),
                const SizedBox(height: 16),
                const Text(
                  'Presente',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CONTROL DE ASISTENCIAS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: _colorDelRol,
                  ),
                ),
                const SizedBox(height: 32),
                _construirTarjeta(),
                const SizedBox(height: 24),
                const Text(
                  'Sistema de Control de Asistencia • v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Logo de la aplicación con un indicador que cambia de color según el rol
  Widget _construirLogo() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF0FB),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Image.asset(
            'recursos/imagenes/logo_presente.png',
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          right: -6,
          bottom: -6,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _colorDelRol,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF9F9FF), width: 3),
            ),
          ),
        ),
      ],
    );
  }

  // Tarjeta blanca que contiene el formulario de acceso
  Widget _construirTarjeta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, size: 20, color: Colors.black54),
              SizedBox(width: 8),
              Text(
                'Selecciona tu rol de acceso',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _construirSelectorRol(),
          const SizedBox(height: 20),
          _construirCampoCorreo(),
          const SizedBox(height: 20),
          _construirCampoClave(),
          const SizedBox(height: 16),
          _construirFilaRecordar(),
          const SizedBox(height: 20),
          _construirBotonIngreso(),
          const SizedBox(height: 20),
          _construirEnlacesAyuda(),
        ],
      ),
    );
  }

  // Selector con las dos opciones de rol
  Widget _construirSelectorRol() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF0FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _construirOpcionRol(
            rol: 'docente',
            texto: 'Soy Docente',
            icono: Icons.school_outlined,
          ),
          _construirOpcionRol(
            rol: 'estudiante',
            texto: 'Soy Estudiante',
            icono: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  // Cada opción del selector; la seleccionada se pinta con el color del rol
  Widget _construirOpcionRol({
    required String rol,
    required String texto,
    required IconData icono,
  }) {
    final bool seleccionado = _rolSeleccionado == rol;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rolSeleccionado = rol),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: seleccionado ? _colorDelRol : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icono,
                size: 16,
                color: seleccionado ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: seleccionado ? Colors.white : Colors.black87,
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

  // Campo del correo institucional con validación del dominio
  Widget _construirCampoCorreo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Correo institucional',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              'Dominio requerido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controladorCorreo,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: _decoracionCampo(
            sugerencia: 'usuario@udla.edu.co',
            iconoInicial: Icons.mail_outline,
            sufijo: _correoValido
                ? Icon(Icons.check_circle_outline, color: _colorDelRol)
                : null,
            hayError: _mostrarErrorCorreo,
          ),
        ),
        if (_mostrarErrorCorreo)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: _colorError),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'El correo debe pertenecer al dominio institucional '
                    '@udla.edu.co',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _colorError,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Campo de la contraseña con el ícono del ojo
  Widget _construirCampoClave() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contraseña',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controladorClave,
          obscureText: _ocultarClave,
          decoration: _decoracionCampo(
            sugerencia: '••••••••',
            iconoInicial: Icons.lock_outline,
            sufijo: IconButton(
              icon: Icon(
                _ocultarClave
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.black54,
              ),
              onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
            ),
          ),
        ),
      ],
    );
  }

  // Estilo común de los campos de texto
  InputDecoration _decoracionCampo({
    required String sugerencia,
    required IconData iconoInicial,
    Widget? sufijo,
    bool hayError = false,
  }) {
    OutlineInputBorder borde(Color color, double grosor) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: grosor),
      );
    }

    return InputDecoration(
      hintText: sugerencia,
      hintStyle: const TextStyle(color: Colors.black38),
      prefixIcon: Icon(iconoInicial, color: Colors.black54),
      suffixIcon: sufijo,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: borde(
        hayError ? _colorError : const Color(0xFFE5E7EB),
        1.5,
      ),
      focusedBorder: borde(hayError ? _colorError : _colorDelRol, 2),
    );
  }

  // Casilla "Recordar sesión" y enlace de contraseña olvidada
  Widget _construirFilaRecordar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _recordarSesion,
                activeColor: _colorDelRol,
                onChanged: (valor) =>
                    setState(() => _recordarSesion = valor ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Recordar sesión',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: TextButton(
            onPressed: _cargando ? null : () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Asegúrate de que tu variable de rol se llame así, o cámbiala por la que usas
                    builder: (context) =>
                        RecuperarClavePaso1(rol: _rolSeleccionado),
                  ),
                );
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _colorDelRol,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Botón principal; su color y texto dependen del rol seleccionado
  Widget _construirBotonIngreso() {
    final String nombreRol = _rolSeleccionado == 'docente'
        ? 'Docente'
        : 'Estudiante';
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _cargando ? null : _intentarIniciarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorDelRol,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Iniciar Sesión como $nombreRol',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  // Enlaces de recuperación de cuenta y de registro
  Widget _construirEnlacesAyuda() {
    return Column(
      children: [
        _construirLineaEnlace(
          '¿Problemas de ingreso? ',
          'Recuperar cuenta',
          () {
            // Temporalmente no hace nada
          },
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFFE5E7EB)),
        const SizedBox(height: 16),
        _construirLineaEnlace('¿No tienes cuenta? ', 'Regístrate aquí', () {
          if (_rolSeleccionado == 'docente') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegistroDocente()),
            );
          } else {
            // AHORA SÍ CONECTAMOS AL ESTUDIANTE
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistroEstudiante(),
              ),
            );
          }
        }),
      ],
    );
  }

  // Línea de texto con una parte resaltada del color del rol (AHORA ES CLICKEABLE)
  Widget _construirLineaEnlace(
    String textoNormal,
    String textoEnlace,
    VoidCallback alPresionar,
  ) {
    return Center(
      child: InkWell(
        // InkWell da un efecto visual de "toque" (splash) y agranda el área táctil
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 16.0,
          ), // Área de toque más grande
          child: Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              style: const TextStyle(color: Colors.black54, fontSize: 13),
              children: [
                TextSpan(text: textoNormal),
                TextSpan(
                  text: textoEnlace,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _colorDelRol,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

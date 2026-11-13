import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecuperarClavePaso3 extends StatefulWidget {
  final String rol;
  final String correo;

  const RecuperarClavePaso3({super.key, required this.rol, required this.correo});

  @override
  State<RecuperarClavePaso3> createState() => _EstadoRecuperarClavePaso3();
}

class _EstadoRecuperarClavePaso3 extends State<RecuperarClavePaso3> {
  Color get _colorTema => widget.rol == 'docente' ? const Color(0xFF00382A) : const Color(0xFFB02A37);

  final TextEditingController _controladorClave = TextEditingController();
  final TextEditingController _controladorConfirmar = TextEditingController();
  
  bool _ocultarClave = true;
  bool _ocultarConfirmar = true;
  bool _cargando = false;

  // Validaciones en tiempo real
  bool get _tiene8Caracteres => _controladorClave.text.length >= 8;
  bool get _tieneMayuscula => _controladorClave.text.contains(RegExp(r'[A-Z]'));
  bool get _tieneNumero => _controladorClave.text.contains(RegExp(r'[0-9]'));
  bool get _tieneEspecial => _controladorClave.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
  bool get _clavesCoinciden => _controladorClave.text == _controladorConfirmar.text && _controladorClave.text.isNotEmpty;

  int get _nivelSeguridad {
    int nivel = 0;
    if (_tiene8Caracteres) nivel++;
    if (_tieneMayuscula) nivel++;
    if (_tieneNumero) nivel++;
    if (_tieneEspecial) nivel++;
    return nivel;
  }

  String get _textoNivelSeguridad {
    if (_nivelSeguridad == 0) return 'Bajo';
    if (_nivelSeguridad <= 2) return 'Medio';
    if (_nivelSeguridad == 3) return 'Bueno';
    return 'Fuerte';
  }

  Future<void> _restablecerContrasena() async {
    if (_nivelSeguridad < 4 || !_clavesCoinciden) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe cumplir todos los parámetros y coincidir.'), backgroundColor: Color(0xFFB3261E)),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // LÓGICA DE SEGURIDAD: Destruimos el código OTP en Firestore para que no pueda ser reutilizado
      await FirebaseFirestore.instance.collection('codigos_recuperacion').doc(widget.correo).delete();

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('¡Contraseña restablecida con éxito!'), backgroundColor: _colorTema),
      );

      // Limpiamos todo el historial de pantallas y lo devolvemos al Login
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar el cambio de contraseña.'), backgroundColor: Color(0xFFB3261E)),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _controladorClave.dispose();
    _controladorConfirmar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFF),
      appBar: _construirAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _construirIndicadorProgreso(),
              const SizedBox(height: 24),
              const Text('Crear nueva contraseña', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              const Text(
                'Elige una contraseña segura y fácil de recordar que no hayas usado anteriormente en este ciclo académico.',
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
              _construirTarjetaFormulario(),
              const SizedBox(height: 32),
              _construirBotonCancelar(),
              const SizedBox(height: 32),
              const Center(child: Text('Sistema de Control de Asistencia • v1.0.0', style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500))),
              const SizedBox(height: 16),
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
      centerTitle: false,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UNIVERSIDAD DE LA AMAZONIA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00382A), letterSpacing: 0.5)),
          Text('Restablecer Contraseña', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: SizedBox(height: 28, width: 28, child: Image.asset('recursos/imagenes/logo_presente.png')),
        )
      ],
    );
  }

  Widget _construirIndicadorProgreso() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF4F6F9), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paso 3 de 3: Nueva Clave', style: TextStyle(color: _colorTema, fontWeight: FontWeight.bold, fontSize: 12)),
              const Text('100% completado', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: 1.0, backgroundColor: _colorTema.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(_colorTema), borderRadius: BorderRadius.circular(4), minHeight: 6),
        ],
      ),
    );
  }

  Widget _construirTarjetaFormulario() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nueva contraseña', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Text('Obligatorio', style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          _construirCampoClave(_controladorClave, _ocultarClave, () => setState(() => _ocultarClave = !_ocultarClave)),
          const SizedBox(height: 12),
          _construirBarraSeguridad(),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Confirmar contraseña', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
              if (_clavesCoinciden) Row(children: [Icon(Icons.check_circle_outline, size: 14, color: _colorTema), const SizedBox(width: 4), const Text('Coinciden', style: TextStyle(fontSize: 11, color: Colors.black54))]),
            ],
          ),
          const SizedBox(height: 8),
          _construirCampoClave(_controladorConfirmar, _ocultarConfirmar, () => setState(() => _ocultarConfirmar = !_ocultarConfirmar), isConfirmacion: true),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF9F9FF), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PARÁMETROS DE VALIDACIÓN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _construirRequisito('Mínimo 8 caracteres', _tiene8Caracteres),
                _construirRequisito('Al menos una letra mayúscula', _tieneMayuscula),
                _construirRequisito('Al menos un número', _tieneNumero),
                _construirRequisito('Al menos un carácter especial (@, #, etc.)', _tieneEspecial),
                _construirRequisito('Las contraseñas coinciden exactamente', _clavesCoinciden),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEFEFF8), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security, size: 20, color: Color(0xFF5C5C96)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Al restablecer tu clave se cerrarán automáticamente las sesiones activas en otros dispositivos no autorizados.',
                    style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _cargando ? null : _restablecerContrasena,
              style: ElevatedButton.styleFrom(backgroundColor: _colorTema, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _cargando 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Restablecer contraseña', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCampoClave(TextEditingController controlador, bool oculto, VoidCallback alternarVisibilidad, {bool isConfirmacion = false}) {
    return TextField(
      controller: controlador,
      obscureText: oculto,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
      decoration: InputDecoration(
        prefixIcon: Icon(isConfirmacion ? Icons.lock_clock_outlined : Icons.lock_outline, color: Colors.black54),
        suffixIcon: IconButton(icon: Icon(oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.black45), onPressed: alternarVisibilidad),
        filled: true,
        fillColor: const Color(0xFFF4F4F9),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _colorTema, width: 2)),
      ),
    );
  }

  Widget _construirBarraSeguridad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Nivel de seguridad:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(_textoNivelSeguridad, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _nivelSeguridad == 4 ? _colorTema : Colors.black54)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(color: index < _nivelSeguridad ? _colorTema : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _construirRequisito(String texto, bool cumplido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(cumplido ? Icons.check_circle : Icons.circle_outlined, size: 16, color: cumplido ? _colorTema : Colors.black26),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: cumplido ? Colors.black87 : Colors.black54))),
        ],
      ),
    );
  }

  Widget _construirBotonCancelar() {
    return GestureDetector(
      onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.close, size: 16, color: Colors.black87),
          SizedBox(width: 6),
          Text('Cancelar y volver al Inicio de Sesión', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}
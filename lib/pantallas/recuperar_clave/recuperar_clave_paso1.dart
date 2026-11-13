import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recuperar_clave_paso2.dart';

class RecuperarClavePaso1 extends StatefulWidget {
  final String rol;

  const RecuperarClavePaso1({super.key, required this.rol});

  @override
  State<RecuperarClavePaso1> createState() => _EstadoRecuperarClavePaso1();
}

class _EstadoRecuperarClavePaso1 extends State<RecuperarClavePaso1> {
  final TextEditingController _controladorCorreo = TextEditingController();
  final FocusNode _focoCorreo = FocusNode();
  String? _errorCorreo;
  bool _cargando = false;

  Color get _colorTema => widget.rol == 'docente' ? const Color(0xFF00382A) : const Color(0xFFB02A37);
  Color get _colorFondoSecundario => const Color(0xFFF4F6F9);

  bool get _correoValido {
    return RegExp(r'^[a-z0-9._\-+]+@udla\.edu\.co$').hasMatch(_controladorCorreo.text.trim().toLowerCase());
  }

  Future<void> _enviarCodigo() async {
    final correoIngresado = _controladorCorreo.text.trim().toLowerCase();

    setState(() {
      _errorCorreo = correoIngresado.isEmpty 
          ? 'Requerido' 
          : (!_correoValido ? 'Debe ser un correo válido @udla.edu.co' : null);
    });

    if (_errorCorreo != null) {
      _focoCorreo.requestFocus();
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. BUSCAR EL CORREO EN FIRESTORE (Sin importar el rol todavía)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('correo', isEqualTo: correoIngresado)
          .limit(1)
          .get();

      if (!mounted) return;

      // Si el correo NO existe en la base de datos
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorCorreo = 'Esta cuenta no existe en el sistema.';
          _cargando = false;
        });
        _focoCorreo.requestFocus();
        return;
      }

      // 2. VERIFICAR QUE EL ROL COINCIDA
      final datosUsuario = querySnapshot.docs.first.data();
      final rolEnBaseDatos = datosUsuario['rol'] ?? '';

      if (rolEnBaseDatos != widget.rol) {
        setState(() {
          _errorCorreo = rolEnBaseDatos == 'estudiante'
              ? 'Este correo pertenece a un estudiante. Regresa al inicio.'
              : 'Este correo pertenece a un docente. Regresa al inicio.';
          _cargando = false;
        });
        _focoCorreo.requestFocus();
        return;
      }

      // 3. GENERAR UN CÓDIGO ALEATORIO DE 6 DÍGITOS
      String codigoGenerado = (Random().nextInt(900000) + 100000).toString();

      // 4. GUARDAR EL CÓDIGO EN FIRESTORE
      await FirebaseFirestore.instance.collection('codigos_recuperacion').doc(correoIngresado).set({
        'codigo': codigoGenerado,
        'creadoEn': FieldValue.serverTimestamp(),
        // El código vencerá en 5 minutos
        'expiraEn': DateTime.now().add(const Duration(minutes: 5)), 
      });

      debugPrint("=========================================");
      debugPrint("CÓDIGO SECRETO PARA EL CORREO $correoIngresado: $codigoGenerado");
      debugPrint("=========================================");

      if (!mounted) return;
      setState(() => _cargando = false);

      // 5. SALTO AL PASO 2
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecuperarClavePaso2(
            rol: widget.rol,
            correo: correoIngresado,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al conectar con la base de datos.'), backgroundColor: Color(0xFFB3261E)),
      );
    }
  }

  @override
  void dispose() {
    _controladorCorreo.dispose();
    _focoCorreo.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _construirIndicadorProgreso(),
              const SizedBox(height: 24),
              _construirTarjetaEncabezado(),
              const SizedBox(height: 16),
              _construirTarjetaFormulario(),
              const SizedBox(height: 32),
              _construirEnlacesInferiores(),
              const SizedBox(height: 32),
              const Text(
                'Sistema de Control de Asistencia • v1.0.0',
                style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
              ),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UNIVERSIDAD DE LA AMAZONIA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00382A), letterSpacing: 0.5)),
          Text('Solicitar Recuperación', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Paso 1 de 3: Identificación', style: TextStyle(color: _colorTema, fontWeight: FontWeight.bold, fontSize: 12)),
            const Text('33% completado', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: 0.33,
          backgroundColor: _colorTema.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(_colorTema),
          borderRadius: BorderRadius.circular(4),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _construirTarjetaEncabezado() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _colorFondoSecundario, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _colorTema, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.restore, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(height: 6),
                Text(
                  'Ingresa tu correo institucional asignado para recibir un código de verificación y restablecer tu acceso a Presente.',
                  style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaFormulario() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Correo institucional', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEFEFF5), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: Color(0xFF5C5C96)),
                    SizedBox(width: 4),
                    Text('Dominio requerido', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5C5C96))),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          
          TextField(
            controller: _controladorCorreo,
            focusNode: _focoCorreo,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _errorCorreo = null),
            decoration: InputDecoration(
              hintText: 'ejemplo@udla.edu.co',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
              prefixIcon: const Icon(Icons.mail_outline, color: Colors.black54),
              suffixIcon: _correoValido && _errorCorreo == null ? Icon(Icons.check_circle, color: _colorTema) : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _correoValido && _errorCorreo == null ? _colorTema : Colors.black12, width: _correoValido && _errorCorreo == null ? 1.5 : 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _colorTema, width: 2)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB3261E), width: 2)),
              errorText: _errorCorreo,
            ),
          ),
          
          const SizedBox(height: 8),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.black54),
              SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
                    children: [
                      TextSpan(text: 'El correo debe pertenecer al dominio institucional '),
                      TextSpan(text: '@udla.edu.co.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF4F4FA), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF5C5C96)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Válido para estudiantes matriculados, docentes y personal administrativo de la Universidad de la Amazonia.',
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
              onPressed: _cargando ? null : _enviarCodigo,
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorTema, 
                foregroundColor: Colors.white, 
                elevation: 0, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: _cargando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Enviar código de recuperación', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEnlacesInferiores() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                '¿Recordaste tu\nclave?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.3),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Regresar al Inicio de\nSesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _colorTema, height: 1.3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Segunda sección: Una sola línea protegida con FittedBox para que no se desborde
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿Problemas de ingreso? ', style: TextStyle(fontSize: 13, color: Colors.black54)),
              GestureDetector(
                onTap: () {
                  // Modal de soporte (futuro)
                },
                child: Text(
                  'Recuperar cuenta',
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold, 
                    color: _colorTema, 
                    decoration: TextDecoration.underline, 
                    decorationColor: _colorTema
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
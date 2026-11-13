import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recuperar_clave_paso3.dart';

class RecuperarClavePaso2 extends StatefulWidget {
  final String rol;
  final String correo;

  const RecuperarClavePaso2({super.key, required this.rol, required this.correo});

  @override
  State<RecuperarClavePaso2> createState() => _EstadoRecuperarClavePaso2();
}

class _EstadoRecuperarClavePaso2 extends State<RecuperarClavePaso2> {
  final List<TextEditingController> _controladoresOTP = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focosOTP = List.generate(6, (_) => FocusNode());
  bool _cargando = false;
  bool _reenviando = false;

  // Temporizadores
  Timer? _timerExpiracion;
  Timer? _timerReenvio;
  int _segundosRestantesExpiracion = 300; // 5 minutos
  int _segundosRestantesReenvio = 45; // 45 segundos para reenviar

  Color get _colorTema => widget.rol == 'docente' ? const Color(0xFF00382A) : const Color(0xFFB02A37);

  @override
  void initState() {
    super.initState();
    _iniciarTemporizadores();
  }

  void _iniciarTemporizadores() {
    _timerExpiracion?.cancel();
    _timerReenvio?.cancel();
    
    _segundosRestantesExpiracion = 300;
    _segundosRestantesReenvio = 45;

    _timerExpiracion = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_segundosRestantesExpiracion > 0) {
            _segundosRestantesExpiracion--;
          } else {
            _timerExpiracion?.cancel();
          }
        });
      }
    });

    _timerReenvio = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_segundosRestantesReenvio > 0) {
            _segundosRestantesReenvio--;
          } else {
            _timerReenvio?.cancel();
          }
        });
      }
    });
  }

  String _formatearTiempo(int segundos) {
    int minutos = segundos ~/ 60;
    int seg = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}';
  }

  // --- 1. LÓGICA REAL: VERIFICAR EL CÓDIGO EN FIRESTORE ---
  Future<void> _verificarCodigo() async {
    String codigoIngresado = _controladoresOTP.map((c) => c.text).join();
    
    if (codigoIngresado.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa los 6 dígitos del código.'), backgroundColor: Color(0xFFB3261E))
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('codigos_recuperacion')
          .doc(widget.correo)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay un código activo para este correo.'), backgroundColor: Color(0xFFB3261E))
        );
        return;
      }

      String codigoGuardado = doc.get('codigo');
      Timestamp expiraEn = doc.get('expiraEn');

      if (DateTime.now().isAfter(expiraEn.toDate())) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El código ha expirado. Por favor solicita uno nuevo.'), backgroundColor: Color(0xFFB3261E))
        );
        return;
      }

      if (codigoIngresado != codigoGuardado) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código incorrecto. Intenta de nuevo.'), backgroundColor: Color(0xFFB3261E))
        );
        
        for (var controller in _controladoresOTP) {
          controller.clear();
        }
        _focosOTP[0].requestFocus();
        return;
      }

      setState(() => _cargando = false);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RecuperarClavePaso3(
            rol: widget.rol,
            correo: widget.correo,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al verificar el código.'), backgroundColor: Color(0xFFB3261E))
      );
    }
  }

  // --- 2. LÓGICA PARA REENVIAR UN NUEVO CÓDIGO ---
  Future<void> _reenviarCodigo() async {
    setState(() => _reenviando = true);

    try {
      String nuevoCodigo = (Random().nextInt(900000) + 100000).toString();

      await FirebaseFirestore.instance.collection('codigos_recuperacion').doc(widget.correo).set({
        'codigo': nuevoCodigo,
        'creadoEn': FieldValue.serverTimestamp(),
        'expiraEn': DateTime.now().add(const Duration(minutes: 5)),
      });

      debugPrint("====== NUEVO CÓDIGO GENERADO: $nuevoCodigo ======");

      _iniciarTemporizadores();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Se ha generado un nuevo código (Revisa consola).'), backgroundColor: _colorTema)
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reenviar el código.'), backgroundColor: Color(0xFFB3261E))
      );
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  void _manejarCambioTexto(String valor, int index) {
    if (valor.isNotEmpty && index < 5) {
      _focosOTP[index + 1].requestFocus();
    } else if (valor.isEmpty && index > 0) {
      _focosOTP[index - 1].requestFocus();
    }
    
    // Eliminamos la auto-verificación de aquí.
    // Ahora el usuario está obligado a presionar el botón verde/rojo para continuar.
    setState(() {}); // Actualizamos la vista para ocultar el puntito
  }

  @override
  void dispose() {
    _timerExpiracion?.cancel();
    _timerReenvio?.cancel();
    for (var controlador in _controladoresOTP) {
      controlador.dispose();
    }
    for (var foco in _focosOTP) {
      foco.dispose();
    }
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
              const SizedBox(height: 32),
              _construirEncabezado(),
              const SizedBox(height: 32),
              _construirTarjetaOTP(),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: _colorTema),
                    const SizedBox(width: 6),
                    Text('Corregir correo institucional', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _colorTema)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Column(
                children: [
                   Icon(Icons.business, color: Colors.black45, size: 20),
                   SizedBox(height: 4),
                   Text('Sistema de Control de Asistencia • v1.0.0', style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500)),
                ],
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
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UNIVERSIDAD DE LA AMAZONIA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00382A), letterSpacing: 0.5)),
          Text('Verificar Código', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text('Paso 2 de 3: Verificación', style: TextStyle(color: _colorTema, fontWeight: FontWeight.bold, fontSize: 12)),
            const Text('66%', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: 0.66, backgroundColor: _colorTema.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(_colorTema), borderRadius: BorderRadius.circular(4), minHeight: 4),
      ],
    );
  }

  Widget _construirEncabezado() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFF4F6F9), shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF00382A), size: 40),
            ),
            Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.security, color: Color(0xFF00382A), size: 20),
            )
          ],
        ),
        const SizedBox(height: 24),
        const Text('Verificar código OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            children: [
              const TextSpan(text: 'Hemos enviado un código numérico de 6 dígitos a tu correo institucional\n'),
              TextSpan(text: widget.correo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const TextSpan(text: '. Ingrésalo a continuación para confirmar tu identidad.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _construirTarjetaOTP() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('CÓDIGO DE SEGURIDAD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) => _construirCasillaOTP(index)),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFF8),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF5C5C96)),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5C5C96)),
                    children: [
                      const TextSpan(text: 'El código expira en '),
                      TextSpan(text: '${_formatearTiempo(_segundosRestantesExpiracion)} min', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]
                  )
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Icon(Icons.sync, size: 16, color: Colors.black45),
               const SizedBox(width: 8),
               Expanded(
                 child: _segundosRestantesReenvio > 0 
                  ? Text('¿No recibiste el código? Reenviar código\n(disponible en ${_segundosRestantesReenvio}s)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))
                  : GestureDetector(
                      onTap: _reenviando ? null : _reenviarCodigo,
                      child: Text('¿No recibiste el código? Reenviar código', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _colorTema, decoration: TextDecoration.underline, height: 1.4)),
                    ),
               )
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _cargando ? null : _verificarCodigo,
              style: ElevatedButton.styleFrom(backgroundColor: _colorTema, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _cargando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Verificar código y continuar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _construirCasillaOTP(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: Focus(
        onFocusChange: (hasFocus) => setState(() {}),
        child: TextField(
          controller: _controladoresOTP[index],
          focusNode: _focosOTP[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _colorTema),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '•', // El puntito nativo cuando está vacío
            hintStyle: const TextStyle(fontSize: 24, color: Colors.black26),
            filled: true,
            fillColor: _focosOTP[index].hasFocus ? Colors.white : const Color(0xFFF4F4F9),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), 
              borderSide: BorderSide.none
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), 
              borderSide: BorderSide(color: _colorTema, width: 2)
            ),
          ),
          onChanged: (valor) => _manejarCambioTexto(valor, index),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'navegacion_estudiante.dart';

class RegistroEstudiantePaso2 extends StatefulWidget {
  final String correo;

  const RegistroEstudiantePaso2({super.key, required this.correo});

  @override
  State<RegistroEstudiantePaso2> createState() =>
      _EstadoRegistroEstudiantePaso2();
}

class _EstadoRegistroEstudiantePaso2 extends State<RegistroEstudiantePaso2> {
  static const Color _colorEstudiante = Color(0xFFB02A37);

  Timer? _temporizador;
  bool _correoVerificado = false;
  bool _estaVerificando = false;
  int _segundosRestantesReenvio = 60;
  bool _puedeReenviar = false;

  @override
  void initState() {
    super.initState();
    _iniciarTemporizadorReenvio();

    // Revisa en segundo plano si el estudiante ya hizo clic en el enlace
    _temporizador = Timer.periodic(const Duration(seconds: 3), (timer) {
      _comprobarVerificacionCorreo();
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _iniciarTemporizadorReenvio() {
    setState(() {
      _segundosRestantesReenvio = 60;
      _puedeReenviar = false;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantesReenvio > 0) {
        setState(() => _segundosRestantesReenvio--);
      } else {
        setState(() => _puedeReenviar = true);
        timer.cancel();
      }
    });
  }

  Future<void> _comprobarVerificacionCorreo() async {
    User? usuarioActual = FirebaseAuth.instance.currentUser;
    if (usuarioActual != null) {
      await usuarioActual.reload();
      usuarioActual = FirebaseAuth.instance.currentUser;

      if (usuarioActual != null && usuarioActual.emailVerified) {
        _temporizador?.cancel();

        if (!mounted) return;

        setState(() {
          _correoVerificado = true;
          _estaVerificando = true;
        });

        // Activa al usuario en la base de datos
        try {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(usuarioActual.uid)
              .update({'estado': 'activo'});
        } catch (e) {
          debugPrint('Error actualizando estado: $e');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Correo verificado con éxito!'),
            backgroundColor: _colorEstudiante,
          ),
        );

        // Envía al estudiante al Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavegacionEstudiante()),
          (ruta) => false,
        );
      }
    }
  }

  Future<void> _reenviarEnlace() async {
    if (_puedeReenviar) {
      User? usuarioActual = FirebaseAuth.instance.currentUser;
      if (usuarioActual != null) {
        try {
          await usuarioActual.sendEmailVerification();
          _iniciarTemporizadorReenvio();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nuevo enlace enviado al correo.'),
                backgroundColor: _colorEstudiante,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Intenta más tarde.'),
                backgroundColor: Color(0xFFB3261E),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _verificacionManual() async {
    setState(() => _estaVerificando = true);
    await _comprobarVerificacionCorreo();

    if (!mounted) return;

    if (!_correoVerificado) {
      setState(() => _estaVerificando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El correo aún no ha sido verificado.'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            FirebaseAuth.instance.signOut();
            Navigator.pop(context);
          },
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: _colorEstudiante),
              SizedBox(width: 6),
              Text(
                'Paso 2 de 2',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.school, color: _colorEstudiante, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'UDLA • ESTUDIANTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _colorEstudiante,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Verifica tu correo',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Último paso para completar tu registro',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _colorEstudiante,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _colorEstudiante,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDECEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 40,
                        color: _colorEstudiante,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Revisa tu bandeja de entrada',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hemos enviado un enlace de confirmación a tu correo institucional:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.correo,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _colorEstudiante,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Abre el correo, haz clic en el enlace y luego regresa a esta pantalla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _colorEstudiante,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reenviar enlace en 00:${_segundosRestantesReenvio.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _reenviarEnlace,
                      child: Text(
                        '¿No lo recibiste? Solicitar nuevo enlace',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _puedeReenviar
                              ? _colorEstudiante
                              : Colors.black26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _estaVerificando ? null : _verificacionManual,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorEstudiante,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _estaVerificando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Ya hice clic en el enlace',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: TextButton(
                      onPressed: _estaVerificando
                          ? null
                          : () {
                              FirebaseAuth.instance.signOut();
                              Navigator.pop(context);
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF4F6F9),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Escribí mal mi correo, corregir',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

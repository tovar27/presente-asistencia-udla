import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'asistencia_estudiante.dart';

class EscanerQrEstudiante extends StatefulWidget {
  final String cursoId;
  final String sesionId;
  final Map<String, dynamic> datosCurso;
  final Map<String, dynamic> datosSesion;

  const EscanerQrEstudiante({
    super.key,
    required this.cursoId,
    required this.sesionId,
    required this.datosCurso,
    required this.datosSesion,
  });

  @override
  State<EscanerQrEstudiante> createState() => _EstadoEscanerQrEstudiante();
}

class _EstadoEscanerQrEstudiante extends State<EscanerQrEstudiante> {
  static const Color _colorEstudiante = Color(0xFFB02A37);
  static const Color _colorVerdeOscuro = Color(0xFF0F5132);

  final MobileScannerController _camaraController = MobileScannerController();
  bool _procesando = false;
  bool _linternaEncendida = false;

  @override
  void dispose() {
    _camaraController.dispose();
    super.dispose();
  }

  String _formatearHora12h(DateTime fecha) {
    final int hora24 = fecha.hour;
    final String periodo = hora24 >= 12 ? 'PM' : 'AM';
    int hora12 = hora24 % 12;
    if (hora12 == 0) hora12 = 12;
    return '${hora12.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} $periodo';
  }

  void _irARespaldoManual() {
    _camaraController.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AsistenciaEstudiante()),
    );
  }

  Future<void> _alDetectarQR(BarcodeCapture captura) async {
    if (_procesando) return;

    final String? valorLeido = captura.barcodes.firstOrNull?.rawValue?.trim();
    if (valorLeido == null || valorLeido.isEmpty) return;

    setState(() => _procesando = true);
    await _camaraController.stop();

    final String codigoSesion = (widget.datosSesion['codigoQR'] ?? '')
        .toString()
        .trim();

    // Validar si el QR corresponde a la sesión abierta
    if (codigoSesion.isNotEmpty && valorLeido != codigoSesion) {
      if (!mounted) return;
      _mostrarDialogoErrorQR();
      return;
    }

    // Calcular puntualidad según tolerancia de la sesión
    final DateTime ahora = DateTime.now();
    bool fueTardanza = false;
    final int toleranciaMin = (widget.datosSesion['tolerancia'] is num)
        ? (widget.datosSesion['tolerancia'] as num).toInt()
        : 15;

    if (widget.datosSesion['horaInicioRegistro'] is Timestamp) {
      final DateTime inicio =
          (widget.datosSesion['horaInicioRegistro'] as Timestamp).toDate();
      final DateTime limite = inicio.add(Duration(minutes: toleranciaMin));
      fueTardanza = ahora.isAfter(limite);
    }

    // NOTA: Aquí conectaremos la escritura en Firestore cuando definamos el esquema de asistencias

    if (!mounted) return;
    _mostrarConfirmacionExito(
      horaMarcacion: _formatearHora12h(ahora),
      fueTardanza: fueTardanza,
      toleranciaMin: toleranciaMin,
    );
  }

  void _mostrarDialogoErrorQR() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: _colorEstudiante),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Código QR no válido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'El código escaneado no coincide con la sesión activa. Puedes volver a intentar o ingresar el token numérico de 6 dígitos.',
          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _procesando = false);
              _camaraController.start();
            },
            child: const Text(
              'Reintentar QR',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _irARespaldoManual();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _colorEstudiante,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ingresar Código',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarConfirmacionExito({
    required String horaMarcacion,
    required bool fueTardanza,
    required int toleranciaMin,
  }) {
    final String nombreAsignatura =
        (widget.datosCurso['nombreAsignatura'] ?? 'Asignatura').toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fueTardanza
                    ? const Color(0xFFFDECEE)
                    : const Color(0xFFD1E7DD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: fueTardanza ? _colorEstudiante : _colorVerdeOscuro,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fueTardanza
                  ? '¡Asistencia registrada con tardanza!'
                  : '¡Asistencia registrada a tiempo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: fueTardanza ? _colorEstudiante : _colorVerdeOscuro,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nombreAsignatura,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fueTardanza
                  ? '$horaMarcacion • Fuera de los $toleranciaMin min de tolerancia'
                  : '$horaMarcacion • Dentro de la tolerancia de $toleranciaMin min',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: fueTardanza
                      ? _colorEstudiante
                      : _colorVerdeOscuro,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Listo, volver a Inicio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nombreAsignatura =
        (widget.datosCurso['nombreAsignatura'] ?? 'Clase en curso').toString();
    final String salon = (widget.datosCurso['salon'] ?? 'Salón asignado')
        .toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreAsignatura,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$salon • Escaneo QR',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _linternaEncendida ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              _camaraController.toggleTorch();
              setState(() => _linternaEncendida = !_linternaEncendida);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Vista de cámara en tiempo real
          MobileScanner(controller: _camaraController, onDetect: _alDetectarQR),

          // Marco visual central para apuntar al QR
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: _colorEstudiante, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // Instrucción superior
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Apunta la cámara al código QR proyectado por el docente en el aula',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ),

          // Tarjeta inferior de respaldo manual si falla el QR
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.qr_code_2_outlined,
                          color: _colorEstudiante,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¿No funciona la cámara o el código QR?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _irARespaldoManual,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorEstudiante,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(
                          Icons.pin_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Ingresar Token de 6 Dígitos',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecuperarCuentaScreen extends StatefulWidget {
  final String rol;

  const RecuperarCuentaScreen({super.key, this.rol = 'Estudiante'});

  @override
  State<RecuperarCuentaScreen> createState() => _EstadoRecuperarCuentaScreen();
}

class _EstadoRecuperarCuentaScreen extends State<RecuperarCuentaScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _codigoCtrl = TextEditingController();
  final TextEditingController _correoInstitucionalCtrl =
      TextEditingController();
  final TextEditingController _correoAlternoCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();

  int _indiceProblemaSeleccionado = 0;
  int _longitudDescripcion = 0;
  bool _enviando = false;

  static const List<Map<String, Object>> _tiposProblema = [
    {
      'titulo': 'No recibo el código OTP',
      'icono': Icons.mark_chat_unread_outlined,
    },
    {
      'titulo': 'Mi cuenta está inactiva o bloqueada',
      'icono': Icons.lock_person_outlined,
    },
    {
      'titulo': 'No tengo acceso a mi correo UDLA',
      'icono': Icons.unsubscribe_outlined,
    },
    {
      'titulo': 'Otro inconveniente técnico',
      'icono': Icons.help_outline_rounded,
    },
  ];

  bool get _esDocente => widget.rol.trim().toLowerCase() == 'docente';

  Color get _colorPrimario =>
      _esDocente ? const Color(0xFF00382A) : const Color(0xFFB02A37);

  Color get _colorSuave =>
      _esDocente ? const Color(0xFFE8F5EE) : const Color(0xFFFDECEE);

  @override
  void initState() {
    super.initState();
    _descripcionCtrl.addListener(() {
      if (mounted) {
        setState(() {
          _longitudDescripcion = _descripcionCtrl.text.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _correoInstitucionalCtrl.dispose();
    _correoAlternoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _enviando = true);

    final String problemaSeleccionado =
        _tiposProblema[_indiceProblemaSeleccionado]['titulo'] as String;

    String radicado =
        'TIC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    try {
      final DocumentReference docRef = await FirebaseFirestore.instance
          .collection('soporte_cuentas')
          .add({
            'rol': _esDocente ? 'Docente' : 'Estudiante',
            'nombreCompleto': _nombreCtrl.text.trim(),
            'codigoInstitucional': _codigoCtrl.text.trim(),
            'correoInstitucional': _correoInstitucionalCtrl.text.trim(),
            'correoAlterno': _correoAlternoCtrl.text.trim(),
            'tipoProblema': problemaSeleccionado,
            'descripcion': _descripcionCtrl.text.trim(),
            'estado': 'pendiente',
            'fechaSolicitud': FieldValue.serverTimestamp(),
          });
      radicado = 'TIC-${docRef.id.substring(0, 6).toUpperCase()}';
    } catch (e) {
      debugPrint('Aviso al registrar solicitud en Firestore: $e');
    }

    if (!mounted) return;
    setState(() => _enviando = false);

    _mostrarDialogoConfirmacion(radicado);
  }

  void _mostrarDialogoConfirmacion(String radicado) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colorSuave,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: _colorPrimario,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Solicitud enviada!',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _colorPrimario,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Radicado: $radicado',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'La Mesa de Ayuda TIC de la Universidad de la Amazonia revisará tu caso y te notificará al correo registrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
                height: 1.4,
              ),
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
                  backgroundColor: _colorPrimario,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Volver al Inicio de Sesión',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: _construirAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _construirTarjetaMesaAyuda(),
              const SizedBox(height: 14),
              _construirTarjetaFormulario(),
              const SizedBox(height: 18),
              _construirPiePagina(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F7F6),
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Flexible(
            child: Text(
              'Recuperar Cuenta',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _colorSuave,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.how_to_reg_outlined,
                  size: 13,
                  color: _colorPrimario,
                ),
                const SizedBox(width: 4),
                Text(
                  'Presente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _colorPrimario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 6),
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _colorPrimario,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'UA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaMesaAyuda() {
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
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _colorSuave,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: _colorPrimario,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _colorSuave,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MESA DE AYUDA TIC',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _colorPrimario,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recuperar Cuenta y Acceso',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Si presentas bloqueos de cuenta, no recibes los códigos de verificación o perdiste acceso a tu correo institucional, completa este formulario para asistencia directa con el equipo técnico de Uniamazonia.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaFormulario() {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Nombre completo
            _construirEtiquetaCampo('Nombre completo', obligatorio: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              decoration: _decoracionInput(
                hint: 'Juan David Cuéllar Valencia',
                icono: Icons.badge_outlined,
              ),
              validator: (valor) {
                if (valor == null || valor.trim().length < 4) {
                  return 'Ingresa tu nombre completo';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 2. Código estudiantil o de empleado
            _construirEtiquetaCampo(
              'Código estudiantil o de empleado',
              obligatorio: true,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codigoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              decoration: _decoracionInput(
                hint: '20211189421',
                icono: Icons.pin_outlined,
              ),
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Ingresa tu código o número de identificación';
                }
                return null;
              },
            ),
            const SizedBox(height: 5),
            const Text(
              'Código único asignado por la Universidad de la Amazonia',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // 3. Correo institucional
            _construirEtiquetaCampo('Correo institucional', obligatorio: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _correoInstitucionalCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              decoration: _decoracionInput(
                hint: 'j.cuellar@udla.edu.co',
                icono: Icons.mail_outline,
              ),
              validator: (valor) {
                if (valor == null ||
                    valor.trim().isEmpty ||
                    !valor.contains('@')) {
                  return 'Ingresa un correo electrónico válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 5),
            const Text(
              '(O correo alternativo si aún no tienes cuenta institucional)',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // 4. Correo de contacto alterno
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Correo de contacto alterno',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'RECOMENDADO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _colorPrimario,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _correoAlternoCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              decoration: _decoracionInput(
                hint: 'juan.cuellar@gmail.com',
                icono: Icons.alternate_email,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Muy útil para notificarte si tu correo institucional está inactivo',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 18),

            // 5. Tipo de inconsistencia o problema
            _construirEtiquetaCampo(
              'Tipo de inconsistencia o problema',
              obligatorio: true,
            ),
            const SizedBox(height: 8),
            Column(
              children: List.generate(_tiposProblema.length, (index) {
                final bool seleccionado = _indiceProblemaSeleccionado == index;
                final Map<String, dynamic> item = _tiposProblema[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _tiposProblema.length - 1 ? 8 : 0,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() => _indiceProblemaSeleccionado = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: seleccionado
                            ? _colorPrimario
                            : const Color(0xFFF3F4F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icono'] as IconData,
                            size: 19,
                            color: seleccionado ? Colors.white : Colors.black54,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['titulo'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: seleccionado
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: seleccionado
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (seleccionado)
                            const Icon(
                              Icons.check_circle_outline,
                              size: 19,
                              color: Colors.white,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),

            // 6. Descripción del problema
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _construirEtiquetaCampo(
                  'Descripción del problema',
                  obligatorio: true,
                ),
                Text(
                  '$_longitudDescripcion / 300',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 4,
              maxLength: 300,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Explica brevemente qué sucede al intentar iniciar sesión, si cambiaste de número celular o si aparece algún mensaje de error...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.black45,
                  height: 1.4,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F8),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _colorPrimario, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFB02A37),
                    width: 1.2,
                  ),
                ),
              ),
              validator: (valor) {
                if (valor == null || valor.trim().length < 10) {
                  return 'Describe brevemente el inconveniente (mínimo 10 caracteres)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 7. Botón Enviar solicitud de soporte
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarSolicitud,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorPrimario,
                  disabledBackgroundColor: _colorPrimario.withValues(
                    alpha: 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_outlined,
                        size: 19,
                        color: Colors.white,
                      ),
                label: Text(
                  _enviando
                      ? 'Enviando solicitud...'
                      : 'Enviar solicitud de soporte',
                  style: const TextStyle(
                    fontSize: 14.5,
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

  Widget _construirEtiquetaCampo(String texto, {bool obligatorio = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        children: [
          TextSpan(text: texto),
          if (obligatorio)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFB02A37)),
            ),
        ],
      ),
    );
  }

  InputDecoration _decoracionInput({
    required String hint,
    required IconData icono,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
      prefixIcon: Icon(icono, size: 19, color: Colors.black54),
      filled: true,
      fillColor: const Color(0xFFF3F4F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _colorPrimario, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB02A37), width: 1.2),
      ),
    );
  }

  Widget _construirPiePagina() {
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, size: 17, color: _colorPrimario),
          label: Text(
            'Volver al Inicio de Sesión',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: _colorPrimario,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Presente • Sistema de Control de Asistencia • v1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.black45),
        ),
      ],
    );
  }
}

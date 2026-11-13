import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'registro_docente_paso2.dart';

class RegistroDocente extends StatefulWidget {
  const RegistroDocente({super.key});

  @override
  State<RegistroDocente> createState() => _EstadoRegistroDocente();
}

class _EstadoRegistroDocente extends State<RegistroDocente> {
  static const Color _colorDocente = Color(0xFF00382A);
  static const Color _colorFondoCampo = Color(0xFFF4F6F9);
  static const Color _colorError = Color(0xFFB3261E); // Rojo para errores

  // Controladores de texto (sin código de empleado, según el mockup)
  final TextEditingController _controladorNombre = TextEditingController();
  final TextEditingController _controladorCorreo = TextEditingController();
  final TextEditingController _controladorDocumento = TextEditingController();
  final TextEditingController _controladorTelefono = TextEditingController();
  final TextEditingController _controladorClave = TextEditingController();
  final TextEditingController _controladorConfirmarClave =
      TextEditingController();

  // Nodos de enfoque
  final FocusNode _focoNombre = FocusNode();
  final FocusNode _focoCorreo = FocusNode();
  final FocusNode _focoDepartamento = FocusNode();
  final FocusNode _focoDocumento = FocusNode();
  final FocusNode _focoTelefono = FocusNode();
  final FocusNode _focoClave = FocusNode();
  final FocusNode _focoConfirmarClave = FocusNode();

  // Mensajes de error
  String? _errorNombre;
  String? _errorCorreo;
  String? _errorDepartamento;
  String? _errorDocumento;
  String? _errorTelefono;
  String? _errorClave;
  String? _errorConfirmarClave;
  bool _errorTerminos = false;

  String? _departamentoSeleccionado;
  String _tipoDocumentoSeleccionado = 'C.C.';
  bool _ocultarClave = true;
  bool _ocultarConfirmarClave = true;
  bool _terminosAceptados = false;
  bool _cargando = false;

  final List<String> _departamentos = [
    'Ciencias Básicas e Ingeniería',
    'Ciencias Agropecuarias',
    'Ciencias de la Educación',
    'Ciencias Económicas y Contables',
    'Derecho y Ciencias Políticas',
  ];

  bool get _tiene8Caracteres => _controladorClave.text.length >= 8;
  bool get _tieneMayuscula => _controladorClave.text.contains(RegExp(r'[A-Z]'));
  bool get _tieneNumero => _controladorClave.text.contains(RegExp(r'[0-9]'));
  bool get _tieneEspecial =>
      _controladorClave.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get _clavesCoinciden =>
      _controladorClave.text == _controladorConfirmarClave.text &&
      _controladorClave.text.isNotEmpty;

  bool get _correoValido {
    final String correo = _controladorCorreo.text.trim().toLowerCase();
    return RegExp(r'^[a-z0-9._\-+]+@udla\.edu\.co$').hasMatch(correo);
  }

  @override
  void dispose() {
    _controladorNombre.dispose();
    _controladorCorreo.dispose();
    _controladorDocumento.dispose();
    _controladorTelefono.dispose();
    _controladorClave.dispose();
    _controladorConfirmarClave.dispose();

    _focoNombre.dispose();
    _focoCorreo.dispose();
    _focoDepartamento.dispose();
    _focoDocumento.dispose();
    _focoTelefono.dispose();
    _focoClave.dispose();
    _focoConfirmarClave.dispose();
    super.dispose();
  }

  // --- LÓGICA DE FIREBASE Y REGISTRO ---
  Future<void> _registrarDocente() async {
    setState(() {
      _errorNombre = _controladorNombre.text.trim().isEmpty
          ? 'Requerido'
          : null;
      _errorCorreo = _controladorCorreo.text.trim().isEmpty
          ? 'Requerido'
          : (!_correoValido ? 'Debe ser un correo @udla.edu.co' : null);
      _errorDepartamento = _departamentoSeleccionado == null
          ? 'Selecciona una opción'
          : null;
      _errorDocumento = _controladorDocumento.text.trim().isEmpty
          ? 'Requerido'
          : null;
      _errorTelefono = _controladorTelefono.text.trim().isEmpty
          ? 'Requerido'
          : null;

      bool claveFuerte =
          _tiene8Caracteres &&
          _tieneMayuscula &&
          _tieneNumero &&
          _tieneEspecial;
      _errorClave = _controladorClave.text.isEmpty
          ? 'Requerido'
          : (!claveFuerte ? 'No cumple los requisitos' : null);
      _errorConfirmarClave = _controladorConfirmarClave.text.isEmpty
          ? 'Requerido'
          : (!_clavesCoinciden ? 'No coinciden' : null);

      _errorTerminos = !_terminosAceptados;
    });

    FocusNode? primerFocoError;
    if (_errorNombre != null) primerFocoError ??= _focoNombre;
    if (_errorCorreo != null) primerFocoError ??= _focoCorreo;
    if (_errorDepartamento != null) primerFocoError ??= _focoDepartamento;
    if (_errorDocumento != null) primerFocoError ??= _focoDocumento;
    if (_errorTelefono != null) primerFocoError ??= _focoTelefono;
    if (_errorClave != null) primerFocoError ??= _focoClave;
    if (_errorConfirmarClave != null) primerFocoError ??= _focoConfirmarClave;

    if (primerFocoError != null) {
      primerFocoError.requestFocus();
      return;
    }

    if (_errorTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar la política de datos.'),
          backgroundColor: _colorError,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Crear cuenta en Firebase Auth
      UserCredential credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _controladorCorreo.text.trim().toLowerCase(),
            password: _controladorClave.text,
          );

      // 2. Guardar estructura exacta en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credencial.user!.uid)
          .set({
            'nombre': _controladorNombre.text.trim(),
            'correo': _controladorCorreo.text.trim().toLowerCase(),
            'rol': 'docente', // CRÍTICO: Para que tu Login lo reconozca
            'departamento': _departamentoSeleccionado,
            'tipo_documento': _tipoDocumentoSeleccionado,
            'documento': _controladorDocumento.text.trim(),
            'telefono': 'co +57 ${_controladorTelefono.text.trim()}',
            'fecha_registro': FieldValue.serverTimestamp(),
            'estado': 'pendiente', // Añadido estado
          });

      // 3. Enviar enlace de verificación de Firebase
      await credencial.user!.sendEmailVerification();

      if (!mounted) return;

      // 4. Navegar al Paso 2 pasando solo el correo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegistroDocentePaso2(
            correo: _controladorCorreo.text.trim().toLowerCase(),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al registrarse';
      if (e.code == 'email-already-in-use')
        mensaje = 'Este correo ya está registrado.';
      if (e.code == 'invalid-email') mensaje = 'Correo inválido.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: _colorError),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: _construirAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _construirIndicadorPaso(),
              const SizedBox(height: 16),
              _construirSeccionCredenciales(),
              const SizedBox(height: 16),
              _construirSeccionCiudadana(),
              const SizedBox(height: 16),
              _construirSeccionSeguridad(),
              const SizedBox(height: 16),
              _construirCheckboxTerminos(),
              const SizedBox(height: 24),
              _construirBotonContinuar(),
              const SizedBox(height: 24),
              _construirEnlaceLogin(),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        children: [
          Text(
            'Registro de Docente',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'PRESENTE • UNIAMAZONIA',
            style: TextStyle(
              color: _colorDocente,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: CircleAvatar(
            backgroundColor: _colorDocente,
            radius: 16,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _construirIndicadorPaso() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EBEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PASO 1 DE 2',
                  style: TextStyle(
                    color: _colorDocente,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Datos Personales e\nInstitucionales',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ),
              const Text(
                '50%',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.5,
            backgroundColor: const Color(0xFFE6EBEA),
            valueColor: const AlwaysStoppedAnimation<Color>(_colorDocente),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: _colorDocente,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ingresa tus datos oficiales registrados ante la Universidad de la Amazonia para validar tu vinculación docente activa.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionCredenciales() {
    return _construirTarjeta(
      titulo: 'CREDENCIALES ACADÉMICAS',
      icono: Icons.badge_outlined,
      hijos: [
        _construirCampoTexto(
          'Nombre completo *',
          Icons.person_outline,
          _controladorNombre,
          _focoNombre,
          _errorNombre,
        ),
        const SizedBox(height: 16),
        _construirCampoCorreo(),
        const SizedBox(height: 16),
        _construirDropdownDepartamento(),
      ],
    );
  }

  Widget _construirSeccionCiudadana() {
    return _construirTarjeta(
      titulo: 'INFORMACIÓN CIUDADANA Y CONTACTO',
      icono: Icons.contact_mail_outlined,
      hijos: [
        _construirCampoDocumento(),
        const SizedBox(height: 16),
        _construirCampoTelefono(),
      ],
    );
  }

  Widget _construirSeccionSeguridad() {
    return _construirTarjeta(
      titulo: 'SEGURIDAD DE LA CUENTA',
      icono: Icons.security_outlined,
      hijos: [
        _construirCampoClave(
          'Contraseña institucional *',
          _controladorClave,
          _focoClave,
          _errorClave,
          _ocultarClave,
          () => setState(() => _ocultarClave = !_ocultarClave),
        ),
        const SizedBox(height: 16),
        _construirCampoClave(
          'Confirmar contraseña *',
          _controladorConfirmarClave,
          _focoConfirmarClave,
          _errorConfirmarClave,
          _ocultarConfirmarClave,
          () =>
              setState(() => _ocultarConfirmarClave = !_ocultarConfirmarClave),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _colorFondoCampo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REQUISITOS DE CONTRASEÑA:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              _construirRequisitoClave(
                'Mínimo 8 caracteres',
                _tiene8Caracteres,
              ),
              _construirRequisitoClave(
                'Al menos una letra mayúscula',
                _tieneMayuscula,
              ),
              _construirRequisitoClave('Al menos un número', _tieneNumero),
              _construirRequisitoClave(
                'Al menos un carácter especial (@, \$, !, %, etc.)',
                _tieneEspecial,
              ),
              _construirRequisitoClave(
                'Las contraseñas coinciden',
                _clavesCoinciden,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirCheckboxTerminos() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _terminosAceptados,
            onChanged: (val) => setState(() {
              _terminosAceptados = val!;
              if (_terminosAceptados) _errorTerminos = false;
            }),
            activeColor: _colorDocente,
            isError: _errorTerminos,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Acepto la política de tratamiento de datos personales de la Universidad de la Amazonia.',
            style: TextStyle(
              fontSize: 12,
              color: _errorTerminos ? _colorError : Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirBotonContinuar() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _cargando ? null : _registrarDocente,
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorDocente,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _cargando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Crear Cuenta y Continuar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _construirEnlaceLogin() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Text.rich(
          TextSpan(
            style: TextStyle(color: Colors.black54, fontSize: 13),
            children: [
              TextSpan(text: '¿Ya tienes cuenta? '),
              TextSpan(
                text: 'Inicia sesión ->',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _colorDocente,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _construirTarjeta({
    required String titulo,
    required IconData icono,
    required List<Widget> hijos,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: _colorDocente, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...hijos,
        ],
      ),
    );
  }

  Widget _construirCampoTexto(
    String etiqueta,
    IconData icono,
    TextEditingController controlador,
    FocusNode foco,
    String? error, {
    TextInputType tipoTeclado = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: error != null ? _colorError : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controlador,
          focusNode: foco,
          keyboardType: tipoTeclado,
          onChanged: (_) {
            if (error != null) {
              setState(() {
                _errorNombre = null;
                _errorDocumento = null;
                _errorTelefono = null;
              });
            }
          },
          decoration: InputDecoration(
            errorText: error,
            prefixIcon: Icon(
              icono,
              color: error != null ? _colorError : Colors.black54,
            ),
            filled: true,
            fillColor: _colorFondoCampo,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirCampoCorreo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Correo institucional *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _errorCorreo != null ? _colorError : Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFD1E7DD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Dominio requerido',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _colorDocente,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controladorCorreo,
          focusNode: _focoCorreo,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _errorCorreo = null),
          decoration: InputDecoration(
            errorText: _errorCorreo,
            prefixIcon: Icon(
              Icons.mail_outline,
              color: _errorCorreo != null ? _colorError : Colors.black54,
            ),
            filled: true,
            fillColor: _colorFondoCampo,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 2),
            ),
          ),
        ),
        if (_errorCorreo == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Debe terminar en @udla.edu.co',
              style: TextStyle(
                fontSize: 11,
                color: _correoValido || _controladorCorreo.text.isEmpty
                    ? Colors.black54
                    : _colorError,
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirDropdownDepartamento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Departamento académico *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _errorDepartamento != null ? _colorError : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          focusNode: _focoDepartamento,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          decoration: InputDecoration(
            errorText: _errorDepartamento,
            prefixIcon: Icon(
              Icons.business_outlined,
              color: _errorDepartamento != null ? _colorError : Colors.black54,
            ),
            filled: true,
            fillColor: _colorFondoCampo,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 2),
            ),
          ),
          value: _departamentoSeleccionado,
          items: _departamentos
              .map(
                (d) => DropdownMenuItem(
                  value: d,
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() {
            _departamentoSeleccionado = val;
            _errorDepartamento = null;
          }),
        ),
      ],
    );
  }

  Widget _construirCampoDocumento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documento de identidad *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _errorDocumento != null ? _colorError : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _colorFondoCampo,
            borderRadius: BorderRadius.circular(10),
            border: _errorDocumento != null
                ? Border.all(color: _colorError, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoDocumentoSeleccionado,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.black54,
                    ),
                    items: ['C.C.', 'C.E.', 'Pasaporte']
                        .map(
                          (String valor) => DropdownMenuItem<String>(
                            value: valor,
                            child: Text(
                              valor,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _tipoDocumentoSeleccionado = v!),
                  ),
                ),
              ),
              const SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, color: Colors.black12),
              ),
              Expanded(
                child: TextField(
                  controller: _controladorDocumento,
                  focusNode: _focoDocumento,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _errorDocumento = null),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorDocumento != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              _errorDocumento!,
              style: const TextStyle(color: _colorError, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _construirCampoTelefono() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teléfono móvil *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _errorTelefono != null ? _colorError : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _colorFondoCampo,
            borderRadius: BorderRadius.circular(10),
            border: _errorTelefono != null
                ? Border.all(color: _colorError, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  'co +57',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, color: Colors.black12),
              ),
              Expanded(
                child: TextField(
                  controller: _controladorTelefono,
                  focusNode: _focoTelefono,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() => _errorTelefono = null),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorTelefono != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              _errorTelefono!,
              style: const TextStyle(color: _colorError, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _construirCampoClave(
    String etiqueta,
    TextEditingController controlador,
    FocusNode foco,
    String? error,
    bool oculto,
    VoidCallback alPresionar,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: error != null ? _colorError : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controlador,
          focusNode: foco,
          obscureText: oculto,
          onChanged: (_) => setState(() {
            _errorClave = null;
            _errorConfirmarClave = null;
          }),
          decoration: InputDecoration(
            errorText: error,
            prefixIcon: Icon(
              Icons.lock_outline,
              color: error != null ? _colorError : Colors.black54,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                oculto
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.black54,
              ),
              onPressed: alPresionar,
            ),
            filled: true,
            fillColor: _colorFondoCampo,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _colorError, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirRequisitoClave(String texto, bool cumplido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 14,
              color: cumplido ? _colorDocente : Colors.black38,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                color: cumplido ? Colors.black87 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'pantallas/pantalla_inicio_sesion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AplicacionPresente());
}

class AplicacionPresente extends StatelessWidget {
  const AplicacionPresente({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presente',
      debugShowCheckedModeBanner: false,
      home: const PantallaInicioSesion(),
    );
  }
}

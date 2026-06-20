import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// 🔑 CHAVE MESTRA: ALTERE APENAS ESTA LINHA NA HORA DE COMPILAR
// false = Gera a Versão FREE (com limites, doação e botão de info)
// true  = Gera a Versão PREMIUM (ilimitada, sem doação, sem limites)
const bool IS_PREMIUM_VERSION = false; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PixFlowApp());
}

class PixFlowApp extends StatelessWidget {
  const PixFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: IS_PREMIUM_VERSION ? 'PixFlow Premium' : 'PixFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const StartupRouter(),
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});
  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (email == null) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const LoginScreen())
      );
    } else {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const HomeScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 20),
            Text('Carregando PixFlow...', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

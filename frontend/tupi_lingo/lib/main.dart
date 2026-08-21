import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/home.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tupi_lingo/login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/register.dart';
import 'package:tupi_lingo/teste.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 2. Necessário para inicializar o Flutter antes do Supabase

  // Carregar as chaves do .env
  await dotenv.load(fileName: ".env");

  // Iniciar supabase antes de tudo
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    print('EVENTO: ${data.event}');
    print('USUARIO: ${data.session?.user.email}');
  });
  runApp(const MyApp());
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Garante que o contexto esteja pronto antes de navegar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      print("DEBUG: Sessão nula, indo para welcome");
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    try {
      // Verifica se o usuário ainda existe no Supabase chamando a API
      try {
        await Supabase.instance.client.auth.getUser();
      } catch (e) {
        print("DEBUG: Usuário deletado ou token inválido no Supabase. Fazendo logout.");
        await Supabase.instance.client.auth.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      final accessToken = session.accessToken;

      // Lê a URL da API (Android Emulator)
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      print('DEBUG: API_URL do .env = ${dotenv.env['API_URL']}');
      print('DEBUG: baseUrl final = $baseUrl');

      final response = await http
          .post(
            Uri.parse("$baseUrl/auth/check-user"),
            headers: {
              "Authorization": "Bearer $accessToken",
              "Content-Type": "application/json",
            },
          )
          .timeout(const Duration(seconds: 10));

      print("DEBUG: Resposta recebida: ${response.statusCode}");
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("DEBUG: Valor do exists no JSON: ${data["exists"]}");
        // Verifica o retorno do seu Django
        if (data["exists"] == true) {
          String tupiLevel = data["tupi_level"]?.toString() ?? "";
          bool isNumeric = int.tryParse(tupiLevel) != null;
          
          if (isNumeric || tupiLevel == 'nenhum') {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TesteScreen(nivel: tupiLevel.isNotEmpty ? tupiLevel : 'iniciante'),
              ),
            );
          }
        } else {
          Navigator.pushReplacementNamed(context, '/register');
        }
      } else {
        print("DEBUG: Erro no servidor: ${response.statusCode}");
        setState(() {
          _hasError = true;
          _errorMessage = "Erro no servidor: ${response.statusCode}";
        });
      }
    } catch (e) {
      print("DEBUG: ERRO na requisição: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Erro de conexão com o servidor. Tente novamente.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                  });
                  _checkAuth();
                },
                child: const Text('Tentar Novamente'),
              ),
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
                },
                child: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TupiLingo',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      // REMOVA O 'home' E DEIXE APENAS O initialRoute
      initialRoute: '/',
      routes: {
        '/': (_) =>
            const AuthGate(), // O AuthGate gerenciará a lógica de navegação
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/register': (_) => const RegisterScreen(),
        '/welcome': (_) => const WelcomeScreen(), // Adicionei para facilitar
      },
      onGenerateRoute: (settings) {
        // Lida com deep links que contêm parâmetros, ex: /?code=...
        if (settings.name != null && settings.name!.startsWith('/?')) {
          return MaterialPageRoute(
            builder: (context) => const AuthGate(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}

// ... resto do seu código
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color backgroundColor = Color(0xFFF3F2E8);
  static const Color titleColor = Color(0xFFB8AF64);
  static const Color subtitleColor = Color(0xFF565D6D);
  static const Color primaryButtonColor = Color(0xFFD08A45);
  static const Color secondaryTextColor = Color(0xFF0E5D4E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            const TupiMascot(),

            const SizedBox(height: 20),

            const Text(
              'TupiLingo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: titleColor,
                height: 1,
              ),
            ),

            const SizedBox(height: 16),

            const SizedBox(
              width: 280,
              child: Text(
                "Eikuaa nde rapo, emo'ĩ nde rekove porãve.\n(Conheça suas raízes, fortaleça sua vida.)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint("Começar agora");
                    Navigator.pushReplacementNamed(context, '/register');
                  },
                  style:
                      ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: primaryButtonColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        shadowColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        'COMEÇAR AGORA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: OutlinedButton(
                  onPressed: () {
                    debugPrint("Já tenho uma conta");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD0D0D0), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'JÁ TENHO UMA CONTA',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class TupiMascot extends StatelessWidget {
  const TupiMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 185,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFD97900),
                borderRadius: BorderRadius.circular(48),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 28,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF7A4A22),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            top: 0,
            right: 28,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF7A4A22),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(top: 58, left: 52, child: _buildEye()),

          Positioned(top: 58, right: 52, child: _buildEye()),

          Positioned(
            top: 92,
            left: 44,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFFA4A4),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),

          Positioned(
            top: 92,
            right: 44,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFFA4A4),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),

          Positioned(
            top: 95,
            child: Container(
              width: 68,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6B3B1F),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),

          Positioned(
            top: 104,
            child: Container(
              width: 18,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          Positioned(
            top: 118,
            child: Container(
              width: 12,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEye() {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        children: [
          const CircleAvatar(radius: 14, backgroundColor: Colors.black),
          Positioned(
            top: 5,
            left: 6,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

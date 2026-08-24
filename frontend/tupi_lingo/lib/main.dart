import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/home/presentation/home.dart';
import 'package:tupi_lingo/features/auth/presentation/login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/features/auth/presentation/register.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // FLUTTER-004: Fallback seguro via --dart-define ou --dart-define-from-file em runtime
    dotenv.loadFromString(envString: '''
SUPABASE_URL=${const String.fromEnvironment('SUPABASE_URL')}
SUPABASE_ANON_KEY=${const String.fromEnvironment('SUPABASE_ANON_KEY')}
API_URL=${const String.fromEnvironment('API_URL')}
''');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseKey == null || supabaseKey.isEmpty) {
    throw Exception(
        'Variaveis de ambiente faltando! Você precisa rodar `flutter clean` e compilar o app novamente com --dart-define-from-file=.env para injetar as credenciais.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // FLUTTER-001 / FLUTTER-002: sem PII em logs; apenas evento em modo debug
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (kDebugMode) {
      debugPrint('[Auth] Evento: ${data.event}');
      // Nunca logar email ou token em produção
    }
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
  // FLUTTER-005: mensagem progressiva de status de conexão
  String _loadingMessage = 'Verificando sua conta...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    try {
      // FLUTTER-005: feedback progressivo
      if (mounted) setState(() => _loadingMessage = 'Validando sessão...');

      try {
        await Supabase.instance.client.auth.getUser();
      } catch (_) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      if (mounted) setState(() => _loadingMessage = 'Conectando ao servidor...');

      final accessToken = session.accessToken;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      // URLS-001: prefixo /api/v1/ adicionado
      final response = await http
          .post(
            Uri.parse("$baseUrl/api/v1/auth/check-user"),
            headers: {
              "Authorization": "Bearer $accessToken",
              "Content-Type": "application/json",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["exists"] == true) {
          String tupiLevel = data["tupi_level"]?.toString() ?? "";
          bool isNumeric = int.tryParse(tupiLevel) != null;

          if (isNumeric || tupiLevel == 'nenhum') {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TesteScreen(
                  nivel: tupiLevel.isNotEmpty ? tupiLevel : 'iniciante',
                ),
              ),
            );
          }
        } else {
          Navigator.pushReplacementNamed(context, '/register');
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = "Erro no servidor. Tente novamente.";
        });
      }
    } catch (_) {
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
        backgroundColor: const Color(0xFFF3F2E8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Color(0xFFD08A45), size: 56),
                const SizedBox(height: 20),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Color(0xFF565D6D),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _loadingMessage = 'Verificando sua conta...';
                    });
                    _checkAuth();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD08A45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Tentar Novamente'),
                ),
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/welcome');
                    }
                  },
                  child: const Text(
                    'Sair da conta',
                    style: TextStyle(color: Color(0xFF565D6D)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // FLUTTER-005: loading com mensagem progressiva
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2E8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD08A45)),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: const TextStyle(
                color: Color(0xFF565D6D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/register': (_) => const RegisterScreen(),
        '/welcome': (_) => const WelcomeScreen(),
      },
      onGenerateRoute: (settings) {
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
                    Navigator.pushReplacementNamed(context, '/register');
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    backgroundColor: primaryButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    shadowColor: Colors.black.withValues(alpha: 0.2),
                  ),
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

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: OutlinedButton(
                  onPressed: () {
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
    return Semantics(
      label: 'Mascote TupiLingo',
      child: SizedBox(
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
                      color: Colors.black.withValues(alpha: 0.12),
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

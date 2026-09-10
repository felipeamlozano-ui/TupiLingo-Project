import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/features/home/presentation/home.dart';
import 'package:tupi_lingo/features/auth/presentation/login.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/features/auth/presentation/register.dart';
import 'package:tupi_lingo/features/assessment/presentation/teste.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tupi_lingo/core/render/shader_warmup_engine.dart';
import 'package:tupi_lingo/core/concurrency/ten_isolates_engine.dart';
import 'package:tupi_lingo/core/memory/memory_residency_engine.dart';
import 'package:tupi_lingo/core/routing/predictive_preloading_engine.dart';
import 'package:tupi_lingo/core/telemetry/performance_telemetry_engine.dart';
import 'package:tupi_lingo/core/platform/platform_web_bridge.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Instant Loading Engine (P0): Telemetria & Proteção de Memória ──────────
  PerformanceTelemetryEngine.instance.start();
  MemoryResidencyEngine.instance.initialize();

  // ─── Instant Loading Engine (P0/P1): Warmup Concorrente sem travar UI ──────
  unawaited(ShaderWarmupEngine.instance.warmup());
  unawaited(TenIsolatesEngine.instance.initialize());

  // ─── HPWE Web Engine (RFC-009B): Ativado apenas sob kIsWeb (Android Intacto) ─
  unawaited(PlatformWebBridge.instance.initialize());

  if (kIsWeb) {
    // RFC-009C Camada 15: Na Web nunca requisitar .env via HTTP (elimina HTTP 404)
    const sbUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://vkmjefhyjtyxuhhnbnry.supabase.co');
    const sbKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrbWplZmh5anR5eHVoaG5ibnJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMzgwOTMsImV4cCI6MjA1NjgxNDA5M30.407YV_7t0D44_i622kK_hBsvXg3w30d3y4D3j72z17g');
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');
    dotenv.loadFromString(envString: '''
SUPABASE_URL=$sbUrl
SUPABASE_ANON_KEY=$sbKey
API_URL=$apiUrl
''');
  } else {
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
          // FLUTTER-006: Usa o contrato V2 da API (variante_ativa + ja_testou).
          // O antigo campo tupi_level foi removido; o nível agora é por variante.
          final varianteAtiva = data["variante_ativa"];
          final bool jaTestou = varianteAtiva?["ja_testou"] == true;

          if (jaTestou) {
            // Usuário já completou o nivelamento para a variante ativa → vai para Home
            Navigator.pushReplacementNamed(context, '/home');
          } else if (varianteAtiva != null) {
            // Variante ativa existe mas ainda não foi nivelado → fluxo de nivelamento
            final String varianteNome = varianteAtiva["nome"]?.toString() ?? 'iniciante';
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TesteScreen(
                  nivel: varianteNome,
                ),
              ),
            );
          } else {
            // Sem variante ativa → usuário precisa escolher língua / fazer nivelamento
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const TesteScreen(nivel: 'iniciante'),
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
        backgroundColor: AppTheme.bg(context),
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
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
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
                  child: Text(
                    'Sair da conta',
                    style: TextStyle(color: AppTheme.textSecondary(context)),
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
      backgroundColor: AppTheme.bg(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD08A45)),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
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

/// Observer de navegação que alimenta a Cadeia de Markov do PredictivePreloadingEngine
class InstantLoadingRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final currentName = route.settings.name ?? '';
    final prevName = previousRoute?.settings.name;
    if (currentName.isNotEmpty) {
      PredictivePreloadingEngine.instance.onRouteChanged(
        currentRoute: currentName,
        previousRoute: prevName,
      );
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final currentName = newRoute?.settings.name ?? '';
    final prevName = oldRoute?.settings.name;
    if (currentName.isNotEmpty) {
      PredictivePreloadingEngine.instance.onRouteChanged(
        currentRoute: currentName,
        previousRoute: prevName,
      );
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TupiLingo',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: '/',
          navigatorObservers: [InstantLoadingRouteObserver()],
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

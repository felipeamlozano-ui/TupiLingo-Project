import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/state/app_progression_notifier.dart';
import 'package:tupi_lingo/features/home/data/models/trail_map_models.dart';
import 'package:tupi_lingo/features/home/presentation/controllers/home_controller.dart';

void main() {
  group('HomeController Unit Tests', () {
    late HomeController controller;

    setUp(() {
      controller = HomeController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('LicaoStatus normalization maps canonical and legacy statuses accurately', () {
      expect(HomeController.parseLicaoStatus('concluida'), LicaoStatus.concluida);
      expect(HomeController.parseLicaoStatus('completed'), LicaoStatus.concluida);
      expect(HomeController.parseLicaoStatus('CONCLUIDA'), LicaoStatus.concluida);

      expect(HomeController.parseLicaoStatus('em_andamento'), LicaoStatus.emAndamento);
      expect(HomeController.parseLicaoStatus('in_progress'), LicaoStatus.emAndamento);

      expect(HomeController.parseLicaoStatus('disponivel'), LicaoStatus.disponivel);
      expect(HomeController.parseLicaoStatus('available'), LicaoStatus.disponivel);

      expect(HomeController.parseLicaoStatus('bloqueada'), LicaoStatus.bloqueada);
      expect(HomeController.parseLicaoStatus('locked'), LicaoStatus.bloqueada);
      expect(HomeController.parseLicaoStatus('desconhecido'), LicaoStatus.bloqueada);
    });

    test('Tab switching and variant updates correctly notify listeners', () {
      int notifications = 0;
      controller.addListener(() {
        notifications++;
      });

      controller.setTabIndex(1);
      expect(controller.currentTabIndex, 1);
      expect(notifications, 1);

      // Setting same tab should not notify
      controller.setTabIndex(1);
      expect(notifications, 1);

      controller.setVarianteAtiva(2, 'Tupi Moderno (Nheengatu)');
      expect(controller.varianteAtivaId, 2);
      expect(controller.varianteNome, 'Tupi Moderno (Nheengatu)');
      expect(notifications, 2);
    });

    test('Conchas delta updates and AppProgressionNotifier consumption work atomically', () {
      controller.updateConchasDelta(25);
      expect(controller.conchas, 25);

      controller.updateConchasDelta(-10);
      expect(controller.conchas, 15);

      // Test AppProgressionNotifier integration
      AppProgressionNotifier.instance.notifyProgressUpdated(conchasGained: 30);
      expect(controller.conchas, 45);
    });

    test('updateFromPayload parses complex trail and lesson hierarchy cleanly', () {
      final mockPayload = {
        'success': true,
        'usuario': {
          'streak_atual': 7,
          'conchas': 120,
          'xp_total': 350,
          'is_staff': false,
        },
        'variante': {
          'id': 1,
          'nome': 'Tupi Antigo',
        },
        'capitulos': [
          {
            'id': 10,
            'numero': 1,
            'titulo': 'Origens na Guanabara',
            'descricao': 'Primeiras saudações',
            'module_progress_percentage': 50.0,
            'licoes': [
              {
                'id': 101,
                'titulo': 'O Encontro',
                'descricao': 'Saudação básica',
                'numero': 1,
                'xp_base': 20,
                'pos_x': 50.0,
                'pos_y': 100.0,
                'status': 'concluida',
                'earned_xp': 20,
              },
              {
                'id': 102,
                'titulo': 'A Aldeia',
                'descricao': 'Vocabulário da taba',
                'numero': 2,
                'xp_base': 25,
                'pos_x': 150.0,
                'pos_y': 200.0,
                'status': 'disponivel',
                'earned_xp': 0,
              },
            ],
            'chest_reward': {
              'milestone_index': 1,
              'status': 'disponivel',
              'unlocked': true,
              'collected': false,
              'recompensa_xp': 75,
              'recompensa_conchas': 50,
              'after_lesson_number': 2,
            },
          },
        ],
      };

      controller.updateFromPayload(mockPayload);

      expect(controller.streakDays, 7);
      expect(controller.conchas, 120);
      expect(controller.xpTotal, 350);
      expect(controller.isAdmin, false);
      expect(controller.totalLicoes, 2);
      expect(controller.totalLicoesCompletas, 1);
      expect(controller.capitulos.length, 1);

      final cap = controller.capitulos.first;
      expect(cap.id, 10);
      expect(cap.titulo, 'Origens na Guanabara');
      expect(cap.licoes.length, 2);
      expect(cap.licoes[0].status, LicaoStatus.concluida);
      expect(cap.licoes[1].status, LicaoStatus.disponivel);
      expect(cap.chestReward?.unlocked, true);
      expect(cap.chestReward?.recompensaConchas, 50);
    });
  });
}

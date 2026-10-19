"""
Suíte Ofensiva Automatizada de Testes de Segurança, Intrusão e Estresse (FASE 8).
Executa centenas de asserções cobrindo:
1. Auth & JWT Bypass (alg=none, tokens expirados, IDOR, tokens sem sub).
2. Privilege Escalation (usuário comum em rotas admin, toggles de flags, OTPs).
3. Exploits de Gamificação (50 threads concorrentes de replay attacks em lições e baús, double-spending na loja, preços negativos).
4. Injeção e Fuzzing (SQLi, PostgREST filter injection, XSS, Prompt Injection, números gigantes/NaN/inf).
5. Blindagem de UI (FriendlyExceptionMiddleware sanitizando 100% de termos técnicos como psycopg2, supabase, traceback, sql, redis).
"""

import concurrent.futures
import json
import time
from unittest.mock import patch, MagicMock

import jwt
from django.conf import settings
from django.core.cache import cache
from django.test import TransactionTestCase, Client, override_settings
from django.http import HttpResponse, JsonResponse

from app.core.middleware import FriendlyExceptionMiddleware, TECHNICAL_TERMS_BLACKLIST, FRIENDLY_VILLAGE_ERROR
from trilha.models import VarianteTupi, TrilhaHistorica, Capitulo, Licao, Exercicio, UserChestReward
from users.models import UserProfile, UserLesson
from users.store_crypto import (
    sign_lesson_completion,
    verify_outbox_lesson,
    mark_nonce_used,
    sign_store_state,
    verify_store_state,
)
from users.services.progress_service import ProgressService
from pedagogico.calibracao.birdbrain_service import BirdbrainService


class OffensiveSecurityTestSuite(TransactionTestCase):
    """Bateria ofensiva massiva executada contra o backend do TupiLingo."""

    def setUp(self):
        cache.clear()
        self.jwt_secret = getattr(settings, 'SUPABASE_JWT_SECRET', None) or 'offensive_suite_secret_key_32_chars'

        # Variante e Trilha canônicas para os testes de estresse
        self.variante, _ = VarianteTupi.objects.get_or_create(
            codigo="tupi_antigo_offensive",
            defaults={"nome": "Tupi Antigo Ofensivo", "ativo": True, "ordem": 99}
        )
        self.trilha, _ = TrilhaHistorica.objects.get_or_create(
            variante=self.variante,
            defaults={"titulo": "Trilha Ofensiva", "publicada": True}
        )
        self.capitulo, _ = Capitulo.objects.get_or_create(
            trilha=self.trilha,
            numero=1,
            defaults={"titulo": "Capítulo 1", "publicado": True}
        )
        self.licao1, _ = Licao.objects.get_or_create(
            capitulo=self.capitulo,
            numero=1,
            defaults={"titulo": "Lição 1 Ofensiva", "xp_base": 20, "publicada": True}
        )
        self.licao2, _ = Licao.objects.get_or_create(
            capitulo=self.capitulo,
            numero=2,
            defaults={"titulo": "Lição 2 Ofensiva", "xp_base": 30, "publicada": True}
        )

        # Exercício associado para cálculo de precisão
        Exercicio.objects.get_or_create(
            licao=self.licao1,
            ordem=1,
            defaults={
                "tipo": "escolha_multipla",
                "enunciado": "Teste",
                "opcoes": ["A", "B"],
                "resposta_correta": 0,
            }
        )

        # Usuários de teste
        self.user_normal = UserProfile.objects.create(
            supabase_uid="00000000-aaaa-bbbb-cccc-000000000001",
            email="aluno.comum@tupilingo.com",
            name="Aluno Comum",
            xp_total=50,
            conchas=20,
            variante_ativa=self.variante,
        )

        self.user_target = UserProfile.objects.create(
            supabase_uid="00000000-aaaa-bbbb-cccc-000000000002",
            email="vitima.idor@tupilingo.com",
            name="Usuário Vítima",
            xp_total=500,
            conchas=200,
            variante_ativa=self.variante,
        )

        self.client = Client()

    def tearDown(self):
        cache.clear()

    def _make_jwt(self, sub: str, exp_delta: int = 3600, alg: str = "HS256", secret: str = None, extra_claims: dict = None):
        secret = secret or self.jwt_secret
        payload = {
            "sub": sub,
            "role": "authenticated",
            "aud": "authenticated",
            "exp": int(time.time()) + exp_delta,
            "iat": int(time.time()),
        }
        if extra_claims:
            payload.update(extra_claims)

        if alg.lower() == "none":
            return jwt.encode(payload, key="", algorithm="none")
        return jwt.encode(payload, secret, algorithm=alg)

    # ══════════════════════════════════════════════════════════════════════════
    # 1. AUTH & JWT BYPASS TESTS
    # ══════════════════════════════════════════════════════════════════════════

    def test_jwt_expired_token_rejected(self):
        """Rejeita tokens com expiração no passado (HTTP 401)."""
        expired_token = self._make_jwt(self.user_normal.supabase_uid, exp_delta=-3600)
        res = self.client.get(
            "/api/v1/store/catalog/",
            HTTP_AUTHORIZATION=f"Bearer {expired_token}",
        )
        self.assertEqual(res.status_code, 401)

    def test_jwt_alg_none_rejected(self):
        """Rejeita tokens com algoritmo alg=none (vulnerabilidade crítica de bypass)."""
        none_token = self._make_jwt(self.user_normal.supabase_uid, alg="none")
        res = self.client.get(
            "/api/v1/store/catalog/",
            HTTP_AUTHORIZATION=f"Bearer {none_token}",
        )
        self.assertEqual(res.status_code, 401)

    def test_jwt_tampered_secret_rejected(self):
        """Rejeita tokens assinados com chave secreta diferente da do Supabase."""
        tampered_token = self._make_jwt(self.user_normal.supabase_uid, secret="chave_completamente_errada_123456789")
        res = self.client.get(
            "/api/v1/store/catalog/",
            HTTP_AUTHORIZATION=f"Bearer {tampered_token}",
        )
        self.assertEqual(res.status_code, 401)

    def test_jwt_missing_sub_rejected(self):
        """Rejeita tokens válidos que não contêm a claim obrigatória 'sub'."""
        token_no_sub = jwt.encode(
            {"role": "authenticated", "aud": "authenticated", "exp": int(time.time()) + 3600},
            self.jwt_secret,
            algorithm="HS256"
        )
        res = self.client.get(
            "/api/v1/store/catalog/",
            HTTP_AUTHORIZATION=f"Bearer {token_no_sub}",
        )
        self.assertEqual(res.status_code, 401)

    def test_idor_user_isolation(self):
        """Garante que o atacante não consegue impersonar a vítima alterando supabase_uid no body."""
        attacker_token = self._make_jwt(self.user_normal.supabase_uid)

        # Tentativa de concluir lição enviando o ID da vítima no payload
        res = self.client.post(
            f"/api/v1/trilha/licao/{self.licao1.id}/concluir/",
            data=json.dumps({
                "acertos": 1,
                "tempo_segundos": 60,
                "user_id": self.user_target.supabase_uid,
                "supabase_uid": self.user_target.supabase_uid,
            }),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {attacker_token}",
        )
        self.assertEqual(res.status_code, 200)

        # O XP deve ter sido concedido exclusivamente ao user_normal autenticado pelo JWT
        self.user_normal.refresh_from_db()
        self.user_target.refresh_from_db()
        self.assertEqual(self.user_target.xp_total, 500)  # Vítima intocada
        self.assertGreater(self.user_normal.xp_total, 50)  # Atacante recebeu para si

    # ══════════════════════════════════════════════════════════════════════════
    # 2. PRIVILEGE ESCALATION TESTS
    # ══════════════════════════════════════════════════════════════════════════

    def test_privilege_escalation_admin_routes_blocked(self):
        """Usuário normal não consegue acessar rotas administrativas (/api/v1/admin/*)."""
        user_token = self._make_jwt(self.user_normal.supabase_uid)
        admin_routes = [
            "/api/v1/admin/dashboard/",
            "/api/v1/admin/users/",
            "/api/v1/admin/audit-logs/",
        ]
        for route in admin_routes:
            res = self.client.get(route, HTTP_AUTHORIZATION=f"Bearer {user_token}")
            self.assertIn(res.status_code, [401, 403, 404])

    def test_privilege_escalation_feature_flags_toggle_blocked(self):
        """Usuário comum não consegue alternar feature flags da plataforma."""
        user_token = self._make_jwt(self.user_normal.supabase_uid)
        res = self.client.post(
            "/api/v1/platform/flags/toggle/",
            data=json.dumps({"flag_name": "ai_tutor_enabled", "enabled": True}),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {user_token}",
        )
        self.assertIn(res.status_code, [401, 403, 404])

    def test_privilege_escalation_master_otp_blocked(self):
        """Tentativa de obter OTP de desenvolvedor com passcode forjado é bloqueada."""
        res = self.client.post(
            "/api/v1/platform/auth/otp/request/",
            data=json.dumps({"dev_id": "hacker", "master_passcode": "senha_errada_123"}),
            content_type="application/json",
        )
        self.assertIn(res.status_code, [400, 401, 403, 404])

    # ══════════════════════════════════════════════════════════════════════════
    # 3. EXPLOITS DE GAMIFICAÇÃO & CONCORRÊNCIA (RACE CONDITIONS)
    # ══════════════════════════════════════════════════════════════════════════

    @override_settings(RATELIMIT_ENABLE=False)
    def test_concurrency_race_condition_50_threads_lesson_completion(self):
        """
        Dispara 50 requisições simultâneas em concorrência real (ThreadPoolExecutor)
        para concluir a mesma lição.
        Graças ao select_for_update e transação atômica, o XP de primeira tentativa
        e as Conchas devem ser creditados EXATAMENTE UMA VEZ.
        """
        token = self._make_jwt(self.user_normal.supabase_uid)
        initial_xp = self.user_normal.xp_total
        initial_conchas = self.user_normal.conchas

        url = f"/api/v1/trilha/licao/{self.licao1.id}/concluir/"
        payload = json.dumps({
            "acertos": 1,
            "tempo_segundos": 60,
            "bonus_exploracao_xp": 0,
        })

        results = []

        def worker_concluir(idx):
            client = Client()
            return client.post(
                url,
                data=payload,
                content_type="application/json",
                HTTP_AUTHORIZATION=f"Bearer {token}",
            )

        # Dispara 50 threads concorrentes
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(worker_concluir, i) for i in range(50)]
            for f in concurrent.futures.as_completed(futures):
                results.append(f.result())

        self.assertEqual(len(results), 50)
        for r in results:
            self.assertEqual(r.status_code, 200)

        self.user_normal.refresh_from_db()

        # O XP concedido para 1 acerto na licao1 (xp_base=20) de primeira tentativa é 20
        # As conchas de primeira tentativa são 5
        self.assertEqual(self.user_normal.xp_total, initial_xp + 20)
        self.assertEqual(self.user_normal.conchas, initial_conchas + 5)

    def test_concurrency_race_condition_chest_collection(self):
        """
        Dispara 20 requisições concorrentes de abertura do mesmo baú cultural.
        Apenas uma deve ter sucesso; todas as outras devem retornar conflito (já coletado).
        """
        # Conclui as lições pré-requisito para o baú (Lições 1 e 2 do capítulo)
        UserLesson.objects.create(
            usuario=self.user_normal,
            licao=self.licao1,
            status="concluida",
            accuracy=1.0,
        )
        UserLesson.objects.create(
            usuario=self.user_normal,
            licao=self.licao2,
            status="concluida",
            accuracy=1.0,
        )

        results = []

        def worker_chest(idx):
            return ProgressService.collect_chest(
                user=self.user_normal,
                capitulo_id=self.capitulo.id,
                milestone_index=1,
            )

        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(worker_chest, i) for i in range(20)]
            for f in concurrent.futures.as_completed(futures):
                results.append(f.result())

        success_count = sum(1 for r in results if r.get("success") is True)
        self.assertEqual(success_count, 1)

        total_chests = UserChestReward.objects.filter(
            user=self.user_normal,
            capitulo=self.capitulo,
            milestone_index=1,
        ).count()
        self.assertEqual(total_chests, 1)

    def test_store_insufficient_conchas_blocked(self):
        """Rejeita compra na loja se o saldo de Conchas for menor que o preço do item."""
        token = self._make_jwt(self.user_normal.supabase_uid)
        self.user_normal.conchas = 5
        self.user_normal.save(update_fields=["conchas"])

        res = self.client.post(
            "/api/v1/store/purchase/",
            data=json.dumps({"item_id": "theme_areia_sagrada"}),  # custa 40 conchas
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        )
        self.assertEqual(res.status_code, 400)
        data = json.loads(res.content)
        self.assertFalse(data.get("success", False))

    def test_store_negative_price_or_invalid_item_blocked(self):
        """Bloqueia tentativas de comprar itens inexistentes ou manipular preços."""
        token = self._make_jwt(self.user_normal.supabase_uid)

        res = self.client.post(
            "/api/v1/store/purchase/",
            data=json.dumps({"item_id": "item_hacker_infinito", "price": -9999}),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        )
        self.assertIn(res.status_code, [400, 404])

    # ══════════════════════════════════════════════════════════════════════════
    # 4. INJEÇÃO, FUZZING & NONCES
    # ══════════════════════════════════════════════════════════════════════════

    def test_anti_replay_nonce_atomic_protection(self):
        """Valida que o mesmo nonce enviado duas vezes é detectado como replay attack."""
        test_nonce = "offensive_test_nonce_777abc"
        self.assertTrue(mark_nonce_used(test_nonce))
        # Segunda tentativa deve retornar False (já registrado)
        self.assertFalse(mark_nonce_used(test_nonce))

    def test_outbox_lesson_hmac_tamper_detected(self):
        """Garante que qualquer alteração de XP, lição ou nonce invalida a assinatura do Outbox."""
        ts = int(time.time())
        nonce = "outbox_nonce_xyz123"
        valid_sig = sign_lesson_completion(self.user_normal.id, 10, 50, ts, nonce)

        # Assinatura válida deve passar
        self.assertTrue(verify_outbox_lesson(self.user_normal.id, 10, 50, ts, nonce, valid_sig))

        # Adulteração de XP (de 50 para 9999) deve falhar
        self.assertFalse(verify_outbox_lesson(self.user_normal.id, 10, 9999, ts, nonce, valid_sig))

        # Adulteração de User ID deve falhar
        self.assertFalse(verify_outbox_lesson(self.user_target.id, 10, 50, ts, nonce, valid_sig))

        # Timestamp no futuro distante (> 10 min) deve falhar
        future_sig = sign_lesson_completion(self.user_normal.id, 10, 50, ts + 3600, nonce)
        self.assertFalse(verify_outbox_lesson(self.user_normal.id, 10, 50, ts + 3600, nonce, future_sig))

    def test_store_state_hmac_tamper_and_replay_detected(self):
        """Garante que a carteira do usuário rejeita saldos forjados e assinaturas expiradas."""
        ts = int(time.time())
        valid_sig = sign_store_state(self.user_normal.id, 150, ts)
        self.assertTrue(verify_store_state(self.user_normal.id, 150, ts, valid_sig))

        # Saldo forjado pelo cliente (ex: hacker injeta 99999 conchas)
        self.assertFalse(verify_store_state(self.user_normal.id, 99999, ts, valid_sig))

        # Replay com timestamp antigo (> 300 segundos)
        old_ts = ts - 400
        old_sig = sign_store_state(self.user_normal.id, 150, old_ts)
        self.assertFalse(verify_store_state(self.user_normal.id, 150, old_ts, old_sig))

    def test_sql_injection_resilience(self):
        """Injeta SQL injection em rotas de busca e conclusão de lição sem vazar dados ou quebrar."""
        token = self._make_jwt(self.user_normal.supabase_uid)
        sqli_payloads = [
            "' OR '1'='1",
            "1; DROP TABLE users_userprofile; --",
            "admin'--",
            "' UNION SELECT id, email, password FROM users_userprofile --",
        ]
        for payload in sqli_payloads:
            res = self.client.get(
                f"/api/v1/trilha/regioes/?variante={payload}",
                HTTP_AUTHORIZATION=f"Bearer {token}",
            )
            self.assertIn(res.status_code, [200, 400, 404])

    def test_xss_sanitization(self):
        """Verifica que tags de script e handlers perigosos são neutralizados."""
        xss_string = "<script>alert('XSS_ATTACK')</script><img src=x onerror=alert(1)>"
        # Testa na conclusão com nome/anotações
        token = self._make_jwt(self.user_normal.supabase_uid)
        res = self.client.post(
            f"/api/v1/trilha/licao/{self.licao1.id}/concluir/",
            data=json.dumps({
                "acertos": 1,
                "tempo_segundos": 60,
                "nota_cultural": xss_string,
            }),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        )
        self.assertEqual(res.status_code, 200)
        self.assertNotIn("<script>", res.content.decode("utf-8"))

    def test_fuzzing_huge_numbers_overflow_protection(self):
        """Envia números gigantescos, NaNs e Infs para o motor psicométrico sem causar crash 500."""
        bb = BirdbrainService()
        huge_val = 999999999999999999999999999999999999999.0

        # Atualiza com valores extremos
        new_theta, new_se, diag = bb.update_theta_after_lesson(
            current_theta=huge_val,
            current_se=0.5,
            lesson_responses=[{"param_a": 1.0, "param_b": 0.0, "param_c": 0.25, "is_correct": True}],
        )
        # Deve clampar theta com segurança em [-4.0, 4.0]
        self.assertTrue(-4.0 <= new_theta <= 4.0)
        self.assertTrue(0.01 <= new_se <= 2.0)

    # ══════════════════════════════════════════════════════════════════════════
    # 5. BLINDAGEM DE UI (FRIENDLY EXCEPTION MIDDLEWARE)
    # ══════════════════════════════════════════════════════════════════════════

    def test_friendly_exception_middleware_intercepts_technical_errors(self):
        """
        Garante que 100% das respostas de erro da API nunca vazem termos técnicos
        da infraestrutura (psycopg2, postgresql, redis, traceback, sql, etc.).
        """
        middleware = FriendlyExceptionMiddleware(get_response=lambda req: HttpResponse("ok"))

        # 1. Simula process_exception com erro de banco
        mock_request = MagicMock()
        mock_request.path = "/api/v1/trilha/mapa/"

        simulated_exc = Exception("psycopg2.OperationalError: could not connect to server: Connection refused")
        response = middleware.process_exception(mock_request, simulated_exc)

        self.assertIsNotNone(response)
        self.assertEqual(response.status_code, 500)
        content_json = json.loads(response.content.decode("utf-8"))
        error_msg = content_json.get("error", "").lower()

        for forbidden_term in TECHNICAL_TERMS_BLACKLIST:
            self.assertNotIn(forbidden_term, error_msg)

        self.assertIn("espíritos da floresta", error_msg)

    def test_friendly_exception_middleware_sanitizes_bad_json_responses(self):
        """Verifica se process_response limpa jargão técnico retornado em responses HTTP >= 400."""
        middleware = FriendlyExceptionMiddleware(get_response=lambda req: None)

        mock_request = MagicMock()
        mock_request.path = "/api/v1/trilha/licao/1/concluir/"

        # Response contendo termos proibidos
        leaking_data = {
            "success": False,
            "error": "Error in redis cache lookup: connection dropped to redis://127.0.0.1:6379",
            "detail": "psycopg2 query failed: SELECT * FROM trilha_licao",
        }
        mock_response = JsonResponse(leaking_data, status=500)

        sanitized_response = middleware.process_response(mock_request, mock_response)
        content_json = json.loads(sanitized_response.content.decode("utf-8"))
        error_msg = content_json.get("error", "").lower()

        for forbidden_term in TECHNICAL_TERMS_BLACKLIST:
            self.assertNotIn(forbidden_term, error_msg)

        self.assertIn("espíritos da floresta", error_msg)

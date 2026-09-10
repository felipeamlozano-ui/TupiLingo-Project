from clean_test_users import clean_users
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Exclui usuários de teste da base de dados PostgreSQL e cascadeia tabelas de progresso."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Simula a execução e lista os usuários e registros sem deletar nada.",
        )
        parser.add_argument(
            "--include-supabase",
            action="store_true",
            help="Deleta os usuários também do auth.users do Supabase.",
        )
        parser.add_argument(
            "--all",
            action="store_true",
            help="Remove TODOS os usuários da base sem exceções (use com cautela).",
        )
        parser.add_argument(
            "--keep-staff",
            action="store_true",
            help="Preserva também quaisquer contas com is_staff=True no Django User.",
        )
        parser.add_argument(
            "--keep-email",
            action="append",
            default=[],
            help="Especifica email adicional a ser preservado da exclusão (pode ser repetido).",
        )

    def handle(self, *args, **options):
        clean_users(
            dry_run=options["dry_run"],
            include_supabase=options["include_supabase"],
            all_users=options["all"],
            extra_keep=options["keep_email"],
            keep_staff=options["keep_staff"],
        )

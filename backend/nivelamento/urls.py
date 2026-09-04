from django.urls import path

from nivelamento import views

urlpatterns = [
    path(
        "nivelamento/gerar-questao/",
        views.gerar_questao_nivelamento,
        name="gerar_questao_nivelamento",
    ),
    path(
        "nivelamento/avaliar/",
        views.avaliar_teste,
        name="avaliar_teste",
    ),
    path(
        "nivelamento/check-variante/",
        views.check_teste_variante,
        name="check_teste_variante",
    ),
    path(
        "nivelamento/definir-nivel-inicial/",
        views.definir_nivel_inicial,
        name="definir_nivel_inicial",
    ),
]

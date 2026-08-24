from django.urls import path

from nivelamento import views

urlpatterns = [
    path(
        "nivelamento/gerar-questao/",
        views.gerar_questao_nivelamento,
        name="gerar_questao_nivelamento",
    ),
]

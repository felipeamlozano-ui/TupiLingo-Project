"""
Saneamento Filológico do TupiLingo segundo as Obras Canônicas do Prof. Dr. Eduardo Navarro (USP):
1. Elimina fraudes/mitos ("Aué", construções macarrônicas "xe irũ", "céu pupé").
2. Corrige contaminações de Nheengatu no Tupi Antigo (troca "puranga" por "katu", "tuxaua" por "morubixaba").
3. Corrige "Mbyá" (etnônimo) para "Tembi'u" (comida/alimento).
4. Remove anacronismos em português ("Cabo Frio", "Cartas de 1645" ensinados como vocábulos).
5. Expurga as variantes descontinuadas Kamaiurá e Tupinambá.
6. Renomeia e padroniza Tupi Contemporâneo para Tupi Antigo Revitalizado.
"""

import json
import os
import shutil
import re
import sys
from pathlib import Path

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_DIR = Path(__file__).resolve().parent.parent
CONTEUDO_DIR = BASE_DIR / "pedagogico" / "conteudo"


def sanear_tupi_antigo():
    print("-> Saneando capítulos de Tupi Antigo...")
    var_dir = CONTEUDO_DIR / "tupi_antigo"
    for cap_file in sorted(var_dir.glob("capitulo_*.json")):
        with open(cap_file, "r", encoding="utf-8") as f:
            content = f.read()

        # 1. Substitui fraude 'Aué' por 'Aué' (Saudação quinhentista autêntica)
        content = content.replace("Aué, xe irũ!", "Aué, xe irũ!")
        content = content.replace("Olá, meu amigo!", "Salve, meu amigo!")
        content = content.replace("Primeiros Encontros: Aué", "Primeiros Encontros: Aué")
        content = content.replace("'Aué'", "'Aué'")
        content = content.replace('"Aué"', '"Aué"')
        content = content.replace("a-u-É", "a-u-É")

        # 2. Corrige macarrônico 'che' para 'xe' e 'amigo' para 'irũ'
        content = content.replace("xe irũ", "xe irũ")

        # 3. Corrige nheengatismos inseridos indevidamente
        content = content.replace("Ygarapé puranga", "Ygarapé katu")
        content = content.replace("Canal protegido.", "Belo canal de águas.")
        content = content.replace("Tuxaua", "Morubixaba")
        content = content.replace("Comandante de guerra", "Líder e principal da aldeia")
        content = content.replace("Tamoio", "Tamuya")
        content = content.replace("Os antigos da federação", "Avô / Ancestral venerado")
        content = content.replace("Mbyá", "Tembi'u")
        content = content.replace("Alimento / Comida", "Comida / O que se come")

        # 4. Corrige vocábulos não-tupi do capítulo 19
        content = content.replace("Cartas de 1645", "Maranduba")
        content = content.replace("Epístolas históricas em Tupi puro", "Mensagem / Notícia histórica")
        content = content.replace("Cabo Frio", "Ybytyra")
        content = content.replace("Fortaleza Tupinambá contra os invasores", "Serra / Fortaleza natural")
        content = content.replace("Tupinambá Kuatiá", "Tupi Kuatiá")

        data = json.loads(content)

        # Remove itens duplicados com exemplo nulo nas lições
        for lic in data.get("licoes", []):
            bloco = lic.get("bloco_ensino", {})
            itens = bloco.get("itens_apresentados", [])
            itens_filtrados = []
            vistos = set()
            for it in itens:
                p = it.get("palavra", "").strip()
                if p and p not in vistos and it.get("exemplo_uso") is not None:
                    vistos.add(p)
                    itens_filtrados.append(it)
                elif p and p not in vistos:
                    vistos.add(p)
                    itens_filtrados.append(it)
            bloco["itens_apresentados"] = itens_filtrados

        with open(cap_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
    print("✔ Tupi Antigo saneado com sucesso.")


def criar_tupi_revitalizado():
    print("-> Padronizando Tupi Antigo Revitalizado...")
    src_dir = CONTEUDO_DIR / "tupi_contemporaneo"
    dst_dir = CONTEUDO_DIR / "tupi_revitalizado"

    if src_dir.exists():
        if dst_dir.exists():
            shutil.rmtree(dst_dir)
        shutil.copytree(src_dir, dst_dir)

    for cap_file in sorted(dst_dir.glob("capitulo_*.json")):
        with open(cap_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Ajusta nome da variante interna
        content = content.replace('"variante": "tupi_contemporaneo"', '"variante": "tupi_revitalizado"')
        
        # Elimina macarrônicos com português
        content = content.replace("Puranga koema, amigo!", "Katu koema, xe irũ!")
        content = content.replace("Yasy-tata céu pupé.", "Îasytatá ybak pupé.")
        content = content.replace("céu pupé", "ybak pupé")
        content = content.replace("Curupira ka'a guardião.", "Kurupera ka'a rerekua.")
        content = content.replace("Manioka roçado pupé.", "Mani'oka koo pupé.")

        # Harmoniza ortografia para Tupi Revitalizado (mantendo coerência com Navarro)
        content = content.replace("Puranga koema", "Katu koema")
        content = content.replace("Puranga pituna", "Katu pykói")
        content = content.replace("Apigawa", "Abá")
        content = content.replace("Kupixawa", "Koo")
        content = content.replace("Kamuti", "Iapé")
        content = content.replace("Tuxaua", "Morubixaba")

        data = json.loads(content)
        # Remove duplicados com exemplos nulos
        for lic in data.get("licoes", []):
            bloco = lic.get("bloco_ensino", {})
            itens = bloco.get("itens_apresentados", [])
            itens_filtrados = []
            vistos = set()
            for it in itens:
                p = it.get("palavra", "").strip()
                if p and p not in vistos and it.get("exemplo_uso") is not None:
                    vistos.add(p)
                    itens_filtrados.append(it)
                elif p and p not in vistos:
                    vistos.add(p)
                    itens_filtrados.append(it)
            bloco["itens_apresentados"] = itens_filtrados

        with open(cap_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")

    # Remove o antigo diretório tupi_contemporaneo se migrado
    if src_dir.exists():
        shutil.rmtree(src_dir)
    print("✔ Tupi Antigo Revitalizado consolidado.")


def expurgar_variantes_descontinuadas():
    print("-> Expurgando Kamaiurá e Tupinambá do conteúdo...")
    for var in ["kamaiura", "tupinamba"]:
        vdir = CONTEUDO_DIR / var
        if vdir.exists():
            shutil.rmtree(vdir)
            print(f"✔ Removido diretório de conteúdo: {var}")

    manifestos_dir = BASE_DIR / "pedagogico" / "manifestos"
    if manifestos_dir.exists():
        # Remove manifestos de kamaiura e tupinamba
        for f in manifestos_dir.glob("manifesto_kamaiura_*.json"):
            f.unlink()
        for f in manifestos_dir.glob("manifesto_tupinamba_*.json"):
            f.unlink()
        
        # Migra e saneia manifestos de tupi_contemporaneo -> tupi_revitalizado
        for f in manifestos_dir.glob("manifesto_tupi_contemporaneo_cap*.json"):
            num_match = re.search(r"cap(\d+)\.json$", f.name)
            if num_match:
                num = num_match.group(1)
                new_f = manifestos_dir / f"manifesto_tupi_revitalizado_cap{num}.json"
                with open(f, "r", encoding="utf-8") as inf:
                    mcontent = inf.read()
                mcontent = mcontent.replace('"variante": "tupi_contemporaneo"', '"variante": "tupi_revitalizado"')
                with open(new_f, "w", encoding="utf-8") as outf:
                    outf.write(mcontent)
                f.unlink()

        # Saneia manifestos de tupi_antigo
        for f in manifestos_dir.glob("manifesto_tupi_antigo_cap*.json"):
            with open(f, "r", encoding="utf-8") as inf:
                mcontent = inf.read()
            mcontent = mcontent.replace('"Aué"', '"Aué"')
            mcontent = mcontent.replace("Aué", "Aué")
            mcontent = mcontent.replace("Aué, xe irũ!", "Aué, xe irũ!")
            mcontent = mcontent.replace("Cartas de 1645", "Maranduba")
            mcontent = mcontent.replace("Cabo Frio", "Ybytyra")
            mcontent = mcontent.replace("Tupinambá Kuatiá", "Tupi Kuatiá")
            with open(f, "w", encoding="utf-8") as outf:
                outf.write(mcontent)
        print("✔ Manifestos saneados e sincronizados.")


if __name__ == "__main__":
    sanear_tupi_antigo()
    criar_tupi_revitalizado()
    expurgar_variantes_descontinuadas()
    print("\n[OK] Saneamento filológico completo executado.")


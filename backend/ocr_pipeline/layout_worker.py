"""
Worker de Análise de Layout e Reconstrução de Ordem de Leitura (Etapas 2 e 3 da Fase 1).
Implementa segmentação por XY-Cut para páginas de dicionário/glossário em 2 colunas,
assegurando que o fluxo de leitura nunca misture palavras entre colunas distintas.
"""

import cv2
import numpy as np
from PIL import Image


class LayoutWorker:
    def __init__(self, gutter_search_range: tuple[float, float] = (0.35, 0.65)):
        self.gutter_min_ratio, self.gutter_max_ratio = gutter_search_range

    def analyze_and_segment(
        self,
        pil_img: Image.Image,
        num_columns: int = 1
    ) -> list[tuple[Image.Image, tuple[int, int, int, int], str]]:
        """
        Segmenta a página em blocos com ordem de leitura estrita.
        Retorna lista de tuplas: (sub_imagem_pil, bbox (x1, y1, x2, y2), tipo_bloco).
        Para 2 colunas: retorna [coluna_esquerda, coluna_direita], lendo coluna 1 antes da 2.
        """
        w, h = pil_img.size
        if num_columns <= 1:
            return [(pil_img, (0, 0, w, h), "single_column")]

        # Converte para OpenCV para análise de perfil vertical
        cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

        # Projeção vertical da densidade de tinta
        v_proj = np.sum(binary, axis=0)

        # Busca do vale central (gutter / medianiz entre as duas colunas)
        start_x = int(w * self.gutter_min_ratio)
        end_x = int(w * self.gutter_max_ratio)
        if end_x <= start_x:
            return [(pil_img, (0, 0, w, h), "single_column")]

        center_slice = v_proj[start_x:end_x]
        valley_rel_x = int(np.argmin(center_slice))
        split_x = start_x + valley_rel_x

        # Detectar se há cabeçalho comum (primeiros 7% da altura)
        header_h = int(h * 0.07)
        footer_y = int(h * 0.94)

        blocks = []

        # 1. Cabeçalho (se houver texto)
        header_crop = pil_img.crop((0, 0, w, header_h))
        header_arr = np.array(header_crop)
        if np.mean(header_arr) < 250: # há tinta no cabeçalho
            blocks.append((header_crop, (0, 0, w, header_h), "header"))

        # 2. Coluna Esquerda: (0, header_h, split_x, footer_y)
        left_crop = pil_img.crop((0, header_h, split_x, footer_y))
        blocks.append((left_crop, (0, header_h, split_x, footer_y), "column_left"))

        # 3. Coluna Direita: (split_x, header_h, w, footer_y)
        right_crop = pil_img.crop((split_x, header_h, w, footer_y))
        blocks.append((right_crop, (split_x, header_h, w, footer_y), "column_right"))

        # 4. Rodapé (se houver texto)
        footer_crop = pil_img.crop((0, footer_y, w, h))
        footer_arr = np.array(footer_crop)
        if np.mean(footer_arr) < 250:
            blocks.append((footer_crop, (0, footer_y, w, h), "footer"))

        return blocks

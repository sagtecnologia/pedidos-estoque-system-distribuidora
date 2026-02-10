#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from PIL import Image, ImageDraw, ImageFont
import textwrap

# Dimensões da imagem
WIDTH = 1920
HEIGHT = 1080

# Cores do design minimalista
COLOR_BG = (245, 247, 250)  # Cinza claro
COLOR_PRIMARY = (0, 112, 192)  # Azul
COLOR_ACCENT = (255, 107, 53)  # Laranja
COLOR_TEXT_DARK = (30, 30, 30)
COLOR_TEXT_LIGHT = (80, 80, 80)

# Criar imagem
img = Image.new('RGB', (WIDTH, HEIGHT), COLOR_BG)
draw = ImageDraw.Draw(img)

# Tentar carregar fontes
try:
    font_huge = ImageFont.truetype("arial.ttf", 120)
    font_xl = ImageFont.truetype("arial.ttf", 80)
    font_large = ImageFont.truetype("arial.ttf", 48)
    font_medium = ImageFont.truetype("arial.ttf", 32)
    font_small = ImageFont.truetype("arial.ttf", 24)
except:
    font_huge = ImageFont.load_default()
    font_xl = ImageFont.load_default()
    font_large = ImageFont.load_default()
    font_medium = ImageFont.load_default()
    font_small = ImageFont.load_default()

# ===== CABEÇALHO =====
# Faixa azul no topo
draw.rectangle([0, 0, WIDTH, 100], fill=COLOR_PRIMARY)
draw.text((60, 30), "ERP & PDV PARA DISTRIBUIDORAS", font=font_small, fill=(255, 255, 255))

# ===== TÍTULO PRINCIPAL =====
title_y = 150
draw.text((60, title_y), "Sua Empresa", font=font_huge, fill=COLOR_PRIMARY)
draw.text((60, title_y + 120), "Mais Organizada", font=font_huge, fill=COLOR_PRIMARY)
draw.text((60, title_y + 240), "e Lucrativa", font=font_huge, fill=COLOR_ACCENT)

# ===== SEÇÃO COM 6 FEATURES EM GRID =====
features_data = [
    ("🛒", "PDV Integrado", "Vendas rápidas com\nNFC-e automática"),
    ("📦", "Controle Estoque", "Rastreie produtos\nem tempo real"),
    ("📊", "Análise Financeira", "Lucros e margens\ndetalhadas"),
    ("📄", "Importação XML", "Cadastre de NF-e\nautomaticamente"),
    ("👥", "Multi-Usuário", "Controle de acessos\ne permissões"),
    ("🔐", "Segurança", "Backup automático\ne proteção de dados"),
]

feature_start_x = 60
feature_start_y = 550
feature_width = 300
feature_height = 200
feature_gap_x = 50
feature_gap_y = 50

for idx, (emoji, title, desc) in enumerate(features_data):
    row = idx // 3
    col = idx % 3
    
    x = feature_start_x + (col * (feature_width + feature_gap_x))
    y = feature_start_y + (row * (feature_height + feature_gap_y))
    
    # Card background
    draw.rectangle([x, y, x + feature_width, y + feature_height], 
                   fill=(255, 255, 255), outline=COLOR_PRIMARY, width=2)
    
    # Emoji
    draw.text((x + 20, y + 20), emoji, font=font_xl, fill=COLOR_PRIMARY)
    
    # Título
    draw.text((x + 20, y + 100), title, font=font_medium, fill=COLOR_TEXT_DARK)
    
    # Descrição
    desc_y = y + 140
    draw.multiline_text((x + 20, desc_y), desc, font=font_small, fill=COLOR_TEXT_LIGHT)

# ===== LADO DIREITO - STATS =====
stats_x = 1200

# Retângulo com fundo azul para stats
draw.rectangle([stats_x, 150, WIDTH - 60, 400], fill=COLOR_PRIMARY)

# Stats
draw.text((stats_x + 40, 180), "30+", font=font_xl, fill=COLOR_ACCENT)
draw.text((stats_x + 40, 280), "Funcionalidades", font=font_medium, fill=(255, 255, 255))

draw.text((stats_x + 40, 350), "100% Integrado • 24/7 Suporte", 
          font=font_medium, fill=(255, 255, 255))

# CTA Buttons
button_y = 470
# Botão primário
draw.rectangle([stats_x, button_y, stats_x + 300, button_y + 70], fill=COLOR_ACCENT)
draw.text((stats_x + 40, button_y + 20), "Solicitar Demo", font=font_medium, fill=(255, 255, 255))

# Botão secundário
draw.rectangle([stats_x, button_y + 100, stats_x + 300, button_y + 170], 
               fill=(255, 255, 255), outline=COLOR_PRIMARY, width=2)
draw.text((stats_x + 50, button_y + 115), "Saber Mais", font=font_medium, fill=COLOR_PRIMARY)

# Footer
footer_y = HEIGHT - 80
draw.line([(60, footer_y), (WIDTH - 60, footer_y)], fill=COLOR_PRIMARY, width=2)
draw.text((60, footer_y + 20), "Sistema completo para distribuidoras  |  Tecnologia em nuvem  |  Seguro e confiável", 
          font=font_small, fill=COLOR_TEXT_LIGHT)

# Salvar versão minimalista
img.save('sistema-divulgacao-alt-1920x1080.png', 'PNG', quality=95)
print("✅ Imagem minimalista criada: sistema-divulgacao-alt-1920x1080.png")

# Versão reduzida
img_small = img.resize((1200, 630), Image.Resampling.LANCZOS)
img_small.save('sistema-divulgacao-alt-1200x630.png', 'PNG', quality=95)
print("✅ Imagem minimalista criada: sistema-divulgacao-alt-1200x630.png")

print("\n✨ Versão minimalista gerada com sucesso!")

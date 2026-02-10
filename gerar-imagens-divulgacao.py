#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from PIL import Image, ImageDraw, ImageFont
from PIL import ImageFilter
import textwrap

# Dimensões da imagem
WIDTH = 1920
HEIGHT = 1080
DPI = 300

# Cores do design
COLOR_PRIMARY = (102, 126, 234)  # #667eea
COLOR_SECONDARY = (118, 75, 162)  # #764ba2
COLOR_HIGHLIGHT = (0, 212, 255)  # #00d4ff
COLOR_WHITE = (255, 255, 255)
COLOR_TEXT = (255, 255, 255)

# Criar imagem com gradiente
img = Image.new('RGB', (WIDTH, HEIGHT), COLOR_PRIMARY)
pixels = img.load()

# Criar gradiente de azul a roxo
for y in range(HEIGHT):
    for x in range(WIDTH):
        # Interpolação linear do gradiente
        r = int(COLOR_PRIMARY[0] + (COLOR_SECONDARY[0] - COLOR_PRIMARY[0]) * (x / WIDTH) + (COLOR_SECONDARY[0] - COLOR_PRIMARY[0]) * (y / HEIGHT) * 0.5)
        g = int(COLOR_PRIMARY[1] + (COLOR_SECONDARY[1] - COLOR_PRIMARY[1]) * (x / WIDTH) + (COLOR_SECONDARY[1] - COLOR_PRIMARY[1]) * (y / HEIGHT) * 0.5)
        b = int(COLOR_PRIMARY[2] + (COLOR_SECONDARY[2] - COLOR_PRIMARY[2]) * (x / WIDTH) + (COLOR_SECONDARY[2] - COLOR_PRIMARY[2]) * (y / HEIGHT) * 0.5)
        pixels[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))

draw = ImageDraw.Draw(img)

# Tentar carregar fontes (fallback para default se não disponível)
try:
    font_large = ImageFont.truetype("arial.ttf", 100)
    font_title = ImageFont.truetype("arial.ttf", 65)
    font_subtitle = ImageFont.truetype("arial.ttf", 32)
    font_feature = ImageFont.truetype("arial.ttf", 24)
    font_small = ImageFont.truetype("arial.ttf", 20)
    font_badge = ImageFont.truetype("arial.ttf", 18)
except:
    font_large = ImageFont.load_default()
    font_title = ImageFont.load_default()
    font_subtitle = ImageFont.load_default()
    font_feature = ImageFont.load_default()
    font_small = ImageFont.load_default()
    font_badge = ImageFont.load_default()

# Desenhar formas de fundo (semi-transparentes)
overlay = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)

# Círculos decorativos
overlay_draw.ellipse([1400, -200, 2000, 400], fill=(255, 255, 255, 20), outline=None)
overlay_draw.ellipse([-100, -100, 400, 400], fill=(255, 255, 255, 15), outline=None)

img = Image.alpha_composite(img.convert('RGBA'), overlay).convert('RGB')
draw = ImageDraw.Draw(img)

# CONTEÚDO ESQUERDO
LEFT_MARGIN = 60
TOP_MARGIN = 80

# Badge
draw.text((LEFT_MARGIN, TOP_MARGIN), "🚀 SOLUÇÃO COMPLETA", font=font_badge, fill=COLOR_HIGHLIGHT)

# Título
title = "ERP & PDV\npara Distribuidoras"
draw.multiline_text((LEFT_MARGIN, TOP_MARGIN + 80), title, font=font_large, fill=COLOR_WHITE)

# Subtítulo
subtitle = "Gerencie pedidos, estoque, vendas, finanças e\ndocumentos fiscais em uma plataforma integrada"
draw.multiline_text((LEFT_MARGIN, TOP_MARGIN + 330), subtitle, font=font_subtitle, fill=(255, 255, 255))

# Features
features = [
    "📊 Controle Financeiro",
    "📦 Gestão de Estoque",
    "📄 NFC-e Integrada",
    "👥 Controle de Acessos",
    "📞 Gestão de Clientes",
    "🔐 Segurança Avançada"
]

feat_y = TOP_MARGIN + 550
feat_x1 = LEFT_MARGIN
feat_x2 = LEFT_MARGIN + 300

for i, feature in enumerate(features):
    if i % 2 == 0:
        draw.text((feat_x1, feat_y), feature, font=font_feature, fill=COLOR_WHITE)
    else:
        draw.text((feat_x2, feat_y), feature, font=font_feature, fill=COLOR_WHITE)
    if (i + 1) % 2 == 0:
        feat_y += 60

# Botão CTA
button_y = TOP_MARGIN + 750
draw.rectangle([LEFT_MARGIN, button_y, LEFT_MARGIN + 350, button_y + 60], 
               fill=COLOR_HIGHLIGHT)
draw.text((LEFT_MARGIN + 70, button_y + 15), "Solicitar Demonstração", 
          font=font_feature, fill=COLOR_SECONDARY)

# CONTEÚDO DIREITO - Cards
RIGHT_START = 1050
CARD_WIDTH = 380
CARD_HEIGHT = 200
CARDS_GAP = 40

cards = [
    ("🛒", "PDV Moderno", "Checkout rápido com emissão automática de documentos fiscais"),
    ("📊", "Análise Financeira", "Visualize receitas, custos e margens em tempo real"),
    ("📦", "Importação XML", "Cadastre fornecedores e produtos direto de NF-e"),
    ("⚡", "Automação", "Sincronização automática e relatórios inteligentes"),
]

card_y = TOP_MARGIN + 80
col = 0

for icon, title, desc in cards:
    card_x = RIGHT_START + (col % 2) * (CARD_WIDTH + CARDS_GAP)
    if col > 0 and col % 2 == 0:
        card_y += CARD_HEIGHT + CARDS_GAP

    # Card background (semi-transparent white with blur effect)
    draw.rectangle([card_x, card_y, card_x + CARD_WIDTH, card_y + CARD_HEIGHT], 
                   fill=(255, 255, 255, 30), outline=(255, 255, 255, 50))
    
    # Icon
    draw.text((card_x + 20, card_y + 20), icon, font=font_large, fill=COLOR_WHITE)
    
    # Title
    title_y = card_y + 100
    draw.text((card_x + 20, title_y), title, font=font_feature, fill=COLOR_WHITE)
    
    # Description
    desc_y = title_y + 50
    wrapped_desc = textwrap.fill(desc, width=40)
    draw.multiline_text((card_x + 20, desc_y), wrapped_desc, font=font_small, fill=(255, 255, 255))
    
    col += 1

# ESTATÍSTICAS INFERIORES
stats = [
    ("30+", "Funcionalidades"),
    ("100%", "Integrado"),
    ("24/7", "Disponível"),
]

stat_y = HEIGHT - 150
stat_start_x = RIGHT_START + 80
stat_gap = 250

for i, (number, label) in enumerate(stats):
    stat_x = stat_start_x + (i * stat_gap)
    
    # Número
    draw.text((stat_x, stat_y), number, font=font_title, fill=COLOR_HIGHLIGHT)
    
    # Label
    draw.text((stat_x, stat_y + 80), label, font=font_small, fill=COLOR_WHITE)

# Salvar imagem
img.save('sistema-divulgacao-1920x1080.png', 'PNG', quality=95)
print("✅ Imagem criada: sistema-divulgacao-1920x1080.png")

# Criar versão reduzida para redes sociais (1200x630)
img_small = img.resize((1200, 630), Image.Resampling.LANCZOS)
img_small.save('sistema-divulgacao-1200x630.png', 'PNG', quality=95)
print("✅ Imagem criada: sistema-divulgacao-1200x630.png")

# Criar versão quadrada para redes sociais (1080x1080)
img_square = Image.new('RGB', (1080, 1080))
# Copiar a parte central da imagem original
left = (WIDTH - 1080) // 2
top = (HEIGHT - 1080) // 2
crop_box = (left, top, left + 1080, top + 1080)
img_square.paste(img.crop(crop_box), (0, 0))
img_square.save('sistema-divulgacao-1080x1080.png', 'PNG', quality=95)
print("✅ Imagem criada: sistema-divulgacao-1080x1080.png")

print("\n✨ Todas as imagens foram geradas com sucesso!")

-- =====================================================
-- DADOS DE PODS DESCARTÁVEIS
-- =====================================================
-- Script para popular o banco com produtos de pods descartáveis
-- Execute após limpar a base ou em uma base vazia
-- =====================================================

-- MARCA: IGNITE
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('IGN-V15', 'Ignite V15', 'Ignite', 'UNI', 25.00, 45.00, 10),
('IGN-V25', 'Ignite V25', 'Ignite', 'UNI', 30.00, 55.00, 10),
('IGN-V50', 'Ignite V50', 'Ignite', 'UNI', 35.00, 65.00, 10),
('IGN-V80', 'Ignite V80', 'Ignite', 'UNI', 40.00, 75.00, 10),
('IGN-V150', 'Ignite V150', 'Ignite', 'UNI', 45.00, 85.00, 10),
('IGN-V250', 'Ignite V250', 'Ignite', 'UNI', 50.00, 95.00, 10),
('IGN-V400', 'Ignite V400', 'Ignite', 'UNI', 52.00, 99.00, 10),
('IGN-V400MIX', 'Ignite V400 MIX', 'Ignite', 'UNI', 54.00, 102.00, 10),
('IGN-V600', 'Ignite V600', 'Ignite', 'UNI', 55.00, 105.00, 10);

-- Sabores Ignite V15
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry', 0 FROM produtos WHERE nome = 'Ignite V15' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape', 0 FROM produtos WHERE nome = 'Ignite V15' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon', 0 FROM produtos WHERE nome = 'Ignite V15' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint', 0 FROM produtos WHERE nome = 'Ignite V15' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry', 0 FROM produtos WHERE nome = 'Ignite V15' AND marca = 'Ignite';

-- Sabores Ignite V25
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Kiwi', 0 FROM produtos WHERE nome = 'Ignite V25' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Ignite V25' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Ignite V25' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint Ice', 0 FROM produtos WHERE nome = 'Ignite V25' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Ignite V25' AND marca = 'Ignite';

-- Sabores Ignite V50
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Watermelon', 0 FROM produtos WHERE nome = 'Ignite V50' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Ignite V50' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Double Apple', 0 FROM produtos WHERE nome = 'Ignite V50' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Passion Fruit', 0 FROM produtos WHERE nome = 'Ignite V50' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lush Ice', 0 FROM produtos WHERE nome = 'Ignite V50' AND marca = 'Ignite';

-- Sabores Ignite V80
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Ignite V80' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Ignite V80' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Ignite V80' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Glacial Mint', 0 FROM produtos WHERE nome = 'Ignite V80' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Ignite V80' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Ignite V80' AND marca = 'Ignite';

-- Sabores Ignite V150
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Passion Fruit Ice', 0 FROM produtos WHERE nome = 'Ignite V150' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Ignite V150' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemonade', 0 FROM produtos WHERE nome = 'Ignite V150' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Red Bull', 0 FROM produtos WHERE nome = 'Ignite V150' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Tangerine Ice', 0 FROM produtos WHERE nome = 'Ignite V150' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cherry Ice', 0 FROM produtos WHERE nome = 'Ignite V150' AND marca = 'Ignite';

-- Sabores Ignite V250
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Kiwi Ice', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Strawberry', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Raspberry', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mix Fruits', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Pineapple Ice', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strong Mint', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Coca-Cola', 0 FROM produtos WHERE nome = 'Ignite V250' AND marca = 'Ignite';

-- Sabores Ignite V400
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Ignite V400' AND marca = 'Ignite';

-- Sabores Ignite V400 MIX
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Banana Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Lemon Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Blueberry Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Passion Fruit Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Kiwi Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Tropical Fruits Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Red Bull Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Guarana Ice', 0 FROM produtos WHERE nome = 'Ignite V400 MIX' AND marca = 'Ignite';

-- Sabores Ignite V600
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Banana', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Lemon', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Green Apple', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Raspberry', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Peach', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Passion Fruit Orange', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Energy Drink', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Bubblegum', 0 FROM produtos WHERE nome = 'Ignite V600' AND marca = 'Ignite';

-- =====================================================

-- MARCA: ELFBAR
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('ELF-BC5000', 'Elfbar BC5000', 'Elfbar', 'UNI', 28.00, 50.00, 10),
('ELF-TE5000', 'Elfbar TE5000', 'Elfbar', 'UNI', 30.00, 55.00, 10),
('ELF-BC10000', 'Elfbar BC10000', 'Elfbar', 'UNI', 35.00, 65.00, 10);

-- Sabores Elfbar BC5000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Elfbar BC5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Elfbar BC5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Ice', 0 FROM produtos WHERE nome = 'Elfbar BC5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Elfbar BC5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Elfbar BC5000' AND marca = 'Elfbar';

-- Sabores Elfbar TE5000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Kiwi', 0 FROM produtos WHERE nome = 'Elfbar TE5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape', 0 FROM produtos WHERE nome = 'Elfbar TE5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon Mint', 0 FROM produtos WHERE nome = 'Elfbar TE5000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Mango', 0 FROM produtos WHERE nome = 'Elfbar TE5000' AND marca = 'Elfbar';

-- Sabores Elfbar BC10000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Miami Mint', 0 FROM produtos WHERE nome = 'Elfbar BC10000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Lemonade', 0 FROM produtos WHERE nome = 'Elfbar BC10000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Triple Berry Ice', 0 FROM produtos WHERE nome = 'Elfbar BC10000' AND marca = 'Elfbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cherry Lemon', 0 FROM produtos WHERE nome = 'Elfbar BC10000' AND marca = 'Elfbar';

-- =====================================================

-- MARCA: HQD
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('HQD-CUVIE', 'HQD Cuvie Plus', 'HQD', 'UNI', 22.00, 40.00, 10),
('HQD-KING', 'HQD King', 'HQD', 'UNI', 30.00, 55.00, 10),
('HQD-MEGA', 'HQD Mega', 'HQD', 'UNI', 35.00, 60.00, 10);

-- Sabores HQD Cuvie Plus
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry', 0 FROM produtos WHERE nome = 'HQD Cuvie Plus' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry', 0 FROM produtos WHERE nome = 'HQD Cuvie Plus' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango', 0 FROM produtos WHERE nome = 'HQD Cuvie Plus' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape', 0 FROM produtos WHERE nome = 'HQD Cuvie Plus' AND marca = 'HQD';

-- Sabores HQD King
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lush Ice', 0 FROM produtos WHERE nome = 'HQD King' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cool Mint', 0 FROM produtos WHERE nome = 'HQD King' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Watermelon', 0 FROM produtos WHERE nome = 'HQD King' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz', 0 FROM produtos WHERE nome = 'HQD King' AND marca = 'HQD';

-- Sabores HQD Mega
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Double Apple', 0 FROM produtos WHERE nome = 'HQD Mega' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'HQD Mega' AND marca = 'HQD';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'HQD Mega' AND marca = 'HQD';

-- =====================================================

-- MARCA: LOST MARY
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('LM-OS5000', 'Lost Mary OS5000', 'Lost Mary', 'UNI', 32.00, 58.00, 10),
('LM-MO5000', 'Lost Mary MO5000', 'Lost Mary', 'UNI', 35.00, 65.00, 10);

-- Sabores Lost Mary OS5000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Lost Mary OS5000' AND marca = 'Lost Mary';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Lost Mary OS5000' AND marca = 'Lost Mary';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Lost Mary OS5000' AND marca = 'Lost Mary';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Peach', 0 FROM produtos WHERE nome = 'Lost Mary OS5000' AND marca = 'Lost Mary';

-- Sabores Lost Mary MO5000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Triple Berry', 0 FROM produtos WHERE nome = 'Lost Mary MO5000' AND marca = 'Lost Mary';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cherry Lemon', 0 FROM produtos WHERE nome = 'Lost Mary MO5000' AND marca = 'Lost Mary';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Kiwi Passion Fruit', 0 FROM produtos WHERE nome = 'Lost Mary MO5000' AND marca = 'Lost Mary';

-- =====================================================

-- MARCA: GEEK BAR
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('GB-PULSE', 'Geek Bar Pulse', 'Geek Bar', 'UNI', 38.00, 70.00, 10),
('GB-B5000', 'Geek Bar B5000', 'Geek Bar', 'UNI', 32.00, 60.00, 10);

-- Sabores Geek Bar Pulse
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Banana', 0 FROM produtos WHERE nome = 'Geek Bar Pulse' AND marca = 'Geek Bar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Ice', 0 FROM produtos WHERE nome = 'Geek Bar Pulse' AND marca = 'Geek Bar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Geek Bar Pulse' AND marca = 'Geek Bar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Miami Mint', 0 FROM produtos WHERE nome = 'Geek Bar Pulse' AND marca = 'Geek Bar';

-- Sabores Geek Bar B5000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Geek Bar B5000' AND marca = 'Geek Bar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Geek Bar B5000' AND marca = 'Geek Bar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon Mint', 0 FROM produtos WHERE nome = 'Geek Bar B5000' AND marca = 'Geek Bar';

-- =====================================================

-- MARCA: PUFF
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('PUFF-BAR', 'Puff Bar', 'Puff', 'UNI', 20.00, 35.00, 10),
('PUFF-PLUS', 'Puff Plus', 'Puff', 'UNI', 25.00, 45.00, 10),
('PUFF-FLOW', 'Puff Flow', 'Puff', 'UNI', 28.00, 50.00, 10);

-- Sabores Puff Bar
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry', 0 FROM produtos WHERE nome = 'Puff Bar' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon', 0 FROM produtos WHERE nome = 'Puff Bar' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry', 0 FROM produtos WHERE nome = 'Puff Bar' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango', 0 FROM produtos WHERE nome = 'Puff Bar' AND marca = 'Puff';

-- Sabores Puff Plus
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cool Mint', 0 FROM produtos WHERE nome = 'Puff Plus' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lush Ice', 0 FROM produtos WHERE nome = 'Puff Plus' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape', 0 FROM produtos WHERE nome = 'Puff Plus' AND marca = 'Puff';

-- Sabores Puff Flow
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Banana', 0 FROM produtos WHERE nome = 'Puff Flow' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Puff Flow' AND marca = 'Puff';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz', 0 FROM produtos WHERE nome = 'Puff Flow' AND marca = 'Puff';

-- =====================================================

-- MARCA: VAPORESSO
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('VAP-XROS', 'Vaporesso XROS', 'Vaporesso', 'UNI', 30.00, 55.00, 10),
('VAP-LUXE', 'Vaporesso LUXE', 'Vaporesso', 'UNI', 35.00, 65.00, 10);

-- Sabores Vaporesso XROS
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Vaporesso XROS' AND marca = 'Vaporesso';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Vaporesso XROS' AND marca = 'Vaporesso';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Vaporesso XROS' AND marca = 'Vaporesso';

-- Sabores Vaporesso LUXE
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Vaporesso LUXE' AND marca = 'Vaporesso';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Mango', 0 FROM produtos WHERE nome = 'Vaporesso LUXE' AND marca = 'Vaporesso';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint Ice', 0 FROM produtos WHERE nome = 'Vaporesso LUXE' AND marca = 'Vaporesso';

-- =====================================================

-- MARCA: SEXADDICT
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('SEX-5000', 'SexAddict 5000', 'SexAddict', 'UNI', 30.00, 55.00, 10),
('SEX-8000', 'SexAddict 8000', 'SexAddict', 'UNI', 35.00, 65.00, 10),
('SEX-10000', 'SexAddict 10000', 'SexAddict', 'UNI', 40.00, 75.00, 10);

-- Sabores SexAddict 5000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'SexAddict 5000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'SexAddict 5000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'SexAddict 5000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'SexAddict 5000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'SexAddict 5000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lush Ice', 0 FROM produtos WHERE nome = 'SexAddict 5000' AND marca = 'SexAddict';

-- Sabores SexAddict 8000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Watermelon', 0 FROM produtos WHERE nome = 'SexAddict 8000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Lemonade', 0 FROM produtos WHERE nome = 'SexAddict 8000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Mango', 0 FROM produtos WHERE nome = 'SexAddict 8000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cool Mint', 0 FROM produtos WHERE nome = 'SexAddict 8000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Double Apple', 0 FROM produtos WHERE nome = 'SexAddict 8000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Passion Fruit', 0 FROM produtos WHERE nome = 'SexAddict 8000' AND marca = 'SexAddict';

-- Sabores SexAddict 10000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Miami Mint', 0 FROM produtos WHERE nome = 'SexAddict 10000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Triple Berry Ice', 0 FROM produtos WHERE nome = 'SexAddict 10000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cherry Lemon', 0 FROM produtos WHERE nome = 'SexAddict 10000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Kiwi Passion Fruit', 0 FROM produtos WHERE nome = 'SexAddict 10000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Banana', 0 FROM produtos WHERE nome = 'SexAddict 10000' AND marca = 'SexAddict';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon Mint', 0 FROM produtos WHERE nome = 'SexAddict 10000' AND marca = 'SexAddict';

-- =====================================================

-- MARCA: NIKBAR
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('NIK-5500', 'Nikbar 5500', 'Nikbar', 'UNI', 28.00, 52.00, 10),
('NIK-8000', 'Nikbar 8000', 'Nikbar', 'UNI', 33.00, 62.00, 10),
('NIK-10K', 'Nikbar 10K', 'Nikbar', 'UNI', 38.00, 72.00, 10);

-- Sabores Nikbar 5500
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Nikbar 5500' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Nikbar 5500' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Nikbar 5500' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint Ice', 0 FROM produtos WHERE nome = 'Nikbar 5500' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Banana Ice', 0 FROM produtos WHERE nome = 'Nikbar 5500' AND marca = 'Nikbar';

-- Sabores Nikbar 8000
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Red Bull', 0 FROM produtos WHERE nome = 'Nikbar 8000' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Monster', 0 FROM produtos WHERE nome = 'Nikbar 8000' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Red Fruits', 0 FROM produtos WHERE nome = 'Nikbar 8000' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Pineapple Coconut', 0 FROM produtos WHERE nome = 'Nikbar 8000' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Tangerine Ice', 0 FROM produtos WHERE nome = 'Nikbar 8000' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lychee Ice', 0 FROM produtos WHERE nome = 'Nikbar 8000' AND marca = 'Nikbar';

-- Sabores Nikbar 10K
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Kiwi Ice', 0 FROM produtos WHERE nome = 'Nikbar 10K' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Lemon', 0 FROM produtos WHERE nome = 'Nikbar 10K' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Passion Fruit', 0 FROM produtos WHERE nome = 'Nikbar 10K' AND marca = 'Nikbar';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Ice Blast', 0 FROM produtos WHERE nome = 'Nikbar 10K' AND marca = 'Nikbar';

-- =====================================================

-- MARCA: VOZOL
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('VOZ-GEAR', 'Vozol Gear', 'Vozol', 'UNI', 30.00, 56.00, 10),
('VOZ-STAR', 'Vozol Star', 'Vozol', 'UNI', 35.00, 66.00, 10),
('VOZ-NEON', 'Vozol Neon', 'Vozol', 'UNI', 40.00, 76.00, 10);

-- Sabores Vozol Gear
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Vozol Gear' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Vozol Gear' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Vozol Gear' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cool Mint', 0 FROM produtos WHERE nome = 'Vozol Gear' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lychee Ice', 0 FROM produtos WHERE nome = 'Vozol Gear' AND marca = 'Vozol';

-- Sabores Vozol Star
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Vozol Star' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Vozol Star' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Vozol Star' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Pineapple Ice', 0 FROM produtos WHERE nome = 'Vozol Star' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Kiwi Ice', 0 FROM produtos WHERE nome = 'Vozol Star' AND marca = 'Vozol';

-- Sabores Vozol Neon
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Watermelon', 0 FROM produtos WHERE nome = 'Vozol Neon' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Lemonade', 0 FROM produtos WHERE nome = 'Vozol Neon' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Mango', 0 FROM produtos WHERE nome = 'Vozol Neon' AND marca = 'Vozol';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Passion Fruit Orange', 0 FROM produtos WHERE nome = 'Vozol Neon' AND marca = 'Vozol';

-- =====================================================

-- MARCA: RANDM
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('RDM-TORNADO', 'RandM Tornado', 'RandM', 'UNI', 42.00, 80.00, 10),
('RDM-CRYSTAL', 'RandM Crystal', 'RandM', 'UNI', 38.00, 72.00, 10);

-- Sabores RandM Tornado
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Kiwi', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Raspberry', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Pink Lemonade', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Peach', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cool Mint', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'RandM Tornado' AND marca = 'RandM';

-- Sabores RandM Crystal
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'RandM Crystal' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Ice', 0 FROM produtos WHERE nome = 'RandM Crystal' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'RandM Crystal' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cherry Cola', 0 FROM produtos WHERE nome = 'RandM Crystal' AND marca = 'RandM';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Energy Drink', 0 FROM produtos WHERE nome = 'RandM Crystal' AND marca = 'RandM';

-- =====================================================

-- MARCA: CALIBURN
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('CAL-A2', 'Caliburn A2', 'Caliburn', 'UNI', 32.00, 60.00, 10),
('CAL-G2', 'Caliburn G2', 'Caliburn', 'UNI', 36.00, 68.00, 10);

-- Sabores Caliburn A2
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Caliburn A2' AND marca = 'Caliburn';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Caliburn A2' AND marca = 'Caliburn';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Caliburn A2' AND marca = 'Caliburn';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint Ice', 0 FROM produtos WHERE nome = 'Caliburn A2' AND marca = 'Caliburn';

-- Sabores Caliburn G2
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Caliburn G2' AND marca = 'Caliburn';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Caliburn G2' AND marca = 'Caliburn';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Caliburn G2' AND marca = 'Caliburn';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon Mint', 0 FROM produtos WHERE nome = 'Caliburn G2' AND marca = 'Caliburn';

-- =====================================================

-- MARCA: SKE CRYSTAL
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('SKE-BAR', 'SKE Crystal Bar', 'SKE Crystal', 'UNI', 36.00, 68.00, 10),
('SKE-PLUS', 'SKE Crystal Plus', 'SKE Crystal', 'UNI', 40.00, 76.00, 10);

-- Sabores SKE Crystal Bar
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Bar' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Razz Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Bar' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Bar' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cherry Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Bar' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Pink Lemonade', 0 FROM produtos WHERE nome = 'SKE Crystal Bar' AND marca = 'SKE Crystal';

-- Sabores SKE Crystal Plus
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Plus' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Plus' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'SKE Crystal Plus' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon Lime', 0 FROM produtos WHERE nome = 'SKE Crystal Plus' AND marca = 'SKE Crystal';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Cool Mint', 0 FROM produtos WHERE nome = 'SKE Crystal Plus' AND marca = 'SKE Crystal';

-- =====================================================

-- MARCA: IVG
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('IVG-BAR', 'IVG Bar', 'IVG', 'UNI', 34.00, 64.00, 10),
('IVG-PLUS', 'IVG Plus', 'IVG', 'UNI', 38.00, 72.00, 10);

-- Sabores IVG Bar
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Watermelon', 0 FROM produtos WHERE nome = 'IVG Bar' AND marca = 'IVG';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blue Raspberry', 0 FROM produtos WHERE nome = 'IVG Bar' AND marca = 'IVG';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Tropical Fruits', 0 FROM produtos WHERE nome = 'IVG Bar' AND marca = 'IVG';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Fresh Mint', 0 FROM produtos WHERE nome = 'IVG Bar' AND marca = 'IVG';

-- Sabores IVG Plus
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Pineapple Ice', 0 FROM produtos WHERE nome = 'IVG Plus' AND marca = 'IVG';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'IVG Plus' AND marca = 'IVG';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blackcurrant Ice', 0 FROM produtos WHERE nome = 'IVG Plus' AND marca = 'IVG';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon & Lime', 0 FROM produtos WHERE nome = 'IVG Plus' AND marca = 'IVG';

-- =====================================================

-- MARCA: SMOK
INSERT INTO produtos (codigo, nome, marca, unidade, preco_compra, preco_venda, estoque_minimo) VALUES
('SMK-NOVO', 'Smok Novo', 'Smok', 'UNI', 30.00, 56.00, 10),
('SMK-NORD', 'Smok Nord', 'Smok', 'UNI', 34.00, 64.00, 10);

-- Sabores Smok Novo
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Strawberry Ice', 0 FROM produtos WHERE nome = 'Smok Novo' AND marca = 'Smok';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Grape Ice', 0 FROM produtos WHERE nome = 'Smok Novo' AND marca = 'Smok';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Blueberry Ice', 0 FROM produtos WHERE nome = 'Smok Novo' AND marca = 'Smok';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mint', 0 FROM produtos WHERE nome = 'Smok Novo' AND marca = 'Smok';

-- Sabores Smok Nord
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Watermelon Ice', 0 FROM produtos WHERE nome = 'Smok Nord' AND marca = 'Smok';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Peach Ice', 0 FROM produtos WHERE nome = 'Smok Nord' AND marca = 'Smok';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Mango Ice', 0 FROM produtos WHERE nome = 'Smok Nord' AND marca = 'Smok';
INSERT INTO produto_sabores (produto_id, sabor, quantidade) 
SELECT id, 'Lemon Mint', 0 FROM produtos WHERE nome = 'Smok Nord' AND marca = 'Smok';

-- =====================================================
-- VERIFICAR RESULTADOS
-- =====================================================

SELECT 
    p.marca,
    p.nome as produto,
    COUNT(ps.id) as total_sabores,
    p.preco_compra,
    p.preco_venda
FROM produtos p
LEFT JOIN produto_sabores ps ON ps.produto_id = p.id
GROUP BY p.marca, p.nome, p.preco_compra, p.preco_venda
ORDER BY p.marca, p.nome;

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================


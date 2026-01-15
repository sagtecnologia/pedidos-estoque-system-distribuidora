/**
 * Script para adicionar session-manager.js em todas as páginas HTML
 * Este script deve ser executado no PowerShell
 */

const fs = require('fs');
const path = require('path');

// Diretório das páginas
const pagesDir = path.join(__dirname, '../pages');

// Ler todos os arquivos HTML
const files = fs.readdirSync(pagesDir).filter(file => file.endsWith('.html'));

console.log(`Encontrados ${files.length} arquivos HTML`);

files.forEach(file => {
    const filePath = path.join(pagesDir, file);
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Pular se não for uma página autenticada (página de login não precisa)
    if (file === 'auth-callback.html') {
        console.log(`⏭️  Pulando ${file} (página de callback)`);
        return;
    }
    
    // Verificar se já tem o session-manager
    if (content.includes('session-manager.js')) {
        console.log(`✅ ${file} já tem session-manager.js`);
        return;
    }
    
    // Verificar se tem config.js (sinal de que é uma página autenticada)
    if (!content.includes('../js/config.js')) {
        console.log(`⏭️  Pulando ${file} (não é página autenticada)`);
        return;
    }
    
    // Adicionar session-manager.js logo após config.js
    const updated = content.replace(
        /<script src="..\/js\/config.js"><\/script>/,
        '<script src="../js/config.js"></script>\n    <script src="../js/session-manager.js"></script>'
    );
    
    if (updated !== content) {
        fs.writeFileSync(filePath, updated, 'utf8');
        console.log(`✅ Adicionado session-manager.js em ${file}`);
    } else {
        console.log(`⚠️  Não foi possível adicionar em ${file}`);
    }
});

console.log('\n✅ Processo concluído!');

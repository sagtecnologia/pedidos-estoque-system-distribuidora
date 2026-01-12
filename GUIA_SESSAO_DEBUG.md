# 🔒 Guia de Debug do Sistema de Sessão

## ⚙️ Como funciona a renovação da sessão?

### 🎯 Eventos que RENOVAM a sessão:
- ✅ **Cliques** (mousedown, click)
- ✅ **Digitação** (keypress)
- ✅ **Scroll** da página
- ✅ **Toque** em telas touch (touchstart)

### ❌ Eventos que NÃO renovam:
- ❌ **Movimento do mouse** (mousemove) - REMOVIDO propositalmente
  - Muito sensível, causava resets constantes
  - Movimento involuntário não significa uso ativo

### 🛡️ Proteção contra resets excessivos:
- **Throttling de 5 segundos**: Mesmo fazendo ações válidas, o timer só reseta a cada 5 segundos
- Isso evita centenas de resets ao fazer scroll rápido ou múltiplos cliques
- Exemplo: Se você clicar 10 vezes em 2 segundos, conta como apenas 1 renovação

### 💡 Configuração:
Você pode ajustar o throttling em [js/session-manager.js](js/session-manager.js):
```javascript
sessionManager = new SessionManager({
    inactivityTimeout: 15 * 60 * 1000,  // 15 minutos
    warningTime: 2 * 60 * 1000,         // 2 minutos de aviso
    resetThrottleTime: 5 * 1000         // 5 segundos entre resets (ajustável)
});
```

---

## ✅ O que foi implementado:

### 1. **Indicador Visual de Sessão na Navbar**
- Um contador regressivo mostrando o tempo até o logout
- Muda de cor conforme o tempo:
  - 🟢 Verde: Mais de 5 minutos restantes
  - 🟡 Amarelo: Entre 3-5 minutos
  - 🔴 Vermelho (pulsante): Menos de 3 minutos
- **Clique no indicador** para ver detalhes completos da sessão

### 2. **Logs Detalhados no Console**
Agora você verá logs completos no console do navegador:

```
═══════════════════════════════════════════
🔒 SESSION MANAGER INICIALIZADO
═══════════════════════════════════════════
⏰ Hora de início: 10:30:45
⏰ Timeout de inatividade: 15 minutos
⚠️ Aviso antes do logout: 2 minutos
🐛 Debug mode: ATIVO
═══════════════════════════════════════════
```

#### Logs de Atividade:
- `🖱️ Atividade detectada após Xs de inatividade`
- `⏱️ Timer resetado`
- `→ Aviso agendado para: [hora]`
- `→ Logout agendado para: [hora]`

#### Logs Periódicos (a cada 2 minutos):
```
═══════════════════════════════════════════
📊 STATUS DA SESSÃO - 10:32:45
═══════════════════════════════════════════
⏱️ Tempo de sessão: 2m 15s
🖱️ Última atividade: 30s atrás
⚠️ Aviso em: 12m 30s
🚪 Logout em: 14m 30s
🔔 Aviso mostrado: NÃO
═══════════════════════════════════════════
```

### 3. **Modal de Detalhes da Sessão**
Clique no indicador de tempo na navbar para ver:
- ⏱️ Tempo total de sessão
- 🖱️ Tempo desde a última atividade
- ⚠️ Tempo até o aviso
- 🚪 Tempo até o logout
- 📋 Botão para ver logs detalhados no console

## 🧪 Como Testar:

### Teste 1: Verificar se está funcionando
1. Abra qualquer página do sistema (exceto login)
2. Abra o Console do navegador (F12 → Console)
3. Você deve ver os logs de inicialização
4. Verifique se o indicador de tempo aparece na navbar (canto superior direito)

### Teste 2: Verificar contador
1. Observe o contador na navbar
2. Ele deve atualizar a cada segundo
3. Clique no contador para ver detalhes completos

### Teste 3: Testar logout automático (modo rápido)
Para testar sem esperar 15 minutos, no console digite:

```javascript
// Recriar Session Manager com tempo curto (2 minutos)
if (window.sessionManager) {
    window.sessionManager.destroy();
}
window.sessionManager = new SessionManager({
    inactivityTimeout: 2 * 60 * 1000,  // 2 minutos
    warningTime: 30 * 1000              // 30 segundos de aviso
});
```

Agora:
1. Não mexa no mouse/teclado por 1min30s
2. O aviso deve aparecer
3. Se não interagir, logout automático em 30s

### Teste 4: Ver logs de status
No console, digite:
```javascript
window.sessionManager.logStatus()
```

### Teste 5: Ver informações completas
No console, digite:
```javascript
console.table(window.sessionManager.getSessionInfo())
```

## 🔍 Diagnóstico de Problemas:

### Se o logout não está funcionando:

1. **Verificar se o SessionManager foi inicializado:**
```javascript
console.log('SessionManager existe?', !!window.sessionManager);
console.log('SessionManager info:', window.sessionManager.getSessionInfo());
```

2. **Verificar se os timers estão ativos:**
```javascript
window.sessionManager.logStatus()
```

3. **Verificar eventos de atividade:**
   - Mexa o mouse e veja se aparece log de atividade
   - Deve aparecer: `🖱️ Atividade detectada após Xs de inatividade`

4. **Forçar um teste de logout:**
```javascript
// Isso deve executar o logout imediatamente
window.sessionManager.performLogout('teste');
```

### Se não aparecer o indicador na navbar:

1. Verifique se está em uma página diferente do login
2. Verifique no console se há erros
3. Verifique se o elemento existe:
```javascript
console.log('Indicador existe?', !!document.getElementById('session-indicator'));
```

## 📊 Monitoramento em Produção:

### Logs que você DEVE ver no console:
1. ✅ Log de inicialização ao carregar a página
2. ✅ Logs de atividade quando usuário interage
3. ✅ Logs periódicos de status (a cada 2 minutos)
4. ✅ Logs de aviso e logout quando acontecerem

### Se não estiver vendo os logs:
- Certifique-se que o console está aberto
- Recarregue a página
- Verifique se está na página correta (não na de login)

## ⚙️ Ajustar Configurações:

Para mudar o tempo de inatividade, edite [js/session-manager.js](js/session-manager.js) linha 358:

```javascript
sessionManager = new SessionManager({
    inactivityTimeout: 15 * 60 * 1000,  // 15 minutos (em milissegundos)
    warningTime: 2 * 60 * 1000,         // 2 minutos de aviso
    debugMode: true                      // Deixe true para ver logs
});
```

## 🐛 Debug Avançado:

### Ativar modo super verbose:
```javascript
// Logar TODAS as atividades (muito verboso!)
window.sessionManager.activityEvents.forEach(event => {
    document.addEventListener(event, () => {
        console.log(`🔵 Evento: ${event}`);
    });
});
```

### Verificar estado dos timers:
```javascript
console.log('Timer de inatividade:', window.sessionManager.inactivityTimer);
console.log('Timer de aviso:', window.sessionManager.warningTimer);
console.log('Logout agendado para:', new Date(window.sessionManager.logoutScheduledAt));
```

## 📞 Suporte:

Se após seguir este guia o problema persistir:
1. Copie todos os logs do console
2. Tire um print do indicador na navbar
3. Anote o comportamento esperado vs observado

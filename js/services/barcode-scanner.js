// =====================================================
// SERVIÇO: LEITOR DE CÓDIGO DE BARRAS
// =====================================================
// Suporte para:
// - Leitor USB/Serial (via teclado emulado)
// - Câmera do dispositivo (celular/webcam)
// - Entrada manual
// =====================================================

const BarcodeScanner = {
    // Configurações
    config: {
        tempoEntreCaracteres: 50, // ms máximo entre caracteres do leitor físico
        tamanhoMinimoCodigoBarras: 4,
        tamanhoMaximoCodigoBarras: 20,
        habilitarCamera: true,
        habilitarSom: true
    },

    // Estado
    buffer: '',
    ultimoCaractere: 0,
    scannerAtivo: false,
    stream: null,
    videoElement: null,
    canvasElement: null,
    animationFrame: null,

    // Callbacks
    onScan: null,
    onError: null,

    // =====================================================
    // LEITOR FÍSICO (USB/SERIAL)
    // =====================================================

    /**
     * Iniciar monitoramento do leitor físico
     * Leitores físicos funcionam emulando teclado
     */
    iniciarLeitorFisico(callback) {
        this.onScan = callback;
        
        document.addEventListener('keypress', this.handleKeyPress.bind(this));
        
        console.log('✅ Leitor físico iniciado');
        return this;
    },

    /**
     * Parar monitoramento do leitor físico
     */
    pararLeitorFisico() {
        document.removeEventListener('keypress', this.handleKeyPress.bind(this));
        this.buffer = '';
    },

    /**
     * Manipular tecla pressionada
     */
    handleKeyPress(event) {
        const now = Date.now();
        
        // Verificar se é um campo de input ativo (não interceptar)
        const activeElement = document.activeElement;
        const isInputField = activeElement && (
            activeElement.tagName === 'INPUT' ||
            activeElement.tagName === 'TEXTAREA' ||
            activeElement.isContentEditable
        );

        // Se o campo de input for o campo de código de barras, permitir
        const isBarcodeInput = activeElement?.id === 'input-codigo' || 
                              activeElement?.classList.contains('barcode-input');

        if (isInputField && !isBarcodeInput) {
            return; // Não interceptar em campos de texto normais
        }

        // Enter detectado
        if (event.key === 'Enter') {
            if (this.buffer.length >= this.config.tamanhoMinimoCodigoBarras) {
                event.preventDefault();
                this.processarCodigo(this.buffer);
            }
            this.buffer = '';
            return;
        }

        // Verificar timing (leitor físico é muito rápido)
        if (now - this.ultimoCaractere > this.config.tempoEntreCaracteres) {
            this.buffer = '';
        }

        // Adicionar caractere ao buffer
        if (event.key.length === 1) {
            this.buffer += event.key;
            this.ultimoCaractere = now;

            // Se estiver no campo de código de barras, não impedir
            if (!isBarcodeInput) {
                event.preventDefault();
            }
        }
    },

    /**
     * Processar código lido
     */
    async processarCodigo(codigo) {
        codigo = codigo.trim();
        
        if (codigo.length < this.config.tamanhoMinimoCodigoBarras ||
            codigo.length > this.config.tamanhoMaximoCodigoBarras) {
            console.warn('Código inválido:', codigo);
            return;
        }

        console.log('📦 Código lido:', codigo);

        // Som de confirmação
        if (this.config.habilitarSom) {
            this.beep();
        }

        // Callback
        if (this.onScan) {
            await this.onScan(codigo);
        }
    },

    // =====================================================
    // CÂMERA (CELULAR/WEBCAM)
    // =====================================================

    /**
     * Verificar suporte à câmera
     */
    verificarSuporteCamera() {
        return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
    },

    /**
     * Iniciar câmera para leitura de código de barras
     */
    async iniciarCamera(videoElementId, callback) {
        if (!this.verificarSuporteCamera()) {
            throw new Error('Câmera não suportada neste navegador');
        }

        this.onScan = callback;
        this.videoElement = document.getElementById(videoElementId);
        
        if (!this.videoElement) {
            throw new Error('Elemento de vídeo não encontrado');
        }

        try {
            // Solicitar acesso à câmera (preferir traseira em dispositivos móveis)
            this.stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    facingMode: 'environment', // Câmera traseira
                    width: { ideal: 1280 },
                    height: { ideal: 720 }
                }
            });

            this.videoElement.srcObject = this.stream;
            await this.videoElement.play();

            // Criar canvas para captura
            this.canvasElement = document.createElement('canvas');
            
            // Aguardar vídeo carregar
            this.videoElement.onloadedmetadata = () => {
                this.canvasElement.width = this.videoElement.videoWidth;
                this.canvasElement.height = this.videoElement.videoHeight;
                
                // Iniciar processamento de frames
                this.scannerAtivo = true;
                this.processarFrame();
            };

            console.log('✅ Câmera iniciada');
            return true;

        } catch (error) {
            console.error('Erro ao acessar câmera:', error);
            
            if (error.name === 'NotAllowedError') {
                throw new Error('Permissão de câmera negada. Verifique as configurações do navegador.');
            } else if (error.name === 'NotFoundError') {
                throw new Error('Nenhuma câmera encontrada no dispositivo.');
            }
            
            throw error;
        }
    },

    /**
     * Parar câmera
     */
    pararCamera() {
        this.scannerAtivo = false;

        if (this.animationFrame) {
            cancelAnimationFrame(this.animationFrame);
            this.animationFrame = null;
        }

        if (this.stream) {
            this.stream.getTracks().forEach(track => track.stop());
            this.stream = null;
        }

        if (this.videoElement) {
            this.videoElement.srcObject = null;
        }

        console.log('🛑 Câmera parada');
    },

    /**
     * Processar frame de vídeo para detectar código de barras
     */
    async processarFrame() {
        if (!this.scannerAtivo) return;

        try {
            const context = this.canvasElement.getContext('2d');
            context.drawImage(this.videoElement, 0, 0);
            
            const imageData = context.getImageData(
                0, 0,
                this.canvasElement.width,
                this.canvasElement.height
            );

            // Usar BarcodeDetector API (Chrome 83+)
            if ('BarcodeDetector' in window) {
                const detector = new BarcodeDetector({
                    formats: ['ean_13', 'ean_8', 'code_128', 'code_39', 'qr_code', 'upc_a', 'upc_e']
                });

                const barcodes = await detector.detect(this.canvasElement);
                
                if (barcodes.length > 0) {
                    const codigo = barcodes[0].rawValue;
                    await this.processarCodigo(codigo);
                    
                    // Pausar brevemente para evitar leituras duplicadas
                    await this.delay(1000);
                }
            } else {
                // Fallback: usar biblioteca externa (quaggaJS ou zxing)
                console.warn('BarcodeDetector não suportado. Considere usar biblioteca externa.');
            }

        } catch (error) {
            console.error('Erro ao processar frame:', error);
        }

        // Próximo frame
        this.animationFrame = requestAnimationFrame(() => this.processarFrame());
    },

    // =====================================================
    // COMPONENTE UI
    // =====================================================

    /**
     * Criar componente de scanner
     * @returns {string} HTML do componente
     */
    criarComponente(options = {}) {
        const {
            inputId = 'input-codigo',
            placeholder = 'Digite ou escaneie o código',
            showCameraButton = true,
            autoFocus = true
        } = options;

        return `
            <div class="barcode-scanner-container">
                <div class="flex items-center gap-2">
                    <div class="relative flex-1">
                        <input 
                            type="text" 
                            id="${inputId}"
                            class="barcode-input w-full px-4 py-3 pl-10 text-lg border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            placeholder="${placeholder}"
                            ${autoFocus ? 'autofocus' : ''}
                        >
                        <span class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400">
                            <i class="fas fa-barcode text-xl"></i>
                        </span>
                    </div>
                    
                    ${showCameraButton ? `
                        <button 
                            type="button"
                            id="btn-camera-scanner"
                            class="p-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition"
                            title="Usar câmera"
                        >
                            <i class="fas fa-camera text-xl"></i>
                        </button>
                    ` : ''}
                    
                    <button 
                        type="button"
                        id="btn-buscar-produto"
                        class="p-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                        title="Buscar produto"
                    >
                        <i class="fas fa-search text-xl"></i>
                    </button>
                </div>
                
                <!-- Modal da câmera -->
                <div id="modal-camera-scanner" class="modal-backdrop hidden fixed inset-0 bg-black bg-opacity-75 z-50 flex items-center justify-center">
                    <div class="bg-white rounded-lg max-w-lg w-full mx-4 overflow-hidden">
                        <div class="flex justify-between items-center px-4 py-3 bg-gray-100">
                            <h3 class="font-semibold text-gray-800">
                                <i class="fas fa-camera mr-2"></i>Scanner de Câmera
                            </h3>
                            <button 
                                type="button"
                                id="btn-fechar-camera"
                                class="text-gray-500 hover:text-gray-700"
                            >
                                <i class="fas fa-times text-xl"></i>
                            </button>
                        </div>
                        
                        <div class="relative">
                            <video 
                                id="video-scanner" 
                                class="w-full bg-black"
                                playsinline
                            ></video>
                            
                            <!-- Overlay de área de leitura -->
                            <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
                                <div class="w-3/4 h-1/3 border-2 border-green-400 rounded-lg"></div>
                            </div>
                        </div>
                        
                        <div class="p-4 bg-gray-50 text-center text-sm text-gray-600">
                            <p>Posicione o código de barras dentro da área verde</p>
                        </div>
                    </div>
                </div>
            </div>
        `;
    },

    /**
     * Inicializar componente de scanner
     */
    inicializarComponente(inputId = 'input-codigo', onScanCallback) {
        const input = document.getElementById(inputId);
        const btnCamera = document.getElementById('btn-camera-scanner');
        const btnBuscar = document.getElementById('btn-buscar-produto');
        const modalCamera = document.getElementById('modal-camera-scanner');
        const btnFecharCamera = document.getElementById('btn-fechar-camera');

        // Callback
        this.onScan = onScanCallback;

        // Leitor físico (também funciona com input)
        this.iniciarLeitorFisico(onScanCallback);

        // Evento do input
        if (input) {
            input.addEventListener('keypress', async (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    const codigo = input.value.trim();
                    if (codigo) {
                        await this.processarCodigo(codigo);
                        input.value = '';
                    }
                }
            });
        }

        // Botão de busca manual
        if (btnBuscar) {
            btnBuscar.addEventListener('click', async () => {
                const codigo = input?.value.trim();
                if (codigo) {
                    await this.processarCodigo(codigo);
                    input.value = '';
                }
            });
        }

        // Abrir câmera
        if (btnCamera && this.verificarSuporteCamera()) {
            btnCamera.addEventListener('click', async () => {
                try {
                    modalCamera?.classList.remove('hidden');
                    await this.iniciarCamera('video-scanner', async (codigo) => {
                        modalCamera?.classList.add('hidden');
                        this.pararCamera();
                        await onScanCallback(codigo);
                    });
                } catch (error) {
                    showToast(error.message, 'error');
                    modalCamera?.classList.add('hidden');
                }
            });
        } else if (btnCamera) {
            btnCamera.style.display = 'none';
        }

        // Fechar câmera
        if (btnFecharCamera) {
            btnFecharCamera.addEventListener('click', () => {
                this.pararCamera();
                modalCamera?.classList.add('hidden');
            });
        }
    },

    // =====================================================
    // UTILITÁRIOS
    // =====================================================

    /**
     * Validar código EAN-13
     */
    validarEAN13(codigo) {
        if (!/^\d{13}$/.test(codigo)) return false;
        
        let soma = 0;
        for (let i = 0; i < 12; i++) {
            soma += parseInt(codigo[i]) * (i % 2 === 0 ? 1 : 3);
        }
        
        const digitoVerificador = (10 - (soma % 10)) % 10;
        return parseInt(codigo[12]) === digitoVerificador;
    },

    /**
     * Validar código EAN-8
     */
    validarEAN8(codigo) {
        if (!/^\d{8}$/.test(codigo)) return false;
        
        let soma = 0;
        for (let i = 0; i < 7; i++) {
            soma += parseInt(codigo[i]) * (i % 2 === 0 ? 3 : 1);
        }
        
        const digitoVerificador = (10 - (soma % 10)) % 10;
        return parseInt(codigo[7]) === digitoVerificador;
    },

    /**
     * Beep sonoro
     */
    beep() {
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            
            oscillator.frequency.value = 1000;
            oscillator.type = 'sine';
            gainNode.gain.value = 0.1;
            
            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.15);
        } catch (e) {
            // Ignorar
        }
    },

    /**
     * Delay
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
};

// Exportar para uso global
window.BarcodeScanner = BarcodeScanner;

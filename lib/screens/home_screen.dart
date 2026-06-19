import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'login_screen.dart';

// ✅ FORMATADOR DE MOEDA BRASILEIRA
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    text = text.padLeft(3, '0');
    int value = int.parse(text);
    double reais = value / 100;
    String formatted = reais.toStringAsFixed(2).replaceAll('.', ',');
    List<String> parts = formatted.split(',');
    String finalIntPart = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    String finalText = '$finalIntPart,${parts[1]}';
    return TextEditingValue(text: finalText, selection: TextSelection.collapsed(offset: finalText.length));
  }
}

// ✅ GERADOR DE PAYLOAD PIX (Padrão BCB)
class PixPayload {
  static String generate({
    required String pixKey,
    required String merchantName,
    required String merchantBank,
    double? amount,
    String txid = '***',
  }) {
    final finalKey = _formatPixKey(pixKey);
    final cleanName = merchantName.trim().toUpperCase();
    final cleanBank = merchantBank.trim().toUpperCase();

    final finalName = cleanName.isEmpty ? 'RECEBEDOR' : (cleanName.length > 25 ? cleanName.substring(0, 25) : cleanName);
    final finalCity = cleanBank.isEmpty ? 'BRASIL' : (cleanBank.length > 15 ? cleanBank.substring(0, 15) : cleanBank);

    final buffer = StringBuffer();
    buffer.write(_tlv('00', '01'));
    final account = StringBuffer();
    account.write(_tlv('00', 'br.gov.bcb.pix'));
    account.write(_tlv('01', finalKey));
    buffer.write(_tlv('26', account.toString()));
    buffer.write(_tlv('52', '0000'));
    buffer.write(_tlv('53', '986'));
    if (amount != null && amount > 0) buffer.write(_tlv('54', amount.toStringAsFixed(2)));
    buffer.write(_tlv('58', 'BR'));
    buffer.write(_tlv('59', finalName));
    buffer.write(_tlv('60', finalCity));
    final additional = StringBuffer();
    additional.write(_tlv('05', txid));
    buffer.write(_tlv('62', additional.toString()));
    buffer.write('6304');
    
    String payload = buffer.toString();
    return payload + _calculateCRC16(payload);
  }

  static String _formatPixKey(String key) {
    String clean = key.trim();
    if (clean.contains('@')) return clean;
    String onlyNumbers = clean.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.contains('.') || clean.contains('-')) {
      if (onlyNumbers.length == 11) return onlyNumbers;
      if (onlyNumbers.length == 14) return onlyNumbers;
    }
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      if (clean.length == 11) return clean;
      if (clean.length == 14) return clean;
      if (clean.startsWith('55') && (clean.length == 12 || clean.length == 13)) return '+$clean';
      if (clean.length == 10 || clean.length == 11) return '+55$clean';
    }
    return clean;
  }

  static String _tlv(String tag, String value) => '$tag${value.length.toString().padLeft(2, '0')}$value';

  static String _calculateCRC16(String payload) {
    int crc = 0xFFFF;
    for (int i = 0; i < payload.length; i++) {
      crc ^= payload.codeUnitAt(i) << 8;
      for (int j = 0; j < 8; j++) crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
    }
    return (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool get _isPremium => IS_PREMIUM_VERSION;
  
  int _freeQrCount = 0;
  String _email = '';
  String _payload = '';
  bool _isLoading = true;

  Timer? _timer;
  int _secondsRemaining = 120;
  bool _isExpired = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _qrKey = GlobalKey();

  final _keyCtrl = TextEditingController(); 
  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // ⚠️ ALTERE AQUI PARA SEUS DADOS REAIS DE DOAÇÃO E RECEBIMENTO
  final String _donationKey = '26558650819'; 
  final String _donationName = 'Flaviano Antonio de Araujo'; 
  final String _donationBank = 'PagSeguro'; 
  
  // ⚠️ ALTERE AQUI PARA SEUS DADOS DE CONTATO (PREMIUM)
  final String _whatsappNumber = '5511986174159'; // Formato: 55 + DDD + Número (sem espaços)
  final String _contactEmail = 'vendas.neyresolve@gmail.com';

  late final String _donationPayload;

  @override
  void initState() {
    super.initState();
    _donationPayload = PixPayload.generate(
      pixKey: _donationKey,
      merchantName: _donationName,
      merchantBank: _donationBank,
      amount: null,
    );
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_scrollController.hasClients) _scrollController.dispose();
    _keyCtrl.dispose(); _nameCtrl.dispose(); _bankCtrl.dispose(); _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final count = await prefs.getInt('free_qr_count') ?? 0;
    final email = await prefs.getString('user_email');
    
    if (mounted) {
      setState(() {
        _freeQrCount = count;
        _email = email ?? 'Usuário';
        _isLoading = false;
      });
    }
  }

  bool _validateFields() {
    if (_keyCtrl.text.trim().isEmpty) { _showError('Digite a Chave PIX'); return false; }
    if (_nameCtrl.text.trim().isEmpty) { _showError('Digite o Nome do Recebedor'); return false; }
    if (_bankCtrl.text.trim().isEmpty) { _showError('Digite o Nome do Banco'); return false; }
    if (_amountCtrl.text.trim().isEmpty) { _showError('Digite o Valor'); return false; }
    return true;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $msg'), backgroundColor: Colors.red.shade700));
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() { _secondsRemaining = 120; _isExpired = false; });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _isExpired = true;
          _amountCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏱️ QR Code expirado! Campo de valor limpo.'), backgroundColor: Colors.orange)
        );
      }
    });
  }

  String get _formattedTime {
    int min = _secondsRemaining ~/ 60;
    int sec = _secondsRemaining % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _generatePayload() {
    String rawAmount = _amountCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    double? amount = double.tryParse(rawAmount);
    _payload = PixPayload.generate(pixKey: _keyCtrl.text, merchantName: _nameCtrl.text, merchantBank: _bankCtrl.text, amount: amount);
  }

  void _scrollToQrCode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _qrKey.currentContext == null) return;
      try {
        Scrollable.ensureVisible(_qrKey.currentContext!, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, alignment: 0.1);
      } catch (e) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      }
    });
  }

  Future<void> _handleGenerate() async {
    if (!_validateFields()) return;
    
    if (!_isPremium && _freeQrCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Limite Free atingido! Adquira a versão Premium.')));
      return;
    }
    
    _generatePayload();
    _startTimer();
    
    if (!_isPremium) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('free_qr_count', _freeQrCount + 1);
    }
    
    _loadData();
    _scrollToQrCode(); 
  }

  Future<void> _copyPayload() async {
    if (_isExpired || !mounted) return;
    await Clipboard.setData(ClipboardData(text: _payload));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código PIX copiado com sucesso!')));
  }

  Future<void> _copyDonationPayload() async {
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: _donationPayload));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código de doação copiado! Obrigado pelo apoio ❤️'), backgroundColor: Colors.green));
  }

  // ✅ FUNÇÃO PARA ABRIR O WHATSAPP
  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent("Olá! Acabei de fazer o pagamento do PixFlow Premium. Segue o comprovante:")}'
    );
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp. Verifique o número.')),
        );
      }
    }
  }

  // ✅ FUNÇÃO PARA COPIAR O E-MAIL
  Future<void> _copyEmail() async {
    await Clipboard.setData(ClipboardData(text: _contactEmail));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('E-mail copiado: $_contactEmail'), backgroundColor: Colors.blue.shade700),
      );
    }
  }

  // ✅ POPUP DE VENDAS COM QR CODE FIXO E INSTRUÇÕES
    void _showPremiumInfoDialog() {
    // Gera o QR Code com valor fixo de R$ 29,90
    final premiumPayload = PixPayload.generate(
      pixKey: _donationKey,
      merchantName: _donationName,
      merchantBank: _donationBank,
      amount: 29.90, 
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite rolagem completa
      backgroundColor: Colors.transparent, // Fundo transparente para bordas arredondadas
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Puxador visual no topo
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text('Seja Premium', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              
              const Text(
                '💰 Valor do Plano: R\$ 29,90 (Pagamento Único)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 20),
              
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: QrImageView(
                    data: premiumPayload,
                    version: QrVersions.auto,
                    size: 220.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Botão Copiar PIX
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: premiumPayload));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código PIX copiado!'), backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar Código PIX (Copia e Cola)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text(
                'Como receber o App Premium:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(1, 'Escaneie o QR Code ou use o Copia e Cola'),
              _buildInstructionStep(2, 'Faça o pagamento de R\$ 29,90'),
              _buildInstructionStep(3, 'Envie o comprovante pelo WhatsApp ou E-mail'),
              _buildInstructionStep(4, 'Receba o link do App Premium instantaneamente!'),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text(
                '📩 Envie o comprovante:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // Botão WhatsApp
              ElevatedButton.icon(
                onPressed: _launchWhatsApp,
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text('Enviar pelo WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Botão Copiar E-mail
              OutlinedButton.icon(
                onPressed: _copyEmail,
                icon: const Icon(Icons.copy, color: Colors.blue),
                label: Text('Copiar E-mail: $_contactEmail', style: const TextStyle(color: Colors.blue)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ WIDGET AUXILIAR PARA AS INSTRUÇÕES NUMERADAS
  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('PixFlow ${_isPremium ? "⭐ Premium" : "(Free)"}'),
        actions: [
          IconButton(
            icon: Icon(_isPremium ? Icons.verified : Icons.star), 
            tooltip: _isPremium ? 'Versão Premium Ativa' : 'Seja Premium',
            onPressed: _isPremium 
                ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você já possui a versão Premium!')))
                : _showPremiumInfoDialog,
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sair', onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Olá, $_email!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            if (!_isPremium)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('📊 QR Codes restantes: ${5 - _freeQrCount}/5', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              
            const SizedBox(height: 16),
            TextField(controller: _keyCtrl, decoration: const InputDecoration(labelText: 'Chave PIX *', hintText: 'CPF, Telefone ou E-mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key))),
            const SizedBox(height: 10),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome do Recebedor *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 10),
            TextField(controller: _bankCtrl, decoration: const InputDecoration(labelText: 'Banco *', hintText: 'Ex: Nubank, Inter, BB', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance))),
            const SizedBox(height: 10),
            TextField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Valor (R\$) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number, inputFormatters: [CurrencyInputFormatter()]),
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _handleGenerate, 
              icon: const Icon(Icons.qr_code), 
              label: const Text('GERAR QR CODE PIX'), 
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14))
            ),
            
            const SizedBox(height: 24),
            
            if (_payload.isNotEmpty && !_isExpired) ...[
              Container(
                key: _qrKey,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.timer, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text('Expira em: $_formattedTime', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Center(
                  child: QrImageView(
                    data: _payload,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _copyPayload, icon: const Icon(Icons.copy), label: const Text(' COPIAR CÓDIGO PIX'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14))),
            ] else if (_isExpired) ...[
              Container(
                key: _qrKey,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(children: [
                  const Icon(Icons.timer_off, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  const Text('QR Code Expirado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  const Text('O tempo de 2 minutos acabou. Altere os dados e gere um novo código.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () { 
                      if (!mounted) return;
                      setState(() { _payload = ''; _isExpired = false; _amountCtrl.clear(); }); 
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('GERAR NOVO CÓDIGO'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                  )
                ]),
              )
            ],

            if (!_isPremium) ...[
              const SizedBox(height: 32),
              const Divider(thickness: 1, color: Colors.grey),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, color: Colors.red.shade400, size: 24),
                        const SizedBox(width: 8),
                        const Text('Gostou do App? Apoie o Projeto!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sua doação de qualquer valor ajuda a manter o PixFlow gratuito. Obrigado! ☕',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: QrImageView(
                        data: _donationPayload,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _copyDonationPayload,
                        icon: const Icon(Icons.copy, size: 20),
                        label: const Text('Copiar Código Pix da Doação'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/prefs_service.dart';
import '../data/valid_codes.dart'; // ✅ Importa a lista de códigos válidos

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _codeCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(); // Mantido por compatibilidade, mas será ignorado
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _handleActivate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // Pequeno delay para sensação de processamento
    await Future.delayed(const Duration(milliseconds: 600));

    // Pega o código, remove espaços extras e converte para MAIÚSCULO
    final enteredCode = _codeCtrl.text.trim().toUpperCase();

    // 🔍 DEBUG: Imprime no terminal para sabermos o que está acontecendo
    print('🔍 DEBUG: Código digitado: "$enteredCode"');
    print('🔍 DEBUG: Está na lista? ${validWeeklyCodes.contains(enteredCode)}');

    // ✅ VALIDAÇÃO: Verifica se o código existe na nossa lista segura
    if (validWeeklyCodes.contains(enteredCode)) {
      
      // Força 7 dias, ignorando o que o usuário digitou no campo "Dias"
      await PrefsService.activatePremium(7);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Premium Semanal ativado com sucesso! (7 dias)'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Volta para a Home e avisa para recarregar
      }
    } else {
      // ❌ CÓDIGO INVÁLIDO
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Código inválido. Verifique e tente novamente.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ativar Premium ⭐'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Benefícios do Premium:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    _buildBenefit(Icons.qr_code_2, 'Geração de QR Codes ilimitada'),
                    _buildBenefit(Icons.timer_off, 'Sem tempo de expiração (2 min)'),
                    _buildBenefit(Icons.star, 'Apoie o desenvolvimento do app'),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              const Text(
                'Insira seu código de ativação:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de Ativação',
                  hintText: 'Ex: W7-TESTE123',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                textCapitalization: TextCapitalization.characters, // Força maiúsculas no teclado
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Digite o código de ativação';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Campo de dias desabilitado/oculto visualmente, pois é fixo em 7 dias
              TextFormField(
                controller: _daysCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dias do Plano',
                  hintText: '7 (Fixo)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                enabled: false, // Desabilita edição, pois é sempre 7 dias
              ),

              const SizedBox(height: 8),
              Text(
                '💡 Dica para teste: Use o código W7-TESTE123',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'ATIVAR PREMIUM AGORA',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
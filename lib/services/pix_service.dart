class PixPayload {
  /// Gera um payload PIX estático válido para qualquer banco brasileiro.
  static String generate({
    required String pixKey,      // E-mail, telefone, CPF, CNPJ ou chave aleatória
    required String merchantName, // Nome do recebedor (máx 25 chars)
    required String merchantCity, // Cidade (máx 15 chars)
    double? amount,              // Valor (opcional)
    String txid = '***',         // ID da transação ('***' para estático)
  }) {
    final buffer = StringBuffer();

    // 00: Payload Format Indicator
    buffer.write(_tlv('00', '01'));

    // 26: Merchant Account Information
    final account = StringBuffer();
    account.write(_tlv('00', 'br.gov.bcb.pix'));
    account.write(_tlv('01', pixKey));
    buffer.write(_tlv('26', account.toString()));

    // 52: Merchant Category Code
    buffer.write(_tlv('52', '0000'));

    // 53: Transaction Currency (986 = BRL)
    buffer.write(_tlv('53', '986'));

    // 54: Transaction Amount (opcional)
    if (amount != null) {
      buffer.write(_tlv('54', amount.toStringAsFixed(2)));
    }

    // 58: Country Code
    buffer.write(_tlv('58', 'BR'));

    // 59: Merchant Name (corta se >25)
    buffer.write(_tlv('59', merchantName.length > 25 ? merchantName.substring(0, 25) : merchantName));

    // 60: Merchant City (corta se >15)
    buffer.write(_tlv('60', merchantCity.length > 15 ? merchantCity.substring(0, 15) : merchantCity));

    // 62: Additional Data Field
    final additional = StringBuffer();
    additional.write(_tlv('05', txid));
    buffer.write(_tlv('62', additional.toString()));

    // 63: CRC16 (placeholder inicial)
    buffer.write('6304');

    String payload = buffer.toString();
    return payload + _crc16Ccitt(payload);
  }

  // Formata Tag-Length-Value
  static String _tlv(String tag, String value) {
    return '$tag${value.length.toString().padLeft(2, '0')}$value';
  }

  // Calcula CRC16-CCITT-FALSE (padrão PIX)
  static String _crc16Ccitt(String payload) {
    int crc = 0xFFFF;
    for (int i = 0; i < payload.length; i++) {
      crc ^= payload.codeUnitAt(i) << 8;
      for (int j = 0; j < 8; j++) {
        crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
      }
    }
    return (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
import 'dart:io';
import 'dart:math';

void main() async {
  print('🛠️  Gerador de Códigos de Ativação (Plano Semanal - 7 Dias)');
  print('------------------------------------------------------------');
  
  stdout.write('Quantos códigos deseja gerar? ');
  String? input = stdin.readLineSync();
  int quantity = int.tryParse(input ?? '1') ?? 1;

  List<String> codes = [];
  final random = Random.secure();
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  for (int i = 0; i < quantity; i++) {
    String code = 'W7-'; 
    for (int j = 0; j < 8; j++) {
      code += chars[random.nextInt(chars.length)];
    }
    codes.add(code);
  }

  print('\n✅ Códigos Gerados com Sucesso!');
  for (String code in codes) {
    print('🔑 $code  (7 Dias)');
  }

  final file = File('codigos_gerados.txt');
  String fileContent = codes.join('\n');
  
  if (await file.exists()) {
    await file.writeAsString('\n$fileContent', mode: FileMode.append);
  } else {
    await file.writeAsString(fileContent);
  }
  
  print('\n💾 Códigos salvos em: ${file.absolute.path}');
}
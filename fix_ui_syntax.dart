import 'dart:io';
void main() {
  final file = File('lib/screens/predictions/match_detail_screen.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(
      "Cyber.display(12, color: Cyber.red, bold: true)",
      "Cyber.display(12, color: Cyber.red, weight: FontWeight.bold)"
  );
  
  content = content.replaceAll(
      "Cyber.display(12, color: Cyber.cyan, bold: true)",
      "Cyber.display(12, color: Cyber.cyan, weight: FontWeight.bold)"
  );
  
  content = content.replaceAll(
      "Cyber.textMain",
      "Cyber.textPrimary"
  );
  
  content = content.replaceAll(
      "bold: true",
      "weight: FontWeight.bold"
  );
  
  file.writeAsStringSync(content);
  print('Fixed UI syntax errors.');
}

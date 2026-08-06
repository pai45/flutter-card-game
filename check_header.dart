import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final res = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/23810/summary?event=1496576'));
  final summaryData = json.decode(res.body);
  final header = summaryData['header'];
  final comp = header['competitions']?[0];
  print('comp is null: ${comp == null}');
  if (comp != null) {
    final competitors = comp['competitors'] as List?;
    print('competitors length: ${competitors?.length}');
    if (competitors != null && competitors.length >= 2) {
      final teamData = competitors.firstWhere((c) => true, orElse: () => null);
      print('competitor keys: ${teamData.keys}');
      final ls = teamData['linescores'] as List?;
      print('linescores: $ls');
    }
  }
}

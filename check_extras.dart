import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final res = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/23810/summary?event=1496576'));
  final data = json.decode(res.body);
  final comp = data['header']['competitions'][0];
  final competitors = comp['competitors'] as List;
  
  for (var c in competitors) {
    print('Team: ${c['team']['displayName']}');
    final linescores = c['linescores'] as List?;
    if (linescores != null) {
      for (var l in linescores) {
        if (l['period'] == 1) {
            final fow = l['fow'] as List?;
            if (fow != null && fow.isNotEmpty) {
                print(' First FOW: ${fow[0]}');
            }
        }
      }
    }
  }
}

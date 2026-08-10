import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final res = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/23810/summary?event=1496576'));
  final data = json.decode(res.body);
  final rosters = data['rosters'] as List?;
  if (rosters != null) {
      for (var r in rosters) {
         for (var p in r['roster']) {
            final a = p['athlete'];
            if (a != null) {
                final shortName = a['shortName']?.toString();
                final displayName = a['displayName']?.toString();
                print('shortName: "$shortName", displayName: "$displayName"');
            }
         }
      }
  }
}

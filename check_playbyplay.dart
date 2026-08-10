import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final res = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/23810/playbyplay?event=1496576'));
  final data = json.decode(res.body);
  final comm = data['commentary'] as Map?;
  if (comm != null) {
    print('Commentary map keys: ${comm.keys}');
    if (comm.containsKey('items')) {
      final items = comm['items'] as List?;
      print('Found ${items?.length} commentary items');
      if (items != null && items.isNotEmpty) {
        print('First item keys: ${items.first.keys}');
        print('First item text: ${items.first['text']}');
      }
    }
  }
}

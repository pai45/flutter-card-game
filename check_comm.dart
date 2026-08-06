// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(
    Uri.parse(
      'https://site.api.espn.com/apis/site/v2/sports/cricket/23810/playbyplay?event=1496576',
    ),
  );
  final data = json.decode(res.body);
  final items = data['commentary']?['items'] as List?;
  if (items != null && items.isNotEmpty) {
    for (int i = 0; i < 5; i++) {
      print('--- Item $i ---');
      print(json.encode(items[i]));
    }
  }
}

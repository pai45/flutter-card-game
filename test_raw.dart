import 'dart:convert';
import 'dart:io';

void main() async {
  final now = DateTime.now();
  for (var offset = -7; offset <= 3; offset++) {
    final date = now.add(Duration(days: offset));
    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    
    final url = Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard?dates=$dateStr');
    try {
      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final events = data['events'] as List? ?? [];
        if (events.isNotEmpty) {
          print('Date $dateStr: Found ${events.length} WNBA events');
        }
      }
    } catch (e) {
      print('Error on $dateStr: $e');
    }
  }
}

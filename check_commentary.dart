import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  final res = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/23810/summary?event=1496576'));
  final summaryData = json.decode(res.body);
  
  print('Has commentary: ${summaryData.containsKey('commentary')}');
  if (summaryData.containsKey('commentary')) {
    final commentaryList = summaryData['commentary'] as List?;
    print('Commentary length: ${commentaryList?.length}');
    if (commentaryList != null && commentaryList.isNotEmpty) {
      print('First commentary item: ${commentaryList.first}');
    }
  } else {
    // Check if it's somewhere else like inside competitions or keyEvents
    print('Has keyEvents: ${summaryData.containsKey('keyEvents')}');
    print('Has playByPlay: ${summaryData.containsKey('playByPlay')}');
    
    // Print all top level keys
    print('Top level keys: ${summaryData.keys}');
  }
}

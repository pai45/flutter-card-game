import 'lib/services/espn_score_service.dart';

void main() async {
  final service = EspnScoreService();
  final matches = await service.fetchDynamicMatches();
  for (var m in matches) {
    if (m.home.name.contains('Belgium') || m.home.name.contains('Denmark')) {
      print('Found match: \ vs \ (ID: \, League: \)');
    }
  }
}

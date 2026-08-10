import 'dart:io';

void main() {
  final file = File('lib/screens/predictions/match_detail_screen.dart');
  String content = file.readAsStringSync();

  // Update _CommentaryTab itemBuilder
  content = content.replaceFirst(
    '''        itemBuilder: (context, index) {
          final item = commentary[index];
          return _CommentaryRow(item: item);
        },''',
    '''        itemBuilder: (context, index) {
          final item = commentary[index];
          if (match.sport == Sport.cricket) {
             return _CricketCommentaryRow(item: item);
          }
          return _CommentaryRow(item: item);
        },''',
  );

  // Add _CricketCommentaryRow before _CommentaryRow
  final cricketRow = '''
class _CricketCommentaryRow extends StatelessWidget {
  const _CricketCommentaryRow({required this.item});
  final MatchCommentary item;

  @override
  Widget build(BuildContext context) {
    Widget? badge;
    if (item.isWicket) {
       badge = Container(
         width: 24,
         height: 24,
         alignment: Alignment.center,
         decoration: BoxDecoration(
           color: Cyber.red.withValues(alpha: 0.2),
           border: Border.all(color: Cyber.red),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Text('W', style: Cyber.display(12, color: Cyber.red, bold: true)),
       );
    } else if (item.scoreValue != null && (item.scoreValue == 4 || item.scoreValue == 6)) {
       badge = Container(
         width: 24,
         height: 24,
         alignment: Alignment.center,
         decoration: BoxDecoration(
           color: Cyber.cyan.withValues(alpha: 0.2),
           border: Border.all(color: Cyber.cyan),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Text('\${item.scoreValue}', style: Cyber.display(12, color: Cyber.cyan, bold: true)),
       );
    } else if (item.scoreValue != null) {
       badge = Container(
         width: 24,
         height: 24,
         alignment: Alignment.center,
         child: Text('\${item.scoreValue}', style: Cyber.body(12, color: Cyber.textMain.withValues(alpha: 0.7))),
       );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.34),
        border: Border.all(color: Cyber.line.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.minute.isNotEmpty) ...[
            SizedBox(
              width: 36,
              child: Text(
                item.minute,
                style: Cyber.display(12, color: Cyber.cyan).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (badge != null) ...[
            badge,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.shortText != null && item.shortText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item.shortText!,
                      style: Cyber.body(14, color: Cyber.textMain, bold: true),
                    ),
                  ),
                Text(
                  item.text,
                  style: Cyber.body(14, color: Cyber.textMain.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
''';

  content = content.replaceFirst(
    'class _CommentaryRow',
    '$cricketRow\nclass _CommentaryRow',
  );

  file.writeAsStringSync(content);
  print('Done.');
}

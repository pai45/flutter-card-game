import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/catalogue_search.dart';
import 'cyber/cyber_widgets.dart';
import 'game_scaffold.dart';

/// Common interaction and empty states for local catalogue search routes.
class CatalogueSearchScaffold extends StatefulWidget {
  const CatalogueSearchScaffold({
    required this.title,
    required this.hint,
    required this.introduction,
    required this.resultsBuilder,
    super.key,
  });
  final String title;
  final String hint;
  final String introduction;
  final Widget Function(BuildContext, String) resultsBuilder;
  @override
  State<CatalogueSearchScaffold> createState() =>
      _CatalogueSearchScaffoldState();
}

class _CatalogueSearchScaffoldState extends State<CatalogueSearchScaffold> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
    title: widget.title,
    leading: IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back_ios_new, color: Cyber.cyan, size: 18),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CyberSearchField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            hintText: widget.hint,
            onChanged: (value) =>
                setState(() => _query = normalizeCatalogueQuery(value)),
            onSubmitted: (_) => _focus.unfocus(),
            onClear: () {
              _controller.clear();
              setState(() => _query = '');
              _focus.requestFocus();
            },
          ),
        ),
        Expanded(
          child: _query.length < 2
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    CyberNoDataState(
                      icon: Icons.search_rounded,
                      title: _query.isEmpty
                          ? 'START YOUR SEARCH'
                          : 'ONE MORE CHARACTER',
                      message: _query.isEmpty
                          ? widget.introduction
                          : 'Enter at least two characters to search.',
                    ),
                  ],
                )
              : widget.resultsBuilder(context, _query),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../config/theme.dart';
import 'hub_backgrounds.g.dart';

export 'hub_backgrounds.g.dart';

/// Shared illustrated world behind Matches and Games. This layer never handles
/// input, announces semantics, changes scroll geometry or runs an ambient ticker.
class CyberHubBackground extends StatelessWidget {
  const CyberHubBackground({required this.theme, super.key});

  final HubBackgroundTheme theme;

  // Cache per bundle so tests, themes and injected bundles remain isolated.
  // Catch missing-file errors before the SVG package starts its decode future.
  static final _assets = Expando<Map<String, Future<String?>>>();
  static Future<String?> _load(AssetBundle bundle, String asset) {
    final cache = _assets[bundle] ??= <String, Future<String?>>{};
    return cache.putIfAbsent(
      asset,
      () => bundle
          .loadString(asset)
          .then<String?>(
            (svg) => svg,
            onError: (Object _, StackTrace _) => null,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final format =
                  constraints.maxWidth >= HubBackgroundSpec.wideMinWidth
                  ? 'wide'
                  : 'portrait';
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.backgroundGradient,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Keep layers mounted: incoming artwork is decoded before a
                    // selection, and interrupted fades cannot retain stale art.
                    for (final candidate in HubBackgroundTheme.values)
                      AnimatedOpacity(
                        key: ValueKey('hub-background-${candidate.name}'),
                        opacity: candidate == theme ? 1 : 0,
                        duration: reducedMotion
                            ? Duration.zero
                            : HubBackgroundSpec.transition,
                        curve: Curves.easeOut,
                        child: FutureBuilder<String?>(
                          key: ValueKey(
                            'hub-artwork-${candidate.name}-$format',
                          ),
                          future: _load(
                            DefaultAssetBundle.of(context),
                            'assets/backgrounds/hub/${candidate.name}-$format.svg',
                          ),
                          builder: (context, snapshot) => snapshot.hasData
                              ? SvgPicture.string(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topRight,
                                  excludeFromSemantics: true,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.expand(),
                                )
                              : const SizedBox.expand(),
                        ),
                      ),
                    for (final gradient in [
                      HubBackgroundSpec.edgeOverlay,
                      HubBackgroundSpec.diagonalOverlay,
                      HubBackgroundSpec.verticalOverlay,
                    ])
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: gradient),
                      ),
                    FutureBuilder<String?>(
                      future: _load(
                        DefaultAssetBundle.of(context),
                        'assets/backgrounds/hub/cyber-overlay.svg',
                      ),
                      builder: (context, snapshot) => snapshot.hasData
                          ? SvgPicture.string(
                              snapshot.data!,
                              fit: BoxFit.fill,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.expand(),
                            )
                          : const SizedBox.expand(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

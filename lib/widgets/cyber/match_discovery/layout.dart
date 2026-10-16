part of '../match_discovery.dart';

/// Lays out real children twice: natural heights first, then the row maximum.
/// Unlike IntrinsicHeight this supports SVG and responsive LayoutBuilder children.
class EditorialEqualRow extends MultiChildRenderObjectWidget {
  const EditorialEqualRow({
    required super.children,
    this.itemWidth,
    this.gap = 16,
    super.key,
  });
  final double? itemWidth;
  final double gap;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EditorialEqualRowRender(itemWidth, gap);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final render = renderObject as _EditorialEqualRowRender;
    render
      ..itemWidth = itemWidth
      ..gap = gap;
    render.markNeedsLayout();
  }
}

class _EditorialRowParentData extends ContainerBoxParentData<RenderBox> {}

class _EditorialEqualRowRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EditorialRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EditorialRowParentData> {
  _EditorialEqualRowRender(this.itemWidth, this.gap);
  double? itemWidth;
  double gap;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EditorialRowParentData) {
      child.parentData = _EditorialRowParentData();
    }
  }

  @override
  void performLayout() {
    final width =
        itemWidth ??
        ((constraints.maxWidth - gap * (childCount - 1)) / childCount).clamp(
          0,
          double.infinity,
        );
    var height = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      if (child.size.height > height) height = child.size.height;
      child = (child.parentData! as _EditorialRowParentData).nextSibling;
    }
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: width, height: height),
        parentUsesSize: true,
      );
      final data = child.parentData! as _EditorialRowParentData;
      data.offset = Offset(x, 0);
      x += width + gap;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(childCount == 0 ? 0 : x - gap, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class EditorialPairedGrid extends StatelessWidget {
  const EditorialPairedGrid({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final one =
        MediaQuery.sizeOf(context).width < MatchDiscoveryTokens.collapseWidth ||
        MediaQuery.textScalerOf(context).scale(14) / 14 >=
            MatchDiscoveryTokens.collapseTextScale;
    if (one) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: MatchDiscoveryTokens.gridGap),
            children[i],
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: MatchDiscoveryTokens.gridGap),
          EditorialEqualRow(
            gap: MatchDiscoveryTokens.gridGap,
            children: [
              children[i],
              if (i + 1 < children.length) children[i + 1],
            ],
          ),
        ],
      ],
    );
  }
}

/// A manual, content-height rail: two cards and a peek, or wider accessible cards.
class EditorialCarousel extends StatefulWidget {
  const EditorialCarousel({
    required this.id,
    required this.label,
    required this.children,
    super.key,
  });
  final String id, label;
  final List<Widget> children;
  @override
  State<EditorialCarousel> createState() => _EditorialCarouselState();
}

class _EditorialCarouselState extends State<EditorialCarousel> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final accessible =
          MediaQuery.sizeOf(context).width <
              MatchDiscoveryTokens.collapseWidth ||
          MediaQuery.textScalerOf(context).scale(14) / 14 >=
              MatchDiscoveryTokens.collapseTextScale;
      final visible = accessible
          ? MatchDiscoveryTokens.personalCarouselAccessibleVisible
          : MatchDiscoveryTokens.personalCarouselVisible;
      final gaps = visible.floor();
      final width =
          ((box.maxWidth - gaps * MatchDiscoveryTokens.gridGap) / visible)
              .clamp(0.0, double.infinity);
      return Semantics(
        label: widget.label,
        container: true,
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent || !_controller.hasClients) {
              return KeyEventResult.ignored;
            }
            final key = event.logicalKey;
            if (![
              LogicalKeyboardKey.arrowLeft,
              LogicalKeyboardKey.arrowRight,
              LogicalKeyboardKey.home,
              LogicalKeyboardKey.end,
            ].contains(key)) {
              return KeyEventResult.ignored;
            }
            final offset = key == LogicalKeyboardKey.home
                ? 0.0
                : key == LogicalKeyboardKey.end
                ? _controller.position.maxScrollExtent
                : _controller.offset +
                      (key == LogicalKeyboardKey.arrowRight ? 1 : -1) *
                          (width + MatchDiscoveryTokens.gridGap);
            _controller.jumpTo(
              offset.clamp(0.0, _controller.position.maxScrollExtent),
            );
            return KeyEventResult.handled;
          },
          child: SingleChildScrollView(
            key: PageStorageKey(widget.id),
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: EditorialEqualRow(
              itemWidth: width,
              gap: MatchDiscoveryTokens.gridGap,
              children: widget.children,
            ),
          ),
        ),
      );
    },
  );
}

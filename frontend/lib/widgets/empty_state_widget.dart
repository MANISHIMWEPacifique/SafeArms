import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? subtitle;
  final Widget? actionButton;
  final double iconSize;
  final EdgeInsets padding;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    this.title,
    this.subtitle,
    this.actionButton,
    this.iconSize = 64,
    this.padding = const EdgeInsets.all(48),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final isNarrow = width < 420;
        final isShort = height < 260;
        final isCompact = isNarrow || height < 360;
        final adaptiveIconSize = _clampDouble(
          iconSize * (isShort ? 0.58 : (isCompact ? 0.75 : 1)),
          32,
          iconSize,
        );
        final adaptivePadding = EdgeInsets.symmetric(
          horizontal: isNarrow ? 16 : (isCompact ? 24 : padding.left),
          vertical: isShort ? 12 : (isCompact ? 20 : padding.top),
        );
        final titleSize = isCompact ? 16.0 : 18.0;
        final subtitleSize = isCompact ? 13.0 : 14.0;
        final primaryGap = isShort ? 8.0 : 16.0;
        final actionGap = isShort ? 12.0 : 24.0;

        final content = Padding(
          padding: adaptivePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: adaptiveIconSize, color: const Color(0xFF78909C)),
              SizedBox(height: primaryGap),
              if (title != null)
                Text(
                  title!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (subtitle != null) ...[
                if (title != null) SizedBox(height: isShort ? 4 : 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                      color: const Color(0xFF78909C), fontSize: subtitleSize),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionButton != null) ...[
                SizedBox(height: actionGap),
                actionButton!,
              ],
            ],
          ),
        );

        if (isShort) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Center(child: content),
            ),
          );
        }

        return Center(child: content);
      },
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

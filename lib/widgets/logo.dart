import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.sizeFactor = 0.4,
    this.alignTop = false,
    this.compact = false,
    this.showTagline = true,
  });

  final double sizeFactor;
  final bool alignTop;
  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final double size = compact
        ? 40
        : (mq.width < mq.height ? mq.width : mq.height) * sizeFactor;

    final icon = Icon(
      Icons.travel_explore_rounded,
      size: compact ? 20 : (size * 0.2).toDouble(),
      color: Color(0xFFF5DEB3),
    );

    final title = Text(
      'Find-IT',
      style: TextStyle(
        fontSize: compact ? 16 : (size * 0.1).toDouble(),
        fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
      ),
    );

    final tagline = Text(
      'Helping you find what matters!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: compact ? 8 : (size * 0.045).toDouble(),
        color: Color(0xFFFFF8E7),
        fontStyle: FontStyle.italic,
      ),
    );

    final logoContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        if (!compact) SizedBox(height: (size * 0.04).toDouble()),
        title,
        if (showTagline && !compact) ...[
          SizedBox(height: (size * 0.015).toDouble()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: (size * 0.12).toDouble()),
            child: tagline,
          ),
        ],
      ],
    );

    final circleLogo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A4140),
        boxShadow: compact
            ? []
            : [
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Center(child: logoContent),
    );

    return alignTop
        ? Padding(
      padding: EdgeInsets.only(top: mq.height * 0.08),
      child: circleLogo,
    )
        : circleLogo;
  }
}

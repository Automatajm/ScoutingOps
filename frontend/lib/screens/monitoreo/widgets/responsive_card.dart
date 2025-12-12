import 'package:flutter/material.dart';

class ResponsiveCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? titleColor;
  final bool showBorder;
  final Widget? headerAction;

  const ResponsiveCard({
    Key? key,
    required this.title,
    required this.child,
    this.padding,
    this.titleColor,
    this.showBorder = true,
    this.headerAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: showBorder
            ? BorderSide(color: Colors.grey.shade200)
            : BorderSide.none,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (headerAction != null) headerAction!,
                ],
              ),
              const Divider(height: 24),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

// Extensión de ResponsiveCard para secciones colapsables
class CollapsibleCard extends StatefulWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? titleColor;
  final bool initiallyExpanded;
  final bool showBorder;

  const CollapsibleCard({
    Key? key,
    required this.title,
    required this.child,
    this.padding,
    this.titleColor,
    this.initiallyExpanded = true,
    this.showBorder = true,
  }) : super(key: key);

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: widget.showBorder
            ? BorderSide(color: Colors.grey.shade200)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título y botón de expansión
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
            },
            child: Padding(
              padding:
                  widget.padding ?? EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: widget.titleColor,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Contenido colapsable - MODIFICADO PARA CORREGIR DESBORDAMIENTO
          AnimatedCrossFade(
            firstChild: Padding(
              padding: widget.padding != null
                  ? EdgeInsets.only(
                      left: (widget.padding as EdgeInsets).left,
                      right: (widget.padding as EdgeInsets).right,
                      bottom: (widget.padding as EdgeInsets).bottom,
                    )
                  : EdgeInsets.only(
                      left: isSmallScreen ? 12 : 16,
                      right: isSmallScreen ? 12 : 16,
                      bottom: isSmallScreen ? 12 : 16,
                    ),
              // Envolvemos el contenido en un SingleChildScrollView para evitar el desbordamiento
              child: widget.child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

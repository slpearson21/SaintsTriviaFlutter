import 'package:material_ui/material_ui.dart';

/// An icon that keeps its drawn size when text is scaled (16–24).
class StIcon extends StatelessWidget {
  const StIcon(this.icon, {super.key, this.size = 24, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color, applyTextScaling: false);
  }
}

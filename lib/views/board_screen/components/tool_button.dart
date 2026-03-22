import 'package:fluent_ui/fluent_ui.dart';

class ToolButton extends StatelessWidget {

  final IconData icon;
  final String title;
  final bool checked;
  final VoidCallback onPressed;

  const ToolButton({super.key, required this.icon, required this.title, required this.checked, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ToggleButton(
      checked: checked,
      onChanged: (_) => onPressed(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            Text(title, maxLines: 1),
          ],
        ),
      ),
    );
  }

}

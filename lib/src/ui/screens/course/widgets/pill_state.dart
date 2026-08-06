import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PillState extends StatelessWidget {
  const PillState({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: active
                ? const Color(0xFF22C55E).withOpacity(.90)
                : const Color(0xFFEF4444).withOpacity(.90),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              active ? 'Activa' : 'Inactiva',
              style: TextStyle(
                color: Colors.white.withOpacity(.90),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Switch(
          //   value: active,
          //   onChanged: (v) {
          //     setState(() => active = v);
          //     HapticFeedback.selectionClick();
          //   },
          //   activeColor: AppTheme.accent,
          // ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../utils/sound_manager.dart';
import 'ui_bits.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = SoundManager.instance;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ListenableBuilder(
        listenable: sm,
        builder: (context, _) => Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Settings', style: fancyText(32, color: const Color(0xFFEF6C00))),
              const SizedBox(height: 14),
              _row(
                sm.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                sm.muted ? 'Sound: Muted' : 'Sound: On',
                !sm.muted,
                (v) => sm.setMuted(!v),
              ),
              _row(
                sm.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
                sm.musicOn ? 'Music: On' : 'Music: Off',
                sm.musicOn,
                (v) => sm.setMusicOn(v),
              ),
              const SizedBox(height: 14),
              ChunkyButton(
                label: 'Done',
                icon: Icons.check_rounded,
                color: const Color(0xFF43A047),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFEF6C00), size: 30),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: fancyText(20, color: const Color(0xFF5D4037)))),
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF43A047)),
        ],
      ),
    );
  }
}

/// Dimmed full-screen card (pause / win / lose).
class ShotOverlay extends StatelessWidget {
  const ShotOverlay({
    super.key,
    required this.title,
    required this.titleColor,
    required this.children,
    this.stars,
    this.subtitle,
  });
  final String title;
  final Color titleColor;
  final List<Widget> children;
  final int? stars;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0x99000000),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Panel(
            accent: titleColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: fancyText(36, color: titleColor)),
                if (stars != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Icon(
                          i < stars! ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFB300),
                          size: 52,
                        ),
                    ],
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, textAlign: TextAlign.center, style: fancyText(18, color: const Color(0xFF5D4037))),
                ],
                const SizedBox(height: 14),
                ...children.expand((w) => [w, const SizedBox(height: 10)]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

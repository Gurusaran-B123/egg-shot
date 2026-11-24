import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/progress_store.dart';
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: ListenableBuilder(
        listenable: sm,
        builder: (context, _) => SingleChildScrollView(
          child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Settings', style: fancyText(26, color: const Color(0xFFEF6C00))),
              const SizedBox(height: 8),
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
              _about(context),
              const SizedBox(height: 14),
              ChunkyButton(
                label: 'Done',
                fontSize: 17,
                icon: Icons.check_rounded,
                color: const Color(0xFF43A047),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  static Future<void> _openSite(BuildContext context) async {
    const url = 'https://deplo-apps.vercel.app/';
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      await Clipboard.setData(const ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied: https://deplo-apps.vercel.app/')),
        );
      }
    }
  }

  /// Dropdown: developer credit, rights and feedback link.
  Widget _about(BuildContext context) {
    final brown = fancyText(14, color: const Color(0xFF5D4037));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          leading: const Icon(Icons.info_rounded, color: Color(0xFFEF6C00), size: 24),
          title: Text('About & Feedback', maxLines: 1, overflow: TextOverflow.ellipsis, style: fancyText(16, color: const Color(0xFF5D4037))),
          iconColor: const Color(0xFFEF6C00),
          collapsedIconColor: const Color(0xFFEF6C00),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Text('Egg Shot', style: fancyText(18, color: const Color(0xFFEF6C00))),
            const SizedBox(height: 6),
            Text('Developed and all rights reserved by', textAlign: TextAlign.center, style: brown),
            Text('Mr. GURUSARAN B', textAlign: TextAlign.center, style: fancyText(16, color: const Color(0xFF3E2723))),
            const SizedBox(height: 6),
            Text('A Deplofree creation', textAlign: TextAlign.center, style: brown),
            const SizedBox(height: 12),
            ChunkyButton(
              label: 'Feedback / Website',
              icon: Icons.open_in_new_rounded,
              color: const Color(0xFF1E88E5),
              fontSize: 15,
              onTap: () => _openSite(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFEF6C00), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fancyText(16, color: const Color(0xFF5D4037))),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF43A047)),
          ),
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


/// Shop: spend stars on power shots and freeze.
class ShopDialog extends StatelessWidget {
  const ShopDialog({super.key});

  static const _icons = ['egg_bomb', 'egg_snake', ''];

  @override
  Widget build(BuildContext context) {
    final w = Wallet.instance;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: ListenableBuilder(
        listenable: w,
        builder: (context, _) => SingleChildScrollView(
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Power Shop', style: fancyText(26, color: const Color(0xFFEF6C00))),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 24),
                    const SizedBox(width: 4),
                    Text('${w.balance} stars', style: fancyText(18, color: const Color(0xFF5D4037))),
                  ],
                ),
                const SizedBox(height: 8),
                for (var k = 0; k < 3; k++) _item(context, w, k),
                const SizedBox(height: 8),
                Text('Earn stars by finishing levels.', style: fancyText(13, color: const Color(0xFF8D6E63))),
                const SizedBox(height: 8),
                ChunkyButton(
                  label: 'Close',
                  fontSize: 17,
                  icon: Icons.check_rounded,
                  color: const Color(0xFF43A047),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, Wallet w, int k) {
    final can = w.balance >= Wallet.costs[k];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 40,
            child: k == 2
                ? const Icon(Icons.ac_unit_rounded, color: Color(0xFF29B6F6), size: 32)
                : Image.asset('assets/images/${_icons[k]}.png',
                    errorBuilder: (c, e, s) => const Icon(Icons.circle, size: 36)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${Wallet.names[k]}  x${w.owned[k]}', style: fancyText(16, color: const Color(0xFF3E2723))),
                Text(Wallet.info[k], style: fancyText(11, color: const Color(0xFF8D6E63))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (w.buy(k)) {
                SoundManager.instance.play('star');
              } else {
                SoundManager.instance.play('wrong', volume: 0.4);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: can ? const Color(0xFF43A047) : Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${Wallet.costs[k]}', style: fancyText(16)),
                  const Icon(Icons.star_rounded, color: Color(0xFFFFEE58), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

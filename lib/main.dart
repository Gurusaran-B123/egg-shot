import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/shot_levels.dart';
import 'screens/shot_screen.dart';
import 'utils/progress_store.dart';
import 'utils/sound_manager.dart';
import 'widgets/overlays.dart';
import 'widgets/ui_bits.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SoundManager.instance.init();
  runApp(const EggShotApp());
}

class EggShotApp extends StatelessWidget {
  const EggShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Egg Shot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: kFont),
      home: const LevelSelect(),
    );
  }
}

class LevelSelect extends StatefulWidget {
  const LevelSelect({super.key});

  @override
  State<LevelSelect> createState() => _LevelSelectState();
}

class _LevelSelectState extends State<LevelSelect> {
  ShotProgress _progress = ShotProgress(List<int>.filled(kShotLevels.length, 0));

  @override
  void initState() {
    super.initState();
    _reload();
    SoundManager.instance.playMusic('bgm_farm');
  }

  Future<void> _reload() async {
    final p = await ShotProgress.load(kShotLevels.length);
    if (mounted) setState(() => _progress = p);
  }

  Future<void> _open(int i) async {
    SoundManager.instance.play('click');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ShotScreen(levelIndex: i)),
    );
    if (mounted) {
      SoundManager.instance.playMusic('bgm_farm');
      _reload();
    }
  }

  void _howTo() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to play', style: fancyText(30, color: const Color(0xFFEF6C00))),
              const SizedBox(height: 10),
              Text(
                'Drag to aim, let go to shoot.\n'
                'Match 3 or more eggs of the same colour: they crack open and a baby hatches!\n'
                'Eggs left hanging fall down for bonus points.\n'
                'Bomb egg: blasts the eggs around it.\n'
                'Snake egg: eats a whole colour of eggs.\n'
                'Tap NEXT to swap eggs. Do not let the eggs touch the red line!',
                textAlign: TextAlign.center,
                style: fancyText(17, color: const Color(0xFF5D4037)),
              ),
              const SizedBox(height: 14),
              ChunkyButton(
                label: 'Got it',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_meadow.jpg',
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(color: const Color(0xFF81C784)),
          ),
          Container(color: const Color(0x44000000)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      RoundIconButton(icon: Icons.help_outline_rounded, color: const Color(0xFF1E88E5), onTap: _howTo),
                      const Spacer(),
                      HudChip(
                        text: '${_progress.total} / ${kShotLevels.length * 3}',
                        icon: Icons.star_rounded,
                        color: const Color(0xFFFFD54F),
                      ),
                      const Spacer(),
                      RoundIconButton(
                        icon: Icons.settings_rounded,
                        color: const Color(0xFF7E57C2),
                        onTap: () => showDialog<void>(context: context, builder: (_) => const SettingsDialog()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('EGG SHOT', style: fancyText(56, color: const Color(0xFFFFEB3B), letter: 2)),
                Text('Match eggs · hatch babies!', style: fancyText(20)),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: kShotLevels.length,
                    itemBuilder: (context, i) => _card(i),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(int i) {
    final lv = kShotLevels[i];
    final open = _progress.unlocked(i);
    final stars = _progress.stars[i];
    return GestureDetector(
      onTap: open ? () => _open(i) : () => SoundManager.instance.play('wrong', volume: 0.4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 4)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/${lv.theme.bg}.jpg',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: lv.theme.accent),
              ),
              Container(color: open ? const Color(0x22000000) : const Color(0xAA000000)),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${lv.number}', style: fancyText(40)),
                  SizedBox(
                    height: 44,
                    child: open
                        ? Image.asset('assets/images/animal_${lv.theme.baby}.png',
                            errorBuilder: (c, e, s) => const SizedBox())
                        : const Icon(Icons.lock_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var s = 0; s < 3; s++)
                        Icon(
                          s < stars ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFD54F),
                          size: 22,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

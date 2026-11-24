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
  final ScrollController _scroll = ScrollController();
  bool _jumped = false;

  @override
  void initState() {
    super.initState();
    _reload();
    SoundManager.instance.playMusic('bgm_farm');
  }

  Future<void> _reload() async {
    final p = await ShotProgress.load(kShotLevels.length);
    await Wallet.instance.refresh(kShotLevels.length);
    if (!mounted) return;
    setState(() => _progress = p);
    if (!_jumped) {
      _jumped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final cw = (MediaQuery.of(context).size.width - 28 - 24) / 3;
        final row = _progress.current ~/ 3;
        final off = (row * (cw / 0.86 + 12)).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
        _scroll.jumpTo(off);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
                'Spend stars in the shop (cart button) on power shots: Bomb blasts nearby eggs, Snake eats a whole colour, Freeze stops the timer.\n'
                'Later levels have a timer or a limited number of eggs.\n'
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
                      ListenableBuilder(
                        listenable: Wallet.instance,
                        builder: (context, _) => HudChip(
                          text: '${Wallet.instance.balance}',
                          icon: Icons.star_rounded,
                          color: const Color(0xFFFFD54F),
                        ),
                      ),
                      const Spacer(),
                      RoundIconButton(
                        icon: Icons.shopping_cart_rounded,
                        color: const Color(0xFF43A047),
                        onTap: () => showDialog<void>(context: context, builder: (_) => const ShopDialog()),
                      ),
                      const SizedBox(width: 8),
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
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: kShotLevels.length + 1,
                    itemBuilder: (context, i) => i >= kShotLevels.length ? _comingSoon() : _card(i),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingSoon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7E57C2), Color(0xFF3949AB)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 6),
          Text('COMING', style: fancyText(18, color: const Color(0xFFFFEE58))),
          Text('SOON', style: fancyText(18, color: const Color(0xFFFFEE58))),
          const SizedBox(height: 4),
          Text('More levels', style: fancyText(12)),
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
                cacheWidth: 260,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: lv.theme.accent),
              ),
              Container(color: open ? const Color(0x22000000) : const Color(0xAA000000)),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${lv.number}', style: fancyText(40)),
                  if (open && (lv.timeLimit > 0 || lv.shotLimit > 0))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (lv.timeLimit > 0) const Icon(Icons.timer_rounded, color: Colors.white, size: 16),
                        if (lv.shotLimit > 0) const Icon(Icons.egg_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  SizedBox(
                    height: 40,
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

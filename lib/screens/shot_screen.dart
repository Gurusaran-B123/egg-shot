import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart' show Ticker;

import 'package:flutter/material.dart';

import '../game/board.dart';
import '../models/shot_levels.dart';
import '../utils/progress_store.dart';
import '../utils/sound_manager.dart';
import '../widgets/effects.dart';
import '../widgets/overlays.dart';
import '../widgets/ui_bits.dart';

// ---- small effect classes -------------------------------------------------
class _Shell {
  _Shell(this.pos, this.code, this.delay, {this.eaten = false});
  final Offset pos;
  final int code;
  double delay;
  final bool eaten;
  double t = 0;
}

class _Baby {
  _Baby(this.pos, this.delay);
  final Offset pos;
  double delay;
  double t = 0;
}

class _Fall {
  _Fall(this.pos, this.code, this.vx, this.vy);
  Offset pos;
  final int code;
  double vx;
  double vy;
  double rot = 0;
}

class _Ring {
  _Ring(this.pos, this.maxR);
  final Offset pos;
  final double maxR;
  double t = 0;
}

class _SnakeFx {
  _SnakeFx(this.pts, this.dur);
  final List<Offset> pts;
  final double dur;
  double t = 0;
}

String _eggName(int code) {
  if (code == kBomb) return 'bomb';
  if (code == kSnake) return 'snake';
  return kPalette[code % kPalette.length];
}

const List<Color> _fallbackColors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFDD835),
  Color(0xFF8E24AA), Color(0xFFFB8C00), Color(0xFFEC407A), Color(0xFF00897B),
];

Widget _eggImg(int code, double w, double h) {
  return Image.asset(
    'assets/images/egg_${_eggName(code)}.png',
    width: w,
    height: h,
    fit: BoxFit.fill,
    errorBuilder: (c, e, s) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: code >= 100 ? Colors.black87 : _fallbackColors[code % 8],
        shape: BoxShape.circle,
      ),
    ),
  );
}

class ShotScreen extends StatefulWidget {
  const ShotScreen({super.key, required this.levelIndex});
  final int levelIndex;

  @override
  State<ShotScreen> createState() => _ShotScreenState();
}

class _ShotScreenState extends State<ShotScreen> with SingleTickerProviderStateMixin {
  late final ShotLevel level = kShotLevels[widget.levelIndex];
  late final ShotTheme theme = level.theme;
  final EggBoard board = EggBoard();
  final math.Random rnd = math.Random();
  final ValueNotifier<int> frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Timer? _endTimer;

  // layout
  double w = 0, h = 0, d = 0, top = 0, shooterY = 0, dangerY = 0;
  int maxRows = 10;
  bool _inited = false;

  // game state
  int phase = 0; // 0 playing, 1 paused, 2 won, 3 lost
  bool _showEnd = false;
  int cur = 0, next = 0;
  double _aim = math.pi / 2;
  bool _flying = false;
  Offset _pos = Offset.zero;
  Offset _dir = const Offset(0, -1);
  int _shotCode = 0;
  int score = 0, babies = 0, shots = 0, misses = 0, combo = 0;
  int _earned = 0;
  int _held = -1; // regular egg put aside while a power shot is armed
  double _timeLeft = 0, _frozen = 0;
  int _shotsLeft = 0;
  String _loseMsg = '';

  // effects
  final List<_Shell> _shells = [];
  final List<_Baby> _babyFx = [];
  final List<_Fall> _falls = [];
  final List<_Ring> _rings = [];
  _SnakeFx? _snakeFx;
  double _shake = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    SoundManager.instance.playMusic(theme.bgm);
    Wallet.instance.refresh(kLevelCount).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    _refundArmed();
    _ticker.dispose();
    frame.dispose();
    SoundManager.instance.playMusic('bgm_farm');
    super.dispose();
  }

  // ---- setup ----------------------------------------------------------------
  void _setup(double width, double height, EdgeInsets pad) {
    if (_inited) return;
    _inited = true;
    w = width;
    h = height;
    d = w / kCols;
    top = pad.top + 104;
    shooterY = h - pad.bottom - d * 1.15;
    dangerY = shooterY - d * 1.6;
    maxRows = math.max(6, ((dangerY - top - d * 0.5) / (d * 0.866)).floor());
    _newGame();
  }

  void _newGame() {
    _refundArmed();
    board.fill(math.min<int>(level.rows, maxRows - 4), level.colors, rnd);
    _held = -1;
    _timeLeft = level.timeLimit.toDouble();
    _shotsLeft = level.shotLimit;
    _frozen = 0;
    _loseMsg = '';
    cur = 0;
    next = 0;
    score = 0;
    babies = 0;
    shots = 0;
    misses = 0;
    combo = 0;
    _flying = false;
    _shells.clear();
    _babyFx.clear();
    _falls.clear();
    _rings.clear();
    _snakeFx = null;
    _shake = 0;
    _aim = math.pi / 2;
    _showEnd = false;
    phase = 0;
    cur = _pick();
    next = _pick();
  }

  int _pick() {
    final present = board.colorsOnBoard().toList();
    if (present.isEmpty) return 0;
    return present[rnd.nextInt(present.length)];
  }

  /// Give back an armed (unused) power shot.
  void _refundArmed() {
    if (_held >= 0 && cur >= 100) {
      Wallet.instance.give(cur == kBomb ? 0 : 1);
      cur = _held;
      _held = -1;
    }
  }

  void _power(int k) {
    if (phase != 0 || _flying) return;
    final w = Wallet.instance;
    SoundManager.instance.play('click', volume: 0.6);
    if (k == 2) {
      if (_frozen > 0) return;
      if (w.owned[2] > 0 || w.buy(2)) {
        w.take(2);
        _frozen = 10;
        SoundManager.instance.play('star');
        setState(() {});
      } else {
        _needStars(k);
      }
      return;
    }
    final code = k == 0 ? kBomb : kSnake;
    if (cur == code && _held >= 0) {
      _refundArmed(); // tap again to put it back
      setState(() {});
      return;
    }
    if (w.owned[k] <= 0 && !w.buy(k)) {
      _needStars(k);
      return;
    }
    _refundArmed();
    w.take(k);
    _held = cur;
    cur = code;
    setState(() {});
  }

  void _needStars(int k) {
    SoundManager.instance.play('wrong', volume: 0.4);
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text('${Wallet.names[k]} costs ${Wallet.costs[k]} stars. Finish levels to earn stars!'),
    ));
  }

  void _validate() {
    final present = board.colorsOnBoard();
    if (present.isEmpty) return;
    if (_held >= 0 && _held < 100 && !present.contains(_held)) {
      _held = present.elementAt(rnd.nextInt(present.length));
    }
    if (cur < 100 && !present.contains(cur)) {
      cur = present.elementAt(rnd.nextInt(present.length));
    }
    if (next < 100 && !present.contains(next)) {
      next = present.elementAt(rnd.nextInt(present.length));
    }
  }

  // ---- input ----------------------------------------------------------------
  void _aimAt(Offset p) {
    final dx = p.dx - w / 2;
    final dy = shooterY - p.dy;
    double a;
    if (dy <= 0) {
      a = dx >= 0 ? 0.17 : math.pi - 0.17;
    } else {
      a = math.atan2(dy, dx);
    }
    _aim = a.clamp(0.17, math.pi - 0.17).toDouble();
    frame.value++;
  }

  void _fire() {
    if (phase != 0 || _flying) return;
    if (level.shotLimit > 0 && _shotsLeft <= 0 && cur < 100) return;
    _flying = true;
    _shotCode = cur;
    if (_held >= 0) {
      cur = _held;
      _held = -1;
    } else {
      cur = next;
      next = _pick();
    }
    _pos = Offset(w / 2, shooterY);
    _dir = Offset(math.cos(_aim), -math.sin(_aim));
    SoundManager.instance.play('click', volume: 0.6);
    setState(() {});
  }

  void _swap() {
    if (phase != 0 || _flying || _held >= 0) return;
    final t = cur;
    cur = next;
    next = t;
    SoundManager.instance.play('click', volume: 0.5);
    setState(() {});
  }

  // ---- loop -----------------------------------------------------------------
  void _tick(Duration e) {
    var dt = (e - _last).inMicroseconds / 1e6;
    _last = e;
    if (dt <= 0) return;
    if (dt > 0.034) dt = 0.034;
    if (phase == 0) {
      if (_frozen > 0) {
        _frozen = math.max(0, _frozen - dt);
      } else if (level.timeLimit > 0) {
        _timeLeft -= dt;
        if (_timeLeft <= 0) {
          _timeLeft = 0;
          _lose('Time is up!');
        }
      }
    }
    if (_flying && phase == 0) _moveShot(dt);
    _updateFx(dt);
    frame.value++;
  }

  bool _hitsAt(Offset p) {
    if (p.dy <= top + d * 0.5 + 2) return true;
    final r0 = ((p.dy - top - d * 0.5) / (d * 0.866)).round();
    for (var r = math.max(0, r0 - 1); r <= r0 + 1 && r < board.rows.length; r++) {
      for (var c = 0; c < board.colsIn(r); c++) {
        if (board.rows[r][c] == kEmpty) continue;
        if ((board.center(r, c, d, top) - p).distance < d * 0.8) return true;
      }
    }
    return false;
  }

  void _moveShot(double dt) {
    var remaining = d * 28 * dt;
    final step = d * 0.2;
    final r = d * 0.44;
    while (remaining > 0 && _flying) {
      final s = math.min(step, remaining);
      remaining -= s;
      _pos = _pos + _dir * s;
      if (_pos.dx < r) {
        _pos = Offset(r, _pos.dy);
        _dir = Offset(-_dir.dx, _dir.dy);
      } else if (_pos.dx > w - r) {
        _pos = Offset(w - r, _pos.dy);
        _dir = Offset(-_dir.dx, _dir.dy);
      }
      if (_hitsAt(_pos)) _land();
    }
  }

  void _updateFx(double dt) {
    for (final s in _shells) {
      if (s.delay > 0) {
        s.delay -= dt;
      } else {
        s.t += dt / (s.eaten ? 0.3 : 0.8);
      }
    }
    _shells.removeWhere((s) => s.t >= 1);
    for (final b in _babyFx) {
      if (b.delay > 0) {
        b.delay -= dt;
      } else {
        b.t += dt / 1.5;
      }
    }
    _babyFx.removeWhere((b) => b.t >= 1);
    for (final f in _falls) {
      f.vy += 1800 * dt;
      f.pos = f.pos + Offset(f.vx * dt, f.vy * dt);
      f.rot += f.vx * dt * 0.01;
    }
    _falls.removeWhere((f) => f.pos.dy > h + d * 2);
    for (final r in _rings) {
      r.t += dt / 0.5;
    }
    _rings.removeWhere((r) => r.t >= 1);
    final sn = _snakeFx;
    if (sn != null) {
      sn.t += dt / sn.dur;
      if (sn.t >= 1) _snakeFx = null;
    }
    if (_shake > 0) _shake = math.max(0, _shake - dt);
  }

  // ---- landing and resolving --------------------------------------------------
  void _land() {
    _flying = false;
    final code = _shotCode;
    final k = board.nearestEmpty(_pos, d, top);
    if (k == null) {
      setState(() {});
      return;
    }
    shots++;
    if (code < 100 && level.shotLimit > 0) _shotsLeft--;
    if (code == kBomb) {
      _explode(k);
    } else if (code == kSnake) {
      _snake(k);
    } else {
      board.setK(k, code);
      final cl = board.cluster(k);
      if (cl.length >= 3) {
        _pop(cl);
        _dropFloating();
        _afterResolve(true);
      } else {
        _afterResolve(false);
      }
    }
  }

  Offset _cen(int k) => board.center(EggBoard.rowOf(k), EggBoard.colOf(k), d, top);

  void _pop(Set<int> keys) {
    final list = keys.toList();
    var sum = Offset.zero;
    for (var i = 0; i < list.length; i++) {
      final p = _cen(list[i]);
      sum = sum + p;
      _shells.add(_Shell(p, board.getK(list[i]), i * 0.03));
      board.setK(list[i], kEmpty);
    }
    final c = sum / list.length.toDouble();
    _babyFx.add(_Baby(c, 0.1));
    babies += list.length >= 6 ? 2 : 1;
    combo++;
    score += 10 * list.length + (list.length - 3) * 10 + (combo > 1 ? 25 * (combo - 1) : 0);
    SoundManager.instance.play('crack', volume: 0.8);
    SoundManager.instance.play(theme.hatchSfx, volume: 0.9);
    if (combo >= 2) SoundManager.instance.play('combo', volume: 0.8);
  }

  void _dropFloating() {
    final fl = board.floating();
    if (fl.isEmpty) return;
    for (final k in fl) {
      _falls.add(_Fall(_cen(k), board.getK(k), (rnd.nextDouble() - 0.5) * 160, -160 - rnd.nextDouble() * 120));
      board.setK(k, kEmpty);
    }
    score += 20 * fl.length;
    SoundManager.instance.play('star', volume: 0.8);
  }

  void _explode(int k) {
    final c = _cen(k);
    _rings.add(_Ring(c, d * 2.4));
    _shake = 0.4;
    var n = 0;
    for (var r = 0; r < board.rows.length; r++) {
      for (var cc = 0; cc < board.colsIn(r); cc++) {
        final v = board.rows[r][cc];
        if (v == kEmpty) continue;
        final p = board.center(r, cc, d, top);
        if ((p - c).distance < d * 1.8) {
          _shells.add(_Shell(p, v, 0.02 * n));
          board.rows[r][cc] = kEmpty;
          n++;
        }
      }
    }
    score += 15 * n;
    combo = 0;
    SoundManager.instance.play('fire');
    _dropFloating();
    _afterResolve(true);
  }

  void _snake(int k) {
    final r = EggBoard.rowOf(k), c = EggBoard.colOf(k);
    final from = _cen(k);
    int? col;
    for (final n in board.neighbors(r, c)) {
      final v = board.getK(n);
      if (v >= 0 && v < 100) {
        col = v;
        break;
      }
    }
    if (col == null) {
      final present = board.colorsOnBoard().toList();
      if (present.isNotEmpty) col = present[rnd.nextInt(present.length)];
    }
    if (col == null) {
      _afterResolve(true);
      return;
    }
    final keys = <int>[];
    for (var rr = 0; rr < board.rows.length; rr++) {
      for (var cc = 0; cc < board.colsIn(rr); cc++) {
        if (board.rows[rr][cc] == col) keys.add(EggBoard.key(rr, cc));
      }
    }
    // Greedy path: always go to the nearest remaining egg. Eats up to 14.
    final path = <Offset>[from];
    final eat = <int>[];
    var at = from;
    while (keys.isNotEmpty && eat.length < 14) {
      keys.sort((a, b) => (_cen(a) - at).distance.compareTo((_cen(b) - at).distance));
      final k0 = keys.removeAt(0);
      eat.add(k0);
      at = _cen(k0);
      path.add(at);
    }
    final dur = 0.3 + eat.length * 0.11;
    for (var i = 0; i < eat.length; i++) {
      _shells.add(_Shell(_cen(eat[i]), col, 0.3 + i * 0.11 - 0.05, eaten: true));
      board.setK(eat[i], kEmpty);
    }
    _snakeFx = _SnakeFx(path, dur);
    score += 15 * eat.length;
    combo = 0;
    SoundManager.instance.play('hatch_dino');
    _dropFloating();
    _afterResolve(true);
  }

  void _afterResolve(bool popped) {
    if (!popped) {
      combo = 0;
      if (_frozen <= 0) misses++;
      SoundManager.instance.play('wrong', volume: 0.3);
      if (_frozen <= 0 && misses >= level.missLimit) {
        misses = 0;
        var cols = board.colorsOnBoard().toList();
        if (cols.isEmpty) cols = List<int>.generate(level.colors, (i) => i);
        board.addRowTop(cols, rnd);
        SoundManager.instance.play('pop', volume: 0.7);
      }
    }
    _settle();
  }

  void _settle() {
    if (board.count() == 0) {
      _win();
      return;
    }
    if (board.maxFilledRow() >= maxRows) {
      _lose('The eggs reached the line.');
      return;
    }
    if (level.shotLimit > 0 && _shotsLeft <= 0 && _held < 0) {
      _lose('You ran out of eggs!');
      return;
    }
    _validate();
    setState(() {});
  }

  void _win() {
    phase = 2;
    _earned = level.starsFor(shots);
    ShotProgress.saveStars(widget.levelIndex, _earned)
        .then((_) => Wallet.instance.refresh(kLevelCount));
    SoundManager.instance.play('win');
    _endTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showEnd = true);
    });
    setState(() {});
  }

  void _lose(String why) {
    phase = 3;
    _loseMsg = why;
    SoundManager.instance.play('lose');
    _endTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showEnd = true);
    });
    setState(() {});
  }

  void _setPause(bool p) {
    if (phase != 0 && phase != 1) return;
    setState(() {
      phase = p ? 1 : 0;
      _ticker.muted = p;
    });
    if (p) {
      SoundManager.instance.pauseMusic();
    } else {
      SoundManager.instance.resumeMusic();
    }
  }

  void _restart() {
    _endTimer?.cancel();
    _ticker.muted = false;
    SoundManager.instance.resumeMusic();
    setState(_newGame);
  }

  List<Offset> _aimDots() {
    final dots = <Offset>[];
    var p = Offset(w / 2, shooterY);
    var dir = Offset(math.cos(_aim), -math.sin(_aim));
    final step = d * 0.35;
    final r = d * 0.44;
    for (var i = 0; i < 36; i++) {
      p = p + dir * step;
      if (p.dx < r) {
        p = Offset(r, p.dy);
        dir = Offset(-dir.dx, dir.dy);
      } else if (p.dx > w - r) {
        p = Offset(w - r, p.dy);
        dir = Offset(-dir.dx, dir.dy);
      }
      if (_hitsAt(p)) break;
      if (i.isEven) dots.add(p);
    }
    return dots;
  }

  // ---- build ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, box) {
        final pad = MediaQuery.of(context).padding;
        _setup(box.maxWidth, box.maxHeight, pad);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/${theme.bg}.jpg',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: theme.accent),
            ),
            Container(color: const Color(0x33000000)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (dd) => _aimAt(dd.localPosition),
              onPanUpdate: (dd) => _aimAt(dd.localPosition),
              onPanEnd: (_) => _fire(),
              onTapUp: (dd) {
                _aimAt(dd.localPosition);
                _fire();
              },
              child: ValueListenableBuilder<int>(
                valueListenable: frame,
                child: _staticLayer(),
                builder: (context, _, child) {
                  final sh = _shake > 0
                      ? Offset((rnd.nextDouble() - 0.5) * 12 * _shake * 2.5,
                          (rnd.nextDouble() - 0.5) * 12 * _shake * 2.5)
                      : Offset.zero;
                  return Transform.translate(
                    offset: sh,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child!,
                        CustomPaint(painter: _FxPainter(this, frame), size: Size.infinite),
                        ..._fxWidgets(),
                        if (_frozen > 0)
                          const Positioned.fill(
                            child: IgnorePointer(child: ColoredBox(color: Color(0x2229B6F6))),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _hud(pad),
            if (phase == 1) _pauseOverlay(),
            if (_showEnd && phase == 2) _winOverlay(),
            if (_showEnd && phase == 3) _loseOverlay(),
          ],
        );
      }),
    );
  }

  Widget _staticLayer() {
    final ew = d * 0.88, eh = d * 1.0;
    final kids = <Widget>[];
    for (var r = 0; r < board.rows.length; r++) {
      for (var c = 0; c < board.colsIn(r); c++) {
        final v = board.rows[r][c];
        if (v == kEmpty) continue;
        final p = board.center(r, c, d, top);
        kids.add(Positioned(
          left: p.dx - ew / 2,
          top: p.dy - eh / 2,
          width: ew,
          height: eh,
          child: _eggImg(v, ew, eh),
        ));
      }
    }
    // shooter nest, current egg and next egg
    kids.add(Positioned(
      left: w / 2 - d * 1.2,
      top: shooterY - d * 0.3,
      width: d * 2.4,
      height: d * 1.5,
      child: Image.asset('assets/images/nest.png', fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const SizedBox()),
    ));
    if (!_flying && phase != 3 && phase != 2) {
      kids.add(Positioned(
        left: w / 2 - ew / 2,
        top: shooterY - eh / 2,
        width: ew,
        height: eh,
        child: _eggImg(cur, ew, eh),
      ));
    }
    kids.add(Positioned(
      left: w / 2 - d * 3.0,
      top: shooterY - d * 0.45,
      width: d * 1.3,
      height: d * 1.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _swap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NEXT', style: fancyText(d * 0.3)),
            _eggImg(next, ew * 0.8, eh * 0.8),
          ],
        ),
      ),
    ));
    if (_held >= 0 && phase == 0) {
      kids.add(Positioned(
        left: 0,
        right: 0,
        top: dangerY - d * 1.0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(18)),
              child: Text(
                cur == kBomb ? 'BOMB ready - aim and shoot!' : 'SNAKE ready - aim and shoot!',
                style: fancyText(16, color: const Color(0xFFFFEE58)),
              ),
            ),
          ),
        ),
      ));
    }
    final bs = d * 0.95;
    for (var k = 0; k < 3; k++) {
      kids.add(Positioned(
        left: w - (3 - k) * (bs + 4) - 4,
        top: shooterY - bs * 0.2,
        width: bs,
        height: bs + 24,
        child: _powerButton(k, bs),
      ));
    }
    return Stack(fit: StackFit.expand, children: kids);
  }

  Widget _powerButton(int k, double bs) {
    final w0 = Wallet.instance;
    final armed = (k == 0 && cur == kBomb && _held >= 0) || (k == 1 && cur == kSnake && _held >= 0);
    final active = k == 2 && _frozen > 0;
    final cols = [const Color(0xFFEF5350), const Color(0xFF66BB6A), const Color(0xFF29B6F6)];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _power(k),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: bs,
            height: bs,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xAA000000),
              border: Border.all(color: (armed || active) ? const Color(0xFFFFEE58) : cols[k], width: 3),
            ),
            child: k == 2
                ? Icon(Icons.ac_unit_rounded, color: cols[2], size: bs * 0.62)
                : Padding(
                    padding: EdgeInsets.all(bs * 0.12),
                    child: Image.asset('assets/images/egg_${k == 0 ? 'bomb' : 'snake'}.png',
                        errorBuilder: (c, e, s) => const SizedBox()),
                  ),
          ),
          Text(
            w0.owned[k] > 0 ? 'x${w0.owned[k]}' : '${Wallet.costs[k]}★',
            style: fancyText(13, color: w0.owned[k] > 0 ? Colors.white : const Color(0xFFFFEE58)),
          ),
        ],
      ),
    );
  }

  List<Widget> _fxWidgets() {
    final ew = d * 0.88, eh = d * 1.0;
    final out = <Widget>[];
    if (_flying) {
      out.add(Positioned(
        left: _pos.dx - ew / 2,
        top: _pos.dy - eh / 2,
        width: ew,
        height: eh,
        child: _eggImg(_shotCode, ew, eh),
      ));
    }
    for (final f in _falls) {
      out.add(Positioned(
        left: f.pos.dx - ew / 2,
        top: f.pos.dy - eh / 2,
        width: ew,
        height: eh,
        child: Transform.rotate(angle: f.rot, child: _eggImg(f.code, ew, eh)),
      ));
    }
    for (final s in _shells) {
      if (s.delay > 0) continue;
      final t = s.t.clamp(0.0, 1.0).toDouble();
      if (s.eaten) {
        out.add(Positioned(
          left: s.pos.dx - ew / 2,
          top: s.pos.dy - eh / 2,
          width: ew,
          height: eh,
          child: Transform.scale(scale: 1 - t, child: _eggImg(s.code, ew, eh)),
        ));
        continue;
      }
      final op = (1 - t * t).clamp(0.0, 1.0).toDouble();
      out.add(_half(s, ew, eh, true, t, op));
      out.add(_half(s, ew, eh, false, t, op));
    }
    for (final b in _babyFx) {
      if (b.delay > 0) continue;
      final t = b.t.clamp(0.0, 1.0).toDouble();
      final size = d * 1.8;
      final sc = t < 0.25 ? 0.3 + 0.7 * (t / 0.25) : 1.0;
      final op = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
      final hop = -math.sin(t * math.pi * 3).abs() * d * 0.25 - t * d * 0.9;
      out.add(Positioned(
        left: b.pos.dx - size / 2,
        top: b.pos.dy - size / 2 + hop,
        width: size,
        height: size,
        child: Opacity(
          opacity: op.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(
            scale: sc,
            child: Image.asset('assets/images/animal_${theme.baby}.png',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.pets, color: Colors.white, size: 40)),
          ),
        ),
      ));
    }
    return out;
  }

  Widget _half(_Shell s, double ew, double eh, bool topHalf, double t, double op) {
    final dx = (topHalf ? -0.6 : 0.6) * d * t;
    final dy = (topHalf ? -0.7 : 0.3) * d * t + (topHalf ? 1.6 : 1.4) * d * t * t;
    return Positioned(
      left: s.pos.dx - ew / 2 + dx,
      top: s.pos.dy - eh / 2 + dy,
      width: ew,
      height: eh,
      child: Opacity(
        opacity: op,
        child: Transform.rotate(
          angle: (topHalf ? -0.9 : 0.9) * t,
          child: ClipPath(
            clipper: EggHalfClipper(top: topHalf),
            child: _eggImg(s.code, ew, eh),
          ),
        ),
      ),
    );
  }

  Widget _hud(EdgeInsets pad) {
    return Positioned(
      top: pad.top + 6,
      left: 8,
      right: 8,
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.pause_rounded, onTap: () => _setPause(true)),
              const SizedBox(width: 8),
              Expanded(child: HudChip(text: 'Level ${level.number} · ${theme.name}', fontSize: 16)),
              const SizedBox(width: 8),
              RoundIconButton(
                icon: Icons.settings_rounded,
                color: const Color(0xFF7E57C2),
                onTap: () => showDialog<void>(context: context, builder: (_) => const SettingsDialog()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: HudChip(text: '$score', icon: Icons.star_rounded, color: const Color(0xFFFFD54F))),
              const SizedBox(width: 6),
              Expanded(child: HudChip(text: '$babies', icon: Icons.pets_rounded, color: const Color(0xFFFF8A80))),
              const SizedBox(width: 6),
              Expanded(
                child: HudChip(
                  text: level.shotLimit > 0 ? '$_shotsLeft left' : '$shots',
                  icon: Icons.gps_fixed_rounded,
                  color: (level.shotLimit > 0 && _shotsLeft <= 3) ? const Color(0xFFFF8A80) : const Color(0xFF80D8FF),
                ),
              ),
              if (level.timeLimit > 0) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: frame,
                    builder: (context, _, __) {
                      final t = _timeLeft.ceil();
                      final txt = '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
                      return HudChip(
                        text: txt,
                        icon: _frozen > 0 ? Icons.ac_unit_rounded : Icons.timer_rounded,
                        color: _frozen > 0
                            ? const Color(0xFF80D8FF)
                            : (t <= 10 ? const Color(0xFFFF5252) : Colors.white),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < level.missLimit; i++)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < misses ? const Color(0xFFFF5252) : Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pauseOverlay() {
    return ShotOverlay(
      title: 'Paused',
      titleColor: const Color(0xFFEF6C00),
      children: [
        ChunkyButton(label: 'Resume', icon: Icons.play_arrow_rounded, color: const Color(0xFF43A047), onTap: () => _setPause(false)),
        ChunkyButton(label: 'Restart', icon: Icons.refresh_rounded, color: const Color(0xFFFFA000), onTap: _restart),
        ChunkyButton(label: 'Levels', icon: Icons.grid_view_rounded, color: const Color(0xFF1E88E5), onTap: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _winOverlay() {
    final hasNext = widget.levelIndex + 1 < kShotLevels.length;
    return ShotOverlay(
      title: 'Level Clear!',
      titleColor: const Color(0xFF43A047),
      stars: _earned,
      subtitle: 'Score $score  ·  Babies hatched $babies',
      children: [
        if (hasNext)
          ChunkyButton(
            label: 'Next Level',
            icon: Icons.arrow_forward_rounded,
            color: const Color(0xFF43A047),
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => ShotScreen(levelIndex: widget.levelIndex + 1)),
            ),
          ),
        ChunkyButton(label: 'Play Again', icon: Icons.refresh_rounded, color: const Color(0xFFFFA000), onTap: _restart),
        ChunkyButton(label: 'Levels', icon: Icons.grid_view_rounded, color: const Color(0xFF1E88E5), onTap: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _loseOverlay() {
    return ShotOverlay(
      title: 'Oh no!',
      titleColor: const Color(0xFFE53935),
      subtitle: '$_loseMsg\nScore $score  ·  Babies hatched $babies',
      children: [
        ChunkyButton(label: 'Try Again', icon: Icons.refresh_rounded, color: const Color(0xFF43A047), onTap: _restart),
        ChunkyButton(label: 'Levels', icon: Icons.grid_view_rounded, color: const Color(0xFF1E88E5), onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// Draws aim dots, danger line, explosion rings, snake and sparkles.
class _FxPainter extends CustomPainter {
  _FxPainter(this.s, Listenable repaint) : super(repaint: repaint);
  final _ShotScreenState s;

  @override
  void paint(Canvas canvas, Size size) {
    final d = s.d;
    if (d <= 0) return;

    // danger line
    final dl = Paint()
      ..color = const Color(0xAAFF5252)
      ..strokeWidth = 3;
    for (double x = 0; x < s.w; x += 22) {
      canvas.drawLine(Offset(x, s.dangerY), Offset(x + 11, s.dangerY), dl);
    }

    // aim dots
    if (s.phase == 0 && !s._flying) {
      final dots = s._aimDots();
      for (var i = 0; i < dots.length; i++) {
        canvas.drawCircle(dots[i], d * 0.075, Paint()..color = Colors.white.withAlpha(220));
      }
    }

    // explosion rings
    for (final r in s._rings) {
      final t = r.t.clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        r.pos,
        r.maxR * t,
        Paint()..color = const Color(0xFFFFEE58).withAlpha(((1 - t) * 110).round()),
      );
      canvas.drawCircle(
        r.pos,
        r.maxR * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = d * 0.25 * (1 - t)
          ..color = const Color(0xFFFF7043).withAlpha(((1 - t) * 255).round()),
      );
    }

    // sparkles around hatching babies
    for (final b in s._babyFx) {
      if (b.delay > 0) continue;
      final t = b.t.clamp(0.0, 1.0).toDouble();
      for (var i = 0; i < 7; i++) {
        final a = i * math.pi * 2 / 7 + t * 2;
        final rr = d * (0.5 + t * 1.3);
        final c = Offset(b.pos.dx + math.cos(a) * rr, b.pos.dy + math.sin(a) * rr * 0.8 - t * d * 0.5);
        canvas.drawPath(
          i.isEven ? starPath(c, d * 0.16) : heartPath(c, d * 0.1),
          Paint()..color = (i.isEven ? const Color(0xFFFFD54F) : const Color(0xFFFF6F91)).withAlpha(((1 - t) * 255).round()),
        );
      }
    }

    // snake
    final sn = s._snakeFx;
    if (sn != null && sn.pts.length >= 2) {
      final n = sn.pts.length - 1;
      final f = (sn.t.clamp(0.0, 1.0) * n).toDouble();
      Offset at(double x) {
        final i = x.floor().clamp(0, n - 1);
        final fr = (x - i).clamp(0.0, 1.0);
        return Offset.lerp(sn.pts[i], sn.pts[i + 1], fr)!;
      }

      final start = math.max(0.0, f - 3.5);
      final path = Path()..moveTo(at(start).dx, at(start).dy);
      for (var i = start.floor() + 1; i < f; i++) {
        final p = sn.pts[i];
        path.lineTo(p.dx, p.dy);
      }
      final head = at(f);
      path.lineTo(head.dx, head.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = d * 0.46
          ..color = const Color(0xFF1B5E20),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = d * 0.34
          ..color = const Color(0xFF66BB6A),
      );
      canvas.drawCircle(head, d * 0.3, Paint()..color = const Color(0xFF43A047));
      canvas.drawCircle(head.translate(-d * 0.1, -d * 0.08), d * 0.08, Paint()..color = Colors.white);
      canvas.drawCircle(head.translate(d * 0.1, -d * 0.08), d * 0.08, Paint()..color = Colors.white);
      canvas.drawCircle(head.translate(-d * 0.1, -d * 0.08), d * 0.035, Paint()..color = Colors.black);
      canvas.drawCircle(head.translate(d * 0.1, -d * 0.08), d * 0.035, Paint()..color = Colors.black);
      canvas.drawLine(
        head.translate(0, d * 0.1),
        head.translate(0, d * 0.34),
        Paint()
          ..color = const Color(0xFFE53935)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_FxPainter old) => true;
}

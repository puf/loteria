import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:loteria_shared/loteria_shared.dart';

import '../services/draw_order.dart';
import '../services/game_repository.dart';
import '../widgets/stage_background.dart';
import '../widgets/winning_pattern_badge.dart';

const String _cardsSpriteAsset = 'assets/loteria_assets/cards-sprite.png';

/// `game_state == drawing` (spec.md section 3) -- and `paused`, which
/// renders the exact same screen (implementation-plan.md: "the screen shows
/// the same content as before, but all disabled") rather than a separate
/// placeholder, just with a small "Paused" indicator added.
///
/// Everything about the round's drawn cards -- the current one, and the
/// history behind it -- is recomputed from `game/draw_count` (a plain
/// counter) plus `game/game_id` via `drawOrderFor` (`draw_order.dart`).
/// Nothing about *which* cards were drawn is separately read here; the
/// admin-side `DrawLoopEngine` is the only writer of that count.
class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key, required this.gameRepository});

  final GameRepository gameRepository;

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  StreamSubscription<int>? _drawCountSub;
  StreamSubscription<GameState?>? _gameStateSub;
  AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _stopAudioTimer;

  List<LoteriaCard>? _drawOrder;
  int _drawCount = 0;
  // The draw count already showing when this screen mounted -- audio only
  // plays for counts *past* this baseline, so a reload/reconnect mid-round
  // doesn't fire a burst of card-name audio for everything already drawn
  // (unlike the dealing screen's flying-tabla replay, a burst of overlapping
  // spoken names would be actively unpleasant, not just visually busy).
  int _baselineDrawCount = 0;
  GameState? _gameState;
  WinningPattern? _winningPattern;
  StreamSubscription<String?>? _claimingUidSub;
  String? _claimingUid;

  // implementation-plan.md v2 TODO: "active"/"blocked" counts, each only
  // counting UIDs still present in `lobby` (i.e. still connected).
  StreamSubscription<Set<String>>? _lobbyUidsSub;
  StreamSubscription<List<String>>? _playerUidsSub;
  StreamSubscription<Set<String>>? _blockedUidsSub;
  Set<String> _lobbyUids = {};
  Set<String> _playerUids = {};
  Set<String> _blockedUids = {};

  // implementation-plan.md v2 TODO: `settings/sound` -- on by default,
  // live so a host toggling it takes effect on the very next card.
  StreamSubscription<bool>? _soundEnabledSub;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final gameId = await widget.gameRepository.fetchGameId();
    final initialCount = await widget.gameRepository.fetchDrawCount();
    final winningPattern = await widget.gameRepository.fetchWinningPattern();
    if (!mounted) return;
    setState(() {
      _drawOrder = gameId == null ? null : drawOrderFor(gameId);
      _drawCount = initialCount;
      _baselineDrawCount = initialCount;
      _winningPattern = winningPattern;
    });
    _drawCountSub = widget.gameRepository.watchDrawCount().listen(_onDrawCount);
    _gameStateSub = widget.gameRepository.watchGameState().listen((state) {
      if (mounted) setState(() => _gameState = state);
    });
    // spec.md: "While a claiming_uid is present in the database, the Stage
    // view shows a character somewhere on the screen" -- implementation-
    // plan.md's decision that `claiming` reuses this same drawing view
    // (rather than a dedicated screen) means that cue lives here.
    _claimingUidSub = widget.gameRepository.watchClaimingUid().listen((uid) {
      if (mounted) setState(() => _claimingUid = uid);
    });
    _lobbyUidsSub = widget.gameRepository.watchLobbyUids().listen((uids) {
      if (mounted) setState(() => _lobbyUids = uids);
    });
    _playerUidsSub = widget.gameRepository.watchDealtPlayerUids().listen((
      uids,
    ) {
      if (mounted) setState(() => _playerUids = uids.toSet());
    });
    _blockedUidsSub = widget.gameRepository.watchBlockedUids().listen((uids) {
      if (mounted) setState(() => _blockedUids = uids);
    });
    _soundEnabledSub = widget.gameRepository.watchSoundEnabled().listen((
      enabled,
    ) {
      if (mounted) setState(() => _soundEnabled = enabled);
    });
  }

  void _onDrawCount(int count) {
    if (!mounted) return;
    final order = _drawOrder;
    final isNewCard =
        count > _baselineDrawCount && order != null && count <= order.length;
    setState(() => _drawCount = count);
    if (isNewCard) {
      _baselineDrawCount = count;
      if (_soundEnabled) _playAudioFor(order[count - 1]);
    }
  }

  /// Seeking isn't sample-accurate in the browser (MP3 decoders commonly
  /// snap a seek forward to the nearest frame boundary), which was clipping
  /// the very start of some clips. Every clip in `cards.mp3` has a full
  /// second of silence before it (verified when the timing data was
  /// extracted from the original doodle's source), so seeking this much
  /// early is always still silence, never bleeding into the previous card's
  /// audio -- cheap insurance against a few tens of milliseconds of seek
  /// slop.
  static const Duration _seekLeadIn = Duration(milliseconds: 150);

  static final _cardsAudioSource = AssetSource('loteria_assets/cards.mp3');

  /// Confirmed live (30+ real draws, real 5s cadence): `audioplayers`' web
  /// backend can eventually hang on a `play()` call and never resolve --
  /// its own internal timeout for that is a full 30s, which is 6 missed
  /// cards' worth of audio at this cadence. This is a much shorter leash so
  /// a hang gets treated as a failure -- and recovered from -- fast.
  static const Duration _playTimeout = Duration(seconds: 3);

  /// Audio matters too much here to leave silently broken if one play call
  /// ever fails (spec.md's whole point of the audio cue) -- calls the
  /// package's primary, best-tested entry point (`play` with an explicit
  /// `position`) fresh each time, and self-heals by recreating the player
  /// and retrying once on any failure or timeout, so one bad play doesn't
  /// take out every card for the rest of the round.
  Future<void> _playAudioFor(LoteriaCard card) async {
    _stopAudioTimer?.cancel();
    final seekTarget = card.audioStart > _seekLeadIn
        ? card.audioStart - _seekLeadIn
        : Duration.zero;
    if (!await _tryPlay(seekTarget, card.slug)) {
      await _recreatePlayer();
      await _tryPlay(seekTarget, card.slug, isRetry: true);
    }
    _stopAudioTimer = Timer(
      card.audioDuration + _seekLeadIn,
      () => _audioPlayer.pause(),
    );
  }

  Future<bool> _tryPlay(
    Duration position,
    String slug, {
    bool isRetry = false,
  }) async {
    try {
      await _audioPlayer
          .play(_cardsAudioSource, position: position)
          .timeout(_playTimeout);
      return true;
    } catch (error) {
      debugPrint(
        'Audio play${isRetry ? ' retry' : ''} failed for $slug: $error',
      );
      return false;
    }
  }

  /// Swaps in a fresh player *before* touching the old (possibly broken)
  /// one -- disposing a player that's already wedged can itself throw, and
  /// if that happened before the reassignment, every card for the rest of
  /// the round would keep reusing the same broken instance. Any failure
  /// disposing the old one is logged and otherwise ignored: it's being
  /// thrown away regardless.
  Future<void> _recreatePlayer() async {
    final old = _audioPlayer;
    _audioPlayer = AudioPlayer();
    try {
      await old.dispose();
    } catch (error) {
      debugPrint('Disposing the old audio player failed (ignored): $error');
    }
  }

  @override
  void dispose() {
    _drawCountSub?.cancel();
    _gameStateSub?.cancel();
    _claimingUidSub?.cancel();
    _lobbyUidsSub?.cancel();
    _playerUidsSub?.cancel();
    _blockedUidsSub?.cancel();
    _soundEnabledSub?.cancel();
    _stopAudioTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _drawOrder;
    final deckExhausted = _drawCount >= loteriaDeck.length;
    final currentCard = (order != null && _drawCount >= 1)
        ? order[_drawCount - 1]
        : null;
    final recentCards = <LoteriaCard>[
      if (order != null)
        for (var i = _drawCount - 1; i >= 1 && i > _drawCount - 4; i--)
          order[i - 1],
    ];

    return StageBackground(
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 340,
                  child: currentCard == null
                      ? null
                      : _CardReveal(
                          key: ValueKey(_drawCount),
                          card: currentCard,
                        ),
                ),
                if (recentCards.isNotEmpty) ...[
                  const SizedBox(width: 56),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < recentCards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        Opacity(
                          opacity: 0.65 - i * 0.18,
                          child: SizedBox(
                            width: 130 - i * 18,
                            child: AspectRatio(
                              aspectRatio: 250 / 375,
                              child: SpriteCrop(
                                assetPath: _cardsSpriteAsset,
                                sourceRect: recentCards[i].spriteRect,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_gameState == GameState.paused)
            const Positioned(top: 32, left: 32, child: _PausedBadge()),
          if (_winningPattern != null)
            Positioned(
              top: 32,
              right: 32,
              child: WinningPatternBadge(pattern: _winningPattern!),
            ),
          if (deckExhausted)
            const Positioned.fill(child: Center(child: _NoMoreCardsBanner())),
          if (_claimingUid != null)
            const Positioned.fill(child: Center(child: _ClaimCue())),
          Positioned(
            bottom: 32,
            left: 32,
            child: _ActivePlayersBadge(
              active: _playerUids.intersection(_lobbyUids).length,
              blocked: _blockedUids.intersection(_lobbyUids).length,
            ),
          ),
        ],
      ),
    );
  }
}

/// implementation-plan.md v2 TODO: "`<x>` active players, `<y>` blocked" --
/// only counting UIDs still present in `lobby` (i.e. still connected),
/// per the TODO's own intersection rule. The intersections themselves are
/// computed by the caller (`DrawingScreen.build`) since they need all
/// three live sets (`players`, `blocked_uids`, `lobby`) together; this
/// widget just renders the two resulting numbers.
class _ActivePlayersBadge extends StatelessWidget {
  const _ActivePlayersBadge({required this.active, required this.blocked});

  final int active;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$active active players, $blocked blocked',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "a large visible claim cue" (implementation-plan.md) while
/// `game.claiming_uid` is non-empty -- spec.md describes this vaguely as
/// "a character somewhere on the screen", but no such asset exists (same
/// gap as the winning-pattern diagram earlier), so this is a bold, pulsing
/// banner instead: unmistakable from the back of a room, which is the
/// actual requirement.
class _ClaimCue extends StatefulWidget {
  const _ClaimCue();

  @override
  State<_ClaimCue> createState() => _ClaimCueState();
}

class _ClaimCueState extends State<_ClaimCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.amber.shade600,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 32)],
        ),
        child: const Text(
          '¡LOTERÍA!',
          style: TextStyle(
            color: Colors.black,
            fontSize: 72,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// The current card's entrance: slides down and rotates into place from
/// above-and-to-the-side, as if just drawn from a deck and set down --
/// smooth and decisive (no bounce/overshoot), fading in over the same
/// motion. Plays once per mount; the parent remounts a fresh instance
/// (via `ValueKey(drawCount)`) for every new card.
class _CardReveal extends StatefulWidget {
  const _CardReveal({super.key, required this.card});

  final LoteriaCard card;

  @override
  State<_CardReveal> createState() => _CardRevealState();
}

class _CardRevealState extends State<_CardReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _rotation;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0.35, -0.55),
      end: Offset.zero,
    ).animate(curved);
    _rotation = Tween<double>(begin: -0.22, end: 0).animate(curved);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionalTranslation(
          translation: _offset.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.rotate(angle: _rotation.value, child: child),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 250 / 375,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: SpriteCrop(
            assetPath: _cardsSpriteAsset,
            sourceRect: widget.card.spriteRect,
          ),
        ),
      ),
    );
  }
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Paused',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// implementation-plan.md: "if the deck ever becomes empty ... show a large
/// 'No more cards' label over the existing displays" -- an overlay, not a
/// replacement, so the final drawn card stays visible underneath.
class _NoMoreCardsBanner extends StatelessWidget {
  const _NoMoreCardsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'No more cards',
        style: TextStyle(
          color: Colors.white,
          fontSize: 64,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

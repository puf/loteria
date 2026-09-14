import 'dart:ui';

/// A single card in the 54-card Lotería deck: its source rectangle within
/// `assets/loteria_assets/cards-sprite.png`, and its spoken-name clip
/// within `assets/loteria_assets/cards.mp3`.
///
/// Slugs, display names, sprite coordinates, and audio timing were all read
/// directly from the original Google Doodle's source (`loteria19.js`), not
/// estimated -- the sprite/audio timing there is generated from the same
/// per-card `[slug, sprite-rect]` / `[slug, audio-key]` tables this class
/// mirrors, so it exactly matches the shipped `cards-sprite.png` and
/// `cards.mp3` (summing every card's [audioDuration] from [audioStart]
/// lands within 50ms of `cards.mp3`'s actual length -- the tables agree).
class LoteriaCard {
  const LoteriaCard(
    this.slug,
    this.displayName,
    this.spriteRect, {
    required this.audioStart,
    required this.audioDuration,
  });

  final String slug;
  final String displayName;
  final Rect spriteRect;

  /// Where this card's spoken name starts within `cards.mp3` -- one
  /// continuous recording of all 54 names back to back, not 54 separate
  /// files.
  final Duration audioStart;

  /// How long this card's spoken-name clip runs from [audioStart].
  final Duration audioDuration;
}

// SHARED: everything in [loteriaDeck] below is a cross-app contract, not a
// player-app-only detail.
// - The slugs and their order: `Tabla` shuffles this exact list with a
//   shared seed (see tabla.dart), so the host/admin process must use the
//   identical 54-slug list in the identical order to independently
//   reproduce a player's tabla and validate claims -- a differently-ordered
//   (even if same-content) list would shuffle to a different board for the
//   same seed.
// - The sprite pixel coordinates (`spriteRect`): the host/stage view also
//   renders cards out of the same `cards-sprite.png`, so it needs this same
//   slug-to-source-rect mapping, not just the player app.
// - The audio timing (`audioStart`/`audioDuration`): only the stage/admin
//   app plays card-name audio today (spec.md's `drawing` state), but it's
//   the same kind of per-card asset metadata as the sprite rect, sourced
//   from the same place, so it lives here rather than duplicated later if
//   another app ever needs it too.
const double _cardW = 250;
const double _cardH = 375;

/// The full 54-card size of `cards-sprite.png`.
const Size cardsSpriteSize = Size(7081, 753);

/// The 54 playable cards, in the order they appear in the sprite (row 1
/// left-to-right, then row 2 left-to-right) -- also alphabetical by slug,
/// which happens to match the order their names are spoken in `cards.mp3`
/// too. Excludes the sprite's "back" and blank filler cells, which aren't
/// playable cards.
const List<LoteriaCard> loteriaDeck = [
  LoteriaCard(
    'ajolote',
    'El Ajolote',
    Rect.fromLTWH(0, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 0),
    audioDuration: Duration(milliseconds: 1790),
  ),
  LoteriaCard(
    'alacran',
    'El Alacrán',
    Rect.fromLTWH(253, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 2790),
    audioDuration: Duration(milliseconds: 1061),
  ),
  LoteriaCard(
    'arana',
    'La Araña',
    Rect.fromLTWH(506, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 4851),
    audioDuration: Duration(milliseconds: 1730),
  ),
  LoteriaCard(
    'arbol',
    'El Árbol',
    Rect.fromLTWH(759, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 7581),
    audioDuration: Duration(milliseconds: 1075),
  ),
  LoteriaCard(
    'arpa',
    'El Arpa',
    Rect.fromLTWH(1012, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 9656),
    audioDuration: Duration(milliseconds: 1258),
  ),
  LoteriaCard(
    'bandera',
    'La Bandera',
    Rect.fromLTWH(1518, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 11914),
    audioDuration: Duration(milliseconds: 1493),
  ),
  LoteriaCard(
    'bandolon',
    'El Bandolón',
    Rect.fromLTWH(1771, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 14407),
    audioDuration: Duration(milliseconds: 1038),
  ),
  LoteriaCard(
    'barril',
    'El Barril',
    Rect.fromLTWH(2024, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 16445),
    audioDuration: Duration(milliseconds: 1146),
  ),
  LoteriaCard(
    'bota',
    'La Bota',
    Rect.fromLTWH(2277, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 18590),
    audioDuration: Duration(milliseconds: 1299),
  ),
  LoteriaCard(
    'botella',
    'La Botella',
    Rect.fromLTWH(2530, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 20889),
    audioDuration: Duration(milliseconds: 1377),
  ),
  LoteriaCard(
    'buscador',
    'El Buscador',
    Rect.fromLTWH(2783, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 23266),
    audioDuration: Duration(milliseconds: 1395),
  ),
  LoteriaCard(
    'calavera',
    'La Calavera',
    Rect.fromLTWH(3036, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 25661),
    audioDuration: Duration(milliseconds: 1799),
  ),
  LoteriaCard(
    'camaron',
    'El Camarón',
    Rect.fromLTWH(3289, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 28460),
    audioDuration: Duration(milliseconds: 1434),
  ),
  LoteriaCard(
    'campana',
    'La Campana',
    Rect.fromLTWH(3542, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 30893),
    audioDuration: Duration(milliseconds: 1462),
  ),
  LoteriaCard(
    'cantarito',
    'El Cantarito',
    Rect.fromLTWH(3795, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 33355),
    audioDuration: Duration(milliseconds: 1154),
  ),
  LoteriaCard(
    'catrin',
    'El Catrín',
    Rect.fromLTWH(4048, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 35510),
    audioDuration: Duration(milliseconds: 1216),
  ),
  LoteriaCard(
    'cazo',
    'El Cazo',
    Rect.fromLTWH(4301, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 37725),
    audioDuration: Duration(milliseconds: 1248),
  ),
  LoteriaCard(
    'chalupa',
    'La Chalupa',
    Rect.fromLTWH(4554, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 39973),
    audioDuration: Duration(milliseconds: 1079),
  ),
  LoteriaCard(
    'concha',
    'La Concha',
    Rect.fromLTWH(4807, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 42052),
    audioDuration: Duration(milliseconds: 1401),
  ),
  LoteriaCard(
    'corazon',
    'El Corazón',
    Rect.fromLTWH(5060, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 44453),
    audioDuration: Duration(milliseconds: 1304),
  ),
  LoteriaCard(
    'corona',
    'La Corona',
    Rect.fromLTWH(5313, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 46757),
    audioDuration: Duration(milliseconds: 1006),
  ),
  LoteriaCard(
    'cotorro',
    'El Cotorro',
    Rect.fromLTWH(5566, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 48763),
    audioDuration: Duration(milliseconds: 1133),
  ),
  LoteriaCard(
    'dama',
    'La Dama',
    Rect.fromLTWH(5819, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 50896),
    audioDuration: Duration(milliseconds: 1304),
  ),
  LoteriaCard(
    'elote',
    'El Elote',
    Rect.fromLTWH(6072, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 53200),
    audioDuration: Duration(milliseconds: 2188),
  ),
  LoteriaCard(
    'emoji',
    'El Emoji',
    Rect.fromLTWH(6325, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 56388),
    audioDuration: Duration(milliseconds: 1534),
  ),
  LoteriaCard(
    'escalera',
    'La Escalera',
    Rect.fromLTWH(6578, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 58922),
    audioDuration: Duration(milliseconds: 1359),
  ),
  LoteriaCard(
    'estrella',
    'La Estrella',
    Rect.fromLTWH(6831, 0, _cardW, _cardH),
    audioStart: Duration(milliseconds: 61282),
    audioDuration: Duration(milliseconds: 1704),
  ),
  LoteriaCard(
    'gallo',
    'El Gallo',
    Rect.fromLTWH(0, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 63985),
    audioDuration: Duration(milliseconds: 1445),
  ),
  LoteriaCard(
    'garza',
    'La Garza',
    Rect.fromLTWH(253, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 66430),
    audioDuration: Duration(milliseconds: 843),
  ),
  LoteriaCard(
    'gorro',
    'El Gorro',
    Rect.fromLTWH(506, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 68273),
    audioDuration: Duration(milliseconds: 1168),
  ),
  LoteriaCard(
    'guacamole',
    'El Guacamole',
    Rect.fromLTWH(759, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 70442),
    audioDuration: Duration(milliseconds: 1887),
  ),
  LoteriaCard(
    'jaras',
    'Las Jaras',
    Rect.fromLTWH(1012, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 73329),
    audioDuration: Duration(milliseconds: 1180),
  ),
  LoteriaCard(
    'luna',
    'La Luna',
    Rect.fromLTWH(1265, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 75509),
    audioDuration: Duration(milliseconds: 806),
  ),
  LoteriaCard(
    'maceta',
    'La Maceta',
    Rect.fromLTWH(1518, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 77315),
    audioDuration: Duration(milliseconds: 1202),
  ),
  LoteriaCard(
    'mano',
    'La Mano',
    Rect.fromLTWH(1771, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 79517),
    audioDuration: Duration(milliseconds: 1417),
  ),
  LoteriaCard(
    'melon',
    'El Melón',
    Rect.fromLTWH(2024, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 81934),
    audioDuration: Duration(milliseconds: 925),
  ),
  LoteriaCard(
    'mundo',
    'El Mundo',
    Rect.fromLTWH(2277, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 83859),
    audioDuration: Duration(milliseconds: 2078),
  ),
  LoteriaCard(
    'musico',
    'El Músico',
    Rect.fromLTWH(2530, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 86937),
    audioDuration: Duration(milliseconds: 1377),
  ),
  LoteriaCard(
    'nopal',
    'El Nopal',
    Rect.fromLTWH(2783, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 89314),
    audioDuration: Duration(milliseconds: 1568),
  ),
  LoteriaCard(
    'pajaro',
    'El Pájaro',
    Rect.fromLTWH(3036, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 91882),
    audioDuration: Duration(milliseconds: 1770),
  ),
  LoteriaCard(
    'palma',
    'La Palma',
    Rect.fromLTWH(3289, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 94652),
    audioDuration: Duration(milliseconds: 1375),
  ),
  LoteriaCard(
    'paraguas',
    'El Paraguas',
    Rect.fromLTWH(3542, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 97027),
    audioDuration: Duration(milliseconds: 1714),
  ),
  LoteriaCard(
    'pera',
    'La Pera',
    Rect.fromLTWH(3795, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 99741),
    audioDuration: Duration(milliseconds: 784),
  ),
  LoteriaCard(
    'pescado',
    'El Pescado',
    Rect.fromLTWH(4048, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 101525),
    audioDuration: Duration(milliseconds: 1413),
  ),
  LoteriaCard(
    'pino',
    'El Pino',
    Rect.fromLTWH(4301, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 103938),
    audioDuration: Duration(milliseconds: 1180),
  ),
  LoteriaCard(
    'rana',
    'La Rana',
    Rect.fromLTWH(4554, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 106119),
    audioDuration: Duration(milliseconds: 1321),
  ),
  LoteriaCard(
    'rosa',
    'La Rosa',
    Rect.fromLTWH(4807, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 108440),
    audioDuration: Duration(milliseconds: 2125),
  ),
  LoteriaCard(
    'sandia',
    'La Sandía',
    Rect.fromLTWH(5060, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 111565),
    audioDuration: Duration(milliseconds: 1556),
  ),
  LoteriaCard(
    'sirena',
    'La Sirena',
    Rect.fromLTWH(5313, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 114121),
    audioDuration: Duration(milliseconds: 1515),
  ),
  LoteriaCard(
    'sol',
    'El Sol',
    Rect.fromLTWH(5566, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 116636),
    audioDuration: Duration(milliseconds: 1269),
  ),
  LoteriaCard(
    'tambor',
    'El Tambor',
    Rect.fromLTWH(5819, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 118905),
    audioDuration: Duration(milliseconds: 1466),
  ),
  LoteriaCard(
    'venado',
    'El Venado',
    Rect.fromLTWH(6072, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 121370),
    audioDuration: Duration(milliseconds: 1265),
  ),
  LoteriaCard(
    'violoncello',
    'El Violoncello',
    Rect.fromLTWH(6325, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 123636),
    audioDuration: Duration(milliseconds: 1670),
  ),
  LoteriaCard(
    'xoloitzcuintle',
    'El Xoloitzcuintle',
    Rect.fromLTWH(6578, 378, _cardW, _cardH),
    audioStart: Duration(milliseconds: 126306),
    audioDuration: Duration(milliseconds: 2098),
  ),
];

/// Code shared between the Loteria player app and stage/admin app --
/// cross-app contracts that must not drift apart between the two
/// codebases. Kept intentionally small: only things actually duplicated
/// live here, grown incrementally as real duplication shows up (see each
/// export's own doc comment for why it's here).
library;

export 'src/bean_image.dart';
export 'src/floating_card.dart';
export 'src/game_state.dart';
export 'src/loteria_card.dart';
export 'src/sprite_crop.dart';
export 'src/tabla.dart';
export 'src/winning_pattern.dart';
export 'src/winning_pattern_diagram.dart';

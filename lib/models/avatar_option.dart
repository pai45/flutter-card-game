class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;
}

const avatarOptions = [
  AvatarOption(
    id: 'adams',
    label: 'Adams',
    assetPath: 'assets/avatar_options/adams.webp',
  ),
  AvatarOption(
    id: 'bellingham',
    label: 'Bellingham',
    assetPath: 'assets/avatar_options/bellingham.webp',
  ),
  AvatarOption(
    id: 'raphinha',
    label: 'Raphinha',
    assetPath: 'assets/avatar_options/raphinha.webp',
  ),
  AvatarOption(
    id: 'camavinga',
    label: 'Camavinga',
    assetPath: 'assets/avatar_options/camavinga.webp',
  ),
  AvatarOption(
    id: 'ndiaye',
    label: 'Ndiaye',
    assetPath: 'assets/avatar_options/ndiaye.webp',
  ),
  AvatarOption(
    id: 'rodri',
    label: 'Rodri',
    assetPath: 'assets/avatar_options/rodri.webp',
  ),
];

AvatarOption avatarOptionById(String? id) => avatarOptions.firstWhere(
  (avatar) => avatar.id == id,
  orElse: () => avatarOptions.first,
);

/// Deterministic avatar pick from a display [name] — the same name always maps
/// to the same face. Used for leaderboard rows, the rival dossier and the
/// friends roster so a rival looks identical everywhere they appear.
AvatarOption avatarForName(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return avatarOptions[hash % avatarOptions.length];
}

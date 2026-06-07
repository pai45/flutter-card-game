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

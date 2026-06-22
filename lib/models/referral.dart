enum ReferralStatus { invited, pending, rewarded }

class ReferralEntry {
  const ReferralEntry({
    required this.id,
    required this.friendName,
    required this.status,
    required this.createdAt,
    this.reward = 0,
  });

  factory ReferralEntry.fromJson(Map<String, dynamic> json) => ReferralEntry(
    id: json['id'] as String,
    friendName: json['friendName'] as String,
    status: ReferralStatus.values.byName(json['status'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    reward: json['reward'] as int? ?? 0,
  );

  final String id;
  final String friendName;
  final ReferralStatus status;
  final DateTime createdAt;
  final int reward;

  ReferralEntry copyWith({ReferralStatus? status, int? reward}) =>
      ReferralEntry(
        id: id,
        friendName: friendName,
        status: status ?? this.status,
        createdAt: createdAt,
        reward: reward ?? this.reward,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'friendName': friendName,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'reward': reward,
  };
}

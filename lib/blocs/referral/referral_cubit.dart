import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/referral.dart';
import '../../services/secure_storage_service.dart';

class ReferralState {
  const ReferralState({
    this.loading = true,
    this.referralLink = '',
    this.referrals = const [],
    this.copied = false,
    this.sharing = false,
    this.latestReward,
  });

  final bool loading;
  final String referralLink;
  final List<ReferralEntry> referrals;
  final bool copied;
  final bool sharing;
  final int? latestReward;

  int get invitedCount => referrals.length;
  int get pendingCount =>
      referrals.where((entry) => entry.status == ReferralStatus.pending).length;
  int get rewardedCount => referrals
      .where((entry) => entry.status == ReferralStatus.rewarded)
      .length;
  int get coinsEarned => referrals.fold(0, (sum, entry) => sum + entry.reward);

  ReferralState copyWith({
    bool? loading,
    String? referralLink,
    List<ReferralEntry>? referrals,
    bool? copied,
    bool? sharing,
    int? latestReward,
    bool clearLatestReward = false,
  }) => ReferralState(
    loading: loading ?? this.loading,
    referralLink: referralLink ?? this.referralLink,
    referrals: referrals ?? this.referrals,
    copied: copied ?? this.copied,
    sharing: sharing ?? this.sharing,
    latestReward: clearLatestReward ? null : latestReward ?? this.latestReward,
  );
}

class ReferralCubit extends Cubit<ReferralState> {
  ReferralCubit(this._storage) : super(const ReferralState());

  final SecureGameStorage _storage;
  bool _simulating = false;

  Future<void> load() async {
    final tag = await _storage.loadOrCreatePlayerTag();
    var entries = await _storage.loadReferralEntries();
    if (entries == null) {
      final now = DateTime.now();
      entries = [
        ReferralEntry(
          id: 'ref-novaq',
          friendName: 'NovaQ',
          status: ReferralStatus.invited,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        ReferralEntry(
          id: 'ref-vortex',
          friendName: 'Vortex',
          status: ReferralStatus.pending,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      await _storage.saveReferralEntries(entries);
    }
    emit(
      ReferralState(
        loading: false,
        referralLink: 'https://play.statoz.app/invite?ref=$tag',
        referrals: entries,
      ),
    );
  }

  void setCopied(bool copied) => emit(state.copyWith(copied: copied));

  void setSharing(bool sharing) => emit(state.copyWith(sharing: sharing));

  void clearLatestReward() => emit(state.copyWith(clearLatestReward: true));

  Future<ReferralEntry?> simulateFriendJoined() async {
    if (_simulating) return null;
    _simulating = true;
    try {
      final index = state.referrals.indexWhere(
        (entry) => entry.status == ReferralStatus.pending,
      );
      if (index < 0) return null;

      final rewarded = state.referrals[index].copyWith(
        status: ReferralStatus.rewarded,
        reward: 500,
      );
      final updated = [...state.referrals]..[index] = rewarded;
      await _storage.saveReferralEntries(updated);
      emit(state.copyWith(referrals: updated, latestReward: 500));
      return rewarded;
    } finally {
      _simulating = false;
    }
  }
}

import 'package:flutter/material.dart';

class ProfileBannerOption {
  const ProfileBannerOption({
    required this.id,
    required this.label,
    required this.colors,
    required this.accent,
    this.assetPath,
  });

  final String id;
  final String label;
  final List<Color> colors;
  final Color accent;
  final String? assetPath;
}

const profileBannerOptions = [
  ProfileBannerOption(
    id: 'south_africa',
    label: 'South Africa',
    colors: [Color(0xff07100f), Color(0xff007a42), Color(0xffffc400)],
    accent: Color(0xff31d0ff),
    assetPath: 'assets/backgrounds/profile_banner_south_africa.png',
  ),
  ProfileBannerOption(
    id: 'green_red',
    label: 'Green Red',
    colors: [Color(0xff061d13), Color(0xff0e6f3a), Color(0xffe21e2b)],
    accent: Color(0xff44ff9a),
    assetPath: 'assets/backgrounds/profile_banner_green_red.png',
  ),
  ProfileBannerOption(
    id: 'korea',
    label: 'Korea',
    colors: [Color(0xffeef2f7), Color(0xffd9212f), Color(0xff0b3f8f)],
    accent: Color(0xfff23b4d),
    assetPath: 'assets/backgrounds/profile_banner_korea.png',
  ),
  ProfileBannerOption(
    id: 'czech',
    label: 'Czech',
    colors: [Color(0xffeef2f7), Color(0xff1452a3), Color(0xffe5242d)],
    accent: Color(0xff4ea3ff),
    assetPath: 'assets/backgrounds/profile_banner_czech.png',
  ),
];

ProfileBannerOption profileBannerOptionById(String? id) =>
    profileBannerOptions.firstWhere(
      (banner) => banner.id == id,
      orElse: () => profileBannerOptions.first,
    );

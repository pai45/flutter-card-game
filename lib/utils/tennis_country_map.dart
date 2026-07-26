import 'package:flutter/material.dart';

/// Maps well-known professional tennis player names (or partial matches) to
/// their 3-letter country abbreviation and the country's primary flag colour.
/// Used by the match-card team logo to show e.g. "ESP" in Spain-red instead of
/// the player's abbreviated name in white.
class TennisCountryMap {
  TennisCountryMap._();

  /// Returns the 3-letter country code for a tennis player, or null if unknown.
  ///
  /// Keys are matched longest-first: several surnames contain a shorter key as
  /// a substring (e.g. "Paula Badosa" contains "paul"), and the more specific
  /// key is always the correct one.
  static String? countryCodeFor(String playerName) {
    final lower = playerName.toLowerCase();
    String? best;
    var bestLength = 0;
    for (final entry in _playerCountries.entries) {
      if (entry.key.length > bestLength && lower.contains(entry.key)) {
        best = entry.value;
        bestLength = entry.key.length;
      }
    }
    return best;
  }

  /// Returns the country's primary flag colour for the given 3-letter code.
  static Color colorFor(String countryCode) =>
      _countryColors[countryCode.toUpperCase()] ?? const Color(0xff888888);

  /// Returns a flag emoji for the given 3-letter code, or null if unknown.
  /// Used as the badge glyph when the source feed doesn't carry a real flag
  /// image (see [SportTeam.flagUrl]) — a genuine flag rather than a coloured
  /// text badge, with no image asset pipeline required.
  static String? flagEmojiFor(String countryCode) =>
      _flagEmoji[countryCode.toUpperCase()];

  // ── Player → country code ───────────────────────────────────────────────
  // Keys are lower-cased substrings that uniquely identify a player.
  static const _playerCountries = <String, String>{
    // Men's (ATP)
    'sinner': 'ITA',
    'alcaraz': 'ESP',
    'djokovic': 'SRB',
    'medvedev': 'RUS',
    'zverev': 'GER',
    'rublev': 'RUS',
    'ruud': 'NOR',
    'fritz': 'USA',
    'de minaur': 'AUS',
    'hurkacz': 'POL',
    'tsitsipas': 'GRE',
    'paul': 'USA',
    'shelton': 'USA',
    'tiafoe': 'USA',
    'rune': 'DEN',
    'dimitrov': 'BUL',
    'draper': 'GBR',
    'berrettini': 'ITA',
    'musetti': 'ITA',
    'auger-aliassime': 'CAN',
    'humbert': 'FRA',
    'jarry': 'CHI',
    'cerundolo': 'ARG',
    'baez': 'ARG',
    'machac': 'CZE',
    'bublik': 'KAZ',
    'popyrin': 'AUS',
    'arnaldi': 'ITA',
    'khachanov': 'RUS',
    'giron': 'USA',
    'navone': 'ARG',
    'korda': 'USA',
    'nakashima': 'USA',
    'nishikori': 'JPN',
    'federer': 'SUI',
    'nadal': 'ESP',
    'murray': 'GBR',

    // Women's (WTA)
    'swiatek': 'POL',
    'sabalenka': 'BLR',
    'gauff': 'USA',
    'rybakina': 'KAZ',
    'pegula': 'USA',
    'zheng': 'CHN',
    'jabeur': 'TUN',
    'ostapenko': 'LAT',
    'paolini': 'ITA',
    'krejcikova': 'CZE',
    'keys': 'USA',
    'kasatkina': 'RUS',
    'vondrousova': 'CZE',
    'haddad maia': 'BRA',
    'muchova': 'CZE',
    'azarenka': 'BLR',
    'bencic': 'SUI',
    'garcia': 'FRA',
    'alexandrova': 'RUS',
    'fernandez': 'CAN',
    'kostyuk': 'UKR',
    'osaka': 'JPN',
    'andreescu': 'CAN',
    'williams': 'USA',

    // Remainder of the Top 100 roster (lib/data/tennis_athletes.dart). Keep in
    // sync when that list changes — an unmapped athlete falls back to "INT" on
    // its collectible card.
    'cobolli': 'ITA',
    'lehecka': 'CZE',
    'lehečka': 'CZE',
    'tien': 'USA',
    'darderi': 'ITA',
    'mensik': 'CZE',
    'menšík': 'CZE',
    'davidovich fokina': 'ESP',
    'vacherot': 'MON',
    'fils': 'FRA',
    'jodar': 'ESP',
    'fonseca': 'BRA',
    'rinderknech': 'FRA',
    'etcheverry': 'ARG',
    'tabilo': 'CHI',
    'buse': 'PER',
    'bergs': 'BEL',
    'fery': 'GBR',
    'blockx': 'BEL',
    'norrie': 'GBR',
    'shapovalov': 'CAN',
    'moutet': 'FRA',
    'struff': 'GER',
    'collignon': 'BEL',
    'munar': 'ESP',
    'michelsen': 'USA',
    'quinn': 'USA',
    'mannarino': 'FRA',
    'atmane': 'FRA',
    'andreeva': 'RUS',
    'noskova': 'CZE',
    'anisimova': 'USA',
    'svitolina': 'UKR',
    'mboko': 'CAN',
    'jovic': 'USA',
    'cirstea': 'ROU',
    'shnaider': 'RUS',
    'kalinskaya': 'RUS',
    'bouzkova': 'CZE',
    'chwalinska': 'POL',
    'tauson': 'DEN',
    'ann li': 'USA',
    'baptiste': 'USA',
    'siniakova': 'CZE',
    'vekic': 'CRO',
    'cristian': 'ROU',
    'sakkari': 'GRE',
    'raducanu': 'GBR',
    'tjen': 'INA',
    'wang xinyu': 'CHN',
    'bucsa': 'ESP',
    'bejlek': 'CZE',
    'bartunkova': 'CZE',
    'frech': 'POL',
    'marcinko': 'CRO',
    'kessler': 'USA',
    'golubic': 'SUI',
    'sonmez': 'TUR',
    'valentova': 'CZE',
    'ruzic': 'CRO',
    'mcnally': 'USA',
    'gibson': 'AUS',
    'kalinina': 'UKR',
    'stearns': 'USA',
    'badosa': 'ESP',
  };

  // ── Country code → primary flag colour ──────────────────────────────────
  static const _countryColors = <String, Color>{
    'ESP': Color(0xffAA151B), // Spain — red
    'SRB': Color(0xffC6363C), // Serbia — red
    'ITA': Color(0xff009246), // Italy — green
    'RUS': Color(0xff0039A6), // Russia — blue
    'GER': Color(0xff000000), // Germany — black
    'NOR': Color(0xffBA0C2F), // Norway — red
    'USA': Color(0xff3C3B6E), // USA — navy blue
    'AUS': Color(0xff00008B), // Australia — dark blue
    'POL': Color(0xffDC143C), // Poland — crimson
    'GRE': Color(0xff0D5EAF), // Greece — blue
    'DEN': Color(0xffC60C30), // Denmark — red
    'BUL': Color(0xff00966E), // Bulgaria — green
    'GBR': Color(0xff012169), // Great Britain — blue
    'CAN': Color(0xffFF0000), // Canada — red
    'FRA': Color(0xff002395), // France — blue
    'CHI': Color(0xffD52B1E), // Chile — red
    'ARG': Color(0xff75AADB), // Argentina — sky blue
    'CZE': Color(0xff11457E), // Czech Republic — blue
    'KAZ': Color(0xff00AFCA), // Kazakhstan — turquoise
    'JPN': Color(0xffBC002D), // Japan — red
    'SUI': Color(0xffFF0000), // Switzerland — red
    'BLR': Color(0xffC8313E), // Belarus — red
    'CHN': Color(0xffDE2910), // China — red
    'TUN': Color(0xffE70013), // Tunisia — red
    'LAT': Color(0xff9E3039), // Latvia — maroon
    'BRA': Color(0xff009C3B), // Brazil — green
    'UKR': Color(0xff005BBB), // Ukraine — blue
    'MON': Color(0xffCE1126), // Monaco — red
    'PER': Color(0xffD91023), // Peru — red
    'BEL': Color(0xffFDDA24), // Belgium — yellow
    'ROU': Color(0xff002B7F), // Romania — blue
    'CRO': Color(0xff171796), // Croatia — blue
    'INA': Color(0xffCE1126), // Indonesia — red
    'TUR': Color(0xffE30A17), // Turkey — red
  };

  // ── Country code → flag emoji ────────────────────────────────────────────
  static const _flagEmoji = <String, String>{
    'ESP': '🇪🇸',
    'SRB': '🇷🇸',
    'ITA': '🇮🇹',
    'RUS': '🇷🇺',
    'GER': '🇩🇪',
    'NOR': '🇳🇴',
    'USA': '🇺🇸',
    'AUS': '🇦🇺',
    'POL': '🇵🇱',
    'GRE': '🇬🇷',
    'DEN': '🇩🇰',
    'BUL': '🇧🇬',
    'GBR': '🇬🇧',
    'CAN': '🇨🇦',
    'FRA': '🇫🇷',
    'CHI': '🇨🇱',
    'ARG': '🇦🇷',
    'CZE': '🇨🇿',
    'KAZ': '🇰🇿',
    'JPN': '🇯🇵',
    'SUI': '🇨🇭',
    'BLR': '🇧🇾',
    'CHN': '🇨🇳',
    'TUN': '🇹🇳',
    'LAT': '🇱🇻',
    'BRA': '🇧🇷',
    'UKR': '🇺🇦',
    'MON': '🇲🇨',
    'PER': '🇵🇪',
    'BEL': '🇧🇪',
    'ROU': '🇷🇴',
    'CRO': '🇭🇷',
    'INA': '🇮🇩',
    'TUR': '🇹🇷',
  };
}

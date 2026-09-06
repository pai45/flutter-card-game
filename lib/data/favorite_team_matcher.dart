import '../models/sport_match.dart';
import 'followable_leagues.dart';
import 'team_palettes.dart' show normaliseTeamName;

/// Which side of a fixture is the player's favourite club.
///
/// [team] is the side as it appears on the fixture (so callers can pull its
/// real badge palette), while [leagueId]/[teamId] identify the stored
/// favourite it matched.
typedef FavoriteSide = ({
  SportTeam team,
  String leagueId,
  String teamId,
  bool isHome,
});

/// One followed club, resolved from storage against [followableLeagues].
typedef FavoriteClub = ({String leagueId, String teamId, SportTeam team});

/// Names and abbreviations that identify a followable team id in fixture data.
///
/// The catalogue in [followableLeagues] uses hand-written ids (`liv`, `mc`,
/// `new`) that mirror `MockPredictionRepository`. But the busiest leagues —
/// EPL and IPL — are filtered OUT of the mock fixture list and arrive from live
/// ESPN enrichment instead, where a team is
/// `SportTeam(id: '382', name: 'Manchester City', shortName: 'MNC')`. Matching
/// on id alone would therefore silently fail exactly where it matters most, so
/// every favourite also carries the normalised names/abbreviations the feeds
/// actually use.
///
/// Keys are [followableLeagues] team ids (globally unique). Values are
/// [normaliseTeamName] output — lowercase, de-accented, alphanumeric only.
const Map<String, Set<String>> kFavoriteTeamAliases = <String, Set<String>>{
  // ── English Premier League ────────────────────────────────────────────────
  'liv': {'liverpool', 'liverpoolfc', 'lfc', 'liv'},
  'ars': {'arsenal', 'arsenalfc', 'ars'},
  'mc': {'mancity', 'manchestercity', 'manchestercityfc', 'mci', 'mnc'},
  'mu': {'manutd', 'manchesterunited', 'manchesterutd', 'mun', 'mnu'},
  'cfc': {'chelsea', 'chelseafc', 'cfc', 'che'},
  'new': {'newcastle', 'newcastleunited', 'newcastleutd', 'new', 'nu'},
  'avl': {'astonvilla', 'astonvillafc', 'avl', 'av'},
  'whu': {'westham', 'westhamunited', 'westhamutd', 'whu', 'wham'},

  // ── La Liga ───────────────────────────────────────────────────────────────
  'rma': {'realmadrid', 'realmadridcf', 'rma', 'rmd'},
  'fcb': {'barcelona', 'fcbarcelona', 'barca', 'fcb', 'bar'},
  'atm': {'atletico', 'atleticomadrid', 'atleticodemadrid', 'atm', 'atl'},
  'sev': {'sevilla', 'sevillafc', 'sev'},
  'rso': {'realsociedad', 'realsociedadfc', 'rso'},
  'bet': {'realbetis', 'betis', 'bet'},

  // ── Serie A ───────────────────────────────────────────────────────────────
  'juv': {'juventus', 'juve', 'juv'},
  'int': {'inter', 'intermilan', 'internazionale', 'int'},
  'mil': {'acmilan', 'milan', 'mil'},
  'nap': {'napoli', 'sscnapoli', 'nap'},
  'rom': {'roma', 'asroma', 'rom'},
  'laz': {'lazio', 'sslazio', 'laz'},

  // ── Bundesliga ────────────────────────────────────────────────────────────
  // Deliberately no 'fcb' here — that abbreviation belongs to Barcelona above.
  'bay': {
    'bayern',
    'bayernmunich',
    'bayernmunchen',
    'fcbayernmunich',
    'fcbayernmunchen',
    'bay',
  },
  'bvb': {'dortmund', 'borussiadortmund', 'bvb', 'dor'},
  'rbl': {'rbleipzig', 'leipzig', 'rbl'},
  'b04': {'leverkusen', 'bayerleverkusen', 'bayer04leverkusen', 'b04', 'lev'},
  'sge': {'frankfurt', 'eintrachtfrankfurt', 'sge'},
  'wob': {'wolfsburg', 'vflwolfsburg', 'wob', 'wol'},

  // ── International T20 (cricket) ───────────────────────────────────────────
  'ind': {'india', 'ind'},
  'eng': {'england', 'eng'},
  'wi': {'westindies', 'wi', 'win'},
  'sl': {'srilanka', 'sl'},

  // ── Formula 1 ─────────────────────────────────────────────────────────────
  'rbr': {'redbullracing', 'redbull', 'rbr'},
  'fer': {'ferrari', 'scuderiaferrari', 'fer'},
  'mcl': {'mclaren', 'mcl'},
  'mer': {'mercedes', 'mercedesamg', 'mer'},
  'ast': {'astonmartin', 'ast', 'amr'},
  'wil': {'williams', 'wil'},

  // ── NBA — ESPN reports the nickname in `team.name` ────────────────────────
  'lal': {'lalakers', 'losangeleslakers', 'lakers', 'lal'},
  'bos': {'boston', 'bostonceltics', 'celtics', 'bos'},
  'gsw': {'goldenstate', 'goldenstatewarriors', 'warriors', 'gsw'},
  'mia': {'miami', 'miamiheat', 'heat', 'mia'},
  'nyk': {'newyork', 'newyorkknicks', 'knicks', 'nyk'},
  'dal': {'dallas', 'dallasmavericks', 'mavericks', 'mavs', 'dal'},

  // ── Tennis (ATP) ──────────────────────────────────────────────────────────
  'alcaraz': {'carlosalcaraz', 'alcaraz', 'alc'},
  'sinner': {'janniksinner', 'sinner', 'sin'},
  'djokovic': {'novakdjokovic', 'djokovic', 'djo'},
};

/// Every accepted identity for the followable team [teamId] in [leagueId].
Set<String> _identitiesFor(String leagueId, String teamId) {
  final identities = <String>{...?kFavoriteTeamAliases[teamId]};
  final catalogue = followableTeam(leagueId, teamId);
  if (catalogue != null) {
    identities
      ..add(normaliseTeamName(catalogue.name))
      ..add(normaliseTeamName(catalogue.shortName));
  }
  identities.remove('');
  return identities;
}

/// Whether [team], as it appears on a fixture, is the followable team
/// [teamId] from [leagueId].
bool teamMatchesFavorite(
  SportTeam team,
  String leagueId,
  String teamId,
) {
  if (team.id == teamId) return true;
  final identities = _identitiesFor(leagueId, teamId);
  if (identities.isEmpty) return false;
  return identities.contains(normaliseTeamName(team.name)) ||
      identities.contains(normaliseTeamName(team.shortName));
}

/// The side of [match] that is one of the player's favourite clubs, or null.
///
/// Favourites are scoped by **sport**, not league id: ESPN-discovered leagues
/// do not necessarily carry the curated ids (`epl`, `laliga`) the favourites
/// map is keyed by, so requiring `match.leagueId == leagueId` would drop real
/// matches. The home side wins if both sides somehow resolve.
FavoriteSide? favoriteSideOf(
  SportMatch match,
  Map<String, String> favoriteTeams,
) {
  if (favoriteTeams.isEmpty) return null;
  for (final entry in favoriteTeams.entries) {
    final league = followableLeagueById(entry.key);
    if (league == null || league.sport != match.sport) continue;
    if (teamMatchesFavorite(match.home, entry.key, entry.value)) {
      return (
        team: match.home,
        leagueId: entry.key,
        teamId: entry.value,
        isHome: true,
      );
    }
    if (teamMatchesFavorite(match.away, entry.key, entry.value)) {
      return (
        team: match.away,
        leagueId: entry.key,
        teamId: entry.value,
        isHome: false,
      );
    }
  }
  return null;
}

/// The player's followed clubs that belong to [sport], in stored order.
List<FavoriteClub> favoriteClubsForSport(
  Sport sport,
  Map<String, String> favoriteTeams,
) {
  final clubs = <FavoriteClub>[];
  for (final entry in favoriteTeams.entries) {
    final league = followableLeagueById(entry.key);
    if (league == null || league.sport != sport) continue;
    final team = followableTeam(entry.key, entry.value);
    if (team == null) continue;
    clubs.add((leagueId: entry.key, teamId: entry.value, team: team));
  }
  return clubs;
}

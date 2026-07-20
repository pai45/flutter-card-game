import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/wc_third_place_2026.dart';
import '../models/basketball_scorecard.dart';
import '../models/league.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';
import '../models/tennis_scorecard.dart';
import 'espn_score_service.dart';
import 'football_question_bank.dart';

/// Data seam for the prediction hub. The UI/cubit only ever talk to this
/// interface, so swapping [MockPredictionRepository] for an HTTP/Firebase
/// implementation when the app goes live needs no UI changes.
abstract class PredictionRepository {
  Future<List<League>> leagues();

  /// Fixtures for [day] (defaults to "today" in mock terms — returns all).
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport});

  /// All quiz sets for a fixture.
  Future<List<PredictionQuiz>> quizzesFor(String matchId);

  /// One quiz set for a fixture, or null if none is configured.
  Future<PredictionQuiz?> quizFor(String matchId, String quizId);

  /// The rank-sorted standings table for [leagueId], or empty if none.
  Future<List<TeamStanding>> standings(String leagueId);

  /// Aggregate vote totals for a match question.
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  );

  /// Rank table scoped to one prediction match.
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  );

  /// Enrich fixtures with live network data asynchronously
  Future<List<SportMatch>> enrichFixturesForSport(List<SportMatch> fixtures, Sport sport);
}

/// Hardcoded fixtures + quizzes mirroring the home mockup, spanning every card
/// state: upcoming-open, upcoming-predicted, live, and finished (football +
/// cricket). Single source of truth for fixtures until a backend exists.
class MockPredictionRepository implements PredictionRepository {
  // ── Leagues (EPL first to match the reference order) ─────────────────────────
  static const _intl = League(
    id: '23810',
    name: 'International T20',
    shortCode: 'T20I',
    accent: Color(0xfff59e0b),
  );
  static const _fifa = League(
    id: 'fifa',
    name: 'FIFA World Cup 26',
    shortCode: 'FIFA',
    accent: Color(0xff00d084),
  );
  static const _f1 = League(
    id: 'f1',
    name: 'Formula 1',
    shortCode: 'F1',
    accent: Color(0xffe10600),
  );
  static const _wnba = League(
    id: 'wnba',
    name: 'WNBA',
    shortCode: 'WNBA',
    accent: Color(0xffff6600),
  );
  static const _nba = League(
    id: 'nba',
    name: 'NBA',
    shortCode: 'NBA',
    accent: Color(0xffc9082a),
  );
  static const _atp = League(
    id: 'atp',
    name: 'ATP Tour',
    shortCode: 'ATP',
    accent: Color(0xff002865),
  );
  static const _wta = League(
    id: 'wta',
    name: 'WTA Tour',
    shortCode: 'WTA',
    accent: Color(0xff8a2be2),
  );
  static const _indycar = League(
    id: 'indycar',
    name: 'IndyCar',
    shortCode: 'INDY',
    accent: Color(0xff001489),
  );
  static const _nascarCup = League(
    id: 'nascar-cup',
    name: 'NASCAR Cup Series',
    shortCode: 'NASCAR',
    accent: Color(0xffffcc00),
  );

  // ── Soccer leagues (ESPN scoreboard feed, Jul 2026) ───────────────────────
  static const _mls = League(
    id: 'mls',
    name: 'Major League Soccer',
    shortCode: 'MLS',
    accent: Cyber.cyan,
  );
  static const _uclq = League(
    id: 'uclq',
    name: 'UCL Qualifying',
    shortCode: 'UCLQ',
    accent: Cyber.violet,
  );
  static const _brasileirao = League(
    id: 'brasileirao',
    name: 'Brasileirao Serie A',
    shortCode: 'BRA',
    accent: Cyber.success,
  );
  static const _ligaMx = League(
    id: 'ligamx',
    name: 'Liga MX',
    shortCode: 'LIGA MX',
    accent: Cyber.magenta,
  );
  static const _allsvenskan = League(
    id: 'allsvenskan',
    name: 'Allsvenskan',
    shortCode: 'ALLS',
    accent: Cyber.amber,
  );
  static const _eliteserien = League(
    id: 'eliteserien',
    name: 'Eliteserien',
    shortCode: 'ELITE',
    accent: Cyber.gold,
  );

  // ── Cricket competitions (ESPN scorepanel, Jul 2026) ──────────────────────
  static const _lpl = League(
    id: 'lpl',
    name: 'Lanka Premier League',
    shortCode: 'LPL',
    accent: Cyber.violet,
  );
  static const _pakTourWi = League(
    id: 'paktourwi',
    name: 'Pakistan tour of West Indies',
    shortCode: 'PAK v WI',
    accent: Cyber.danger,
  );
  static const _saWomenU19TourPak = League(
    id: 'sawu19tourpak',
    name: 'SA Women U19 tour of Pakistan',
    shortCode: 'SAW U19',
    accent: Cyber.magenta,
  );

  // ── Teams ──────────────────────────────────────────────────────────────────
  // ── WNBA teams (real ESPN feed) — basketball had zero seeded fixtures ─────
  // before this; NBA is off-season in July, so WNBA is the initial source.
  static const _dallasWings = SportTeam(
    id: 'dallaswings',
    name: 'Dallas Wings',
    shortName: 'DAL',
    color: Color(0xff002b5c),
  );
  static const _losAngelesSparks = SportTeam(
    id: 'losangelessparks',
    name: 'Los Angeles Sparks',
    shortName: 'LA',
    color: Color(0xff552583),
  );
  static const _atlantaDream = SportTeam(
    id: 'atlantadream',
    name: 'Atlanta Dream',
    shortName: 'ATL',
    color: Color(0xffe31837),
  );
  static const _chicagoSky = SportTeam(
    id: 'chicagosky',
    name: 'Chicago Sky',
    shortName: 'CHI',
    color: Color(0xff5091cd),
  );
  static const _phoenixMercury = SportTeam(
    id: 'phoenixmercury',
    name: 'Phoenix Mercury',
    shortName: 'PHX',
    color: Color(0xff3c286e),
  );
  static const _connecticutSun = SportTeam(
    id: 'connecticutsun',
    name: 'Connecticut Sun',
    shortName: 'CON',
    color: Color(0xfff05023),
  );
  // ── Cricket teams (Lanka Premier League + touring sides, ESPN feed) ───────
  static const _colomboKaps = SportTeam(
    id: 'colombokaps',
    name: 'Colombo Kaps',
    shortName: 'CLK',
    color: Color(0xffbe06cb),
  );
  static const _dambullaSixers = SportTeam(
    id: 'dambullasixers',
    name: 'Dambulla Sixers',
    shortName: 'DAS',
    color: Color(0xff077eda),
  );
  static const _galleGallants = SportTeam(
    id: 'gallegallants',
    name: 'Galle Gallants',
    shortName: 'GAG',
    color: Color(0xff0ed879),
  );
  static const _jaffnaKings = SportTeam(
    id: 'jaffnakings',
    name: 'Jaffna Kings',
    shortName: 'JK',
    color: Color(0xffe9ca07),
  );
  // ESPN supplies no colour for this side; placeholder chosen to stay
  // distinct from the other four LPL franchises. Correct via
  // kTeamPaletteOverrides if wrong.
  static const _kandyRoyals = SportTeam(
    id: 'kandyroyals',
    name: 'Kandy Royals',
    shortName: 'KAR',
    color: Color(0xffb3123c),
  );
  static const _pakistan = SportTeam(
    id: 'pakistan',
    name: 'Pakistan',
    shortName: 'PAK',
    color: Color(0xff07df52),
  );
  // ESPN supplies no colour for the U19 side; reuses Pakistan's senior green.
  static const _pakistanWomenU19 = SportTeam(
    id: 'pakistanwomenu19',
    name: 'Pakistan Women Under-19s',
    shortName: 'PAW19',
    color: Color(0xff07df52),
  );
  // ESPN supplies no colour for the U19 side; matches the app's South Africa green.
  static const _southAfricaWomenU19 = SportTeam(
    id: 'southafricawomenu19',
    name: 'South Africa Women Under-19s',
    shortName: 'SAW19',
    color: Color(0xff16a34a),
  );
  // ── Soccer teams — names/abbreviations/brand colours from the ESPN feed.
  // Colours too dark to read on the fixture card fall back to the club's
  // ESPN alternate colour, or are lifted in-hue until legible.
  static const _agf = SportTeam(
    id: '7853',
    name: 'AGF',
    shortName: 'AGF',
    color: Color(0xff64748b),  // lifted
  );
  static const _araratArmenia = SportTeam(
    id: '20024',
    name: 'Ararat-Armenia',
    shortName: 'ARA',
    color: Color(0xff64748b),  // lifted
  );
  static const _athleticoPr = SportTeam(
    id: '3458',
    name: 'Athletico-PR',
    shortName: 'CAP',
    color: Color(0xffd80518),
  );
  static const _atlantaUnitedFc = SportTeam(
    id: '18418',
    name: 'Atlanta United FC',
    shortName: 'ATL',
    color: Color(0xff9d2235),
  );
  static const _atleticoMg = SportTeam(
    id: '7632',
    name: 'Atlético-MG',
    shortName: 'CAM',
    color: Color(0xfffafafc),  // alternate
  );
  static const _austinFc = SportTeam(
    id: '20906',
    name: 'Austin FC',
    shortName: 'ATX',
    color: Color(0xff00b140),
  );
  static const _bkHacken = SportTeam(
    id: '7834',
    name: 'BK Häcken',
    shortName: 'BKH',
    color: Color(0xfff7ee09),  // alternate
  );
  static const _bahia = SportTeam(
    id: '9967',
    name: 'Bahia',
    shortName: 'BAH',
    color: Color(0xff0093ec),  // alternate
  );
  static const _bodoGlimt = SportTeam(
    id: '2980',
    name: 'Bodo/Glimt',
    shortName: 'BODO',
    color: Color(0xfffcee33),
  );
  static const _botafogo = SportTeam(
    id: '6086',
    name: 'Botafogo',
    shortName: 'BOT',
    color: Color(0xfffafafc),  // alternate
  );
  static const _cfMontreal = SportTeam(
    id: '9720',
    name: 'CF Montréal',
    shortName: 'MTL',
    color: Color(0xff003da6),
  );
  static const _csuCraiova = SportTeam(
    id: '8089',
    name: 'CSU Craiova',
    shortName: 'UCRA',
    color: Color(0xff64748b),  // lifted
  );
  static const _chapecoense = SportTeam(
    id: '9318',
    name: 'Chapecoense',
    shortName: 'CHA',
    color: Color(0xff417505),
  );
  static const _charlotteFc = SportTeam(
    id: '21300',
    name: 'Charlotte FC',
    shortName: 'CLT',
    color: Color(0xff0085ca),
  );
  static const _chicagoFireFc = SportTeam(
    id: '182',
    name: 'Chicago Fire FC',
    shortName: 'CHI',
    color: Color(0xff7ccdef),
  );
  static const _coloradoRapids = SportTeam(
    id: '184',
    name: 'Colorado Rapids',
    shortName: 'COL',
    color: Color(0xff8a2432),
  );
  static const _columbusCrew = SportTeam(
    id: '183',
    name: 'Columbus Crew',
    shortName: 'CLB',
    color: Color(0xfffedd00),  // alternate
  );
  static const _corinthians = SportTeam(
    id: '874',
    name: 'Corinthians',
    shortName: 'COR',
    color: Color(0xfffafafc),  // alternate
  );
  static const _coritiba = SportTeam(
    id: '3456',
    name: 'Coritiba',
    shortName: 'CFC',
    color: Color(0xff417505),
  );
  static const _cruzAzul = SportTeam(
    id: '218',
    name: 'Cruz Azul',
    shortName: 'CAZ',
    color: Color(0xffffffff),  // alternate
  );
  static const _cruzeiro = SportTeam(
    id: '2022',
    name: 'Cruzeiro',
    shortName: 'CRU',
    color: Color(0xff0093ec),
  );
  static const _dCUnited = SportTeam(
    id: '193',
    name: 'D.C. United',
    shortName: 'DC',
    color: Color(0xffd61018),  // alternate
  );
  static const _degerforsIf = SportTeam(
    id: '20856',
    name: 'Degerfors IF',
    shortName: 'DEG',
    color: Color(0xff64748b),  // lifted
  );
  static const _dinamoZagreb = SportTeam(
    id: '597',
    name: 'Dinamo Zagreb',
    shortName: 'DZG',
    color: Color(0xffccff00),  // alternate
  );
  static const _djurgarden = SportTeam(
    id: '2339',
    name: 'Djurgården',
    shortName: 'DJU',
    color: Color(0xff64a6e1),
  );
  static const _egnatia = SportTeam(
    id: '21943',
    name: 'Egnatia',
    shortName: 'EGN',
    color: Color(0xff64748b),  // lifted
  );
  static const _fcCincinnati = SportTeam(
    id: '18267',
    name: 'FC Cincinnati',
    shortName: 'CIN',
    color: Color(0xfffe5000),  // alternate
  );
  static const _fcDallas = SportTeam(
    id: '185',
    name: 'FC Dallas',
    shortName: 'DAL',
    color: Color(0xffc6093b),
  );
  static const _fcThun = SportTeam(
    id: '3024',
    name: 'FC Thun',
    shortName: 'THUN',
    color: Color(0xffff0900),
  );
  static const _fenerbahce = SportTeam(
    id: '436',
    name: 'Fenerbahce',
    shortName: 'FEN',
    color: Color(0xffffff00),
  );
  static const _flamengo = SportTeam(
    id: '819',
    name: 'Flamengo',
    shortName: 'FLA',
    color: Color(0xffd84f4f),  // lifted
  );
  static const _gornikZabrze = SportTeam(
    id: '8180',
    name: 'Gornik Zabrze',
    shortName: 'GOR',
    color: Color(0xff64748b),  // lifted
  );
  static const _halmstadsBk = SportTeam(
    id: '3017',
    name: 'Halmstads BK',
    shortName: 'HBK',
    color: Color(0xff0058a2),
  );
  static const _hamarkameratene = SportTeam(
    id: '21380',
    name: 'Hamarkameratene',
    shortName: 'HAM',
    color: Color(0xff64748b),  // lifted
  );
  static const _hammarbyIf = SportTeam(
    id: '2495',
    name: 'Hammarby IF',
    shortName: 'HAM',
    color: Color(0xffffcc00),
  );
  static const _hapoelBeEr = SportTeam(
    id: '13083',
    name: 'Hapoel Be\'er',
    shortName: 'HBE',
    color: Color(0xfffd0000),
  );
  static const _heartOfMidlothian = SportTeam(
    id: '262',
    name: 'Heart of Midlothian',
    shortName: 'HOM',
    color: Color(0xffead6b7),  // alternate
  );
  static const _houstonDynamoFc = SportTeam(
    id: '6077',
    name: 'Houston Dynamo FC',
    shortName: 'HOU',
    color: Color(0xffff6b00),
  );
  static const _ifElfsborg = SportTeam(
    id: '529',
    name: 'IF Elfsborg',
    shortName: 'ELF',
    color: Color(0xffffef32),
  );
  static const _ikSirius = SportTeam(
    id: '8547',
    name: 'IK Sirius',
    shortName: 'SIR',
    color: Color(0xffd62612),
  );
  static const _iberia1999 = SportTeam(
    id: '20025',
    name: 'Iberia 1999',
    shortName: 'IBE',
    color: Color(0xff64748b),  // lifted
  );
  static const _interMiamiCf = SportTeam(
    id: '20232',
    name: 'Inter Miami CF',
    shortName: 'MIA',
    color: Color(0xfff7b5cd),  // alternate
  );
  static const _internacional = SportTeam(
    id: '1936',
    name: 'Internacional',
    shortName: 'INT',
    color: Color(0xffd84f4f),  // lifted
  );
  static const _kiKlaksvik = SportTeam(
    id: '2547',
    name: 'KI Klaksvik',
    shortName: 'KLA',
    color: Color(0xff64748b),  // lifted
  );
  static const _kairatAlmaty = SportTeam(
    id: '2528',
    name: 'Kairat Almaty',
    shortName: 'KAI',
    color: Color(0xfffcee33),
  );
  static const _kalmarFf = SportTeam(
    id: '3052',
    name: 'Kalmar FF',
    shortName: 'KFF',
    color: Color(0xffdb1b30),
  );
  static const _kaunoZalgiris = SportTeam(
    id: '20028',
    name: 'Kauno Zalgiris',
    shortName: 'ZAL',
    color: Color(0xff64748b),  // lifted
  );
  static const _kupsKuopio = SportTeam(
    id: '8169',
    name: 'KuPS Kuopio',
    shortName: 'KUPS',
    color: Color(0xff64748b),  // lifted
  );
  static const _laGalaxy = SportTeam(
    id: '187',
    name: 'LA Galaxy',
    shortName: 'LA',
    color: Color(0xffffffff),  // alternate
  );
  static const _lafc = SportTeam(
    id: '18966',
    name: 'LAFC',
    shortName: 'LAFC',
    color: Color(0xffc7a36f),  // alternate
  );
  static const _larne = SportTeam(
    id: '20039',
    name: 'Larne',
    shortName: 'LAR',
    color: Color(0xffffffff),  // alternate
  );
  static const _lechPoznan = SportTeam(
    id: '2990',
    name: 'Lech Poznan',
    shortName: 'LECH',
    color: Color(0xff64748b),  // lifted
  );
  static const _levskiSofia = SportTeam(
    id: '490',
    name: 'Levski Sofia',
    shortName: 'LEVS',
    color: Color(0xff6182cf),
  );
  static const _lillestrom = SportTeam(
    id: '987',
    name: 'Lillestrom',
    shortName: 'LIL',
    color: Color(0xffe8e337),
  );
  static const _lincolnRedImps = SportTeam(
    id: '17856',
    name: 'Lincoln Red Imps',
    shortName: 'LRI',
    color: Color(0xffffffff),  // alternate
  );
  static const _malmoFf = SportTeam(
    id: '2720',
    name: 'Malmö FF',
    shortName: 'MAL',
    color: Color(0xff5699eb),
  );
  static const _minnesotaUnitedFc = SportTeam(
    id: '17362',
    name: 'Minnesota United FC',
    shortName: 'MIN',
    color: Color(0xff9bcde4),  // alternate
  );
  static const _mjallbyAif = SportTeam(
    id: '20301',
    name: 'Mjällby AIF',
    shortName: 'MJA',
    color: Color(0xffffd400),  // alternate
  );
  static const _nkCelje = SportTeam(
    id: '3362',
    name: 'NK Celje',
    shortName: 'NKC',
    color: Color(0xffff6600),  // alternate
  );
  static const _nashvilleSc = SportTeam(
    id: '18986',
    name: 'Nashville SC',
    shortName: 'NSH',
    color: Color(0xffece83a),
  );
  static const _newEnglandRevolution = SportTeam(
    id: '189',
    name: 'New England Revolution',
    shortName: 'NE',
    color: Color(0xffce0e2d),  // alternate
  );
  static const _newYorkCityFc = SportTeam(
    id: '17606',
    name: 'New York City FC',
    shortName: 'NYC',
    color: Color(0xff9fd2ff),
  );
  static const _omoniaNicosia = SportTeam(
    id: '617',
    name: 'Omonia Nicosia',
    shortName: 'OMON',
    color: Color(0xff025719),
  );
  static const _orgryteIs = SportTeam(
    id: '131552',
    name: 'Örgryte IS',
    shortName: 'Örg',
    color: Color(0xff64748b),  // lifted
  );
  static const _orlandoCitySc = SportTeam(
    id: '12011',
    name: 'Orlando City SC',
    shortName: 'ORL',
    color: Color(0xff60269e),
  );
  static const _palmeiras = SportTeam(
    id: '2029',
    name: 'Palmeiras',
    shortName: 'PAL',
    color: Color(0xff417505),
  );
  static const _philadelphiaUnion = SportTeam(
    id: '10739',
    name: 'Philadelphia Union',
    shortName: 'PHI',
    color: Color(0xffe0d0a6),  // alternate
  );
  static const _portlandTimbers = SportTeam(
    id: '9723',
    name: 'Portland Timbers',
    shortName: 'POR',
    color: Color(0xff2c5234),
  );
  static const _puebla = SportTeam(
    id: '231',
    name: 'Puebla',
    shortName: 'PUE',
    color: Color(0xffffffff),
  );
  static const _pumasUnam = SportTeam(
    id: '233',
    name: 'Pumas UNAM',
    shortName: 'UNAM',
    color: Color(0xffffffff),
  );
  static const _realSaltLake = SportTeam(
    id: '4771',
    name: 'Real Salt Lake',
    shortName: 'RSL',
    color: Color(0xffa32035),
  );
  static const _redBullNewYork = SportTeam(
    id: '190',
    name: 'Red Bull New York',
    shortName: 'RBNY',
    color: Color(0xffba0c2f),
  );
  static const _redStarBelgrade = SportTeam(
    id: '2290',
    name: 'Red Star Belgrade',
    shortName: 'RSB',
    color: Color(0xffff0000),
  );
  static const _remo = SportTeam(
    id: '4936',
    name: 'Remo',
    shortName: 'REMO',
    color: Color(0xff265891),
  );
  static const _skSturmGraz = SportTeam(
    id: '3746',
    name: 'SK Sturm Graz',
    shortName: 'STG',
    color: Color(0xffffffff),
  );
  static const _sabahFk = SportTeam(
    id: '21922',
    name: 'Sabah FK',
    shortName: 'SAB',
    color: Color(0xff64748b),  // lifted
  );
  static const _sanDiegoFc = SportTeam(
    id: '22529',
    name: 'San Diego FC',
    shortName: 'SD',
    color: Color(0xff697a7c),
  );
  static const _sanJoseEarthquakes = SportTeam(
    id: '191',
    name: 'San Jose Earthquakes',
    shortName: 'SJ',
    color: Color(0xff003da6),
  );
  static const _saoPaulo = SportTeam(
    id: '2026',
    name: 'São Paulo',
    shortName: 'SAO',
    color: Color(0xffd84f4f),  // lifted
  );
  static const _seattleSoundersFc = SportTeam(
    id: '9726',
    name: 'Seattle Sounders FC',
    shortName: 'SEA',
    color: Color(0xff2dc84d),
  );
  static const _shamrockRovers = SportTeam(
    id: '2564',
    name: 'Shamrock Rovers',
    shortName: 'SHR',
    color: Color(0xff288a00),
  );
  static const _slovanBratislava = SportTeam(
    id: '521',
    name: 'Slovan Bratislava',
    shortName: 'SLB',
    color: Color(0xff81c0ff),
  );
  static const _sportingKansasCity = SportTeam(
    id: '186',
    name: 'Sporting Kansas City',
    shortName: 'SKC',
    color: Color(0xffa7c6ed),
  );
  static const _stLouisCitySc = SportTeam(
    id: '21812',
    name: 'St. Louis CITY SC',
    shortName: 'STL',
    color: Color(0xffec1458),
  );
  static const _toluca = SportTeam(
    id: '223',
    name: 'Toluca',
    shortName: 'TOL',
    color: Color(0xffef0107),
  );
  static const _torontoFc = SportTeam(
    id: '7318',
    name: 'Toronto FC',
    shortName: 'TOR',
    color: Color(0xffaa182c),
  );
  static const _vancouverWhitecaps = SportTeam(
    id: '9727',
    name: 'Vancouver Whitecaps',
    shortName: 'VAN',
    color: Color(0xffffffff),
  );
  static const _vikingFk = SportTeam(
    id: '510',
    name: 'Viking FK',
    shortName: 'VIK',
    color: Color(0xffffffff),  // alternate
  );
  static const _vikingurReykjavik = SportTeam(
    id: '8249',
    name: 'Vikingur Reykjavik',
    shortName: 'VIK',
    color: Color(0xffffffff),  // alternate
  );
  static const _vitoria = SportTeam(
    id: '3457',
    name: 'Vitória',
    shortName: 'VIT',
    color: Color(0xffc6101c),
  );
  // ── F1 race weekends ────────────────────────────────────────────────────────
  // Each F1 fixture is one race weekend; `home` carries the Grand Prix name so
  // it reads in the weekend-hub header, `away` is the field placeholder.
  static const _f1Field = SportTeam(
    id: 'f1_field',
    name: 'Formula 1',
    shortName: 'F1',
    color: Color(0xffe10600),
  );
  static const _gpBritish = SportTeam(
    id: 'gp_british',
    name: 'British Grand Prix',
    shortName: 'GBR',
    color: Color(0xff012169),
  );
  static const _gpBelgian = SportTeam(
    id: 'gp_belgian',
    name: 'Belgian Grand Prix',
    shortName: 'BEL',
    color: Color(0xfffdda24),
  );
  static const _gpHungarian = SportTeam(
    id: 'gp_hungarian',
    name: 'Hungarian Grand Prix',
    shortName: 'HUN',
    color: Color(0xffcd2a3e),
  );

  // Championship standings — shared across weekends (order = points table).
  static const _f1Standings = <String>[
    'Charles Leclerc',
    'George Russell',
    'Lewis Hamilton',
    'Lando Norris',
    'Isack Hadjar',
    'Liam Lawson',
    'Arvid Lindblad',
    'Gabriel Bortoleto',
    'Franco Colapinto',
    'Pierre Gasly',
    'Oscar Piastri',
    'Oliver Bearman',
    'Esteban Ocon',
    'Sergio Pérez',
    'Kimi Antonelli',
    'Valtteri Bottas',
    'Carlos Sainz',
    'Fernando Alonso',
    'Lance Stroll',
    'Max Verstappen',
    'Alexander Albon',
    'Nico Hülkenberg',
  ];

  // Session line-up for a weekend that has not run yet (results fill in later).
  static const _f1UpcomingSessions = <F1SessionResult>[
    F1SessionResult(name: 'Practice 1', results: []),
    F1SessionResult(name: 'Practice 2', results: []),
    F1SessionResult(name: 'Practice 3', results: []),
    F1SessionResult(name: 'Qualifying', results: []),
    F1SessionResult(name: 'Race', results: []),
  ];
  static const _france = SportTeam(
    id: 'fra',
    name: 'France',
    shortName: 'FRA',
    color: Color(0xff1d4ed8),
  );
  static const _paraguay = SportTeam(
    id: 'par',
    name: 'Paraguay',
    shortName: 'PAR',
    color: Color(0xffd7263d),
  );
  static const _senegal = SportTeam(
    id: 'sen',
    name: 'Senegal',
    shortName: 'SEN',
    color: Color(0xff16a34a),
  );
  static const _iraq = SportTeam(
    id: 'irq',
    name: 'Iraq',
    shortName: 'IRQ',
    color: Color(0xffdc2626),
  );
  static const _norway = SportTeam(
    id: 'nor',
    name: 'Norway',
    shortName: 'NOR',
    color: Color(0xff0f4c81),
  );
  static const _argentina = SportTeam(
    id: 'arg',
    name: 'Argentina',
    shortName: 'ARG',
    color: Color(0xff74acdf),
  );
  static const _algeria = SportTeam(
    id: 'alg',
    name: 'Algeria',
    shortName: 'ALG',
    color: Color(0xff059669),
  );
  static const _austria = SportTeam(
    id: 'aut',
    name: 'Austria',
    shortName: 'AUT',
    color: Color(0xffef4444),
  );
  static const _jordan = SportTeam(
    id: 'jor',
    name: 'Jordan',
    shortName: 'JOR',
    color: Color(0xffb91c1c),
  );
  static const _ghana = SportTeam(
    id: 'gha',
    name: 'Ghana',
    shortName: 'GHA',
    color: Color(0xfffacc15),
  );
  static const _panama = SportTeam(
    id: 'pan',
    name: 'Panama',
    shortName: 'PAN',
    color: Color(0xff2563eb),
  );
  static const _england = SportTeam(
    id: 'eng',
    name: 'England',
    shortName: 'ENG',
    color: Color(0xffffffff),
  );
  static const _india = SportTeam(
    id: 'ind',
    name: 'India',
    shortName: 'IND',
    color: Color(0xff1d4ed8),
  );
  static const _westIndies = SportTeam(
    id: 'wi',
    name: 'West Indies',
    shortName: 'WI',
    color: Color(0xff7a0016),
  );
  static const _sriLanka = SportTeam(
    id: 'sl',
    name: 'Sri Lanka',
    shortName: 'SL',
    color: Color(0xff002b54),
  );
  static const _denmark = SportTeam(
    id: 'den',
    name: 'Denmark',
    shortName: 'DEN',
    color: Color(0xffc60c30),
  );
  static const _estonia = SportTeam(
    id: 'est',
    name: 'Estonia',
    shortName: 'EST',
    color: Color(0xff0072ce),
  );

  static const _gibraltar = SportTeam(
    id: 'gibr',
    name: 'Gibraltar',
    shortName: 'GIBR',
    color: Color(0xffe2001a),
  );
  static const _hungary = SportTeam(
    id: 'hun',
    name: 'Hungary',
    shortName: 'HUN',
    color: Color(0xff436f4d),
  );

  static const _romania = SportTeam(
    id: 'rom',
    name: 'Romania',
    shortName: 'ROM',
    color: Color(0xfffcd116),
  );
  static const _serbia = SportTeam(
    id: 'srb',
    name: 'Serbia',
    shortName: 'SRB',
    color: Color(0xffc6363c),
  );
  static const _croatia = SportTeam(
    id: 'cro',
    name: 'Croatia',
    shortName: 'CRO',
    color: Color(0xff1d4ed8),
  );
  static const _portugal = SportTeam(
    id: 'por',
    name: 'Portugal',
    shortName: 'POR',
    color: Color(0xffb91c1c),
  );
  static const _congoDr = SportTeam(
    id: 'cod',
    name: 'Congo DR',
    shortName: 'COD',
    color: Color(0xff38bdf8),
  );
  static const _uzbekistan = SportTeam(
    id: 'uzb',
    name: 'Uzbekistan',
    shortName: 'UZB',
    color: Color(0xff22d3ee),
  );
  static const _colombia = SportTeam(
    id: 'col',
    name: 'Colombia',
    shortName: 'COL',
    color: Color(0xfffacc15),
  );
  static const _brazil = SportTeam(
    id: 'bra',
    name: 'Brazil',
    shortName: 'BRA',
    color: Color(0xfffacc15),
  );
  static const _japan = SportTeam(
    id: 'jpn',
    name: 'Japan',
    shortName: 'JPN',
    color: Color(0xffffffff),
  );
  static const _germany = SportTeam(
    id: 'ger',
    name: 'Germany',
    shortName: 'GER',
    color: Color(0xffffffff),
  );
  static const _sweden = SportTeam(
    id: 'swe',
    name: 'Sweden',
    shortName: 'SWE',
    color: Color(0xfffacc15),
  );
  static const _morocco = SportTeam(
    id: 'mar',
    name: 'Morocco',
    shortName: 'MAR',
    color: Color(0xffc1272d),
  );
  static const _canada = SportTeam(
    id: 'can',
    name: 'Canada',
    shortName: 'CAN',
    color: Color(0xffef4444),
  );
  static const _spain = SportTeam(
    id: 'esp',
    name: 'Spain',
    shortName: 'ESP',
    color: Color(0xfff59e0b),
  );
  static const _usa = SportTeam(
    id: 'usa',
    name: 'United States',
    shortName: 'USA',
    color: Color(0xff2563eb),
  );
  static const _belgium = SportTeam(
    id: 'bel',
    name: 'Belgium',
    shortName: 'BEL',
    color: Color(0xfffacc15),
  );
  static const _mexico = SportTeam(
    id: 'mex',
    name: 'Mexico',
    shortName: 'MEX',
    color: Color(0xff16a34a),
  );
  static const _egypt = SportTeam(
    id: 'egy',
    name: 'Egypt',
    shortName: 'EGY',
    color: Color(0xffdc2626),
  );
  static const _switzerland = SportTeam(
    id: 'sui',
    name: 'Switzerland',
    shortName: 'SUI',
    color: Color(0xffef4444),
  );
  static const _netherlands = SportTeam(
    id: 'ned',
    name: 'Netherlands',
    shortName: 'NED',
    color: Color(0xffff7a00),
  );
  static const _southAfrica = SportTeam(
    id: 'rsa',
    name: 'South Africa',
    shortName: 'RSA',
    color: Color(0xff16a34a),
  );
  static const _caboVerde = SportTeam(
    id: 'cpv',
    name: 'Cabo Verde',
    shortName: 'CPV',
    color: Color(0xff2563eb),
  );
  static const _liv = SportTeam(
    id: 'liv',
    name: 'Liverpool',
    shortName: 'LFC',
    color: Color(0xffc8102e),
  );
  static const _mc = SportTeam(
    id: 'mc',
    name: 'Man City',
    shortName: 'MCI',
    color: Color(0xff6cabdd),
  );
  static const _cfc = SportTeam(
    id: 'cfc',
    name: 'Chelsea',
    shortName: 'CFC',
    color: Color(0xff1f4fd6),
  );
  static const _new = SportTeam(
    id: 'new',
    name: 'Newcastle',
    shortName: 'NEW',
    color: Color(0xffededE8),
  );
  static const _mu = SportTeam(
    id: 'mu',
    name: 'Man Utd',
    shortName: 'MU',
    color: Color(0xffd5122a),
  );
  static const _whu = SportTeam(
    id: 'whu',
    name: 'West Ham',
    shortName: 'WHU',
    color: Color(0xff7a263a),
  );
  static const _srh = SportTeam(
    id: 'srh',
    name: 'Hyderabad',
    shortName: 'SRH',
    color: Color(0xffff822e),
  );
  static const _mi = SportTeam(
    id: 'mi',
    name: 'Mumbai',
    shortName: 'MI',
    color: Color(0xff2856a5),
  );
  static const _pjk = SportTeam(
    id: 'pjk',
    name: 'Punjab',
    shortName: 'PJK',
    color: Color(0xffdcd9cf),
  );
  static const _kkr = SportTeam(
    id: 'kkr',
    name: 'KKR',
    shortName: 'KKR',
    color: Color(0xfff0c419),
  );

  // Extra teams that only populate the standings tables (no fixtures yet).
  static const _ars = SportTeam(
    id: 'ars',
    name: 'Arsenal',
    shortName: 'ARS',
    color: Color(0xffef0107),
  );
  static const _avl = SportTeam(
    id: 'avl',
    name: 'Aston Villa',
    shortName: 'AVL',
    color: Color(0xff7a003c),
  );
  static const _bha = SportTeam(
    id: 'bha',
    name: 'Brighton',
    shortName: 'BHA',
    color: Color(0xff0057b8),
  );
  static const _eve = SportTeam(
    id: 'eve',
    name: 'Everton',
    shortName: 'EVE',
    color: Color(0xff003399),
  );
  static const _bur = SportTeam(
    id: 'bur',
    name: 'Burnley',
    shortName: 'BUR',
    color: Color(0xff6c1d45),
  );
  static const _csk = SportTeam(
    id: 'csk',
    name: 'Chennai',
    shortName: 'CSK',
    color: Color(0xfff9cd05),
  );
  static const _rcb = SportTeam(
    id: 'rcb',
    name: 'Bangalore',
    shortName: 'RCB',
    color: Color(0xffd81920),
  );

  // Tennis Teams (Players)
  static const _alcaraz = SportTeam(
    id: 'carlos_alcaraz',
    name: 'Carlos Alcaraz',
    shortName: 'C. Alcaraz',
    color: Color(0xffffffff),
  );
  static const _djokovic = SportTeam(
    id: 'novak_djokovic',
    name: 'Novak Djokovic',
    shortName: 'N. Djokovic',
    color: Color(0xffffffff),
  );
  static const _paolini = SportTeam(
    id: 'jasmine_paolini',
    name: 'Jasmine Paolini',
    shortName: 'J. Paolini',
    color: Color(0xffffffff),
  );
  static const _krejcikova = SportTeam(
    id: 'barbora_krejcikova',
    name: 'Barbora Krejcikova',
    shortName: 'B. Krejcikova',
    color: Color(0xffffffff),
  );

  // Fixtures are built relative to "now" so statuses stay believable on launch.
  late final DateTime _now = DateTime.now();
  late final DateTime _today = DateTime(_now.year, _now.month, _now.day);

  DateTime _at(int dayOffset, int hour, [int minute = 0]) =>
      _today.add(Duration(days: dayOffset, hours: hour, minutes: minute));

  MatchStatus _fallbackStatusFor(DateTime kickoff) {
    if (_now.isBefore(kickoff)) return MatchStatus.upcoming;
    if (_now.isBefore(kickoff.add(const Duration(minutes: 125)))) {
      return MatchStatus.live;
    }
    return MatchStatus.finished;
  }

  /// Synchronous read access to the seeded fixture catalogue, for the picks
  /// side (MockPickRepository) to auto-generate/auto-settle markets against
  /// without needing its own duplicate copy of this data.
  List<SportMatch> get seedFixtures => _fixtures;

  late final List<SportMatch> _fixtures = [
    // ── WNBA, 19 Jul 2026 (real ESPN feed) ───────────────────────────────────
    // Basketball had zero fixtures before this — NBA is off-season in July,
    // so WNBA is the only viable initial source.
    SportMatch(
      id: '401857080',
      leagueId: _wnba.id,
      sport: Sport.basketball,
      home: _dallasWings,
      away: _losAngelesSparks,
      kickoff: DateTime.utc(2026, 7, 19, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    SportMatch(
      id: '401857081',
      leagueId: _wnba.id,
      sport: Sport.basketball,
      home: _atlantaDream,
      away: _chicagoSky,
      kickoff: DateTime.utc(2026, 7, 19, 20, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    SportMatch(
      id: '401857082',
      leagueId: _wnba.id,
      sport: Sport.basketball,
      home: _phoenixMercury,
      away: _connecticutSun,
      kickoff: DateTime.utc(2026, 7, 19, 23, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Demo: finished WNBA fixture with NO hand-authored quiz override — its
    // quiz is built and settled entirely by QuizArchetypes/SettlementWriter
    // (the new auto-settlement engine) the first time loadSport runs, so a
    // fresh install proves basketball reaches the gold-reveal state without
    // anyone hand-transcribing a result.
    SportMatch(
      id: 'wnba_demo_dal_phx',
      leagueId: _wnba.id,
      sport: Sport.basketball,
      home: _dallasWings,
      away: _phoenixMercury,
      kickoff: _at(-1, 19, 0),
      status: MatchStatus.finished,
      homeScore: '82',
      awayScore: '75',
      resultLine: 'Dallas Wings won 82-75',
      basketballScorecard: const BasketballScorecard(
        homeBoxscore: BasketballTeamBoxscore(
          teamName: 'Dallas Wings',
          teamId: 'dallaswings',
          stats: BasketballTeamStats(
            fgMadeApt: '30-68',
            fgPct: 44.1,
            tpMadeApt: '8-22',
            tpPct: 36.4,
            ftMadeApt: '14-18',
            ftPct: 77.8,
            rebounds: 34,
            assists: 19,
            steals: 7,
            blocks: 3,
            turnovers: 12,
          ),
          players: [],
        ),
        awayBoxscore: BasketballTeamBoxscore(
          teamName: 'Phoenix Mercury',
          teamId: 'phoenixmercury',
          stats: BasketballTeamStats(
            fgMadeApt: '27-64',
            fgPct: 42.2,
            tpMadeApt: '7-24',
            tpPct: 29.2,
            ftMadeApt: '14-19',
            ftPct: 73.7,
            rebounds: 31,
            assists: 16,
            steals: 5,
            blocks: 2,
            turnovers: 14,
          ),
          players: [],
        ),
        linescores: BasketballLinescores(
          homeScores: [22, 20, 21, 19],
          awayScores: [18, 19, 20, 18],
          homeTotal: 82,
          awayTotal: 75,
        ),
      ),
      rewardXp: 25,
    ),
    // ── World Cup 2026 third-place play-off ─────────────────────────────────
    // England beat France 6-4 at Hard Rock Stadium. Full ESPN detail (team
    // stats, timeline, lineups, play-by-play) lives in wc_third_place_2026.dart
    // and drives the STATS tab.
    SportMatch(
      id: '760516',
      leagueId: _fifa.id,
      sport: Sport.football,
      home: _france,
      away: _england,
      kickoff: DateTime.utc(2026, 7, 18, 21, 0).toLocal(),
      status: MatchStatus.finished,
      homeScore: '4',
      awayScore: '6',
      resultLine: 'England won 6-4 to take third place',
      teamStats: kWcThirdPlaceTeamStats,
      timelineEvents: kWcThirdPlaceTimeline,
      homeLineup: kWcThirdPlaceFranceLineup,
      awayLineup: kWcThirdPlaceEnglandLineup,
      commentary: kWcThirdPlaceCommentary,
      rewardXp: 60,
    ),
    // ── Real ESPN cricket fixtures, 20–26 Jul 2026 ──────────────────────────
    // ESPN's cricket scoreboards reject date ranges, so these were swept one
    // day at a time per competition. Kickoffs are the feed's UTC timestamps.
    // Lanka Premier League · Dambulla Sixers v Kandy Royals · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537336',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _dambullaSixers,
      away: _kandyRoyals,
      kickoff: DateTime.utc(2026, 7, 21, 14, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Colombo Kaps v Jaffna Kings · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537337',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _colomboKaps,
      away: _jaffnaKings,
      kickoff: DateTime.utc(2026, 7, 22, 9, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Dambulla Sixers v Galle Gallants · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537338',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _dambullaSixers,
      away: _galleGallants,
      kickoff: DateTime.utc(2026, 7, 22, 14, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // South Africa Women U19 tour of Pakistan · Pakistan Women Under-19s v South Africa Women Under-19s · National Stadium, Karachi
    SportMatch(
      id: '1545550',
      leagueId: _saWomenU19TourPak.id,
      sport: Sport.cricket,
      home: _pakistanWomenU19,
      away: _southAfricaWomenU19,
      kickoff: DateTime.utc(2026, 7, 22, 14, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Colombo Kaps v Kandy Royals · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537339',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _colomboKaps,
      away: _kandyRoyals,
      kickoff: DateTime.utc(2026, 7, 23, 9, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Galle Gallants v Jaffna Kings · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537340',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _galleGallants,
      away: _jaffnaKings,
      kickoff: DateTime.utc(2026, 7, 23, 14, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // South Africa Women U19 tour of Pakistan · Pakistan Women Under-19s v South Africa Women Under-19s · National Stadium, Karachi
    SportMatch(
      id: '1545551',
      leagueId: _saWomenU19TourPak.id,
      sport: Sport.cricket,
      home: _pakistanWomenU19,
      away: _southAfricaWomenU19,
      kickoff: DateTime.utc(2026, 7, 24, 14, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Galle Gallants v Kandy Royals · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537341',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _galleGallants,
      away: _kandyRoyals,
      kickoff: DateTime.utc(2026, 7, 25, 9, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Dambulla Sixers v Colombo Kaps · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537342',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _dambullaSixers,
      away: _colomboKaps,
      kickoff: DateTime.utc(2026, 7, 25, 14, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Pakistan tour of West Indies · West Indies v Pakistan · Brian Lara Stadium, Tarouba, Trinidad
    SportMatch(
      id: '1538630',
      leagueId: _pakTourWi.id,
      sport: Sport.cricket,
      home: _westIndies,
      away: _pakistan,
      kickoff: DateTime.utc(2026, 7, 25, 14, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 40,
    ),
    // Lanka Premier League · Jaffna Kings v Kandy Royals · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537343',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _jaffnaKings,
      away: _kandyRoyals,
      kickoff: DateTime.utc(2026, 7, 26, 9, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Lanka Premier League · Dambulla Sixers v Galle Gallants · Rangiri Dambulla International Stadium
    SportMatch(
      id: '1537344',
      leagueId: _lpl.id,
      sport: Sport.cricket,
      home: _dambullaSixers,
      away: _galleGallants,
      kickoff: DateTime.utc(2026, 7, 26, 14, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // ── Real ESPN soccer fixtures, 19–23 Jul 2026 ───────────────────────────
    // Pulled from site.api.espn.com scoreboard; kickoffs are the feed's UTC
    // timestamps rendered in local time. XP scales with the stage.
    // Swedish Allsvenskan · IK Sirius at IF Elfsborg · Boras Arena
    SportMatch(
      id: '401842755',
      leagueId: _allsvenskan.id,
      sport: Sport.football,
      home: _ifElfsborg,
      away: _ikSirius,
      kickoff: DateTime.utc(2026, 7, 19, 14, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Swedish Allsvenskan · Degerfors IF at Hammarby IF · Tele2 Arena
    SportMatch(
      id: '401842760',
      leagueId: _allsvenskan.id,
      sport: Sport.football,
      home: _hammarbyIf,
      away: _degerforsIf,
      kickoff: DateTime.utc(2026, 7, 19, 14, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Swedish Allsvenskan · BK Häcken at Halmstads BK · Örjans Vall
    SportMatch(
      id: '401842761',
      leagueId: _allsvenskan.id,
      sport: Sport.football,
      home: _halmstadsBk,
      away: _bkHacken,
      kickoff: DateTime.utc(2026, 7, 19, 14, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // FIFA World Cup · Argentina at Spain · MetLife Stadium
    SportMatch(
      id: '760517',
      leagueId: _fifa.id,
      sport: Sport.football,
      home: _spain,
      away: _argentina,
      kickoff: DateTime.utc(2026, 7, 19, 19, 0).toLocal(),
      status: MatchStatus.upcoming,
      prizeLabel: 'FINAL',
      rewardXp: 100,
    ),
    // Swedish Allsvenskan · Djurgården at Örgryte IS · Gamla Ullevi
    SportMatch(
      id: '401842756',
      leagueId: _allsvenskan.id,
      sport: Sport.football,
      home: _orgryteIs,
      away: _djurgarden,
      kickoff: DateTime.utc(2026, 7, 20, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Swedish Allsvenskan · Malmö FF at Kalmar FF · Guldfageln Arena
    SportMatch(
      id: '401842758',
      leagueId: _allsvenskan.id,
      sport: Sport.football,
      home: _kalmarFf,
      away: _malmoFf,
      kickoff: DateTime.utc(2026, 7, 20, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // UEFA Champions League Qualifying · Slovan Bratislava at Iberia 1999 · Mikheil Meskhi Stadioni
    SportMatch(
      id: '401891563',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _iberia1999,
      away: _slovanBratislava,
      kickoff: DateTime.utc(2026, 7, 21, 16, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Lincoln Red Imps at Mjällby AIF · Strandvallen
    SportMatch(
      id: '401891564',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _mjallbyAif,
      away: _lincolnRedImps,
      kickoff: DateTime.utc(2026, 7, 21, 16, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · KuPS Kuopio at Sabah FK · Bank Respublika Stadium
    SportMatch(
      id: '401891587',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _sabahFk,
      away: _kupsKuopio,
      kickoff: DateTime.utc(2026, 7, 21, 16, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Shamrock Rovers at Ararat-Armenia · Vazgen Sargsyan Republican Stadium
    SportMatch(
      id: '401891670',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _araratArmenia,
      away: _shamrockRovers,
      kickoff: DateTime.utc(2026, 7, 21, 16, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Lech Poznan at AGF · Cepheus Park Randers
    SportMatch(
      id: '401877837',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _agf,
      away: _lechPoznan,
      kickoff: DateTime.utc(2026, 7, 21, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Gornik Zabrze at Fenerbahce · Ulker Stadyumu
    SportMatch(
      id: '401877768',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _fenerbahce,
      away: _gornikZabrze,
      kickoff: DateTime.utc(2026, 7, 21, 18, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Dinamo Zagreb at FC Thun · Stockhorn Arena
    SportMatch(
      id: '401877769',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _fcThun,
      away: _dinamoZagreb,
      kickoff: DateTime.utc(2026, 7, 21, 18, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Heart of Midlothian at SK Sturm Graz · Merkur Arena
    SportMatch(
      id: '401877836',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _skSturmGraz,
      away: _heartOfMidlothian,
      kickoff: DateTime.utc(2026, 7, 21, 18, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Kauno Zalgiris at KI Klaksvik · Djúpumyrar
    SportMatch(
      id: '401891845',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _kiKlaksvik,
      away: _kaunoZalgiris,
      kickoff: DateTime.utc(2026, 7, 21, 18, 45).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Hapoel Be'er at Vikingur Reykjavik · Vikingsvöllur
    SportMatch(
      id: '401891588',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _vikingurReykjavik,
      away: _hapoelBeEr,
      kickoff: DateTime.utc(2026, 7, 21, 19, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · Red Star Belgrade at Larne · Inver Park
    SportMatch(
      id: '401891687',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _larne,
      away: _redStarBelgrade,
      kickoff: DateTime.utc(2026, 7, 21, 19, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // Brazil Serie A · Bahia at Atlético-MG · Arena MRV
    SportMatch(
      id: '401841148',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _atleticoMg,
      away: _bahia,
      kickoff: DateTime.utc(2026, 7, 21, 22, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Liga MX · Puebla at Cruz Azul · Estadio Corregidora
    SportMatch(
      id: '401877036',
      leagueId: _ligaMx.id,
      sport: Sport.football,
      home: _cruzAzul,
      away: _puebla,
      kickoff: DateTime.utc(2026, 7, 22, 1, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Liga MX · Pumas UNAM at Toluca · Estadio Nemesio Díez Riega
    SportMatch(
      id: '401877035',
      leagueId: _ligaMx.id,
      sport: Sport.football,
      home: _toluca,
      away: _pumasUnam,
      kickoff: DateTime.utc(2026, 7, 22, 3, 5).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Norwegian Eliteserien · Viking FK at Lillestrom · Arasen Stadion
    SportMatch(
      id: '401843362',
      leagueId: _eliteserien.id,
      sport: Sport.football,
      home: _lillestrom,
      away: _vikingFk,
      kickoff: DateTime.utc(2026, 7, 22, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // Norwegian Eliteserien · Hamarkameratene at Bodo/Glimt · Aspmyra Stadion
    SportMatch(
      id: '401873902',
      leagueId: _eliteserien.id,
      sport: Sport.football,
      home: _bodoGlimt,
      away: _hamarkameratene,
      kickoff: DateTime.utc(2026, 7, 22, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 20,
    ),
    // UEFA Champions League Qualifying · Kairat Almaty at Omonia Nicosia · GSP Stadium
    SportMatch(
      id: '401891884',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _omoniaNicosia,
      away: _kairatAlmaty,
      kickoff: DateTime.utc(2026, 7, 22, 17, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · CSU Craiova at Levski Sofia · Georgi Asparuhov Stadium
    SportMatch(
      id: '401891788',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _levskiSofia,
      away: _csuCraiova,
      kickoff: DateTime.utc(2026, 7, 22, 17, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // UEFA Champions League Qualifying · NK Celje at Egnatia · Arena Egnatia
    SportMatch(
      id: '401891883',
      leagueId: _uclq.id,
      sport: Sport.football,
      home: _egnatia,
      away: _nkCelje,
      kickoff: DateTime.utc(2026, 7, 22, 19, 0).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 30,
    ),
    // Brazil Serie A · Palmeiras at Coritiba · Couto Pereira
    SportMatch(
      id: '401841152',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _coritiba,
      away: _palmeiras,
      kickoff: DateTime.utc(2026, 7, 22, 22, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Red Bull New York at Philadelphia Union · Subaru Park
    SportMatch(
      id: '761665',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _philadelphiaUnion,
      away: _redBullNewYork,
      kickoff: DateTime.utc(2026, 7, 22, 23, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Toronto FC at New England Revolution · Gillette Stadium
    SportMatch(
      id: '761666',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _newEnglandRevolution,
      away: _torontoFc,
      kickoff: DateTime.utc(2026, 7, 22, 23, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Chicago Fire FC at Inter Miami CF · Nu Stadium
    SportMatch(
      id: '761667',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _interMiamiCf,
      away: _chicagoFireFc,
      kickoff: DateTime.utc(2026, 7, 22, 23, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · New York City FC at Columbus Crew · ScottsMiracle-Gro Field
    SportMatch(
      id: '761668',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _columbusCrew,
      away: _newYorkCityFc,
      kickoff: DateTime.utc(2026, 7, 22, 23, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Vancouver Whitecaps at FC Cincinnati · TQL Stadium
    SportMatch(
      id: '761669',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _fcCincinnati,
      away: _vancouverWhitecaps,
      kickoff: DateTime.utc(2026, 7, 22, 23, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Atlanta United FC at Charlotte FC · Bank of America Stadium
    SportMatch(
      id: '761670',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _charlotteFc,
      away: _atlantaUnitedFc,
      kickoff: DateTime.utc(2026, 7, 23, 0, 15).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Brazil Serie A · Flamengo at Chapecoense · Arena Condá
    SportMatch(
      id: '401841150',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _chapecoense,
      away: _flamengo,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Brazil Serie A · Cruzeiro at Internacional · Estadio Beira-Rio
    SportMatch(
      id: '401841154',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _internacional,
      away: _cruzeiro,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Brazil Serie A · Athletico-PR at São Paulo · Estádio Municipal Cicero de Souza Marques
    SportMatch(
      id: '401841156',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _saoPaulo,
      away: _athleticoPr,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · D.C. United at Houston Dynamo FC · Shell Energy Stadium
    SportMatch(
      id: '761671',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _houstonDynamoFc,
      away: _dCUnited,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Minnesota United FC at Sporting Kansas City · Children's Mercy Park
    SportMatch(
      id: '761672',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _sportingKansasCity,
      away: _minnesotaUnitedFc,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · CF Montréal at Nashville SC · GEODIS Park
    SportMatch(
      id: '761673',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _nashvilleSc,
      away: _cfMontreal,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Seattle Sounders FC at Austin FC · Q2 Stadium
    SportMatch(
      id: '761674',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _austinFc,
      away: _seattleSoundersFc,
      kickoff: DateTime.utc(2026, 7, 23, 0, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · San Diego FC at Colorado Rapids · Dick's Sporting Goods Park
    SportMatch(
      id: '761675',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _coloradoRapids,
      away: _sanDiegoFc,
      kickoff: DateTime.utc(2026, 7, 23, 1, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Orlando City SC at San Jose Earthquakes · PayPal Park
    SportMatch(
      id: '761676',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _sanJoseEarthquakes,
      away: _orlandoCitySc,
      kickoff: DateTime.utc(2026, 7, 23, 2, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · FC Dallas at Portland Timbers · Providence Park
    SportMatch(
      id: '761677',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _portlandTimbers,
      away: _fcDallas,
      kickoff: DateTime.utc(2026, 7, 23, 2, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · St. Louis CITY SC at LA Galaxy · Dignity Health Sports Park
    SportMatch(
      id: '761678',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _laGalaxy,
      away: _stLouisCitySc,
      kickoff: DateTime.utc(2026, 7, 23, 2, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // MLS · Real Salt Lake at LAFC · BMO Stadium
    SportMatch(
      id: '761679',
      leagueId: _mls.id,
      sport: Sport.football,
      home: _lafc,
      away: _realSaltLake,
      kickoff: DateTime.utc(2026, 7, 23, 2, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Brazil Serie A · Remo at Corinthians · Neo Química Arena
    SportMatch(
      id: '401841151',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _corinthians,
      away: _remo,
      kickoff: DateTime.utc(2026, 7, 23, 22, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Brazil Serie A · Vitória at Botafogo · Joao Havelange Stadium
    SportMatch(
      id: '401879458',
      leagueId: _brasileirao.id,
      sport: Sport.football,
      home: _botafogo,
      away: _vitoria,
      kickoff: DateTime.utc(2026, 7, 23, 22, 30).toLocal(),
      status: MatchStatus.upcoming,
      rewardXp: 25,
    ),
    // Wimbledon Men's Final (Mock)
    SportMatch(
      id: 'wimbledon_mens_final_26',
      leagueId: 'atp',
      sport: Sport.tennis,
      home: _alcaraz,
      away: _djokovic,
      kickoff: DateTime(2026, 7, 12, 14),
      status: MatchStatus.finished,
      homeScore: '3',
      awayScore: '0',
      prizeLabel: 'Win 8500 coins',
      tennisScorecard: const TennisScorecard(sets: [
        TennisSet(homeScore: 6, awayScore: 4, isHomeWinner: true),
        TennisSet(homeScore: 6, awayScore: 2, isHomeWinner: true),
        TennisSet(homeScore: 6, awayScore: 1, isHomeWinner: true),
      ]),
    ),
    // Wimbledon Women's Final (Mock)
    SportMatch(
      id: 'wimbledon_womens_final_26',
      leagueId: 'wta',
      sport: Sport.tennis,
      home: _krejcikova,
      away: _paolini,
      kickoff: DateTime(2026, 7, 11, 14),
      status: MatchStatus.finished,
      homeScore: '2',
      awayScore: '1',
      prizeLabel: 'Win 8200 coins',
      tennisScorecard: const TennisScorecard(sets: [
        TennisSet(homeScore: 6, awayScore: 2, isHomeWinner: true),
        TennisSet(homeScore: 2, awayScore: 6, isAwayWinner: true),
        TennisSet(homeScore: 6, awayScore: 4, isHomeWinner: true),
      ]),
    ),
    // FIFA World Cup 26 knockout stage only: Round of 32 through Final.
    SportMatch(
      id: 'fifa_r32_mex_rsa',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _mexico,
      away: _southAfrica,
      kickoff: DateTime(2026, 6, 28, 18),
      status: _fallbackStatusFor(DateTime(2026, 6, 28, 18)),
      prizeLabel: 'Win 4200 coins',
    ),
    SportMatch(
      id: 'fifa_r32_bra_jpn',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _brazil,
      away: _japan,
      kickoff: DateTime(2026, 6, 28, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 6, 28, 20, 30)),
      prizeLabel: 'Win 5200 coins',
    ),
    SportMatch(
      id: 'fifa_r32_ger_par',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _germany,
      away: _paraguay,
      kickoff: DateTime(2026, 6, 28, 23),
      status: _fallbackStatusFor(DateTime(2026, 6, 28, 23)),
      prizeLabel: 'Win 4800 coins',
    ),
    SportMatch(
      id: 'fifa_r32_ned_mar',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _netherlands,
      away: _morocco,
      kickoff: DateTime(2026, 6, 29, 18),
      status: _fallbackStatusFor(DateTime(2026, 6, 29, 18)),
      prizeLabel: 'Win 4300 coins',
    ),
    SportMatch(
      id: 'fifa_r32_fra_swe',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _france,
      away: _sweden,
      kickoff: DateTime(2026, 6, 29, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 6, 29, 20, 30)),
      prizeLabel: 'Win 5600 coins',
    ),
    SportMatch(
      id: 'fifa_r32_arg_cpv',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _argentina,
      away: _caboVerde,
      kickoff: DateTime(2026, 6, 29, 23),
      status: _fallbackStatusFor(DateTime(2026, 6, 29, 23)),
      prizeLabel: 'Win 5800 coins',
    ),
    SportMatch(
      id: 'fifa_r32_por_cro',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _portugal,
      away: _croatia,
      kickoff: DateTime(2026, 6, 30, 18),
      status: _fallbackStatusFor(DateTime(2026, 6, 30, 18)),
      prizeLabel: 'Win 5400 coins',
    ),
    SportMatch(
      id: 'fifa_r32_usa_sen',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _usa,
      away: _senegal,
      kickoff: DateTime(2026, 6, 30, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 6, 30, 20, 30)),
      prizeLabel: 'Win 5000 coins',
    ),
    SportMatch(
      id: 'fifa_r32_eng_gha',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _england,
      away: _ghana,
      kickoff: DateTime(2026, 7, 1, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 1, 18)),
      prizeLabel: 'Win 5200 coins',
    ),
    SportMatch(
      id: 'fifa_r32_esp_aut',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _spain,
      away: _austria,
      kickoff: DateTime(2026, 7, 1, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 1, 20, 30)),
      prizeLabel: 'Win 5300 coins',
    ),
    SportMatch(
      id: 'fifa_r32_bel_ira',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _belgium,
      away: _iraq,
      kickoff: DateTime(2026, 7, 2, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 2, 18)),
      prizeLabel: 'Win 4700 coins',
    ),
    SportMatch(
      id: 'fifa_r32_nor_egy',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _norway,
      away: _egypt,
      kickoff: DateTime(2026, 7, 2, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 2, 20, 30)),
      prizeLabel: 'Win 4500 coins',
    ),
    SportMatch(
      id: 'fifa_r32_sui_alg',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _switzerland,
      away: _algeria,
      kickoff: DateTime(2026, 7, 3, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 3, 18)),
      prizeLabel: 'Win 3900 coins',
    ),
    SportMatch(
      id: 'fifa_r32_can_col',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _canada,
      away: _colombia,
      kickoff: DateTime(2026, 7, 3, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 3, 20, 30)),
      prizeLabel: 'Win 4600 coins',
    ),
    SportMatch(
      id: 'fifa_r32_pan_uzb',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _panama,
      away: _uzbekistan,
      kickoff: DateTime(2026, 7, 3, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 3, 23)),
      prizeLabel: 'Win 3600 coins',
    ),
    SportMatch(
      id: 'fifa_r32_jor_cod',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _jordan,
      away: _congoDr,
      kickoff: DateTime(2026, 7, 3, 23, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 3, 23, 30)),
      prizeLabel: 'Win 3600 coins',
    ),
    SportMatch(
      id: 'fifa_r16_can_mar',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _canada,
      away: _morocco,
      kickoff: DateTime(2026, 7, 4, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 4, 18)),
      prizeLabel: 'Win 6200 coins',
    ),
    SportMatch(
      id: 'fifa_fra_par',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _france,
      away: _paraguay,
      kickoff: DateTime(2026, 7, 5, 2, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 5, 2, 30)),
      prizeLabel: 'Win 7000 coins',
      liveStatusNote: 'Live score not updated yet',
    ),
    SportMatch(
      id: 'fifa_r16_bra_nor',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _brazil,
      away: _norway,
      kickoff: DateTime(2026, 7, 5, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 5, 18)),
      prizeLabel: 'Win 6400 coins',
    ),
    SportMatch(
      id: 'fifa_r16_mex_eng',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _mexico,
      away: _england,
      kickoff: DateTime(2026, 7, 5, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 5, 23)),
      prizeLabel: 'Win 6500 coins',
    ),
    SportMatch(
      id: 'fifa_r16_por_esp',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _portugal,
      away: _spain,
      kickoff: DateTime(2026, 7, 6, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 6, 18)),
      prizeLabel: 'Win 6800 coins',
    ),
    SportMatch(
      id: 'fifa_r16_usa_bel',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _usa,
      away: _belgium,
      kickoff: DateTime(2026, 7, 6, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 6, 23)),
      prizeLabel: 'Win 6100 coins',
    ),
    SportMatch(
      id: 'fifa_r16_arg_egy',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _argentina,
      away: _egypt,
      kickoff: DateTime(2026, 7, 7, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 7, 18)),
      prizeLabel: 'Win 6600 coins',
    ),
    SportMatch(
      id: 'fifa_r16_sui_col',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _switzerland,
      away: _colombia,
      kickoff: DateTime(2026, 7, 7, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 7, 23)),
      prizeLabel: 'Win 6000 coins',
    ),
    SportMatch(
      id: 'fifa_qf_mar_fra',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _morocco,
      away: _france,
      kickoff: DateTime(2026, 7, 9, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 9, 23)),
      prizeLabel: 'Win 8000 coins',
    ),
    SportMatch(
      id: 'fifa_qf_por_bel',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _portugal,
      away: _belgium,
      kickoff: DateTime(2026, 7, 10, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 10, 23)),
      prizeLabel: 'Win 7800 coins',
    ),
    SportMatch(
      id: 'fifa_qf_nor_eng',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _norway,
      away: _england,
      kickoff: DateTime(2026, 7, 11, 18),
      status: _fallbackStatusFor(DateTime(2026, 7, 11, 18)),
      prizeLabel: 'Win 7600 coins',
    ),
    SportMatch(
      id: 'fifa_qf_arg_col',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _argentina,
      away: _colombia,
      kickoff: DateTime(2026, 7, 11, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 11, 23)),
      prizeLabel: 'Win 7900 coins',
    ),
    SportMatch(
      id: 'fifa_sf_fra_bel',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _france,
      away: _belgium,
      kickoff: DateTime(2026, 7, 14, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 14, 23)),
      prizeLabel: 'Win 9000 coins',
    ),
    SportMatch(
      id: 'fifa_sf_eng_arg',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _england,
      away: _argentina,
      kickoff: DateTime(2026, 7, 15, 23),
      status: _fallbackStatusFor(DateTime(2026, 7, 15, 23)),
      prizeLabel: 'Win 9000 coins',
    ),
    SportMatch(
      id: 'fifa_third_bel_eng',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _belgium,
      away: _england,
      kickoff: DateTime(2026, 7, 18, 20, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 18, 20, 30)),
      prizeLabel: 'Win 6500 coins',
    ),
    SportMatch(
      id: 'fifa_final_fra_arg',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _france,
      away: _argentina,
      kickoff: DateTime(2026, 7, 19, 23, 30),
      status: _fallbackStatusFor(DateTime(2026, 7, 19, 23, 30)),
      prizeLabel: 'Win 12000 coins',
    ),
    // ── Demo fixtures (yesterday) for the redesigned match-card states. All
    // finished so they sit together under one day-back on the MATCH tab.
    // 1) Finished + an unsettled prediction → gold "RESULTS ARE OUT" (unclaimed).
    SportMatch(
      id: 'fifa_demo_esp_ger',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _spain,
      away: _germany,
      kickoff: _at(-1, 18, 30),
      status: MatchStatus.finished,
      homeScore: '2',
      awayScore: '1',
    ),
    // 2) Finished + settled win + a won Oz pick → revealed "+XP | +OZ". Reuses
    // the orphan 'fifa_arg_jor_winner' market (matchId fifa_arg_jor) for volume.
    SportMatch(
      id: 'fifa_arg_jor',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _argentina,
      away: _jordan,
      kickoff: _at(-1, 16),
      status: MatchStatus.finished,
      homeScore: '3',
      awayScore: '1',
    ),
    // 3) Finished, never engaged → "FULL TIME | VOL" (ignored).
    SportMatch(
      id: 'fifa_demo_eng_cro',
      leagueId: 'fifa',
      sport: Sport.football,
      home: _england,
      away: _croatia,
      kickoff: _at(-1, 21),
      status: MatchStatus.finished,
      homeScore: '1',
      awayScore: '0',
    ),
    // EPL — today's headline fixture: Man Utd vs Arsenal.
    SportMatch(
      id: 'epl_mu_ars',
      leagueId: 'epl',
      sport: Sport.football,
      home: _mu,
      away: _ars,
      kickoff: _at(0, 17, 30),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
    ),
    // EPL — upcoming, open for prediction (prize strip).
    SportMatch(
      id: 'epl_liv_mc',
      leagueId: 'epl',
      sport: Sport.football,
      home: _liv,
      away: _mc,
      kickoff: _at(0, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
    ),
    // EPL — live football, score in progress.
    SportMatch(
      id: 'epl_cfc_new',
      leagueId: 'epl',
      sport: Sport.football,
      home: _cfc,
      away: _new,
      kickoff: _now.subtract(const Duration(minutes: 67)),
      status: MatchStatus.live,
      liveMinute: 67,
      homeScore: '2',
      awayScore: '1',
    ),
    // EPL — finished football, earned reward (no result line on the card).
    SportMatch(
      id: 'epl_mu_whu',
      leagueId: 'epl',
      sport: Sport.football,
      home: _mu,
      away: _whu,
      kickoff: _at(-1, 19, 30),
      status: MatchStatus.finished,
      homeScore: '2',
      awayScore: '1',
      rewardXp: 100,
    ),
    // IPL — finished cricket, per-side innings + result + earned reward.
    SportMatch(
      id: 'ipl_srh_mi',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _srh,
      away: _mi,
      kickoff: _at(-2, 15),
      status: MatchStatus.finished,
      homeScore: '202-10 (20 ov)',
      awayScore: '221-4 (20 ov)',
      resultLine: 'Mumbai won by 19 runs',
      rewardXp: 100,
    ),
    // IPL — upcoming, already predicted (see PredictionCubit demo seed).
    SportMatch(
      id: 'ipl_pjk_kkr',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _pjk,
      away: _kkr,
      kickoff: _at(0, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
    ),
    // IPL — finished cricket, settled prediction history demo (PJK vs RCB).
    SportMatch(
      id: 'ipl_pjk_rcb',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _pjk,
      away: _rcb,
      kickoff: _at(-3, 15),
      status: MatchStatus.finished,
      homeScore: '221-4',
      awayScore: '198-8 (20 ov)',
      resultLine: 'Punjab won by 23 runs',
      rewardXp: 20,
    ),
    SportMatch(
      id: 'epl_ars_new',
      leagueId: 'epl',
      sport: Sport.football,
      home: _ars,
      away: _new,
      kickoff: _at(1, 20),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 3000 coins',
    ),
    // Live IND vs ENG API matched event!
    SportMatch(
      id: '1496576', // ESPN Event ID
      leagueId: '23810', // ESPN League ID
      sport: Sport.cricket,
      home: _england,
      away: _india,
      kickoff: _now,
      status: MatchStatus.live,
    ),
    SportMatch(
      id: '1543361',
      leagueId: '1543347',
      sport: Sport.cricket,
      home: _denmark,
      away: _estonia,
      kickoff: _now,
      status: MatchStatus.live,
    ),
    SportMatch(
      id: '1543362',
      leagueId: '1543347',
      sport: Sport.cricket,
      home: _gibraltar,
      away: _belgium,
      kickoff: _now,
      status: MatchStatus.live,
    ),
    SportMatch(
      id: '1543363',
      leagueId: '1543347',
      sport: Sport.cricket,
      home: _hungary,
      away: _norway,
      kickoff: _now.add(const Duration(hours: 4)),
      status: MatchStatus.upcoming,
    ),
    SportMatch(
      id: '1543364',
      leagueId: '1543347',
      sport: Sport.cricket,
      home: _romania,
      away: _serbia,
      kickoff: _now.add(const Duration(hours: 4)),
      status: MatchStatus.upcoming,
    ),
    SportMatch(
      id: '1538312',
      leagueId: '23810', // Map to International T20
      sport: Sport.cricket,
      home: _westIndies,
      away: _sriLanka,
      kickoff: _at(-4, 14),
      status: MatchStatus.finished,
    ),
    // IPL — finished cricket, settleable reveal demo (8th fixture).
    SportMatch(
      id: 'ipl_csk_mi',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _csk,
      away: _mi,
      kickoff: _at(-1, 15),
      status: MatchStatus.finished,
      homeScore: '189-6 (20 ov)',
      awayScore: '175-8 (20 ov)',
      resultLine: 'Chennai won by 14 runs',
      rewardXp: 325,
    ),
    // EPL — finished football, settleable reveal demo (9th fixture).
    SportMatch(
      id: 'epl_avl_bha',
      leagueId: 'epl',
      sport: Sport.football,
      home: _avl,
      away: _bha,
      kickoff: _at(-2, 19, 45),
      status: MatchStatus.finished,
      homeScore: '2',
      awayScore: '0',
      rewardXp: 300,
    ),
    SportMatch(
      id: 'ipl_rcb_srh',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _rcb,
      away: _srh,
      kickoff: _at(2, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 3500 coins',
    ),
    SportMatch(
      id: 'epl_mc_mu',
      leagueId: 'epl',
      sport: Sport.football,
      home: _mc,
      away: _mu,
      kickoff: _at(3, 21),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
    ),
    SportMatch(
      id: 'ipl_kkr_csk',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _kkr,
      away: _csk,
      kickoff: _at(3, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 4000 coins',
    ),
    SportMatch(
      id: 'epl_whu_eve',
      leagueId: 'epl',
      sport: Sport.football,
      home: _whu,
      away: _eve,
      kickoff: _at(4, 18, 30),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 2000 coins',
    ),
    SportMatch(
      id: 'ipl_mi_pjk',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _mi,
      away: _pjk,
      kickoff: _at(4, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 3500 coins',
    ),
    // British GP — completed weekend (reveal-ready predictions).
    SportMatch(
      id: 'f1_british_gp',
      leagueId: 'f1',
      sport: Sport.motorsport,
      home: _gpBritish,
      away: _f1Field,
      kickoff: DateTime(2026, 7, 3, 12, 30),
      f1WeekendEndDate: DateTime(2026, 7, 5, 16, 0),
      status: MatchStatus.finished,
      homeScore: 'P1',
      awayScore: 'P3',
      resultLine: 'British Grand Prix: Hamilton takes the chequered flag',
      rewardXp: 150,
      timelineEvents: const [
        MatchEvent(
          minute: 12,
          isHomeTeam: true,
          playerName: 'Lewis Hamilton',
          type: MatchEventType.substitution,
          secondaryPlayerName: 'Overtakes for P2',
        ),
        MatchEvent(
          minute: 52,
          isHomeTeam: true,
          playerName: 'Lewis Hamilton',
          type: MatchEventType.goal,
          secondaryPlayerName: 'Wins the Race!',
        ),
      ],
      f1DriverStandings: _f1Standings,
      f1Sessions: const [
        F1SessionResult(
          name: 'Practice 1',
          results: ['1. Norris', '2. Piastri', '3. Leclerc'],
        ),
        F1SessionResult(
          name: 'Practice 2',
          results: ['1. Leclerc', '2. Hamilton', '3. Russell'],
        ),
        F1SessionResult(
          name: 'Practice 3',
          results: ['1. Russell', '2. Norris', '3. Hamilton'],
        ),
        F1SessionResult(
          name: 'Qualifying',
          results: ['1. Leclerc', '2. Russell', '3. Hamilton'],
        ),
        F1SessionResult(
          name: 'Race',
          results: ['1. Hamilton', '2. Leclerc', '3. Russell'],
        ),
      ],
    ),
    // Belgian GP — next race weekend (open predictions).
    SportMatch(
      id: 'f1_belgian_gp',
      leagueId: 'f1',
      sport: Sport.motorsport,
      home: _gpBelgian,
      away: _f1Field,
      kickoff: DateTime(2026, 7, 24, 12, 30),
      f1WeekendEndDate: DateTime(2026, 7, 26, 15, 0),
      status: MatchStatus.upcoming,
      rewardXp: 150,
      f1DriverStandings: _f1Standings,
      f1Sessions: _f1UpcomingSessions,
    ),
    // Hungarian GP — following weekend (open predictions).
    SportMatch(
      id: 'f1_hungarian_gp',
      leagueId: 'f1',
      sport: Sport.motorsport,
      home: _gpHungarian,
      away: _f1Field,
      kickoff: DateTime(2026, 7, 31, 12, 30),
      f1WeekendEndDate: DateTime(2026, 8, 2, 15, 0),
      status: MatchStatus.upcoming,
      rewardXp: 150,
      f1DriverStandings: _f1Standings,
      f1Sessions: _f1UpcomingSessions,
    ),
    // 10th: Tennis match (Wimbledon)
    SportMatch(
      id: 'wimbledon_mock_1',
      leagueId: 'wimbledon',
      sport: Sport.tennis,
      home: const SportTeam(
        id: 'alcaraz',
        name: 'Carlos Alcaraz',
        shortName: 'ALC',
        color: Color(0xffc60b1e),
      ),
      away: const SportTeam(
        id: 'djokovic',
        name: 'Novak Djokovic',
        shortName: 'DJO',
        color: Color(0xffc6363c),
      ),
      kickoff: _now.add(const Duration(hours: 3)),
      status: MatchStatus.upcoming,
    ),
  ];

  late final Map<String, List<PredictionQuiz>> _quizSets = {
    'fifa_fra_par': _franceParaguayQuizzes(),
    // British GP is settled (reveal-ready); the two upcoming GPs are open.
    'f1_british_gp': _f1Quizzes(
      'f1_british_gp',
      winnerSettled: 0,
      safetyCarSettled: 0,
      fastLapSettled: 2,
    ),
    'f1_belgian_gp': _belgianGpQuizzes(),
    'f1_hungarian_gp': _f1Quizzes('f1_hungarian_gp'),
  };

  late final Map<String, PredictionQuiz> _quizzes = {
    for (final fixture in _fixtures)
      if (fixture.leagueId == 'fifa' && fixture.id != 'fifa_fra_par')
        fixture.id: _footballQuiz(
          fixture.id,
          fixture.home.name,
          fixture.away.name,
        ),
    // World Cup third-place play-off — France 4-6 England. Overrides the
    // generated FIFA quiz above (later keys win) because that builder leaves
    // every answer unsettled, which makes a quiz unsettleable. Each answer here
    // is the real outcome, so the quiz plays its full over → reveal → XP flow.
    '760516': const PredictionQuiz(
      matchId: '760516',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 100,
          settledHomeScore: 4,
          settledAwayScore: 6,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Who wins the third-place play-off?',
          options: ['France', 'Draw', 'England'],
          reward: 50,
          settledOptionIndex: 2,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 40,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Total goals over/under 4.5?',
          options: ['Over 4.5', 'Under 4.5'],
          reward: 40,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q5',
          text: 'Which side scores first?',
          options: ['France', 'England'],
          reward: 45,
          settledOptionIndex: 1,
        ),
      ],
    ),
    'epl_mu_ars': _footballQuiz('epl_mu_ars', 'Man Utd', 'Arsenal'),
    'epl_liv_mc': _footballQuiz('epl_liv_mc', 'Liverpool', 'Man City'),
    'epl_cfc_new': const PredictionQuiz(
      matchId: 'epl_cfc_new',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 100,
          settledHomeScore: 2,
          settledAwayScore: 1,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 50,
        ),
      ],
    ),
    'ipl_pjk_kkr': const PredictionQuiz(
      matchId: 'ipl_pjk_kkr',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Punjab', 'KKR'],
          reward: 50,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sixes over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 100,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Who will win Punjab vs KKR?',
          options: ['Punjab', 'KKR'],
          reward: 75,
        ),
      ],
    ),
    'wimbledon_mens_final_26': _tennisQuiz(
      matchId: 'wimbledon_mens_final_26',
      home: 'C. Alcaraz',
      away: 'N. Djokovic',
      isMens: true,
    ),
    'wimbledon_womens_final_26': _tennisQuiz(
      matchId: 'wimbledon_womens_final_26',
      home: 'B. Krejcikova',
      away: 'J. Paolini',
      isMens: false,
    ),
    // Settled quiz so history / finished demos can show mixed ✓/✕ rows.
    'epl_mu_whu': const PredictionQuiz(
      matchId: 'epl_mu_whu',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 10,
          settledHomeScore: 2,
          settledAwayScore: 1,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Total goals over/under 2.5?',
          options: ['Over 2.5', 'Under 2.5'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Which side scores first?',
          options: ['Man Utd', 'West Ham', 'No goal'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q5',
          text: 'Will a red card be shown?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 1,
        ),
      ],
    ),
    'ipl_srh_mi': const PredictionQuiz(
      matchId: 'ipl_srh_mi',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Hyderabad', 'Mumbai'],
          reward: 50,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sixes over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 100,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Who will win Hyderabad vs Mumbai?',
          options: ['Hyderabad', 'Tie', 'Mumbai'],
          reward: 100,
          settledOptionIndex: 2,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Will either opener score 50+?',
          options: ['Yes', 'No'],
          reward: 75,
          settledOptionIndex: 0,
        ),
      ],
    ),
    'ipl_pjk_rcb': const PredictionQuiz(
      matchId: 'ipl_pjk_rcb',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Punjab', 'Bangalore'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sixes over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 5,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Top scorer from Punjab?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Will rain affect play?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q5',
          text: 'Who wins Punjab vs RCB?',
          options: ['Punjab', 'Tie', 'Bangalore'],
          reward: 5,
          settledOptionIndex: 0,
        ),
      ],
    ),
    'epl_ars_new': _footballQuiz('epl_ars_new', 'Arsenal', 'Newcastle'),
    // Settled cricket quiz — Chennai won the toss, hit 15 sixes, won the match;
    // demo prediction misses q2 (user picks Under 12.5, actual is Over).
    'ipl_csk_mi': const PredictionQuiz(
      matchId: 'ipl_csk_mi',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Chennai', 'Mumbai'],
          reward: 50,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sixes over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 100,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Who will win Chennai vs Mumbai?',
          options: ['Chennai', 'Tie', 'Mumbai'],
          reward: 100,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Will either opener score 50+?',
          options: ['Yes', 'No'],
          reward: 75,
          settledOptionIndex: 0,
        ),
      ],
    ),
    // Settled football quiz — Villa won 2-0; demo prediction misses q4
    // (user picks Over 2.5, actual is Under 2.5 with only 2 goals).
    'epl_avl_bha': const PredictionQuiz(
      matchId: 'epl_avl_bha',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 100,
          settledHomeScore: 2,
          settledAwayScore: 0,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 50,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Which side scores first?',
          options: ['Aston Villa', 'Brighton', 'No goal'],
          reward: 75,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Total goals over/under 2.5?',
          options: ['Over 2.5', 'Under 2.5'],
          reward: 75,
          settledOptionIndex: 1,
        ),
      ],
    ),
    'ipl_rcb_srh': _cricketQuiz('ipl_rcb_srh', 'Bangalore', 'Hyderabad'),
    'epl_mc_mu': _footballQuiz('epl_mc_mu', 'Man City', 'Man Utd'),
    'ipl_kkr_csk': _cricketQuiz('ipl_kkr_csk', 'KKR', 'Chennai'),
    'epl_whu_eve': _footballQuiz('epl_whu_eve', 'West Ham', 'Everton'),
    'ipl_mi_pjk': _cricketQuiz('ipl_mi_pjk', 'Mumbai', 'Punjab'),
  };

  /// Football quizzes are built from the shared bank ([buildFootballQuiz]) so
  /// every upcoming football fixture draws a gamified, per-match subset of the
  /// canonical question set with per-question background art.
  static PredictionQuiz _footballQuiz(
    String matchId,
    String home,
    String away,
  ) => buildFootballQuiz(matchId: matchId, home: home, away: away);

  static List<PredictionQuiz> _predictTabQuizSets(
    SportMatch match,
    PredictionQuiz primary,
  ) {
    final main = switch (match.sport) {
      Sport.football => _withQuizMeta(
        primary,
        title: 'Scoreline Quiz',
        subtitle: 'Final score and scoring market',
        entryFee: kScorelineQuizEntryFee,
      ),
      Sport.cricket => _withQuizMeta(
        primary,
        title: 'Match Basics Quiz',
        subtitle: 'Toss, sixes, and match winner',
      ),
      Sport.tennis => _withQuizMeta(
        primary,
        title: 'Match Basics Quiz',
        subtitle: 'Winner, sets, and tiebreaks',
      ),
      Sport.basketball => _withQuizMeta(
        primary,
        title: 'Match Basics Quiz',
        subtitle: 'Winner, total points, and margins',
      ),
      _ => primary,
    };
    final events = switch (match.sport) {
      Sport.football => _footballEventsQuiz(match),
      Sport.cricket => _cricketEventsQuiz(match),
      _ => null,
    };
    return events == null ? [main] : [main, events];
  }

  static PredictionQuiz _withQuizMeta(
    PredictionQuiz quiz, {
    required String title,
    required String subtitle,
    int entryFee = 0,
  }) => PredictionQuiz(
    id: quiz.id,
    matchId: quiz.matchId,
    title: title,
    subtitle: subtitle,
    prizeLabel: entryFee > 0
        ? '${kScorelineContestPrizes.join(' / ')} Oz prize pool'
        : '${quiz.maxReward} XP available',
    questions: quiz.questions,
    entryFee: entryFee,
  );

  static PredictionQuiz _tennisQuiz({
    required String matchId,
    required String home,
    required String away,
    required bool isMens,
  }) {
    return PredictionQuiz(
      matchId: matchId,
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who will win the match?',
          options: [home, away],
          reward: 100,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sets played?',
          options: isMens ? ['3 sets', '4 sets', '5 sets'] : ['2 sets', '3 sets'],
          reward: 50,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Will there be a tiebreak in the match?',
          options: ['Yes', 'No'],
          reward: 75,
        ),
      ],
    );
  }

  static List<PredictionQuiz> _franceParaguayQuizzes() => const [
    PredictionQuiz(
      id: 'main',
      matchId: 'fifa_fra_par',
      title: 'Scoreline Quiz',
      subtitle: 'Final score and scoring market',
      prizeLabel: '190 XP available',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 120,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 70,
        ),
      ],
    ),
    PredictionQuiz(
      id: 'events',
      matchId: 'fifa_fra_par',
      title: 'Match Events Quiz',
      subtitle: 'Winner, first goal, and discipline',
      prizeLabel: '230 XP available',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins France vs Paraguay?',
          options: ['France', 'Draw', 'Paraguay'],
          reward: 90,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Which team scores first?',
          options: ['France', 'Paraguay', 'No goal'],
          reward: 80,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Will a red card be shown?',
          options: ['Yes', 'No'],
          reward: 60,
        ),
      ],
    ),
  ];

  static PredictionQuiz _footballEventsQuiz(SportMatch match) {
    final home = match.home.name;
    final away = match.away.name;
    return PredictionQuiz(
      id: 'events',
      matchId: match.id,
      title: 'Match Events Quiz',
      subtitle: 'Winner, first goal, and discipline',
      prizeLabel: '230 XP available',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins $home vs $away?',
          options: [home, 'Draw', away],
          reward: 90,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Which team scores first?',
          options: [home, away, 'No goal'],
          reward: 80,
        ),
        const QuizQuestion(
          id: 'q3',
          text: 'Will a red card be shown?',
          options: ['Yes', 'No'],
          reward: 60,
        ),
      ],
    );
  }

  static PredictionQuiz _cricketEventsQuiz(SportMatch match) {
    final home = match.home.name;
    final away = match.away.name;
    return PredictionQuiz(
      id: 'events',
      matchId: match.id,
      title: 'Match Events Quiz',
      subtitle: 'Powerplay, wickets, and final-over drama',
      prizeLabel: '210 XP available',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who has the higher powerplay score?',
          options: [home, away, 'Tie'],
          reward: 80,
        ),
        const QuizQuestion(
          id: 'q2',
          text: 'Total wickets over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 70,
        ),
        const QuizQuestion(
          id: 'q3',
          text: 'Will the match be decided in the final over?',
          options: ['Yes', 'No'],
          reward: 60,
        ),
      ],
    );
  }

  static PredictionQuiz _cricketQuiz(
    String matchId,
    String home,
    String away,
  ) => PredictionQuiz(
    matchId: matchId,
    questions: [
      QuizQuestion(
        id: 'q1',
        text: 'Who wins the toss?',
        options: [home, away],
        reward: 50,
      ),
      const QuizQuestion(
        id: 'q2',
        text: 'Total sixes over/under 12.5?',
        options: ['Over 12.5', 'Under 12.5'],
        reward: 100,
      ),
      QuizQuestion(
        id: 'q3',
        text: 'Who will win $home vs $away?',
        options: [home, 'Tie', away],
        reward: 100,
      ),
      const QuizQuestion(
        id: 'q4',
        text: 'Will either opener score 50+?',
        options: ['Yes', 'No'],
        reward: 75,
      ),
    ],
  );

  // ── Standings (rank-sorted; seeded to look like a real season) ───────────────
  // Football: diffLabel is goal difference, points = W*3 + D*1.
  // Cricket: diffLabel is net run rate, points = W*2, no drawn column.
  static const _standings = <String, List<TeamStanding>>{
    'fifa': [
      TeamStanding(
        team: _france,
        rank: 1,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _argentina,
        rank: 2,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _england,
        rank: 3,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _portugal,
        rank: 4,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _senegal,
        rank: 5,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _paraguay,
        rank: 6,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _norway,
        rank: 7,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
      TeamStanding(
        team: _croatia,
        rank: 8,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        points: 0,
        diffLabel: '0',
        form: '-----',
      ),
    ],
    'epl': [
      TeamStanding(
        team: _liv,
        rank: 1,
        played: 28,
        won: 20,
        drawn: 5,
        lost: 3,
        points: 65,
        diffLabel: '+41',
        form: 'WWDWW',
      ),
      TeamStanding(
        team: _ars,
        rank: 2,
        played: 28,
        won: 19,
        drawn: 6,
        lost: 3,
        points: 63,
        diffLabel: '+38',
        form: 'WDWWL',
      ),
      TeamStanding(
        team: _mc,
        rank: 3,
        played: 28,
        won: 18,
        drawn: 6,
        lost: 4,
        points: 60,
        diffLabel: '+35',
        form: 'WWLDW',
      ),
      TeamStanding(
        team: _avl,
        rank: 4,
        played: 28,
        won: 15,
        drawn: 7,
        lost: 6,
        points: 52,
        diffLabel: '+15',
        form: 'DWWLW',
      ),
      TeamStanding(
        team: _mu,
        rank: 5,
        played: 28,
        won: 14,
        drawn: 6,
        lost: 8,
        points: 48,
        diffLabel: '+9',
        form: 'WLWDL',
      ),
      TeamStanding(
        team: _bha,
        rank: 6,
        played: 28,
        won: 12,
        drawn: 9,
        lost: 7,
        points: 45,
        diffLabel: '+6',
        form: 'DDWLW',
      ),
      TeamStanding(
        team: _new,
        rank: 7,
        played: 28,
        won: 12,
        drawn: 6,
        lost: 10,
        points: 42,
        diffLabel: '+4',
        form: 'LWWDL',
      ),
      TeamStanding(
        team: _cfc,
        rank: 8,
        played: 28,
        won: 11,
        drawn: 8,
        lost: 9,
        points: 41,
        diffLabel: '+2',
        form: 'WDLWD',
      ),
      TeamStanding(
        team: _whu,
        rank: 9,
        played: 28,
        won: 9,
        drawn: 7,
        lost: 12,
        points: 34,
        diffLabel: '-8',
        form: 'LLDWL',
      ),
      TeamStanding(
        team: _eve,
        rank: 10,
        played: 28,
        won: 7,
        drawn: 9,
        lost: 12,
        points: 30,
        diffLabel: '-11',
        form: 'DLLDW',
      ),
      TeamStanding(
        team: _bur,
        rank: 11,
        played: 28,
        won: 4,
        drawn: 6,
        lost: 18,
        points: 18,
        diffLabel: '-29',
        form: 'LLDLL',
      ),
    ],
    'ipl': [
      TeamStanding(
        team: _mi,
        rank: 1,
        played: 8,
        won: 6,
        lost: 2,
        points: 12,
        diffLabel: '+0.95',
        form: 'WWLWW',
      ),
      TeamStanding(
        team: _kkr,
        rank: 2,
        played: 8,
        won: 5,
        lost: 3,
        points: 10,
        diffLabel: '+0.62',
        form: 'WLWWL',
      ),
      TeamStanding(
        team: _csk,
        rank: 3,
        played: 8,
        won: 5,
        lost: 3,
        points: 10,
        diffLabel: '+0.41',
        form: 'WWLWL',
      ),
      TeamStanding(
        team: _srh,
        rank: 4,
        played: 8,
        won: 4,
        lost: 4,
        points: 8,
        diffLabel: '+0.12',
        form: 'LWLWW',
      ),
      TeamStanding(
        team: _pjk,
        rank: 5,
        played: 8,
        won: 3,
        lost: 5,
        points: 6,
        diffLabel: '-0.34',
        form: 'LLWLW',
      ),
      TeamStanding(
        team: _rcb,
        rank: 6,
        played: 8,
        won: 2,
        lost: 6,
        points: 4,
        diffLabel: '-0.88',
        form: 'LLWLL',
      ),
    ],
  };

  static const _curatedLeagues = <League>[
    _fifa,
    _mls,
    _uclq,
    _brasileirao,
    _ligaMx,
    _allsvenskan,
    _eliteserien,
    _lpl,
    _pakTourWi,
    _saWomenU19TourPak,
    _intl,
    _f1,
    _wnba,
    _nba,
    _atp,
    _wta,
    _indycar,
    _nascarCup,
  ];

  @override
  Future<List<League>> leagues() async {
    final knownIds = _curatedLeagues.map((l) => l.id).toSet();
    return [
      ..._curatedLeagues,
      for (final league in EspnScoreService.discoveredLeagues.values)
        if (!knownIds.contains(league.id)) league,
    ];
  }

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async {
    final mockFixtures = _fixtures
        .where((f) => f.leagueId != 'epl' && f.leagueId != 'ipl')
        .where((f) => sport == null || f.sport == sport)
        .toList();

    return List.unmodifiable(mockFixtures);
  }

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async {
    final sets = _quizSets[matchId];
    if (sets != null) return List.unmodifiable(sets);
    final quiz = _quizzes[matchId];
    if (quiz == null) return const [];
    final fixture = _fixtureFor(matchId);
    if (fixture == null) return [quiz];
    return List.unmodifiable(_predictTabQuizSets(fixture, quiz));
  }

  SportMatch? _fixtureFor(String matchId) {
    for (final fixture in _fixtures) {
      if (fixture.id == matchId) return fixture;
    }
    return null;
  }

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async {
    final quizzes = await quizzesFor(matchId);
    for (final quiz in quizzes) {
      if (quiz.id == quizId) return quiz;
    }
    return null;
  }

  @override
  Future<List<TeamStanding>> standings(String leagueId) async =>
      _standings[leagueId] ?? const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async {
    final quiz = await quizFor(matchId, quizId);
    if (quiz == null) return null;
    for (final question in quiz.questions) {
      if (question.id == questionId) {
        return PredictionVoteBreakdown(
          matchId: matchId,
          questionId: questionId,
          totals: _voteTotals(matchId, quizId, question),
        );
      }
    }
    return null;
  }

  @override
  Future<List<SportMatch>> enrichFixturesForSport(List<SportMatch> fixtures, Sport sport) async {
    final espnService = EspnScoreService();
    final dynamicMatches = await espnService.fetchDynamicMatchesForSport(sport);
    
    // Combine local and dynamic fixtures avoiding duplicates by id
    final Map<String, SportMatch> allFixturesMap = {};
    for (final f in fixtures) {
      if (f.sport == sport) {
        allFixturesMap[f.id] = f;
      }
    }
    for (final f in dynamicMatches) {
      allFixturesMap[f.id] = f;
    }
    
    final allFixturesForSport = allFixturesMap.values.toList();
    final enriched = await espnService.enrichAllForSport(allFixturesForSport, sport);
    
    // Merge back with other sports
    final otherFixtures = fixtures.where((f) => f.sport != sport).toList();
    return [...otherFixtures, ...enriched];
  }

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async {
    final seed = _stableSeed('$matchId:$quizId');
    final names = const [
      'You',
      'Aarav',
      'Maya',
      'Dev',
      'Priya',
      'Kabir',
      'Isha',
    ];
    return [
      for (var i = 0; i < names.length; i++)
        MatchPredictionLeaderboardEntry(
          rank: i + 1,
          name: names[i],
          points: 620 - i * 47 + (seed + i * 13) % 31,
          correct: 5 - (i % 3),
        ),
    ];
  }

  static Map<int, int> _voteTotals(
    String matchId,
    String quizId,
    QuizQuestion question,
  ) {
    final seed = _stableSeed('$matchId:$quizId:${question.id}');
    if (question.isScorePrediction) {
      final correct = question.settledScoreEncoded;
      final scores = <int>[
        ?correct,
        ScoreAnswer.encode(1, 0),
        ScoreAnswer.encode(1, 1),
        ScoreAnswer.encode(2, 1),
        ScoreAnswer.encode(0, 0),
      ];
      final totals = <int, int>{};
      for (var i = 0; i < scores.length; i++) {
        totals.putIfAbsent(scores[i], () => 28 + ((seed + i * 23) % 72));
      }
      return totals;
    }

    return {
      for (var i = 0; i < question.options.length; i++)
        i: 34 + ((seed + i * 29) % 96),
    };
  }

  static int _stableSeed(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) % 100000;
    }
    return hash;
  }

  // Reusable per-weekend F1 quiz set. Settled indices are supplied for a
  // completed weekend and left null (open) for upcoming ones.
  static List<PredictionQuiz> _f1Quizzes(
    String matchId, {
    int? winnerSettled,
    int? safetyCarSettled,
    int? fastLapSettled,
  }) => [
    PredictionQuiz(
      id: 'main',
      matchId: matchId,
      title: 'Race Predictions',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who will win the race?',
          options: const [
            'Lewis Hamilton',
            'Charles Leclerc',
            'Kimi Antonelli',
            'George Russell',
          ],
          reward: 100,
          settledOptionIndex: winnerSettled,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Will there be a safety car?',
          options: const ['Yes', 'No'],
          reward: 50,
          settledOptionIndex: safetyCarSettled,
        ),
      ],
    ),
    PredictionQuiz(
      id: 'bonus',
      matchId: matchId,
      title: 'Bonus Predictions',
      questions: [
        QuizQuestion(
          id: 'b1',
          text: 'Who gets the fastest lap?',
          options: const ['Lewis Hamilton', 'Charles Leclerc', 'George Russell'],
          reward: 75,
          settledOptionIndex: fastLapSettled,
        ),
      ],
    ),
  ];

  // Spa-Francorchamps flavoured predictions for the Belgian GP weekend — the
  // signature "will it rain?" hook drives the extra question the generic
  // [_f1Quizzes] template doesn't carry.
  static List<PredictionQuiz> _belgianGpQuizzes() => [
    PredictionQuiz(
      id: 'main',
      matchId: 'f1_belgian_gp',
      title: 'Race Predictions',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who will win the Belgian Grand Prix?',
          options: const [
            'Charles Leclerc',
            'George Russell',
            'Lando Norris',
            'Max Verstappen',
          ],
          reward: 100,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Will it rain during the race at Spa?',
          options: const ['Yes', 'No'],
          reward: 60,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Will there be a safety car?',
          options: const ['Yes', 'No'],
          reward: 50,
        ),
      ],
    ),
    PredictionQuiz(
      id: 'bonus',
      matchId: 'f1_belgian_gp',
      title: 'Bonus Predictions',
      questions: [
        QuizQuestion(
          id: 'b1',
          text: 'Who takes pole position at Spa?',
          options: const [
            'Charles Leclerc',
            'George Russell',
            'Lando Norris',
            'Max Verstappen',
          ],
          reward: 75,
        ),
        QuizQuestion(
          id: 'b2',
          text: 'Who sets the fastest lap?',
          options: const [
            'Lewis Hamilton',
            'Charles Leclerc',
            'George Russell',
            'Oscar Piastri',
          ],
          reward: 75,
        ),
      ],
    ),
  ];
}

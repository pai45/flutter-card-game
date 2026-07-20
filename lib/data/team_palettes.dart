// GENERATED — team colour database harvested from the public ESPN APIs.
// Regenerate rather than hand-editing the [kTeamPalettes] map; put manual
// corrections in [kTeamPaletteOverrides], which always wins.
//
// Each team resolves to three colours:
//   primary   — the badge fill (ESPN's team colour)
//   text      — the label drawn on top; chosen as black/white by WCAG
//               contrast against primary (every entry clears AA 4.5:1)
//   secondary — the badge accent edge; ESPN's alternate colour, or derived
//               from primary when ESPN has none or it is too close to read
import 'package:flutter/material.dart';

import '../models/sport_match.dart';

/// The three colours that describe one team's badge.
@immutable
class TeamPalette {
  const TeamPalette(this.primary, this.text, this.secondary);

  /// Badge fill.
  final Color primary;

  /// Label colour on top of [primary] — contrast-checked, never derived at
  /// paint time.
  final Color text;

  /// Accent edge along the bottom of the badge.
  final Color secondary;
}

/// Manual corrections. Keyed like [kTeamPalettes] — the sport name, a colon,
/// then the normalised team name, e.g. `'football:arsenal'`. An entry here
/// beats the generated one; add corrections here rather than editing the
/// generated data below, which is overwritten on every regeneration.
const Map<String, TeamPalette> kTeamPaletteOverrides = <String, TeamPalette>{
  // The app carries its own short-form "Man City" (which does not match ESPN's
  // "Manchester City") and a hand-picked sky blue that predates this database.
  // Kept as an override so the badge renders exactly as it did before.
  'football:mancity': TeamPalette(
    Color(0xff74acde),
    Color(0xff000000),
    Color(0xff1c3f5f),
  ),
};

/// Sport-namespaced palettes — ESPN team ids collide across sports, and a
/// name like "England" is a different colour in cricket than in football, so
/// the sport is part of the key.
const Map<String, TeamPalette> kTeamPalettes = <String, TeamPalette>{
  // ── basketball ─────────────────────────────────────────────
  'basketball:atlantadream': TeamPalette(Color(0xffe31837), Color(0xffffffff), Color(0xfff5b0bb)), // Atlanta Dream
  'basketball:atlantahawks': TeamPalette(Color(0xffc8102e), Color(0xffffffff), Color(0xfffdb927)), // Atlanta Hawks
  'basketball:bostonceltics': TeamPalette(Color(0xff008348), Color(0xffffffff), Color(0xffffffff)), // Boston Celtics
  'basketball:brooklynnets': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // Brooklyn Nets
  'basketball:charlottehornets': TeamPalette(Color(0xff008ca8), Color(0xff000000), Color(0xff1d1060)), // Charlotte Hornets
  'basketball:chicagobulls': TeamPalette(Color(0xffce1141), Color(0xffffffff), Color(0xff000000)), // Chicago Bulls
  'basketball:chicagosky': TeamPalette(Color(0xff5091cd), Color(0xff000000), Color(0xffffd520)), // Chicago Sky
  'basketball:clevelandcavaliers': TeamPalette(Color(0xff860038), Color(0xffffffff), Color(0xffbc945c)), // Cleveland Cavaliers
  'basketball:connecticutsun': TeamPalette(Color(0xfff05023), Color(0xff000000), Color(0xff0a2240)), // Connecticut Sun
  'basketball:dallasmavericks': TeamPalette(Color(0xff0064b1), Color(0xffffffff), Color(0xffbbc4ca)), // Dallas Mavericks
  'basketball:dallaswings': TeamPalette(Color(0xff002b5c), Color(0xffffffff), Color(0xffc4d600)), // Dallas Wings
  'basketball:denvernuggets': TeamPalette(Color(0xff0e2240), Color(0xffffffff), Color(0xfffec524)), // Denver Nuggets
  'basketball:detroitpistons': TeamPalette(Color(0xff1d428a), Color(0xffffffff), Color(0xffc8102e)), // Detroit Pistons
  'basketball:goldenstatevalkyries': TeamPalette(Color(0xffb38fcf), Color(0xff000000), Color(0xff000000)), // Golden State Valkyries
  'basketball:goldenstatewarriors': TeamPalette(Color(0xfffdb927), Color(0xff000000), Color(0xff1d428a)), // Golden State Warriors
  'basketball:houstonrockets': TeamPalette(Color(0xffce1141), Color(0xffffffff), Color(0xff000000)), // Houston Rockets
  'basketball:indianafever': TeamPalette(Color(0xff002d62), Color(0xffffffff), Color(0xffe03a3e)), // Indiana Fever
  'basketball:indianapacers': TeamPalette(Color(0xff0c2340), Color(0xffffffff), Color(0xffffd520)), // Indiana Pacers
  'basketball:laclippers': TeamPalette(Color(0xff12173f), Color(0xffffffff), Color(0xffc8102e)), // LA Clippers
  'basketball:lasvegasaces': TeamPalette(Color(0xffa7a8aa), Color(0xff000000), Color(0xff000000)), // Las Vegas Aces
  'basketball:losangeleslakers': TeamPalette(Color(0xff552583), Color(0xffffffff), Color(0xfffdb927)), // Los Angeles Lakers
  'basketball:losangelessparks': TeamPalette(Color(0xff552583), Color(0xffffffff), Color(0xfffdb927)), // Los Angeles Sparks
  'basketball:memphisgrizzlies': TeamPalette(Color(0xff5d76a9), Color(0xff000000), Color(0xff12173f)), // Memphis Grizzlies
  'basketball:miamiheat': TeamPalette(Color(0xff98002e), Color(0xffffffff), Color(0xff000000)), // Miami Heat
  'basketball:milwaukeebucks': TeamPalette(Color(0xff00471b), Color(0xffffffff), Color(0xffeee1c6)), // Milwaukee Bucks
  'basketball:minnesotalynx': TeamPalette(Color(0xff266092), Color(0xffffffff), Color(0xff79bc43)), // Minnesota Lynx
  'basketball:minnesotatimberwolves': TeamPalette(Color(0xff266092), Color(0xffffffff), Color(0xff79bc43)), // Minnesota Timberwolves
  'basketball:neworleanspelicans': TeamPalette(Color(0xff0a2240), Color(0xffffffff), Color(0xffb4975a)), // New Orleans Pelicans
  'basketball:newyorkknicks': TeamPalette(Color(0xff1d428a), Color(0xffffffff), Color(0xfff58426)), // New York Knicks
  'basketball:newyorkliberty': TeamPalette(Color(0xff86cebc), Color(0xff000000), Color(0xff000000)), // New York Liberty
  'basketball:oklahomacitythunder': TeamPalette(Color(0xff007ac1), Color(0xffffffff), Color(0xff9acae6)), // Oklahoma City Thunder
  'basketball:orlandomagic': TeamPalette(Color(0xff0150b5), Color(0xffffffff), Color(0xff9ca0a3)), // Orlando Magic
  'basketball:philadelphia76ers': TeamPalette(Color(0xff1d428a), Color(0xffffffff), Color(0xffe01234)), // Philadelphia 76ers
  'basketball:phoenixmercury': TeamPalette(Color(0xff3c286e), Color(0xffffffff), Color(0xfffa4b0a)), // Phoenix Mercury
  'basketball:phoenixsuns': TeamPalette(Color(0xff29127a), Color(0xffffffff), Color(0xffe56020)), // Phoenix Suns
  'basketball:portlandfire': TeamPalette(Color(0xffcee5eb), Color(0xff000000), Color(0xff000000)), // Portland Fire
  'basketball:portlandtrailblazers': TeamPalette(Color(0xffe03a3e), Color(0xff000000), Color(0xff000000)), // Portland Trail Blazers
  'basketball:sacramentokings': TeamPalette(Color(0xff5a2d81), Color(0xffffffff), Color(0xff6a7a82)), // Sacramento Kings
  'basketball:sanantoniospurs': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc4ced4)), // San Antonio Spurs
  'basketball:seattlestorm': TeamPalette(Color(0xff2c5235), Color(0xffffffff), Color(0xfffee11a)), // Seattle Storm
  'basketball:torontoraptors': TeamPalette(Color(0xffd91244), Color(0xffffffff), Color(0xff000000)), // Toronto Raptors
  'basketball:torontotempo': TeamPalette(Color(0xff33476d), Color(0xffffffff), Color(0xff7e8ba3)), // Toronto Tempo
  'basketball:utahjazz': TeamPalette(Color(0xff4e008e), Color(0xffffffff), Color(0xff79a3dc)), // Utah Jazz
  'basketball:washingtonmystics': TeamPalette(Color(0xffe03a3e), Color(0xff000000), Color(0xff002b5c)), // Washington Mystics
  'basketball:washingtonwizards': TeamPalette(Color(0xffe31837), Color(0xffffffff), Color(0xff002b5c)), // Washington Wizards
  // ── cricket ─────────────────────────────────────────────
  'cricket:england': TeamPalette(Color(0xff0673c1), Color(0xffffffff), Color(0xff97c4e5)), // England
  'cricket:englandwomen': TeamPalette(Color(0xff0673c1), Color(0xffffffff), Color(0xff97c4e5)), // England Women
  'cricket:gujarattitans': TeamPalette(Color(0xff334779), Color(0xffffffff), Color(0xff7e8bab)), // Gujarat Titans
  'cricket:india': TeamPalette(Color(0xff050ceb), Color(0xffffffff), Color(0xff787cf4)), // India
  'cricket:indiawomen': TeamPalette(Color(0xff050ceb), Color(0xffffffff), Color(0xff787cf4)), // India Women
  'cricket:royalchallengersbengaluru': TeamPalette(Color(0xfff10920), Color(0xff000000), Color(0xfffbb7be)), // Royal Challengers Bengaluru
  // ── motorsport (F1 constructors) ──────────────────────────
  'motorsport:alpine': TeamPalette(Color(0xfffff500), Color(0xff000000), Color(0xff999300)), // Alpine
  'motorsport:astonmartin': TeamPalette(Color(0xff006f62), Color(0xffffffff), Color(0xff7cb5ae)), // Aston Martin
  'motorsport:audi': TeamPalette(Color(0xffff2d00), Color(0xff000000), Color(0xffffcdc2)), // Audi
  'motorsport:cadillac': TeamPalette(Color(0xffa2aaad), Color(0xff000000), Color(0xff5b5f61)), // Cadillac
  'motorsport:ferrari': TeamPalette(Color(0xffdc0000), Color(0xffffffff), Color(0xfff2a4a4)), // Ferrari
  'motorsport:haas': TeamPalette(Color(0xff5a5a5a), Color(0xffffffff), Color(0xffa1a1a1)), // Haas
  'motorsport:mclaren': TeamPalette(Color(0xffff8700), Color(0xff000000), Color(0xff8f4c00)), // McLaren
  'motorsport:mercedes': TeamPalette(Color(0xff00d2be), Color(0xff000000), Color(0xff00766a)), // Mercedes
  'motorsport:racingbulls': TeamPalette(Color(0xff6692ff), Color(0xff000000), Color(0xffebf1ff)), // Racing Bulls
  'motorsport:redbull': TeamPalette(Color(0xff00327d), Color(0xffffffff), Color(0xff5677a9)), // Red Bull
  'motorsport:williams': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff999999)), // Williams
  // ── motorsport (IndyCar/NASCAR) ────────────────────────────
  // ESPN's IndyCar/NASCAR scoreboard doesn't expose per-driver team/manufacturer
  // affiliation the way F1's does, so these are series-brand colours rather
  // than per-team entries — same role the plain F1 fixture badge color plays.
  'motorsport:indycarfield': TeamPalette(Color(0xff001489), Color(0xffffffff), Color(0xff5b6ec7)), // IndyCar blue
  'motorsport:nascarcupfield': TeamPalette(Color(0xffffcc00), Color(0xff000000), Color(0xff8f7300)), // NASCAR Cup yellow
  // ── football ─────────────────────────────────────────────
  'football:1fcheidenheim1846': TeamPalette(Color(0xffda0308), Color(0xffffffff), Color(0xff003399)), // 1. FC Heidenheim 1846
  'football:1fcmagdeburg': TeamPalette(Color(0xff0068b2), Color(0xffffffff), Color(0xffffffff)), // 1. FC Magdeburg
  'football:1fcnurnberg': TeamPalette(Color(0xff9f0000), Color(0xffffffff), Color(0xff1a1a1a)), // 1. FC Nürnberg
  'football:1fcunionberlin': TeamPalette(Color(0xffda0308), Color(0xffffffff), Color(0xffd4d4d4)), // 1. FC Union Berlin
  'football:2demayo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // 2 de Mayo
  'football:aalesund': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Aalesund
  'football:aberdeen': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xfff9e900)), // Aberdeen
  'football:academicodeviseu': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Académico de Viseu
  'football:achorsens': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // AC Horsens
  'football:acmilan': TeamPalette(Color(0xffe4002b), Color(0xffffffff), Color(0xffffffff)), // AC Milan
  'football:adelaideunited': TeamPalette(Color(0xffea413c), Color(0xff000000), Color(0xffffffff)), // Adelaide United
  'football:adodenhaag': TeamPalette(Color(0xff307b64), Color(0xffffffff), Color(0xffa0ffe5)), // ADO Den Haag
  'football:adt': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // ADT
  'football:aekathens': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff000000)), // AEK Athens
  'football:aeklarnaca': TeamPalette(Color(0xfffde100), Color(0xff000000), Color(0xff008741)), // AEK Larnaca
  'football:afcbournemouth': TeamPalette(Color(0xfff42727), Color(0xff000000), Color(0xff0000cc)), // AFC Bournemouth
  'football:agf': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // AGF
  'football:aguila': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Águila
  'football:aguilasdoradas': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff000000)), // Águilas Doradas
  'football:aik': TeamPalette(Color(0xffc9ad00), Color(0xff000000), Color(0xff003155)), // AIK
  'football:ajauxerre': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1a1a1a)), // AJ Auxerre
  'football:ajaxamsterdam': TeamPalette(Color(0xffdf1b27), Color(0xffffffff), Color(0xfff4adb2)), // Ajax Amsterdam
  'football:alahli': TeamPalette(Color(0xff078543), Color(0xffffffff), Color(0xff193b67)), // Al Ahli
  'football:alajuelense': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Alajuelense
  'football:alanyaspor': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Alanyaspor
  'football:alaves': TeamPalette(Color(0xff0000ff), Color(0xffffffff), Color(0xffc3c3c3)), // Alavés
  'football:albacete': TeamPalette(Color(0xffbc0814), Color(0xffffffff), Color(0xffe08d92)), // Albacete
  'football:albionfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Albion FC
  'football:aldosivi': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xffffff00)), // Aldosivi
  'football:alettifaq': TeamPalette(Color(0xff00b32c), Color(0xff000000), Color(0xffe40010)), // Al Ettifaq
  'football:alfateh': TeamPalette(Color(0xff26ba09), Color(0xff000000), Color(0xff156805)), // Al Fateh
  'football:alfayha': TeamPalette(Color(0xfffa8228), Color(0xff000000), Color(0xff0000ff)), // Al Fayha
  'football:algeria': TeamPalette(Color(0xff4f9a44), Color(0xff000000), Color(0xffffffff)), // Algeria
  'football:alhazem': TeamPalette(Color(0xffffd700), Color(0xff000000), Color(0xff998100)), // Al Hazem
  'football:alhilal': TeamPalette(Color(0xff1c31ce), Color(0xffffffff), Color(0xffe3e4ed)), // Al Hilal
  'football:alianzaatletico': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Alianza Atlético
  'football:alianzafc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffff00)), // Alianza FC
  'football:alianzalima': TeamPalette(Color(0xff0000ff), Color(0xffffffff), Color(0xff000000)), // Alianza Lima
  'football:alittihad': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff000000)), // Al Ittihad
  'football:alkhaleej': TeamPalette(Color(0xff196f3d), Color(0xffffffff), Color(0xffffee58)), // Al Khaleej
  'football:alkholood': TeamPalette(Color(0xff008000), Color(0xffffffff), Color(0xff8fc78f)), // Al Kholood
  'football:almeria': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xff1a1a1a)), // Almería
  'football:alnajma': TeamPalette(Color(0xff015617), Color(0xffffffff), Color(0xff000000)), // Al Najma
  'football:alnassr': TeamPalette(Color(0xfff7f316), Color(0xff000000), Color(0xff1c31ce)), // Al Nassr
  'football:alokhdood': TeamPalette(Color(0xff87ceeb), Color(0xff000000), Color(0xff000000)), // Al Okhdood
  'football:alqadsiah': TeamPalette(Color(0xffffd700), Color(0xff000000), Color(0xffc60000)), // Al Qadsiah
  'football:alriyadh': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Al Riyadh
  'football:alshabab': TeamPalette(Color(0xffffac1c), Color(0xff000000), Color(0xffffffff)), // Al Shabab
  'football:altaawoun': TeamPalette(Color(0xffeef209), Color(0xff000000), Color(0xff000000)), // Al Taawoun
  'football:alverca': TeamPalette(Color(0xff0047ab), Color(0xffffffff), Color(0xff6691cd)), // Alverca
  'football:alwaysready': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xfffafafc)), // Always Ready
  'football:amazulu': TeamPalette(Color(0xff228b22), Color(0xff000000), Color(0xff000000)), // AmaZulu
  'football:amedsfk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Amed SFK
  'football:america': TeamPalette(Color(0xffffff91), Color(0xff000000), Color(0xff001c58)), // América
  'football:americadecali': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xff000000)), // América de Cali
  'football:americamineiro': TeamPalette(Color(0xff417505), Color(0xffffffff), Color(0xfffafafc)), // América Mineiro
  'football:anderlecht': TeamPalette(Color(0xff695196), Color(0xffffffff), Color(0xfffafafc)), // Anderlecht
  'football:angers': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xffffffff)), // Angers
  'football:annecy': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Annecy
  'football:antwerp': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffffffff)), // Antwerp
  'football:araratarmenia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Ararat-Armenia
  'football:argentina': TeamPalette(Color(0xff74acdf), Color(0xff000000), Color(0xff173e69)), // Argentina
  'football:argentinosjuniors': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Argentinos Juniors
  'football:aris': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Aris
  'football:arminiabielefeld': TeamPalette(Color(0xff00599f), Color(0xffffffff), Color(0xff2c2d37)), // Arminia Bielefeld
  'football:arouca': TeamPalette(Color(0xffffea01), Color(0xff000000), Color(0xff293dc2)), // Arouca
  'football:arsenal': TeamPalette(Color(0xffe20520), Color(0xffffffff), Color(0xff003399)), // Arsenal
  'football:asmonaco': TeamPalette(Color(0xffe91514), Color(0xffffffff), Color(0xff004c37)), // AS Monaco
  'football:asnancylorraine': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xff0000bf)), // AS Nancy Lorraine
  'football:asroma': TeamPalette(Color(0xff990a2c), Color(0xffffffff), Color(0xffeae9e7)), // AS Roma
  'football:asterastripoli': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Asteras Tripoli
  'football:astonvilla': TeamPalette(Color(0xff660e36), Color(0xffffffff), Color(0xff9f6780)), // Aston Villa
  'football:atalanta': TeamPalette(Color(0xff1157bf), Color(0xffffffff), Color(0xffffffff)), // Atalanta
  'football:athletic': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // Athletic
  'football:athleticclub': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffe798a3)), // Athletic Club
  'football:athleticopr': TeamPalette(Color(0xffd80518), Color(0xffffffff), Color(0xfff0a1a8)), // Athletico-PR
  'football:atlantaunitedfc': TeamPalette(Color(0xff9d2235), Color(0xffffffff), Color(0xffaa9767)), // Atlanta United FC
  'football:atlante': TeamPalette(Color(0xff022789), Color(0xffffffff), Color(0xff5770b1)), // Atlante
  'football:atlas': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xffe1e1e1)), // Atlas
  'football:atleticobucaramanga': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Atlético Bucaramanga
  'football:atleticodesanluis': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xffdfa829)), // Atlético de San Luis
  'football:atleticogoianiense': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xffffc2c2)), // Atlético Goianiense
  'football:atleticograu': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Atlético Grau
  'football:atleticojunior': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000055)), // Atlético Junior
  'football:atleticomadrid': TeamPalette(Color(0xffca3624), Color(0xffffffff), Color(0xff000099)), // Atlético Madrid
  'football:atleticomg': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Atlético-MG
  'football:atleticonacional': TeamPalette(Color(0xff06933c), Color(0xff000000), Color(0xff000000)), // Atlético Nacional
  'football:atleticotucuman': TeamPalette(Color(0xff0093ec), Color(0xff000000), Color(0xffc60000)), // Atlético Tucumán
  'football:atromitos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Atromitos
  'football:aucas': TeamPalette(Color(0xffca1524), Color(0xffffffff), Color(0xff000000)), // Aucas
  'football:aucklandfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff0900ff)), // Auckland FC
  'football:audaxitaliano': TeamPalette(Color(0xff046904), Color(0xffffffff), Color(0xff000000)), // Audax Italiano
  'football:austinfc': TeamPalette(Color(0xff00b140), Color(0xff000000), Color(0xff000000)), // Austin FC
  'football:australia': TeamPalette(Color(0xffffcd00), Color(0xff000000), Color(0xff997b00)), // Australia
  'football:austria': TeamPalette(Color(0xffd72b2c), Color(0xffffffff), Color(0xff000000)), // Austria
  'football:austrialustenau': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Austria Lustenau
  'football:austriavienna': TeamPalette(Color(0xff745692), Color(0xffffffff), Color(0xff1a1a1a)), // Austria Vienna
  'football:avai': TeamPalette(Color(0xff0093ec), Color(0xff000000), Color(0xfffafafc)), // Avaí
  'football:avispafukuoka': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Avispa Fukuoka
  'football:azalkmaar': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xffffffff)), // AZ Alkmaar
  'football:bahia': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff0093ec)), // Bahia
  'football:banfield': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff1a1a1a)), // Banfield
  'football:barcelona': TeamPalette(Color(0xff990000), Color(0xffffffff), Color(0xfffce38a)), // Barcelona
  'football:barcelonasc': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff000000)), // Barcelona SC
  'football:bari': TeamPalette(Color(0xffaa0001), Color(0xffffffff), Color(0xff000000)), // Bari
  'football:barracascentral': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Barracas Central
  'football:bayerleverkusen': TeamPalette(Color(0xffda0308), Color(0xffffffff), Color(0xfff9fbfc)), // Bayer Leverkusen
  'football:bayernmunich': TeamPalette(Color(0xffdc052d), Color(0xffffffff), Color(0xff1a1a1a)), // Bayern Munich
  'football:beijingguoan': TeamPalette(Color(0xff02a300), Color(0xff000000), Color(0xfffff212)), // Beijing Guoan
  'football:belgium': TeamPalette(Color(0xffe30613), Color(0xffffffff), Color(0xff6ecff6)), // Belgium
  'football:belgranocordoba': TeamPalette(Color(0xff0060f0), Color(0xffffffff), Color(0xff1a1a1a)), // Belgrano (Córdoba)
  'football:benfica': TeamPalette(Color(0xffca281d), Color(0xffffffff), Color(0xff1a1a1a)), // Benfica
  'football:bengalurufc': TeamPalette(Color(0xff0000fd), Color(0xffffffff), Color(0xff8383fe)), // Bengaluru FC
  'football:besiktas': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1a1a1a)), // Besiktas
  'football:birminghamcity': TeamPalette(Color(0xff0000fa), Color(0xffffffff), Color(0xfffe5442)), // Birmingham City
  'football:bkhacken': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfff7ee09)), // BK Häcken
  'football:blackburnrovers': TeamPalette(Color(0xff0000fa), Color(0xffffffff), Color(0xff1a1a1a)), // Blackburn Rovers
  'football:bocajuniors': TeamPalette(Color(0xfffcb000), Color(0xff000000), Color(0xff0060f0)), // Boca Juniors
  'football:bodoglimt': TeamPalette(Color(0xfffcee33), Color(0xff000000), Color(0xff988f1f)), // Bodo/Glimt
  'football:bolivar': TeamPalette(Color(0xff3c96c4), Color(0xff000000), Color(0xff000000)), // Bolívar
  'football:bologna': TeamPalette(Color(0xff04043d), Color(0xffffffff), Color(0xffffffff)), // Bologna
  'football:boltonwanderers': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1a1a1a)), // Bolton Wanderers
  'football:boracbanjaluka': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffffffff)), // Borac Banja Luka
  'football:borussiadortmund': TeamPalette(Color(0xffffee00), Color(0xff000000), Color(0xff272726)), // Borussia Dortmund
  'football:borussiamonchengladbach': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff03915c)), // Borussia Mönchengladbach
  'football:bosniaherzegovina': TeamPalette(Color(0xff112855), Color(0xffffffff), Color(0xffffffff)), // Bosnia-Herzegovina
  'football:bostonriver': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Boston River
  'football:botafogo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Botafogo
  'football:botafogosp': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Botafogo-SP
  'football:boulogne': TeamPalette(Color(0xfffb2e29), Color(0xff000000), Color(0xfffecbc9)), // Boulogne
  'football:boyacachicofc': TeamPalette(Color(0xff0202db), Color(0xffffffff), Color(0xff000000)), // Boyacá Chicó FC
  'football:braga': TeamPalette(Color(0xffde1f26), Color(0xffffffff), Color(0xfff3afb1)), // Braga
  'football:brazil': TeamPalette(Color(0xfffee000), Color(0xff000000), Color(0xff193375)), // Brazil
  'football:breidablik': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Breidablik
  'football:brentford': TeamPalette(Color(0xfff42727), Color(0xff000000), Color(0xfff8ced9)), // Brentford
  'football:brest': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xffffffff)), // Brest
  'football:brightonhovealbion': TeamPalette(Color(0xff0606fa), Color(0xffffffff), Color(0xffffdd00)), // Brighton & Hove Albion
  'football:brisbaneroar': TeamPalette(Color(0xfff5a12d), Color(0xff000000), Color(0xff895a19)), // Brisbane Roar
  'football:bristolcity': TeamPalette(Color(0xfff42727), Color(0xff000000), Color(0xffffffff)), // Bristol City
  'football:brondbyif': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff43473d)), // Brøndby IF
  'football:burgos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Burgos
  'football:burnley': TeamPalette(Color(0xff6c1d45), Color(0xffffffff), Color(0xff00ffff)), // Burnley
  'football:cadiz': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff1a1a1a)), // Cádiz
  'football:cagliari': TeamPalette(Color(0xff282846), Color(0xffffffff), Color(0xffffffff)), // Cagliari
  'football:canada': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffed2224)), // Canada
  'football:capeverde': TeamPalette(Color(0xff000080), Color(0xffffffff), Color(0xffef3340)), // Cape Verde
  'football:carabobo': TeamPalette(Color(0xff000169), Color(0xffffffff), Color(0xff753000)), // Carabobo
  'football:cardiffcity': TeamPalette(Color(0xff0000fa), Color(0xffffffff), Color(0xffc6d4db)), // Cardiff City
  'football:carrarese': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Carrarese
  'football:casapia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Casa Pia
  'football:castellon': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Castellón
  'football:catanzaro': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Catanzaro
  'football:caykurrizespor': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Caykur Rizespor
  'football:cdmalacateco': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // CD Malacateco
  'football:cdnacional': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // C.D. Nacional
  'football:cdplatense': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // C.D. Platense
  'football:cdsabadell': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // CD Sabadell
  'football:ceara': TeamPalette(Color(0xff010101), Color(0xffffffff), Color(0xfffafafc)), // Ceará
  'football:celtavigo': TeamPalette(Color(0xff6cace4), Color(0xff000000), Color(0xff004996)), // Celta Vigo
  'football:celtic': TeamPalette(Color(0xff009921), Color(0xff000000), Color(0xfff9e900)), // Celtic
  'football:centralcoastmariners': TeamPalette(Color(0xfff5fe05), Color(0xff000000), Color(0xff104c94)), // Central Coast Mariners
  'football:centralcordobasantiagodelestero': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Central Córdoba (Santiago del Estero)
  'football:centralespanolfutbolclub': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Central Español Fútbol Club
  'football:cerclebruggeksv': TeamPalette(Color(0xff048a28), Color(0xff000000), Color(0xffcccccc)), // Cercle Brugge KSV
  'football:cerezoosaka': TeamPalette(Color(0xffffc0cb), Color(0xff000000), Color(0xff99747a)), // Cerezo Osaka
  'football:cerro': TeamPalette(Color(0xff6bc7f5), Color(0xff000000), Color(0xff000000)), // Cerro
  'football:cerrolargo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Cerro Largo
  'football:cerroporteno': TeamPalette(Color(0xffef2d24), Color(0xff000000), Color(0xff000000)), // Cerro Porteño
  'football:cesena': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xff5f5f5f)), // Cesena
  'football:ceuta': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Ceuta
  'football:cfmontreal': TeamPalette(Color(0xff003da6), Color(0xffffffff), Color(0xffc1c5c8)), // CF Montréal
  'football:cfrclujnapoca': TeamPalette(Color(0xff94283f), Color(0xffffffff), Color(0xffffffff)), // CFR Cluj-Napoca
  'football:chapecoense': TeamPalette(Color(0xff417505), Color(0xffffffff), Color(0xfffafafc)), // Chapecoense
  'football:charlottefc': TeamPalette(Color(0xff0085ca), Color(0xff000000), Color(0xff000000)), // Charlotte FC
  'football:charltonathletic': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xff020202)), // Charlton Athletic
  'football:chelsea': TeamPalette(Color(0xff144992), Color(0xffffffff), Color(0xffffffff)), // Chelsea
  'football:chengdurongcheng': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Chengdu Rongcheng
  'football:chennaiyinfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Chennaiyin FC
  'football:chicagofirefc': TeamPalette(Color(0xff7ccdef), Color(0xff000000), Color(0xffff0000)), // Chicago Fire FC
  'football:chippaunited': TeamPalette(Color(0xff7999d1), Color(0xff000000), Color(0xfff0f4fa)), // Chippa United
  'football:chongqingtonglianglong': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Chongqing Tonglianglong
  'football:ciencianodelcusco': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Cienciano del Cusco
  'football:clermontfoot': TeamPalette(Color(0xff8c3140), Color(0xffffffff), Color(0xffffffff)), // Clermont Foot
  'football:clubbrugge': TeamPalette(Color(0xff0081ff), Color(0xff000000), Color(0xffffffff)), // Club Brugge
  'football:clubdeportivoolimpia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Club Deportivo Olimpia
  'football:clubolimpia': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xfffafafc)), // Club Olimpia
  'football:cobresal': TeamPalette(Color(0xfffd0000), Color(0xff000000), Color(0xffffc2c2)), // Cobresal
  'football:colocolo': TeamPalette(Color(0xff050505), Color(0xffffffff), Color(0xff595959)), // Colo Colo
  'football:colombia': TeamPalette(Color(0xfffbd632), Color(0xff000000), Color(0xff21418c)), // Colombia
  'football:coloradorapids': TeamPalette(Color(0xff8a2432), Color(0xffffffff), Color(0xff8ab7e9)), // Colorado Rapids
  'football:columbuscrew': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffedd00)), // Columbus Crew
  'football:comerciantesunidos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Comerciantes Unidos
  'football:como': TeamPalette(Color(0xff3933ff), Color(0xffffffff), Color(0xffffffff)), // Como
  'football:congodr': TeamPalette(Color(0xff418fde), Color(0xff000000), Color(0xffc60000)), // Congo DR
  'football:coquimbounido': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffbe805)), // Coquimbo Unido
  'football:cordoba': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff1a1a1a)), // Córdoba
  'football:corinthians': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Corinthians
  'football:coritiba': TeamPalette(Color(0xff417505), Color(0xffffffff), Color(0xfffafafc)), // Coritiba
  'football:corumfk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Çorum FK
  'football:coventrycity': TeamPalette(Color(0xff87cced), Color(0xff000000), Color(0xffffffff)), // Coventry City
  'football:crb': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xfffafafc)), // CRB
  'football:criciuma': TeamPalette(Color(0xfff8e71c), Color(0xff000000), Color(0xff000000)), // Criciúma
  'football:croatia': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xff0c2fff)), // Croatia
  'football:cruzazul': TeamPalette(Color(0xff0000ff), Color(0xffffffff), Color(0xffffffff)), // Cruz Azul
  'football:cruzeiro': TeamPalette(Color(0xff0093ec), Color(0xff000000), Color(0xfffafafc)), // Cruzeiro
  'football:crystalpalace': TeamPalette(Color(0xff0202fb), Color(0xffffffff), Color(0xffffdd00)), // Crystal Palace
  'football:csikszereda': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Csíkszereda
  'football:csucraiova': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // CSU Craiova
  'football:cucutadeportivo': TeamPalette(Color(0xff320101), Color(0xffffffff), Color(0xffff0000)), // Cúcuta Deportivo
  'football:cuiaba': TeamPalette(Color(0xff004526), Color(0xffffffff), Color(0xffffd65a)), // Cuiabá
  'football:curacao': TeamPalette(Color(0xff0537e4), Color(0xffffffff), Color(0xff7893f0)), // Curaçao
  'football:cuscofc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Cusco FC
  'football:czechia': TeamPalette(Color(0xffd7141a), Color(0xffffffff), Color(0xffffffff)), // Czechia
  'football:dalianyingbo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Dalian Yingbo
  'football:damac': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffffbf00)), // Damac
  'football:danubio': TeamPalette(Color(0xff0a0a0a), Color(0xffffffff), Color(0xff545454)), // Danubio
  'football:dcunited': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffd61018)), // D.C. United
  'football:defensayjusticia': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff288a00)), // Defensa y Justicia
  'football:defensorsporting': TeamPalette(Color(0xff3e188b), Color(0xffffffff), Color(0xff000000)), // Defensor Sporting
  'football:degerforsif': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Degerfors IF
  'football:delfin': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Delfín
  'football:deportesconcepcion': TeamPalette(Color(0xff800080), Color(0xffffffff), Color(0xffffffff)), // Deportes Concepcion
  'football:deporteslimache': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Deportes Limache
  'football:deportestolima': TeamPalette(Color(0xff5b0528), Color(0xffffffff), Color(0xff925970)), // Deportes Tolima
  'football:deportivocali': TeamPalette(Color(0xff046d04), Color(0xffffffff), Color(0xff000000)), // Deportivo Cali
  'football:deportivocuenca': TeamPalette(Color(0xfffd0000), Color(0xff000000), Color(0xff000000)), // Deportivo Cuenca
  'football:deportivogarcilaso': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Deportivo Garcilaso
  'football:deportivolacoruna': TeamPalette(Color(0xff3366cc), Color(0xffffffff), Color(0xffb9e8f0)), // Deportivo La Coruña
  'football:deportivolaguaira': TeamPalette(Color(0xfffc4401), Color(0xff000000), Color(0xffc60000)), // Deportivo La Guaira
  'football:deportivomaldonado': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Deportivo Maldonado
  'football:deportivomoquegua': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Deportivo Moquegua
  'football:deportivopasto': TeamPalette(Color(0xfffc0100), Color(0xff000000), Color(0xff000000)), // Deportivo Pasto
  'football:deportivopereira': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xffff0000)), // Deportivo Pereira
  'football:deportivorecoleta': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Deportivo Recoleta
  'football:deportivoriestra': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xffc60000)), // Deportivo Riestra
  'football:deportivotachira': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xfff8dd00)), // Deportivo Táchira
  'football:derbycounty': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff999999)), // Derby County
  'football:dijonfco': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xffffffff)), // Dijon FCO
  'football:dinamobucuresti': TeamPalette(Color(0xffff1626), Color(0xff000000), Color(0xffffc5c9)), // Dinamo Bucuresti
  'football:dinamozagreb': TeamPalette(Color(0xff0000bb), Color(0xffffffff), Color(0xffccff00)), // Dinamo Zagreb
  'football:djurgarden': TeamPalette(Color(0xff64a6e1), Color(0xff000000), Color(0xffffffff)), // Djurgården
  'football:dritagjilan': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Drita Gjilan
  'football:dundee': TeamPalette(Color(0xff000040), Color(0xffffffff), Color(0xffffffff)), // Dundee
  'football:dundeeunited': TeamPalette(Color(0xffff621a), Color(0xff000000), Color(0xffffece3)), // Dundee United
  'football:dunkerque': TeamPalette(Color(0xff005a9c), Color(0xffffffff), Color(0xff000000)), // Dunkerque
  'football:durbancity': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Durban City
  'football:dynamodresden': TeamPalette(Color(0xfff2a71d), Color(0xff000000), Color(0xff962807)), // Dynamo Dresden
  'football:dynamokyiv': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff0000bf)), // Dynamo Kyiv
  'football:ecuador': TeamPalette(Color(0xffffdd00), Color(0xff000000), Color(0xff034ea2)), // Ecuador
  'football:egnatia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Egnatia
  'football:egypt': TeamPalette(Color(0xffd20300), Color(0xffffffff), Color(0xffffffff)), // Egypt
  'football:eibar': TeamPalette(Color(0xffc00000), Color(0xffffffff), Color(0xff000099)), // Eibar
  'football:eintrachtfrankfurt': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff272726)), // Eintracht Frankfurt
  'football:elche': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff288a00)), // Elche
  'football:eldense': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Eldense
  'football:emelec': TeamPalette(Color(0xff0505d2), Color(0xffffffff), Color(0xff000000)), // Emelec
  'football:empoli': TeamPalette(Color(0xff005bdd), Color(0xffffffff), Color(0xffffffff)), // Empoli
  'football:energiecottbus': TeamPalette(Color(0xffcc0000), Color(0xffffffff), Color(0xffffff00)), // Energie Cottbus
  'football:england': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffea1f29)), // England
  'football:erzurumbb': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Erzurum BB
  'football:espanyol': TeamPalette(Color(0xff3366cc), Color(0xffffffff), Color(0xffa0b8e7)), // Espanyol
  'football:estoril': TeamPalette(Color(0xffffea01), Color(0xff000000), Color(0xff293dc2)), // Estoril
  'football:estrela': TeamPalette(Color(0xff3b8132), Color(0xffffffff), Color(0xffa9c8a5)), // Estrela
  'football:estudiantesdelaplata': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Estudiantes de La Plata
  'football:estudiantesderiocuarto': TeamPalette(Color(0xff008bd0), Color(0xff000000), Color(0xff000000)), // Estudiantes de Río Cuarto
  'football:everton': TeamPalette(Color(0xff0606fa), Color(0xffffffff), Color(0xff132257)), // Everton
  'football:evertoncd': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Everton CD
  'football:excelsior': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffb41226)), // Excelsior
  'football:eyupspor': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Eyupspor
  'football:fagianookayama': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Fagiano Okayama
  'football:falkirk': TeamPalette(Color(0xff000099), Color(0xffffffff), Color(0xffc60000)), // Falkirk
  'football:fcandorra': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Andorra
  'football:fcarges': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Arges
  'football:fcatertbissen': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Atert Bissen
  'football:fcaugsburg': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff03915c)), // FC Augsburg
  'football:fcbasel': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffffffff)), // FC Basel
  'football:fcbotosani': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Botosani
  'football:fccajamarca': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Cajamarca
  'football:fccincinnati': TeamPalette(Color(0xff003087), Color(0xffffffff), Color(0xfffe5000)), // FC Cincinnati
  'football:fccologne': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffda0308)), // FC Cologne
  'football:fcdallas': TeamPalette(Color(0xffc6093b), Color(0xffffffff), Color(0xff001f5b)), // FC Dallas
  'football:fcfamalicao': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff183760)), // FC Famalicao
  'football:fcfarulconstanta': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Farul Constanta
  'football:fcgoa': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // FC Goa
  'football:fcgroningen': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff30565c)), // FC Groningen
  'football:fcjuarez': TeamPalette(Color(0xff89f442), Color(0xff000000), Color(0xff529328)), // FC Juarez
  'football:fckobenhavn': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1a1a1a)), // F.C. København
  'football:fclugano': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // FC Lugano
  'football:fcluzern': TeamPalette(Color(0xff0d3996), Color(0xffffffff), Color(0xfffcd116)), // FC Luzern
  'football:fcmidtjylland': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffff0900)), // FC Midtjylland
  'football:fcmotagua': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // FC Motagua
  'football:fcnoah': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // FC Noah
  'football:fcnordsjaelland': TeamPalette(Color(0xffcf010e), Color(0xffffffff), Color(0xff0093ec)), // FC Nordsjælland
  'football:fcporto': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xffffa000)), // FC Porto
  'football:fcsb': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xffdc1f26)), // FCSB
  'football:fcsion': TeamPalette(Color(0xffff0900), Color(0xff000000), Color(0xff000000)), // FC Sion
  'football:fcthun': TeamPalette(Color(0xffff0900), Color(0xff000000), Color(0xfffcd116)), // FC Thun
  'football:fctokyo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // FC Tokyo
  'football:fctwente': TeamPalette(Color(0xfff31522), Color(0xff000000), Color(0xff9df9f7)), // FC Twente
  'football:fcutrecht': TeamPalette(Color(0xfff31522), Color(0xff000000), Color(0xff1a316b)), // FC Utrecht
  'football:fczurich': TeamPalette(Color(0xff5ba5e2), Color(0xff000000), Color(0xff0b1433)), // FC Zürich
  'football:fenerbahce': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff999900)), // Fenerbahce
  'football:ferencvaros': TeamPalette(Color(0xff239b56), Color(0xff000000), Color(0xff000000)), // Ferencvaros
  'football:feyenoordrotterdam': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xff000000)), // Feyenoord Rotterdam
  'football:fiorentina': TeamPalette(Color(0xff4c1d84), Color(0xffffffff), Color(0xffffffff)), // Fiorentina
  'football:fkqarabag': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // FK Qarabag
  'football:fksutjeska': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // FK Sutjeska
  'football:flamengo': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Flamengo
  'football:flora': TeamPalette(Color(0xff34a66d), Color(0xff000000), Color(0xffdff1e8)), // Flora
  'football:florianafc': TeamPalette(Color(0xff3bc705), Color(0xff000000), Color(0xfff5f126)), // Floriana FC
  'football:fluminense': TeamPalette(Color(0xff7e0202), Color(0xffffffff), Color(0xff417505)), // Fluminense
  'football:fortalezaceif': TeamPalette(Color(0xffdc0000), Color(0xffffffff), Color(0xfff2a4a4)), // Fortaleza CEIF
  'football:fortunasittard': TeamPalette(Color(0xfffcee33), Color(0xff000000), Color(0xff988f1f)), // Fortuna Sittard
  'football:france': TeamPalette(Color(0xff000080), Color(0xffffffff), Color(0xffc8e6d8)), // France
  'football:fredrikstad': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Fredrikstad
  'football:frosinone': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff999900)), // Frosinone
  'football:fulham': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff00cc00)), // Fulham
  'football:gais': TeamPalette(Color(0xff009d58), Color(0xff000000), Color(0xffbfe6d5)), // GAIS
  'football:galatasaray': TeamPalette(Color(0xffaa0031), Color(0xffffffff), Color(0xffffffff)), // Galatasaray
  'football:gambaosaka': TeamPalette(Color(0xff0105bc), Color(0xffffffff), Color(0xffffffff)), // Gamba Osaka
  'football:gaziantepfk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Gaziantep FK
  'football:genclerbirligi': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffe91b23)), // Genclerbirligi
  'football:genoa': TeamPalette(Color(0xff08305d), Color(0xffffffff), Color(0xffffffff)), // Genoa
  'football:germany': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff00ced1)), // Germany
  'football:getafe': TeamPalette(Color(0xff0000ff), Color(0xffffffff), Color(0xff8383ff)), // Getafe
  'football:ghana': TeamPalette(Color(0xfffbd632), Color(0xff000000), Color(0xff000000)), // Ghana
  'football:gilvicente': TeamPalette(Color(0xffde1f26), Color(0xffffffff), Color(0xffffffff)), // Gil Vicente
  'football:gimnasialaplata': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xffaed39f)), // Gimnasia La Plata
  'football:gimnasiamendoza': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Gimnasia (Mendoza)
  'football:girona': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Girona
  'football:goaheadeagles': TeamPalette(Color(0xfff80017), Color(0xff000000), Color(0xff8f0058)), // Go Ahead Eagles
  'football:goias': TeamPalette(Color(0xff417505), Color(0xffffffff), Color(0xfffafafc)), // Goiás
  'football:goldenarrows': TeamPalette(Color(0xff008000), Color(0xffffffff), Color(0xffffd700)), // Golden Arrows
  'football:gornikzabrze': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Gornik Zabrze
  'football:goztepe': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Goztepe
  'football:granada': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffe798a3)), // Granada
  'football:grasshoppers': TeamPalette(Color(0xff5668d4), Color(0xffffffff), Color(0xffeae04b)), // Grasshoppers
  'football:grazerak': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Grazer AK
  'football:gremio': TeamPalette(Color(0xff0093ec), Color(0xff000000), Color(0xff000000)), // Grêmio
  'football:grenoble': TeamPalette(Color(0xff005da3), Color(0xffffffff), Color(0xff000000)), // Grenoble
  'football:guadalajara': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xff104e8a)), // Guadalajara
  'football:guarani': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Guaraní
  'football:guayaquilcityfc': TeamPalette(Color(0xff0505d2), Color(0xffffffff), Color(0xffc60000)), // Guayaquil City FC
  'football:guingamp': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xff1a1a1a)), // Guingamp
  'football:gyorietofc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Györi ETO FC
  'football:haiti': TeamPalette(Color(0xff0033a0), Color(0xffffffff), Color(0xffffffff)), // Haiti
  'football:halmstadsbk': TeamPalette(Color(0xff0058a2), Color(0xffffffff), Color(0xffd6b160)), // Halmstads BK
  'football:hamarkameratene': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Hamarkameratene
  'football:hamburgsv': TeamPalette(Color(0xff1a26af), Color(0xffffffff), Color(0xff1a1a1a)), // Hamburg SV
  'football:hammarbyif': TeamPalette(Color(0xffffcc00), Color(0xff000000), Color(0xff007a43)), // Hammarby IF
  'football:hamrunspartans': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Hamrun Spartans
  'football:hannover96': TeamPalette(Color(0xff179d33), Color(0xff000000), Color(0xff1a1a1a)), // Hannover 96
  'football:hapoelbeer': TeamPalette(Color(0xfffd0000), Color(0xff000000), Color(0xffffc2c2)), // Hapoel Be'er
  'football:heartofmidlothian': TeamPalette(Color(0xff8e003b), Color(0xffffffff), Color(0xffead6b7)), // Heart of Midlothian
  'football:heerenveen': TeamPalette(Color(0xff003eff), Color(0xffffffff), Color(0xff1a316b)), // Heerenveen
  'football:henan': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Henan
  'football:hermannstadt': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Hermannstadt
  'football:herthaberlin': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xff091453)), // Hertha Berlin
  'football:hibernian': TeamPalette(Color(0xff009f00), Color(0xff000000), Color(0xffffffff)), // Hibernian
  'football:holsteinkiel': TeamPalette(Color(0xff0754ba), Color(0xffffffff), Color(0xfff9fbfc)), // Holstein Kiel
  'football:houstondynamofc': TeamPalette(Color(0xffff6b00), Color(0xff000000), Color(0xff101820)), // Houston Dynamo FC
  'football:huachipato': TeamPalette(Color(0xff023396), Color(0xffffffff), Color(0xff000000)), // Huachipato
  'football:hullcity': TeamPalette(Color(0xfff28800), Color(0xff000000), Color(0xffffffff)), // Hull City
  'football:huracan': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Huracán
  'football:iberia1999': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Iberia 1999
  'football:ifbrommapojkarna': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffdf1e1e)), // IF Brommapojkarna
  'football:ifelfsborg': TeamPalette(Color(0xffffef32), Color(0xff000000), Color(0xffff0900)), // IF Elfsborg
  'football:ifkgoteborg': TeamPalette(Color(0xfffabd00), Color(0xff000000), Color(0xff214a99)), // IFK Göteborg
  'football:iksirius': TeamPalette(Color(0xffd62612), Color(0xffffffff), Color(0xff000000)), // IK Sirius
  'football:ikstart': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // IK Start
  'football:independiente': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Independiente
  'football:independientedelvalle': TeamPalette(Color(0xff000d5d), Color(0xffffffff), Color(0xff565e94)), // Independiente del Valle
  'football:independientemedellin': TeamPalette(Color(0xffd70000), Color(0xffffffff), Color(0xff000000)), // Independiente Medellín
  'football:independienterivadavia': TeamPalette(Color(0xff000061), Color(0xffffffff), Color(0xff565696)), // Independiente Rivadavia
  'football:independientesantafe': TeamPalette(Color(0xffe33439), Color(0xff000000), Color(0xfffafafc)), // Independiente Santa Fe
  'football:institutocordoba': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Instituto (Córdoba)
  'football:interdescaldes': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Inter D'Escaldes
  'football:interkashi': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Inter Kashi
  'football:intermiamicf': TeamPalette(Color(0xff231f20), Color(0xffffffff), Color(0xfff7b5cd)), // Inter Miami CF
  'football:internacional': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Internacional
  'football:internacionaldebogota': TeamPalette(Color(0xffc5a065), Color(0xff000000), Color(0xff000000)), // Internacional de Bogotá
  'football:internazionale': TeamPalette(Color(0xff00239c), Color(0xffffffff), Color(0xffffffff)), // Internazionale
  'football:ipswichtown': TeamPalette(Color(0xff0000fa), Color(0xffffffff), Color(0xff8383fd)), // Ipswich Town
  'football:iraklis': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Iraklis
  'football:iran': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffda0000)), // Iran
  'football:iraq': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff0a4d2e)), // Iraq
  'football:istanbulbasaksehir': TeamPalette(Color(0xffff6600), Color(0xff000000), Color(0xff091453)), // Istanbul Basaksehir
  'football:ivorycoast': TeamPalette(Color(0xffff8200), Color(0xff000000), Color(0xff8f4900)), // Ivory Coast
  'football:jagielloniabialystok': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Jagiellonia Bialystok
  'football:jaguaresdecordoba': TeamPalette(Color(0xff329bd4), Color(0xff000000), Color(0xffc60000)), // Jaguares de Córdoba
  'football:jamshedpurfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Jamshedpur FC
  'football:japan': TeamPalette(Color(0xff000555), Color(0xffffffff), Color(0xff56598e)), // Japan
  'football:jefunitedichiharachiba': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // JEF United Ichihara-Chiba
  'football:jordan': TeamPalette(Color(0xffe70000), Color(0xffffffff), Color(0xffffffff)), // Jordan
  'football:juanpabloii': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Juan Pablo II
  'football:juventud': TeamPalette(Color(0xff023396), Color(0xffffffff), Color(0xff607ebd)), // Juventud
  'football:juventude': TeamPalette(Color(0xff417505), Color(0xffffffff), Color(0xfffafafc)), // Juventude
  'football:juventus': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffef32)), // Juventus
  'football:juvestabia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Juve Stabia
  'football:kaagent': TeamPalette(Color(0xff0000ff), Color(0xffffffff), Color(0xffffffff)), // KAA Gent
  'football:kairatalmaty': TeamPalette(Color(0xfffcee33), Color(0xff000000), Color(0xff988f1f)), // Kairat Almaty
  'football:kaiserslautern': TeamPalette(Color(0xff8c273d), Color(0xffffffff), Color(0xff1a1a1a)), // Kaiserslautern
  'football:kaizerchiefs': TeamPalette(Color(0xffffcc00), Color(0xff000000), Color(0xff300089)), // Kaizer Chiefs
  'football:kalamata': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Kalamata
  'football:kalmarff': TeamPalette(Color(0xffdb1b30), Color(0xffffffff), Color(0xffc6870f)), // Kalmar FF
  'football:karlsruhersc': TeamPalette(Color(0xff2563b8), Color(0xffffffff), Color(0xff8fafdb)), // Karlsruher SC
  'football:kashimaantlers': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xff060040)), // Kashima Antlers
  'football:kashiwareysol': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Kashiwa Reysol
  'football:kasimpasa': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Kasimpasa
  'football:kaunozalgiris': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Kauno Zalgiris
  'football:kawasakifrontale': TeamPalette(Color(0xffb0d5fc), Color(0xff000000), Color(0xffa8a003)), // Kawasaki Frontale
  'football:keralablastersfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Kerala Blasters FC
  'football:kfshkendija': TeamPalette(Color(0xffe91514), Color(0xffffffff), Color(0xff000000)), // KF Shkëndija
  'football:kfumoslo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // KFUM Oslo
  'football:kifisia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Kifisia
  'football:kiklaksvik': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // KI Klaksvik
  'football:kilmarnock': TeamPalette(Color(0xff0046ff), Color(0xffffffff), Color(0xffbabbbf)), // Kilmarnock
  'football:kocaelispor': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Kocaelispor
  'football:konyaspor': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff000000)), // Konyaspor
  'football:kristiansundbk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Kristiansund BK
  'football:kupskuopio': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // KuPS Kuopio
  'football:kvcwesterlo': TeamPalette(Color(0xff005bd2), Color(0xffffffff), Color(0xfffffb00)), // KVC Westerlo
  'football:kvkortrijk': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xffcccccc)), // KV Kortrijk
  'football:kvmechelen': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xffcccccc)), // KV Mechelen
  'football:kyotosanga': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Kyoto Sanga
  'football:lafc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc7a36f)), // LAFC
  'football:lagalaxy': TeamPalette(Color(0xff00235d), Color(0xffffffff), Color(0xffffffff)), // LA Galaxy
  'football:lanus': TeamPalette(Color(0xff9f0000), Color(0xffffffff), Color(0xff1a1a1a)), // Lanús
  'football:larne': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffffffff)), // Larne
  'football:laserena': TeamPalette(Color(0xffc22222), Color(0xffffffff), Color(0xffe39999)), // La Serena
  'football:lasklinz': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff000000)), // LASK Linz
  'football:laspalmas': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff3366cc)), // Las Palmas
  'football:lausannesports': TeamPalette(Color(0xff000099), Color(0xffffffff), Color(0xffc60000)), // Lausanne Sports
  'football:lazio': TeamPalette(Color(0xff74bde7), Color(0xff000000), Color(0xffffef32)), // Lazio
  'football:lecce': TeamPalette(Color(0xffe4002b), Color(0xffffffff), Color(0xff08305d)), // Lecce
  'football:lechpoznan': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Lech Poznan
  'football:leedsunited': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff0000ff)), // Leeds United
  'football:leganes': TeamPalette(Color(0xff6cace4), Color(0xff000000), Color(0xff3c6080)), // Leganés
  'football:legiawarsaw': TeamPalette(Color(0xff2b6a36), Color(0xffffffff), Color(0xffffffff)), // Legia Warsaw
  'football:lehavreac': TeamPalette(Color(0xff011f68), Color(0xffffffff), Color(0xffededed)), // Le Havre AC
  'football:lemans': TeamPalette(Color(0xffd62b11), Color(0xffffffff), Color(0xffefaba0)), // Le Mans
  'football:lens': TeamPalette(Color(0xffe91514), Color(0xffffffff), Color(0xff004c37)), // Lens
  'football:leon': TeamPalette(Color(0xff008000), Color(0xffffffff), Color(0xfffff61b)), // León
  'football:leones': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Leones
  'football:levadiakos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Levadiakos
  'football:levante': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xff000000)), // Levante
  'football:levskisofia': TeamPalette(Color(0xff6182cf), Color(0xff000000), Color(0xfffcfcfc)), // Levski Sofia
  'football:liaoningtieren': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Liaoning Tieren
  'football:libertad': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Libertad
  'football:libertadecuador': TeamPalette(Color(0xffffa500), Color(0xff000000), Color(0xff000000)), // Libertad (Ecuador)
  'football:ligadequito': TeamPalette(Color(0xff1c1d5c), Color(0xffffffff), Color(0xff60618d)), // Liga de Quito
  'football:lille': TeamPalette(Color(0xffc2051b), Color(0xffffffff), Color(0xffe2d3d7)), // Lille
  'football:lillestrom': TeamPalette(Color(0xffe8e337), Color(0xff000000), Color(0xffff0000)), // Lillestrom
  'football:lincolncity': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffc6d4db)), // Lincoln City
  'football:lincolnredimps': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffffffff)), // Lincoln Red Imps
  'football:liverpool': TeamPalette(Color(0xffd11317), Color(0xffffffff), Color(0xffffffff)), // Liverpool
  'football:llanerosfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Llaneros FC
  'football:lommelsk': TeamPalette(Color(0xff2d8322), Color(0xffffffff), Color(0xffffffff)), // Lommel SK
  'football:londrina': TeamPalette(Color(0xff0093ec), Color(0xff000000), Color(0xfffafafc)), // Londrina
  'football:lorient': TeamPalette(Color(0xfff46100), Color(0xff000000), Color(0xff1a1a1a)), // Lorient
  'football:loschankas': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Los Chankas
  'football:ludogoretsrazgrad': TeamPalette(Color(0xff008000), Color(0xffffffff), Color(0xffffffff)), // Ludogorets Razgrad
  'football:lyngbyboldklub': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Lyngby Boldklub
  'football:lyon': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1a1a1a)), // Lyon
  'football:macara': TeamPalette(Color(0xff0195dd), Color(0xff000000), Color(0xfffafafc)), // Macará
  'football:macarthurfc': TeamPalette(Color(0xffdbc242), Color(0xff000000), Color(0xff000000)), // Macarthur FC
  'football:maccabitelaviv': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff020202)), // Maccabi Tel-Aviv
  'football:machidazelvia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Machida Zelvia
  'football:magesifc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Magesi FC
  'football:mainz': TeamPalette(Color(0xffda0308), Color(0xffffffff), Color(0xff000055)), // Mainz
  'football:malaga': TeamPalette(Color(0xffb9e8f0), Color(0xff000000), Color(0xff6f8c90)), // Málaga
  'football:mallorca': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffccff00)), // Mallorca
  'football:malmoff': TeamPalette(Color(0xff5699eb), Color(0xff000000), Color(0xff052a87)), // Malmö FF
  'football:mamelodisundowns': TeamPalette(Color(0xffffd700), Color(0xff000000), Color(0xff228b22)), // Mamelodi Sundowns
  'football:manchestercity': TeamPalette(Color(0xff99c5ea), Color(0xff000000), Color(0xff000000)), // Manchester City
  'football:manchesterunited': TeamPalette(Color(0xffda020e), Color(0xffffffff), Color(0xffffffff)), // Manchester United
  'football:mantafc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Manta F.C.
  'football:mantova': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xffffc2c2)), // Mantova
  'football:maritimo': TeamPalette(Color(0xff008222), Color(0xffffffff), Color(0xff01e5db)), // Maritimo
  'football:marseille': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff011f68)), // Marseille
  'football:marumogallants': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Marumo Gallants
  'football:melbournecityfc': TeamPalette(Color(0xff87cefa), Color(0xff000000), Color(0xfffafafc)), // Melbourne City FC
  'football:melbournevictory': TeamPalette(Color(0xff104c94), Color(0xffffffff), Color(0xffd3d3d3)), // Melbourne Victory
  'football:melgar': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Melgar
  'football:metaloglobus': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Metaloglobus
  'football:metz': TeamPalette(Color(0xff8c3140), Color(0xffffffff), Color(0xffe6c168)), // Metz
  'football:mexico': TeamPalette(Color(0xff006847), Color(0xffffffff), Color(0xff000000)), // Mexico
  'football:middlesbrough': TeamPalette(Color(0xfff42727), Color(0xff000000), Color(0xff87cced)), // Middlesbrough
  'football:millonarios': TeamPalette(Color(0xff0202db), Color(0xffffffff), Color(0xff000000)), // Millonarios
  'football:millwall': TeamPalette(Color(0xff091453), Color(0xffffffff), Color(0xff007066)), // Millwall
  'football:minnesotaunitedfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff9bcde4)), // Minnesota United FC
  'football:mirassol': TeamPalette(Color(0xfffedc00), Color(0xff000000), Color(0xff417505)), // Mirassol
  'football:mitohollyhock': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Mito Hollyhock
  'football:mjallbyaif': TeamPalette(Color(0xff231f20), Color(0xffffffff), Color(0xffffd400)), // Mjällby AIF
  'football:mlvitebsk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // ML Vitebsk
  'football:modena': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Modena
  'football:mohammedansc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Mohammedan SC
  'football:mohunbagansupergiant': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Mohun Bagan Super Giant
  'football:molde': TeamPalette(Color(0xff000099), Color(0xffffffff), Color(0xffffffff)), // Molde
  'football:monterrey': TeamPalette(Color(0xff001c58), Color(0xffffffff), Color(0xffffffff)), // Monterrey
  'football:montevideocitytorque': TeamPalette(Color(0xff6bc7f5), Color(0xff000000), Color(0xff000000)), // Montevideo City Torque
  'football:montevideowanderers': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xfffafafc)), // Montevideo Wanderers
  'football:montpellier': TeamPalette(Color(0xff011f68), Color(0xffffffff), Color(0xffffffff)), // Montpellier
  'football:monza': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffffffff)), // Monza
  'football:moreirense': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff000000)), // Moreirense
  'football:morocco': TeamPalette(Color(0xffdf2027), Color(0xffffffff), Color(0xffffffff)), // Morocco
  'football:motherwell': TeamPalette(Color(0xfff7aa25), Color(0xff000000), Color(0xff535e64)), // Motherwell
  'football:mumbaicityfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Mumbai City FC
  'football:municipal': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Municipal
  'football:mushucruna': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Mushuc Runa
  'football:nacional': TeamPalette(Color(0xff345bbc), Color(0xffffffff), Color(0xff97abdd)), // Nacional
  'football:nacionalasuncion': TeamPalette(Color(0xff7cbde7), Color(0xff000000), Color(0xff000000)), // Nacional Asunción
  'football:nacionalpotosi': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xffc60000)), // Nacional Potosí
  'football:nagoyagrampus': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Nagoya Grampus
  'football:nantes': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff011f68)), // Nantes
  'football:napoli': TeamPalette(Color(0xff0677d2), Color(0xffffffff), Color(0xffffffff)), // Napoli
  'football:nashvillesc': TeamPalette(Color(0xffece83a), Color(0xff000000), Color(0xff1f1646)), // Nashville SC
  'football:nautico': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xfffafafc)), // Náutico
  'football:necaxa': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xff000000)), // Necaxa
  'football:necnijmegen': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xff84aee7)), // NEC Nijmegen
  'football:neomsc': TeamPalette(Color(0xff259eee), Color(0xff000000), Color(0xffe7f4fd)), // Neom SC
  'football:netherlands': TeamPalette(Color(0xfffb5d00), Color(0xff000000), Color(0xfffee5d7)), // Netherlands
  'football:newcastlejets': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xffffffff)), // Newcastle Jets
  'football:newcastleunited': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // Newcastle United
  'football:newellsoldboys': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Newell's Old Boys
  'football:newenglandrevolution': TeamPalette(Color(0xff022166), Color(0xffffffff), Color(0xffce0e2d)), // New England Revolution
  'football:newyorkcityfc': TeamPalette(Color(0xff9fd2ff), Color(0xff000000), Color(0xff000229)), // New York City FC
  'football:newzealand': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // New Zealand
  'football:nice': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xffe2d3d7)), // Nice
  'football:nkcelje': TeamPalette(Color(0xff000099), Color(0xffffffff), Color(0xffff6600)), // NK Celje
  'football:northeastunitedfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // NorthEast United FC
  'football:norway': TeamPalette(Color(0xffc8102e), Color(0xffffffff), Color(0xffe89ba8)), // Norway
  'football:norwichcity': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff1d428a)), // Norwich City
  'football:nottinghamforest': TeamPalette(Color(0xffc8102e), Color(0xffffffff), Color(0xff132257)), // Nottingham Forest
  'football:novorizontino': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffd704)), // Novorizontino
  'football:nublense': TeamPalette(Color(0xffc22222), Color(0xffffffff), Color(0xffe39999)), // Ñublense
  'football:odenseboldklub': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Odense Boldklub
  'football:odishafc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Odisha FC
  'football:oficrete': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // OFI Crete
  'football:ohiggins': TeamPalette(Color(0xff517ab7), Color(0xff000000), Color(0xff000000)), // O'Higgins
  'football:ohleuven': TeamPalette(Color(0xff048a28), Color(0xff000000), Color(0xff000000)), // OH Leuven
  'football:olympiacos': TeamPalette(Color(0xffd01729), Color(0xffffffff), Color(0xffeb9ea6)), // Olympiacos
  'football:omonianicosia': TeamPalette(Color(0xff025719), Color(0xffffffff), Color(0xffffffff)), // Omonia Nicosia
  'football:oncecaldas': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Once Caldas
  'football:operariopr': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Operário PR
  'football:orbitcollege': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Orbit College
  'football:orense': TeamPalette(Color(0xff008f39), Color(0xff000000), Color(0xff000000)), // Orense
  'football:orgryteis': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Örgryte IS
  'football:orlandocitysc': TeamPalette(Color(0xff60269e), Color(0xffffffff), Color(0xfff0d283)), // Orlando City SC
  'football:orlandopirates': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Orlando Pirates
  'football:osasuna': TeamPalette(Color(0xffcd0000), Color(0xffffffff), Color(0xffffffff)), // Osasuna
  'football:pachuca': TeamPalette(Color(0xff001c58), Color(0xffffffff), Color(0xff02b0d0)), // Pachuca
  'football:pacificfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Pacific FC
  'football:padova': TeamPalette(Color(0xffaa0001), Color(0xffffffff), Color(0xff1a1a1a)), // Padova
  'football:pafos': TeamPalette(Color(0xff82c0fe), Color(0xff000000), Color(0xff003399)), // Pafos
  'football:palermo': TeamPalette(Color(0xfff9bed4), Color(0xff000000), Color(0xff967280)), // Palermo
  'football:palestino': TeamPalette(Color(0xff2a1b07), Color(0xffffffff), Color(0xff6a6052)), // Palestino
  'football:palmeiras': TeamPalette(Color(0xff417505), Color(0xffffffff), Color(0xfffafafc)), // Palmeiras
  'football:panama': TeamPalette(Color(0xffd21034), Color(0xffffffff), Color(0xffeda0ae)), // Panama
  'football:panathinaikos': TeamPalette(Color(0xff2b6a36), Color(0xffffffff), Color(0xffffffff)), // Panathinaikos
  'football:panetolikos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Panetolikos
  'football:paoksalonika': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // PAOK Salonika
  'football:paraguay': TeamPalette(Color(0xffea2300), Color(0xff000000), Color(0xff21418c)), // Paraguay
  'football:parisfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Paris FC
  'football:parissaintgermain': TeamPalette(Color(0xff011f68), Color(0xffffffff), Color(0xffffffff)), // Paris Saint-Germain
  'football:parma': TeamPalette(Color(0xff19161d), Color(0xffffffff), Color(0xffffdd30)), // Parma
  'football:pau': TeamPalette(Color(0xff0070b1), Color(0xffffffff), Color(0xfff3cf56)), // Pau
  'football:peczwolle': TeamPalette(Color(0xff0000d4), Color(0xffffffff), Color(0xff000000)), // PEC Zwolle
  'football:penarol': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Peñarol
  'football:perthglory': TeamPalette(Color(0xff562d84), Color(0xffffffff), Color(0xffffffff)), // Perth Glory
  'football:pescara': TeamPalette(Color(0xff409fff), Color(0xff000000), Color(0xff000099)), // Pescara
  'football:petrocub': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // Petrocub
  'football:petrolulploiesti': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Petrolul Ploiesti
  'football:philadelphiaunion': TeamPalette(Color(0xff051f31), Color(0xffffffff), Color(0xffe0d0a6)), // Philadelphia Union
  'football:platense': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Platense
  'football:polokwanecityfc': TeamPalette(Color(0xffff7f00), Color(0xff000000), Color(0xff00ffff)), // Polokwane City FC
  'football:pontepreta': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Ponte Preta
  'football:portlandtimbers': TeamPalette(Color(0xff2c5234), Color(0xffffffff), Color(0xffc99700)), // Portland Timbers
  'football:portsmouth': TeamPalette(Color(0xff0000fa), Color(0xffffffff), Color(0xff1a1a1a)), // Portsmouth
  'football:portugal': TeamPalette(Color(0xffda291c), Color(0xffffffff), Color(0xfff1aea9)), // Portugal
  'football:prestonnorthend': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff87cced)), // Preston North End
  'football:progreso': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Progreso
  'football:psveindhoven': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xff000000)), // PSV Eindhoven
  'football:puebla': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff0032a8)), // Puebla
  'football:pumasunam': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff060040)), // Pumas UNAM
  'football:punjabfc': TeamPalette(Color(0xff8f171a), Color(0xffffffff), Color(0xffffc80b)), // Punjab FC
  'football:qatar': TeamPalette(Color(0xff691a40), Color(0xffffffff), Color(0xffffffff)), // Qatar
  'football:qingdaohainiu': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Qingdao Hainiu
  'football:qingdaowestcoast': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Qingdao West Coast
  'football:queensparkrangers': TeamPalette(Color(0xff0000d4), Color(0xffffffff), Color(0xff1a1a1a)), // Queens Park Rangers
  'football:queretaro': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff02b0d0)), // Querétaro
  'football:raallalouviere': TeamPalette(Color(0xff287f45), Color(0xffffffff), Color(0xfff8f9fa)), // RAAL La Louvière
  'football:racingclub': TeamPalette(Color(0xff409fff), Color(0xff000000), Color(0xff000000)), // Racing Club
  'football:racinggenk': TeamPalette(Color(0xff0000ff), Color(0xffffffff), Color(0xffcccccc)), // Racing Genk
  'football:racingmontevideo': TeamPalette(Color(0xff107436), Color(0xffffffff), Color(0xff8abb9d)), // Racing (Montevideo)
  'football:racingsantander': TeamPalette(Color(0xff3b6c1a), Color(0xffffffff), Color(0xff0eb214)), // Racing Santander
  'football:rakowczestochowa': TeamPalette(Color(0xffee2e24), Color(0xff000000), Color(0xff164ba0)), // Raków Czestochowa
  'football:randersfc': TeamPalette(Color(0xff81c0ff), Color(0xff000000), Color(0xff486b8f)), // Randers FC
  'football:rangers': TeamPalette(Color(0xff0046ff), Color(0xffffffff), Color(0xffffffff)), // Rangers
  'football:rapidbucuresti': TeamPalette(Color(0xff803033), Color(0xffffffff), Color(0xff000000)), // Rapid Bucuresti
  'football:rapidvienna': TeamPalette(Color(0xff2b6a36), Color(0xffffffff), Color(0xff8cae92)), // Rapid Vienna
  'football:rayovallecano': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffcd0000)), // Rayo Vallecano
  'football:rbleipzig': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff740c14)), // RB Leipzig
  'football:rbsalzburg': TeamPalette(Color(0xffd82c3a), Color(0xffffffff), Color(0xff052a87)), // RB Salzburg
  'football:rcceltafortuna': TeamPalette(Color(0xff6cace4), Color(0xff000000), Color(0xff004996)), // RC Celta Fortuna
  'football:realbetis': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xffccff00)), // Real Betis
  'football:realespana': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Real España
  'football:realesteli': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Real Estelí
  'football:realmadrid': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff00529f)), // Real Madrid
  'football:realoviedo': TeamPalette(Color(0xffe23627), Color(0xff000000), Color(0xffffd200)), // Real Oviedo
  'football:realsaltlake': TeamPalette(Color(0xffa32035), Color(0xffffffff), Color(0xffdaa900)), // Real Salt Lake
  'football:realsociedad': TeamPalette(Color(0xff3366cc), Color(0xffffffff), Color(0xffffdd00)), // Real Sociedad
  'football:realsociedadii': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Real Sociedad II
  'football:realvalladolid': TeamPalette(Color(0xff7a2d9d), Color(0xffffffff), Color(0xffffffff)), // Real Valladolid
  'football:redbullbragantino': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Red Bull Bragantino
  'football:redbullnewyork': TeamPalette(Color(0xffba0c2f), Color(0xffffffff), Color(0xffffc72c)), // Red Bull New York
  'football:redstarbelgrade': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xff0000dd)), // Red Star Belgrade
  'football:redstarfc93': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Red Star FC 93
  'football:reggiana': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Reggiana
  'football:remo': TeamPalette(Color(0xff265891), Color(0xffffffff), Color(0xfffafafa)), // Remo
  'football:richardsbayfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Richards Bay FC
  'football:rigafc': TeamPalette(Color(0xff00aae4), Color(0xff000000), Color(0xff000000)), // Riga FC
  'football:rijeka': TeamPalette(Color(0xff42befd), Color(0xff000000), Color(0xff000000)), // Rijeka
  'football:rioave': TeamPalette(Color(0xff3b8649), Color(0xff000000), Color(0xffb1cfb7)), // Rio Ave
  'football:riverplate': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // River Plate
  'football:rodezaveyron': TeamPalette(Color(0xffa5042b), Color(0xffffffff), Color(0xffd17e92)), // Rodez Aveyron
  'football:rosariocentral': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff792dcd)), // Rosario Central
  'football:rosenborg': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff000000)), // Rosenborg
  'football:royalcharleroisc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffe2a9b)), // Royal Charleroi SC
  'football:rubionu': TeamPalette(Color(0xff32cd32), Color(0xff000000), Color(0xff000000)), // Rubio Ñú
  'football:sabahfk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sabah FK
  'football:saintetienne': TeamPalette(Color(0xff51cc5f), Color(0xff000000), Color(0xffffffff)), // Saint-Étienne
  'football:sampdoria': TeamPalette(Color(0xff2234a4), Color(0xffffffff), Color(0xffffffff)), // Sampdoria
  'football:samsunspor': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Samsunspor
  'football:sandefjord': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Sandefjord
  'football:sandiegofc': TeamPalette(Color(0xff697a7c), Color(0xff000000), Color(0xfff89e1a)), // San Diego FC
  'football:sanfreccehiroshima': TeamPalette(Color(0xff69519f), Color(0xffffffff), Color(0xfff9bed4)), // Sanfrecce Hiroshima
  'football:sanjoseearthquakes': TeamPalette(Color(0xff003da6), Color(0xffffffff), Color(0xffffffff)), // San Jose Earthquakes
  'football:sanlorenzo': TeamPalette(Color(0xff0060f0), Color(0xffffffff), Color(0xff8fb9f8)), // San Lorenzo
  'football:santaclara': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffddbf64)), // Santa Clara
  'football:santos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Santos
  'football:saobernardo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // São Bernardo
  'football:saopaulo': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // São Paulo
  'football:sarmientojunin': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff000000)), // Sarmiento (Junín)
  'football:sarpsborgfk': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Sarpsborg FK
  'football:sassuolo': TeamPalette(Color(0xff0fa653), Color(0xff000000), Color(0xff000000)), // Sassuolo
  'football:saudiarabia': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff125b34)), // Saudi Arabia
  'football:sccambuur': TeamPalette(Color(0xfffcee33), Color(0xff000000), Color(0xff98994e)), // SC Cambuur
  'football:sceastbengal': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // SC East Bengal
  'football:scfreiburg': TeamPalette(Color(0xffda0308), Color(0xffffffff), Color(0xffffffff)), // SC Freiburg
  'football:schalke04': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xffffffff)), // Schalke 04
  'football:scotland': TeamPalette(Color(0xff1a2d69), Color(0xffffffff), Color(0xffde4e44)), // Scotland
  'football:scpaderborn07': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xffffffff)), // SC Paderborn 07
  'football:scrheindorfaltach': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // SC Rheindorf Altach
  'football:seattlesoundersfc': TeamPalette(Color(0xff2dc84d), Color(0xff000000), Color(0xff0033a0)), // Seattle Sounders FC
  'football:sekhukhuneunitedfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sekhukhune United FC
  'football:senegal': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff006436)), // Senegal
  'football:servette': TeamPalette(Color(0xffb8273b), Color(0xffffffff), Color(0xfff7e8a6)), // Servette
  'football:sevilla': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffd81022)), // Sevilla
  'football:shakhtardonetsk': TeamPalette(Color(0xffff5900), Color(0xff000000), Color(0xff1a1a1a)), // Shakhtar Donetsk
  'football:shamrockrovers': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff000000)), // Shamrock Rovers
  'football:shandongtaishan': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Shandong Taishan
  'football:shanghaiport': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xfffcfcfc)), // Shanghai Port
  'football:shanghaishenhua': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Shanghai Shenhua
  'football:sheffieldunited': TeamPalette(Color(0xfff42727), Color(0xff000000), Color(0xff1d428a)), // Sheffield United
  'football:shelbourne': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Shelbourne
  'football:shenzhenxinpengcheng': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Shenzhen Xinpengcheng
  'football:shimizuspulse': TeamPalette(Color(0xffed561d), Color(0xff000000), Color(0xffeebe21)), // Shimizu S-Pulse
  'football:sigmaolomouc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Sigma Olomouc
  'football:silkeborgif': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Silkeborg IF
  'football:sinttruidense': TeamPalette(Color(0xfff8ea2c), Color(0xff000000), Color(0xff000000)), // Sint-Truidense
  'football:siwelele': TeamPalette(Color(0xff057932), Color(0xffffffff), Color(0xffffffff)), // Siwelele
  'football:skbrann': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xff32cd32)), // SK Brann
  'football:sksturmgraz': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff000000)), // SK Sturm Graz
  'football:slaviaprague': TeamPalette(Color(0xffdc1f26), Color(0xffffffff), Color(0xff81c0ff)), // Slavia Prague
  'football:slovanbratislava': TeamPalette(Color(0xff81c0ff), Color(0xff000000), Color(0xff1a1a1a)), // Slovan Bratislava
  'football:sochaux': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff000040)), // Sochaux
  'football:sonderjyskefodbold': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Sønderjyske Fodbold
  'football:southafrica': TeamPalette(Color(0xffffb81c), Color(0xff000000), Color(0xff0c562e)), // South Africa
  'football:southampton': TeamPalette(Color(0xffed1a3b), Color(0xff000000), Color(0xfff1ee13)), // Southampton
  'football:southkorea': TeamPalette(Color(0xffce2028), Color(0xffffffff), Color(0xff9e82c8)), // South Korea
  'football:spain': TeamPalette(Color(0xffc60b1e), Color(0xffffffff), Color(0xffffffff)), // Spain
  'football:spartaprague': TeamPalette(Color(0xff791b29), Color(0xffffffff), Color(0xffffffff)), // Sparta Prague
  'football:spartarotterdam': TeamPalette(Color(0xfff31522), Color(0xff000000), Color(0xff84aee7)), // Sparta Rotterdam
  'football:spezia': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1a1a1a)), // Spezia
  'football:sport': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Sport
  'football:sportboys': TeamPalette(Color(0xffffadcc), Color(0xff000000), Color(0xff000000)), // Sport Boys
  'football:sporthuancayo': TeamPalette(Color(0xfffd0032), Color(0xff000000), Color(0xffffc2ce)), // Sport Huancayo
  'football:sportingclubdelhi': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sporting Club Delhi
  'football:sportingcp': TeamPalette(Color(0xff008127), Color(0xffffffff), Color(0xffffffff)), // Sporting CP
  'football:sportingcristal': TeamPalette(Color(0xff3bb8e2), Color(0xff000000), Color(0xff000000)), // Sporting Cristal
  'football:sportinggijon': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xff1a1a1a)), // Sporting Gijón
  'football:sportingkansascity': TeamPalette(Color(0xffa7c6ed), Color(0xff000000), Color(0xff0a2240)), // Sporting Kansas City
  'football:sportingsanmiguelito': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sporting San Miguelito
  'football:sportivoameliano': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sportivo Ameliano
  'football:sportivoluqueno': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Sportivo Luqueño
  'football:sportivosanlorenzo': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sportivo San Lorenzo
  'football:sportivotrinidense': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Sportivo Trinidense
  'football:spvgggreutherfurth': TeamPalette(Color(0xff288a00), Color(0xff000000), Color(0xff1a1a1a)), // SpVgg Greuther Fürth
  'football:stadedereims': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xff0000bf)), // Stade de Reims
  'football:stadelaval': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xff5f5f5f)), // Stade Laval
  'football:staderennais': TeamPalette(Color(0xffef2f24), Color(0xff000000), Color(0xffffffff)), // Stade Rennais
  'football:standardliege': TeamPalette(Color(0xffcc272e), Color(0xffffffff), Color(0xffcccccc)), // Standard Liege
  'football:stellenbosch': TeamPalette(Color(0xffa11b1b), Color(0xffffffff), Color(0xfffee515)), // Stellenbosch
  'football:stgallen': TeamPalette(Color(0xff007c27), Color(0xffffffff), Color(0xfffcd116)), // St. Gallen
  'football:stjohnstone': TeamPalette(Color(0xff0046ff), Color(0xffffffff), Color(0xff83a5ff)), // St Johnstone
  'football:stlouiscitysc': TeamPalette(Color(0xffec1458), Color(0xff000000), Color(0xff001544)), // St. Louis CITY SC
  'football:stmirren': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff10d5f8)), // St Mirren
  'football:stokecity': TeamPalette(Color(0xfff42727), Color(0xff000000), Color(0xff1a1a1a)), // Stoke City
  'football:stpauli': TeamPalette(Color(0xff442e23), Color(0xffffffff), Color(0xffffffff)), // St. Pauli
  'football:strasbourg': TeamPalette(Color(0xff0000bf), Color(0xffffffff), Color(0xffffffff)), // Strasbourg
  'football:sudtirol': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Sudtirol
  'football:sunderland': TeamPalette(Color(0xffeb172b), Color(0xff000000), Color(0xff87cced)), // Sunderland
  'football:svdarmstadt98': TeamPalette(Color(0xff003399), Color(0xffffffff), Color(0xfffafafc)), // SV Darmstadt 98
  'football:svelversberg': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // SV Elversberg
  'football:svjoskoried': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // SV Josko Ried
  'football:swanseacity': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff1d428a)), // Swansea City
  'football:sweden': TeamPalette(Color(0xfffecb00), Color(0xff000000), Color(0xff006aa7)), // Sweden
  'football:switzerland': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xffbcecac)), // Switzerland
  'football:sydneyfc': TeamPalette(Color(0xff87cefa), Color(0xff000000), Color(0xfffafafc)), // Sydney FC
  'football:tallerescordoba': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Talleres (Córdoba)
  'football:tecnicouniversitario': TeamPalette(Color(0xff212121), Color(0xffffffff), Color(0xff646464)), // Técnico Universitario
  'football:telstar': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xfffcee33)), // Telstar
  'football:tenerife': TeamPalette(Color(0xff008bc4), Color(0xff000000), Color(0xff1a1a1a)), // Tenerife
  'football:thenewsaints': TeamPalette(Color(0xff239b56), Color(0xff000000), Color(0xffc60000)), // The New Saints
  'football:tianjinjinmentiger': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Tianjin Jinmen Tiger
  'football:tigre': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffe79494)), // Tigre
  'football:tigresuanl': TeamPalette(Color(0xffffd011), Color(0xff000000), Color(0xff0000ff)), // Tigres UANL
  'football:tijuana': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xffe1e1e1)), // Tijuana
  'football:tokyoverdy1969': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Tokyo Verdy 1969
  'football:toluca': TeamPalette(Color(0xffef0107), Color(0xff000000), Color(0xffffffff)), // Toluca
  'football:torino': TeamPalette(Color(0xff9f0000), Color(0xffffffff), Color(0xffffffff)), // Torino
  'football:torontofc': TeamPalette(Color(0xffaa182c), Color(0xffffffff), Color(0xffa2a9ad)), // Toronto FC
  'football:tottenhamhotspur': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff000000)), // Tottenham Hotspur
  'football:toulouse': TeamPalette(Color(0xff560080), Color(0xffffffff), Color(0xffffff00)), // Toulouse
  'football:trabzonspor': TeamPalette(Color(0xff5699eb), Color(0xff000000), Color(0xff8e003b)), // Trabzonspor
  'football:trefiori': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Tre Fiori
  'football:tromso': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Tromso
  'football:troyes': TeamPalette(Color(0xff0000bf), Color(0xffffffff), Color(0xfffafafc)), // Troyes
  'football:tsgalaxyfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // TS Galaxy FC
  'football:tsghoffenheim': TeamPalette(Color(0xff003399), Color(0xffffffff), Color(0xff000055)), // TSG Hoffenheim
  'football:tsveintrachtbraunschweig': TeamPalette(Color(0xffffde16), Color(0xff000000), Color(0xff1a1a1a)), // TSV Eintracht Braunschweig
  'football:tsvhartberg': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // TSV Hartberg
  'football:tunisia': TeamPalette(Color(0xffd20300), Color(0xffffffff), Color(0xffffffff)), // Tunisia
  'football:turkiye': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffef3340)), // Türkiye
  'football:ucvfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // UCV FC
  'football:udinese': TeamPalette(Color(0xff19161d), Color(0xffffffff), Color(0xffffef32)), // Udinese
  'football:unionlacalera': TeamPalette(Color(0xfffd0000), Color(0xff000000), Color(0xff000000)), // Unión La Calera
  'football:unionsantafe': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xff000000)), // Unión (Santa Fe)
  'football:unionstgilloise': TeamPalette(Color(0xfffcee33), Color(0xff000000), Color(0xff988f1f)), // Union St.-Gilloise
  'football:unireaslobozia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Unirea Slobozia
  'football:unitedstates': TeamPalette(Color(0xff213065), Color(0xffffffff), Color(0xffd42339)), // United States
  'football:universidadcatolica': TeamPalette(Color(0xff0a4f8d), Color(0xffffffff), Color(0xff000000)), // Universidad Católica
  'football:universidadcatolicaquito': TeamPalette(Color(0xff0a4f8d), Color(0xffffffff), Color(0xff000000)), // Universidad Católica (Quito)
  'football:universidaddechile': TeamPalette(Color(0xff0232cc), Color(0xffffffff), Color(0xff000000)), // Universidad de Chile
  'football:universidaddeconcepcion': TeamPalette(Color(0xff0c4da2), Color(0xffffffff), Color(0xfffbe805)), // Universidad de Concepción
  'football:universitario': TeamPalette(Color(0xffffffbf), Color(0xff000000), Color(0xff000000)), // Universitario
  'football:universitateacluj': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Universitatea Cluj
  'football:urawareddiamonds': TeamPalette(Color(0xffe5370b), Color(0xff000000), Color(0xff000000)), // Urawa Red Diamonds
  'football:uruguay': TeamPalette(Color(0xff55b5e5), Color(0xff000000), Color(0xff000080)), // Uruguay
  'football:usavellino': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xff5f5f5f)), // US Avellino
  'football:utaarad': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // UTA Arad
  'football:utc': TeamPalette(Color(0xff8d0019), Color(0xffffffff), Color(0xffbe6e7c)), // UTC
  'football:uzbekistan': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff0072ce)), // Uzbekistan
  'football:valencia': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff004996)), // Valencia
  'football:valerenga': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Vålerenga
  'football:vancouverwhitecaps': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff12284c)), // Vancouver Whitecaps
  'football:vardar': TeamPalette(Color(0xffda070e), Color(0xffffffff), Color(0xff000000)), // Vardar
  'football:vascodagama': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xfffafafc)), // Vasco da Gama
  'football:vasterassk': TeamPalette(Color(0xff007948), Color(0xffffffff), Color(0xffffffff)), // Västerås SK
  'football:vegareal': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Vega Real
  'football:velezsarsfield': TeamPalette(Color(0xff0070b0), Color(0xffffffff), Color(0xff89bdda)), // Vélez Sarsfield
  'football:venezia': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffffffff)), // Venezia
  'football:verdesfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Verdes FC
  'football:vfbstuttgart': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xffda0308)), // VfB Stuttgart
  'football:vflbochum': TeamPalette(Color(0xff000055), Color(0xffffffff), Color(0xffaac4f2)), // VfL Bochum
  'football:vflosnabruck': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // VfL Osnabruck
  'football:vflwolfsburg': TeamPalette(Color(0xff81f733), Color(0xff000000), Color(0xff1a1a1a)), // VfL Wolfsburg
  'football:viborgff': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Viborg FF
  'football:vikingfk': TeamPalette(Color(0xff000080), Color(0xffffffff), Color(0xffffffff)), // Viking FK
  'football:vikingurreykjavik': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffffffff)), // Vikingur Reykjavik
  'football:viktoriaplzen': TeamPalette(Color(0xff0000dd), Color(0xffffffff), Color(0xff000000)), // Viktoria Plzen
  'football:vilanova': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xfffafafc)), // Vila Nova
  'football:villarreal': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff6cace4)), // Villarreal
  'football:virtusentella': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Virtus Entella
  'football:visselkobe': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Vissel Kobe
  'football:vitoria': TeamPalette(Color(0xffc6101c), Color(0xffffffff), Color(0xffe6969b)), // Vitória
  'football:vitoriadeguimaraes': TeamPalette(Color(0xffffffff), Color(0xff000000), Color(0xff000000)), // Vitória de Guimaraes
  'football:volosnfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Volos NFC
  'football:vvarennagasaki': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // V-Varen Nagasaki
  'football:waaslandbeveren': TeamPalette(Color(0xfff2ff00), Color(0xff000000), Color(0xff929900)), // Waasland-Beveren
  'football:waterhouse': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Waterhouse
  'football:watford': TeamPalette(Color(0xffffff00), Color(0xff000000), Color(0xff1d428a)), // Watford
  'football:wellingtonphoenixfc': TeamPalette(Color(0xfff5fe05), Color(0xff000000), Color(0xff000000)), // Wellington Phoenix FC
  'football:werderbremen': TeamPalette(Color(0xff03915c), Color(0xff000000), Color(0xffffffff)), // Werder Bremen
  'football:westbromwichalbion': TeamPalette(Color(0xff091453), Color(0xffffffff), Color(0xffffff00)), // West Bromwich Albion
  'football:westernsydneywanderers': TeamPalette(Color(0xffc60000), Color(0xffffffff), Color(0xffc9b177)), // Western Sydney Wanderers
  'football:westhamunited': TeamPalette(Color(0xff7c2c3b), Color(0xffffffff), Color(0xfff1e7e0)), // West Ham United
  'football:willemii': TeamPalette(Color(0xff1a316b), Color(0xffffffff), Color(0xff96c0df)), // Willem II
  'football:winterthur': TeamPalette(Color(0xffc23833), Color(0xffffffff), Color(0xffffffff)), // Winterthur
  'football:wolfsberger': TeamPalette(Color(0xff1a1a1a), Color(0xffffffff), Color(0xffffffff)), // Wolfsberger
  'football:wolverhamptonwanderers': TeamPalette(Color(0xfffdb913), Color(0xff000000), Color(0xff986f0b)), // Wolverhampton Wanderers
  'football:wrexham': TeamPalette(Color(0xffc8142f), Color(0xffffffff), Color(0xffffffff)), // Wrexham
  'football:wsgswarovskitirol': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // WSG Swarovski Tirol
  'football:wuhanthreetowns': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Wuhan Three Towns
  'football:yokohamafmarinos': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Yokohama F. Marinos
  'football:youngboys': TeamPalette(Color(0xffffdd00), Color(0xff000000), Color(0xff998500)), // Young Boys
  'football:yunnanyukun': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Yunnan Yukun
  'football:zhejiangprofessionalfc': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xffc60000)), // Zhejiang Professional FC
  'football:zrinjskimostar': TeamPalette(Color(0xff000000), Color(0xffffffff), Color(0xff565656)), // Zrinjski Mostar
  'football:zultewaregem': TeamPalette(Color(0xffff0000), Color(0xff000000), Color(0xff000000)), // Zulte-Waregem
};

const Map<String, String> _translit = <String, String>{
  'æ': 'ae',
  'Æ': 'ae',
  'ø': 'o',
  'Ø': 'o',
  'ß': 'ss',
  'đ': 'd',
  'ð': 'd',
  'þ': 'th',
};

/// Normalises a display name into the key form used by [kTeamPalettes]:
/// transliterated, accent-stripped, lowercased, alphanumerics only.
String normaliseTeamName(String name) {
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    final ch = String.fromCharCode(rune);
    final mapped = _translit[ch] ?? _deaccent(ch);
    for (final c in mapped.toLowerCase().codeUnits) {
      final isDigit = c >= 0x30 && c <= 0x39;
      final isLetter = c >= 0x61 && c <= 0x7a;
      if (isDigit || isLetter) buffer.writeCharCode(c);
    }
  }
  return buffer.toString();
}

String _deaccent(String ch) {
  const from = 'áãäåàâçèéêëíïñóôöúüÁÇÉÑÖ';
  const to = 'aaaaaaceeeeiinooouuACENO';
  final i = from.indexOf(ch);
  return i == -1 ? ch : to[i];
}

/// The palette for [team]. Falls back through: an override, the generated
/// database for [sport], the same name under any other sport, and finally a
/// palette derived from the team's own colour — so this never fails, and a
/// team the ESPN sweep never saw still renders correctly.
TeamPalette paletteForTeam(SportTeam team, {Sport? sport}) {
  final name = normaliseTeamName(team.name);
  if (sport != null) {
    final key = '${sport.name}:$name';
    final hit = kTeamPaletteOverrides[key] ?? kTeamPalettes[key];
    if (hit != null) return hit;
  }
  for (final s in Sport.values) {
    final key = '${s.name}:$name';
    final hit = kTeamPaletteOverrides[key] ?? kTeamPalettes[key];
    if (hit != null) return hit;
  }
  return derivePalette(team.color);
}

/// Builds a palette from a bare colour, matching the rules the generator
/// uses: black/white text by contrast, and an accent pushed away in
/// luminance until it separates from the fill.
TeamPalette derivePalette(Color primary) {
  final text = _contrast(primary, Colors.white) >= _contrast(primary, Colors.black)
      ? Colors.white
      : Colors.black;
  final lighten = primary.computeLuminance() < 0.35;
  var accent = primary;
  for (var i = 0; i < 80; i++) {
    if (_contrast(accent, primary) >= 2.6) break;
    accent = lighten
        ? Color.lerp(accent, Colors.white, 0.05)!
        : Color.lerp(accent, Colors.black, 0.07)!;
  }
  return TeamPalette(primary, text, accent);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

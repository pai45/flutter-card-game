import 'package:flutter/material.dart';

import '../config/enums.dart';

class PlayerCard {
  const PlayerCard({required this.id, required this.name, required this.shortName, required this.country, required this.countryCode, required this.position, required this.role, required this.rating, required this.trait, required this.tier, required this.icon, this.portraitAsset});

  final String id;
  final String name;
  final String shortName;
  final String country;
  final String countryCode;
  final String position;
  final PlayerRole role;
  final int rating;
  final String trait;
  final CardTier tier;
  final IconData icon;
  final String? portraitAsset;

  String? get resolvedPortraitAsset => portraitAsset ?? playerPortraitAssets[shortName];

  bool get hasPortrait => resolvedPortraitAsset != null;

  bool get isGoalkeeper => role == PlayerRole.goalkeeper;
}

const Map<String, String> playerPortraitAssets = {
  'A. ROBINSON': 'assets/player_images/A. ROBINSON.webp',
  'ADAMS': 'assets/player_images/ADAMS.webp',
  'ALEXIS': 'assets/player_images/ALEXIS.webp',
  'ALISSON': 'assets/player_images/ALISSON.webp',
  'ALVAREZ': 'assets/player_images/ALVAREZ.webp',
  'ARAUJO': 'assets/player_images/ARAUJO.webp',
  'ARIAS': 'assets/player_images/ARIAS.webp',
  'ARRASCAETA': 'assets/player_images/ARRASCAETA.webp',
  'B. FERNANDES': 'assets/player_images/B. FERNANDES.webp',
  'B. SILVA': 'assets/player_images/B. SILVA.webp',
  'BALOGUN': 'assets/player_images/BALOGUN.webp',
  'BAUMANN': 'assets/player_images/BAUMANN.webp',
  'BEHICH': 'assets/player_images/BEHICH.webp',
  'BELLINGHAM': 'assets/player_images/BELLINGHAM.webp',
  'BENTANCUR': 'assets/player_images/BENTANCUR.webp',
  'BOMBITO': 'assets/player_images/BOMBITO.webp',
  'BOYLE': 'assets/player_images/BOYLE.webp',
  'BROZOVIC': 'assets/player_images/BROZOVIC.webp',
  'BRUNO G.': 'assets/player_images/BRUNO G..webp',
  'BUCHANAN': 'assets/player_images/BUCHANAN.webp',
  'BUDIMIR': 'assets/player_images/BUDIMIR.webp',
  'CALHANOGLU': 'assets/player_images/CALHANOGLU.webp',
  'CAMAVINGA': 'assets/player_images/CAMAVINGA.webp',
  'CANCELO': 'assets/player_images/CANCELO.webp',
  'CARVAJAL': 'assets/player_images/CARVAJAL.webp',
  'CASEMIRO': 'assets/player_images/CASEMIRO.webp',
  'CASTAGNE': 'assets/player_images/CASTAGNE.webp',
  'CHAVEZ': 'assets/player_images/CHAVEZ.webp',
  'CIRCATI': 'assets/player_images/CIRCATI.webp',
  'CORNELIUS': 'assets/player_images/CORNELIUS.webp',
  'COURTOIS': 'assets/player_images/COURTOIS.webp',
  'CUBARSI': 'assets/player_images/CUBARSI.webp',
  'CUNHA': 'assets/player_images/CUNHA.webp',
  'D. COSTA': 'assets/player_images/D. COSTA.webp',
  'D. GOMEZ': 'assets/player_images/D. GOMEZ.webp',
  'D. MUNOZ': 'assets/player_images/D. MUNOZ.webp',
  'DAVIES': 'assets/player_images/DAVIES.webp',
  'DAVINSON': 'assets/player_images/DAVINSON.webp',
  'DE BRUYNE': 'assets/player_images/DE BRUYNE.webp',
  'DE PAUL': 'assets/player_images/DE PAUL.webp',
  'DEMBELE': 'assets/player_images/DEMBELE.webp',
  'DEPAY': 'assets/player_images/DEPAY.webp',
  'DIAS': 'assets/player_images/DIAS.webp',
  'DIOMANDE': 'assets/player_images/DIOMANDE.webp',
  'DOAK': 'assets/player_images/DOAK.webp',
  'DOAN': 'assets/player_images/DOAN.webp',
  'DOKU': 'assets/player_images/DOKU.webp',
  'DUKE': 'assets/player_images/DUKE.webp',
  'DUMFRIES': 'assets/player_images/DUMFRIES.webp',
  'DURAN': 'assets/player_images/DURAN.webp',
  'EDERSON': 'assets/player_images/EDERSON.webp',
  'EDSON': 'assets/player_images/EDSON.webp',
  'ELANGA': 'assets/player_images/ELANGA.webp',
  'ELIA': 'assets/player_images/ELIA.webp',
  'EMI': 'assets/player_images/EMI.webp',
  'ENDO': 'assets/player_images/ENDO.webp',
  'ENCISO': 'assets/player_images/ENCISO.webp',
  'EN-NESYRI': 'assets/player_images/EN-NESYRI.webp',
  'ENZO': 'assets/player_images/ENZO.webp',
  'EUSTAQUIO': 'assets/player_images/EUSTAQUIO.webp',
  'F. DE JONG': 'assets/player_images/F. DE JONG.webp',
  'FODEN': 'assets/player_images/FODEN.webp',
  'GABRIEL': 'assets/player_images/GABRIEL.webp',
  'GAKPO': 'assets/player_images/GAKPO.webp',
  'GALLARDO': 'assets/player_images/GALLARDO.webp',
  'G. GOMEZ': 'assets/player_images/G. GOMEZ.webp',
  'GILMOUR': 'assets/player_images/GILMOUR.webp',
  'GIMENEZ': 'assets/player_images/GIMENEZ.webp',
  'GORETZKA': 'assets/player_images/GORETZKA.webp',
  'GRAVENBERCH': 'assets/player_images/GRAVENBERCH.webp',
  'GRIEZMANN': 'assets/player_images/GRIEZMANN.webp',
  'GULER': 'assets/player_images/GULER.webp',
  'GVARDIOL': 'assets/player_images/GVARDIOL.webp',
  'GYOKERES': 'assets/player_images/GYOKERES.webp',
  'HAALAND': 'assets/player_images/HAALAND.webp',
  'HAKIMI': 'assets/player_images/HAKIMI.webp',
  'HALLER': 'assets/player_images/HALLER.webp',
  'HAVERTZ': 'assets/player_images/HAVERTZ.webp',
  'HUIJSEN': 'assets/player_images/HUIJSEN.webp',
  'HWANG': 'assets/player_images/HWANG.webp',
  'IN-BEOM': 'assets/player_images/IN-BEOM.webp',
  'IRANKUNDA': 'assets/player_images/IRANKUNDA.webp',
  'IRVINE': 'assets/player_images/IRVINE.webp',
  'ISAK': 'assets/player_images/ISAK.webp',
  'ITAKURA': 'assets/player_images/ITAKURA.webp',
  'J. DAVID': 'assets/player_images/J. DAVID.webp',
  'J. NEVES': 'assets/player_images/J. NEVES.webp',
  'J. SANCHEZ': 'assets/player_images/J. SANCHEZ.webp',
  'JAE-SUNG': 'assets/player_images/JAE-SUNG.webp',
  'JAMES': 'assets/player_images/JAMES.webp',
  'JOHNSTON': 'assets/player_images/JOHNSTON.webp',
  'KADIOGLU': 'assets/player_images/KADIOGLU.webp',
  'KAMADA': 'assets/player_images/KAMADA.webp',
  'KANE': 'assets/player_images/KANE.webp',
  'KANG-IN': 'assets/player_images/KANG-IN.webp',
  'KANTE': 'assets/player_images/KANTE.webp',
  'KESSIE': 'assets/player_images/KESSIE.webp',
  'KIM MJ': 'assets/player_images/KIM MJ.webp',
  'KIM SG': 'assets/player_images/KIM SG.webp',
  'KIMMICH': 'assets/player_images/KIMMICH.webp',
  'KOKCU': 'assets/player_images/KOKCU.webp',
  'KONE': 'assets/player_images/KONE.webp',
  'KOUNDE': 'assets/player_images/KOUNDE.webp',
  'KOULIBALY': 'assets/player_images/KOULIBALY.webp',
  'KOVACIC': 'assets/player_images/KOVACIC.webp',
  'KRAMARIC': 'assets/player_images/KRAMARIC.webp',
  'KUBO': 'assets/player_images/KUBO.webp',
  'KULUSEVSKI': 'assets/player_images/KULUSEVSKI.webp',
  'LARIN': 'assets/player_images/LARIN.webp',
  'LARSSON': 'assets/player_images/LARSSON.webp',
  'LAUTARO': 'assets/player_images/LAUTARO.webp',
  'LEAO': 'assets/player_images/LEAO.webp',
  'LEO 10': 'assets/player_images/LEO 10.webp',
  'LERMA': 'assets/player_images/LERMA.webp',
  'LISANDRO': 'assets/player_images/LISANDRO.webp',
  'LIVAKOVIC': 'assets/player_images/LIVAKOVIC.webp',
  'LOZANO': 'assets/player_images/LOZANO.webp',
  'LUIS DIAZ': 'assets/player_images/LUIS DIAZ.webp',
  'LUKAKU': 'assets/player_images/LUKAKU.webp',
  'M. ARAUJO': 'assets/player_images/M. ARAUJO.webp',
  'MAHREZ': 'assets/player_images/MAHREZ.webp',
  'MAIGNAN': 'assets/player_images/MAIGNAN.webp',
  'MAJER': 'assets/player_images/MAJER.webp',
  'MALAGON': 'assets/player_images/MALAGON.webp',
  'MANE': 'assets/player_images/MANE.webp',
  'MARMOUSH': 'assets/player_images/MARMOUSH.webp',
  'MARQUINHOS': 'assets/player_images/MARQUINHOS.webp',
  'MASUAKU': 'assets/player_images/MASUAKU.webp',
  'MBAPPE': 'assets/player_images/MBAPPE.webp',
  'MBEMBA': 'assets/player_images/MBEMBA.webp',
  'MCGINN': 'assets/player_images/MCGINN.webp',
  'MCGREE': 'assets/player_images/MCGREE.webp',
  'MCKENNIE': 'assets/player_images/MCKENNIE.webp',
  'MCTOMINAY': 'assets/player_images/MCTOMINAY.webp',
  'MILLER': 'assets/player_images/MILLER.webp',
  'MINAMINO': 'assets/player_images/MINAMINO.webp',
  'MITOMA': 'assets/player_images/MITOMA.webp',
  'MODRIC': 'assets/player_images/MODRIC.webp',
  'MOLINA': 'assets/player_images/MOLINA.webp',
  'MONTES': 'assets/player_images/MONTES.webp',
  'MORITA': 'assets/player_images/MORITA.webp',
  'MOSTAFA M': 'assets/player_images/MOSTAFA M.webp',
  'MUSAH': 'assets/player_images/MUSAH.webp',
  'MUSIALA': 'assets/player_images/MUSIALA.webp',
  'N. JACKSON': 'assets/player_images/N. JACKSON.webp',
  'N. MENDES': 'assets/player_images/N. MENDES.webp',
  'NDIAYE': 'assets/player_images/NDIAYE.webp',
  'NDICKA': 'assets/player_images/NDICKA.webp',
  'NEYMAR': 'assets/player_images/NEYMAR.webp',
  'NICO': 'assets/player_images/NICO.webp',
  'NUNEZ': 'assets/player_images/NUNEZ.webp',
  'NUSA': 'assets/player_images/NUSA.webp',
  'ODEGAARD': 'assets/player_images/ODEGAARD.webp',
  'OH': 'assets/player_images/OH.webp',
  'OLISE': 'assets/player_images/OLISE.webp',
  'ONANA': 'assets/player_images/ONANA.webp',
  'OYARZABAL': 'assets/player_images/OYARZABAL.webp',
  'PAIK': 'assets/player_images/PAIK.webp',
  'PALMER': 'assets/player_images/PALMER.webp',
  'PEDRI': 'assets/player_images/PEDRI.webp',
  'PELLISTRI': 'assets/player_images/PELLISTRI.webp',
  'PERISIC': 'assets/player_images/PERISIC.webp',
  'PICKFORD': 'assets/player_images/PICKFORD.webp',
  'PULISIC': 'assets/player_images/PULISIC.webp',
  'R. JAMES': 'assets/player_images/R. JAMES.webp',
  'RAPHINHA': 'assets/player_images/RAPHINHA.webp',
  'RASHFORD': 'assets/player_images/RASHFORD.webp',
  'RAUL': 'assets/player_images/RAUL.webp',
  'RAUM': 'assets/player_images/RAUM.webp',
  'REIJNDERS': 'assets/player_images/REIJNDERS.webp',
  'REYNA': 'assets/player_images/REYNA.webp',
  'RICE': 'assets/player_images/RICE.webp',
  'RICHARDS': 'assets/player_images/RICHARDS.webp',
  'RIOS': 'assets/player_images/RIOS.webp',
  'ROBERTSON': 'assets/player_images/ROBERTSON.webp',
  'ROCHET': 'assets/player_images/ROCHET.webp',
  'RODRI': 'assets/player_images/RODRI.webp',
  'ROMERO': 'assets/player_images/ROMERO.webp',
  'RONALDO': 'assets/player_images/RONALDO.webp',
  'RUDIGER': 'assets/player_images/RUDIGER.webp',
  'RYAN': 'assets/player_images/RYAN.webp',
  'SAKA': 'assets/player_images/SAKA.webp',
  'SALAH': 'assets/player_images/SALAH.webp',
  'SALIBA': 'assets/player_images/SALIBA.webp',
  'SANE': 'assets/player_images/SANE.webp',
  'SANTI': 'assets/player_images/SANTI.webp',
  'SARR': 'assets/player_images/SARR.webp',
  'SEOL': 'assets/player_images/SEOL.webp',
  'SIMON': 'assets/player_images/SIMON.webp',
  'SIMONS': 'assets/player_images/SIMONS.webp',
  'SINISTERRA': 'assets/player_images/SINISTERRA.webp',
  'SON': 'assets/player_images/SON.webp',
  'SORLOTH': 'assets/player_images/SORLOTH.webp',
  'SOSA': 'assets/player_images/SOSA.webp',
  'SOUTTAR': 'assets/player_images/SOUTTAR.webp',
  'ST. CLAIR': 'assets/player_images/ST. CLAIR.webp',
  'STANISIC': 'assets/player_images/STANISIC.webp',
  'STONES': 'assets/player_images/STONES.webp',
  'TAH': 'assets/player_images/TAH.webp',
  'TCHOUAMENI': 'assets/player_images/TCHOUAMENI.webp',
  'THEO': 'assets/player_images/THEO.webp',
  'THEATE': 'assets/player_images/THEATE.webp',
  'TIELEMANS': 'assets/player_images/TIELEMANS.webp',
  'TOMIYASU': 'assets/player_images/TOMIYASU.webp',
  'TREZEGUET': 'assets/player_images/TREZEGUET.webp',
  'TROSSARD': 'assets/player_images/TROSSARD.webp',
  'TURNER': 'assets/player_images/TURNER.webp',
  'UGARTE': 'assets/player_images/UGARTE.webp',
  'UPAMECANO': 'assets/player_images/UPAMECANO.webp',
  'VALVERDE': 'assets/player_images/VALVERDE.webp',
  'VAN DE VEN': 'assets/player_images/VAN DE VEN.webp',
  'VAN DIJK': 'assets/player_images/VAN DIJK.webp',
  'VARGAS': 'assets/player_images/VARGAS.webp',
  'VASQUEZ': 'assets/player_images/VASQUEZ.webp',
  'VERBRUGGEN': 'assets/player_images/VERBRUGGEN.webp',
  'VITINHA': 'assets/player_images/VITINHA.webp',
  'VINICIUS JR': 'assets/player_images/VINICIUS JR.webp',
  'WEAH': 'assets/player_images/WEAH.webp',
  'WIRTZ': 'assets/player_images/WIRTZ.webp',
  'WISSA': 'assets/player_images/WISSA.webp',
  'WITSEL': 'assets/player_images/WITSEL.webp',
  'YAMAL': 'assets/player_images/YAMAL.webp',
  'YILDIZ': 'assets/player_images/YILDIZ.webp',
  'ZION': 'assets/player_images/ZION.webp',
  'ZUBIMENDI': 'assets/player_images/ZUBIMENDI.webp',
};

class ActionCard {
  const ActionCard({required this.id, required this.title, required this.category, required this.tier, required this.effect, required this.power, required this.risky, required this.icon});

  final String id;
  final String title;
  final ActionCategory category;
  final CardTier tier;
  final String effect;
  final int power;
  final bool risky;
  final IconData icon;
}

class ScenarioCard {
  const ScenarioCard({required this.id, required this.title, required this.description, required this.attackBonus, required this.defenseBonus, required this.icon});

  final String id;
  final String title;
  final String description;
  final int attackBonus;
  final int defenseBonus;
  final IconData icon;
}

const attackers = [
  // === ARGENTINA ===
  PlayerCard(id: 'arg-lionel-messi', name: 'Lionel Messi', shortName: 'LEO 10', country: 'Argentina', countryCode: 'ARG', position: 'RW/CAM', role: PlayerRole.attacker, rating: 92, trait: 'Creator Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'arg-lautaro-martinez', name: 'Lautaro Martínez', shortName: 'LAUTARO', country: 'Argentina', countryCode: 'ARG', position: 'ST', role: PlayerRole.attacker, rating: 88, trait: 'Box Striker', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'arg-julian-alvarez', name: 'Julián Álvarez', shortName: 'ALVAREZ', country: 'Argentina', countryCode: 'ARG', position: 'ST/SS', role: PlayerRole.attacker, rating: 88, trait: 'Pressing Forward', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'arg-rodrigo-de-paul', name: 'Rodrigo De Paul', shortName: 'DE PAUL', country: 'Argentina', countryCode: 'ARG', position: 'CM', role: PlayerRole.attacker, rating: 83, trait: 'Engine Midfielder', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'arg-enzo-fernandez', name: 'Enzo Fernández', shortName: 'ENZO', country: 'Argentina', countryCode: 'ARG', position: 'CM', role: PlayerRole.attacker, rating: 84, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'arg-alexis-mac-allister', name: 'Alexis Mac Allister', shortName: 'ALEXIS', country: 'Argentina', countryCode: 'ARG', position: 'CM', role: PlayerRole.attacker, rating: 85, trait: 'Chance Creator', tier: CardTier.silver, icon: Icons.sync_alt),
  // === BRAZIL ===
  PlayerCard(id: 'bra-vinicius-junior', name: 'Vinícius Júnior', shortName: 'VINICIUS JR', country: 'Brazil', countryCode: 'BRA', position: 'LW', role: PlayerRole.attacker, rating: 93, trait: 'Explosive Winger', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'bra-neymar', name: 'Neymar', shortName: 'NEYMAR', country: 'Brazil', countryCode: 'BRA', position: 'LW/SS', role: PlayerRole.attacker, rating: 90, trait: 'Flair Forward', tier: CardTier.platinum, icon: Icons.auto_awesome),
  PlayerCard(id: 'bra-raphinha', name: 'Raphinha', shortName: 'RAPHINHA', country: 'Brazil', countryCode: 'BRA', position: 'RW', role: PlayerRole.attacker, rating: 89, trait: 'Direct Runner', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'bra-bruno-guimaraes', name: 'Bruno Guimarães', shortName: 'BRUNO G.', country: 'Brazil', countryCode: 'BRA', position: 'CM', role: PlayerRole.attacker, rating: 87, trait: 'Press Breaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'bra-matheus-cunha', name: 'Matheus Cunha', shortName: 'CUNHA', country: 'Brazil', countryCode: 'BRA', position: 'ST/SS', role: PlayerRole.attacker, rating: 84, trait: 'Link-Up Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  // === FRANCE ===
  PlayerCard(id: 'fra-kylian-mbappe', name: 'Kylian Mbappé', shortName: 'MBAPPE', country: 'France', countryCode: 'FRA', position: 'ST/LW', role: PlayerRole.attacker, rating: 94, trait: 'Clinical Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'fra-ousmane-dembele', name: 'Ousmane Dembélé', shortName: 'DEMBELE', country: 'France', countryCode: 'FRA', position: 'RW', role: PlayerRole.attacker, rating: 89, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'fra-michael-olise', name: 'Michael Olise', shortName: 'OLISE', country: 'France', countryCode: 'FRA', position: 'CAM/RW', role: PlayerRole.attacker, rating: 88, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  // === ENGLAND ===
  PlayerCard(id: 'eng-harry-kane', name: 'Harry Kane', shortName: 'KANE', country: 'England', countryCode: 'ENG', position: 'ST', role: PlayerRole.attacker, rating: 92, trait: 'Clinical Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'eng-jude-bellingham', name: 'Jude Bellingham', shortName: 'BELLINGHAM', country: 'England', countryCode: 'ENG', position: 'CAM/CM', role: PlayerRole.attacker, rating: 92, trait: 'Box-to-Box Star', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'eng-bukayo-saka', name: 'Bukayo Saka', shortName: 'SAKA', country: 'England', countryCode: 'ENG', position: 'RW', role: PlayerRole.attacker, rating: 89, trait: 'Wide Creator', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'eng-phil-foden', name: 'Phil Foden', shortName: 'FODEN', country: 'England', countryCode: 'ENG', position: 'CAM/LW', role: PlayerRole.attacker, rating: 88, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'eng-marcus-rashford', name: 'Marcus Rashford', shortName: 'RASHFORD', country: 'England', countryCode: 'ENG', position: 'LW/ST', role: PlayerRole.attacker, rating: 84, trait: 'Inside Forward', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'eng-cole-palmer', name: 'Cole Palmer', shortName: 'PALMER', country: 'England', countryCode: 'ENG', position: 'CAM/RW', role: PlayerRole.attacker, rating: 85, trait: 'Technical Creator', tier: CardTier.silver, icon: Icons.psychology),
  // === PORTUGAL ===
  PlayerCard(id: 'por-cristiano-ronaldo', name: 'Cristiano Ronaldo', shortName: 'RONALDO', country: 'Portugal', countryCode: 'POR', position: 'ST', role: PlayerRole.attacker, rating: 90, trait: 'Iconic Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'por-rafael-leao', name: 'Rafael Leão', shortName: 'LEAO', country: 'Portugal', countryCode: 'POR', position: 'LW', role: PlayerRole.attacker, rating: 87, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'por-bruno-fernandes', name: 'Bruno Fernandes', shortName: 'B. FERNANDES', country: 'Portugal', countryCode: 'POR', position: 'CAM', role: PlayerRole.attacker, rating: 88, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'por-bernardo-silva', name: 'Bernardo Silva', shortName: 'B. SILVA', country: 'Portugal', countryCode: 'POR', position: 'RW/CAM', role: PlayerRole.attacker, rating: 88, trait: 'Technical Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'por-vitinha', name: 'Vitinha', shortName: 'VITINHA', country: 'Portugal', countryCode: 'POR', position: 'CM', role: PlayerRole.attacker, rating: 84, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  // === SPAIN ===
  PlayerCard(id: 'esp-lamine-yamal', name: 'Lamine Yamal', shortName: 'YAMAL', country: 'Spain', countryCode: 'ESP', position: 'RW', role: PlayerRole.attacker, rating: 89, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'esp-nico-williams', name: 'Nico Williams', shortName: 'NICO', country: 'Spain', countryCode: 'ESP', position: 'LW', role: PlayerRole.attacker, rating: 87, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'esp-pedri-gonzalez', name: 'Pedri González', shortName: 'PEDRI', country: 'Spain', countryCode: 'ESP', position: 'CM/CAM', role: PlayerRole.attacker, rating: 89, trait: 'Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'esp-mikel-oyarzabal', name: 'Mikel Oyarzabal', shortName: 'OYARZABAL', country: 'Spain', countryCode: 'ESP', position: 'ST/SS', role: PlayerRole.attacker, rating: 83, trait: 'Support Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  // === GERMANY ===
  PlayerCard(id: 'ger-jamal-musiala', name: 'Jamal Musiala', shortName: 'MUSIALA', country: 'Germany', countryCode: 'GER', position: 'CAM/LW', role: PlayerRole.attacker, rating: 88, trait: 'Agile Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'ger-florian-wirtz', name: 'Florian Wirtz', shortName: 'WIRTZ', country: 'Germany', countryCode: 'GER', position: 'CAM', role: PlayerRole.attacker, rating: 89, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'ger-kai-havertz', name: 'Kai Havertz', shortName: 'HAVERTZ', country: 'Germany', countryCode: 'GER', position: 'ST/CAM', role: PlayerRole.attacker, rating: 84, trait: 'Link-Up Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'ger-leroy-sane', name: 'Leroy Sané', shortName: 'SANE', country: 'Germany', countryCode: 'GER', position: 'RW/LW', role: PlayerRole.attacker, rating: 84, trait: 'Explosive Winger', tier: CardTier.silver, icon: Icons.directions_run),
  // === NETHERLANDS ===
  PlayerCard(id: 'ned-frenkie-de-jong', name: 'Frenkie de Jong', shortName: 'F. DE JONG', country: 'Netherlands', countryCode: 'NED', position: 'CM', role: PlayerRole.attacker, rating: 87, trait: 'Tempo Controller', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'ned-cody-gakpo', name: 'Cody Gakpo', shortName: 'GAKPO', country: 'Netherlands', countryCode: 'NED', position: 'LW/ST', role: PlayerRole.attacker, rating: 87, trait: 'Inside Forward', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'ned-xavi-simons', name: 'Xavi Simons', shortName: 'SIMONS', country: 'Netherlands', countryCode: 'NED', position: 'CAM/RW', role: PlayerRole.attacker, rating: 84, trait: 'Flair Playmaker', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'ned-memphis-depay', name: 'Memphis Depay', shortName: 'DEPAY', country: 'Netherlands', countryCode: 'NED', position: 'ST/SS', role: PlayerRole.attacker, rating: 82, trait: 'Creator Finisher', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'ned-ryan-gravenberch', name: 'Ryan Gravenberch', shortName: 'GRAVENBERCH', country: 'Netherlands', countryCode: 'NED', position: 'CM', role: PlayerRole.attacker, rating: 84, trait: 'Press Breaker', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'ned-tijjani-reijnders', name: 'Tijjani Reijnders', shortName: 'REIJNDERS', country: 'Netherlands', countryCode: 'NED', position: 'CM/CAM', role: PlayerRole.attacker, rating: 83, trait: 'Late Runner', tier: CardTier.silver, icon: Icons.sync_alt),
  // === BELGIUM ===
  PlayerCard(id: 'bel-kevin-de-bruyne', name: 'Kevin De Bruyne', shortName: 'DE BRUYNE', country: 'Belgium', countryCode: 'BEL', position: 'CAM/CM', role: PlayerRole.attacker, rating: 91, trait: 'Master Creator', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'bel-romelu-lukaku', name: 'Romelu Lukaku', shortName: 'LUKAKU', country: 'Belgium', countryCode: 'BEL', position: 'ST', role: PlayerRole.attacker, rating: 86, trait: 'Power Striker', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'bel-jeremy-doku', name: 'Jérémy Doku', shortName: 'DOKU', country: 'Belgium', countryCode: 'BEL', position: 'LW/RW', role: PlayerRole.attacker, rating: 83, trait: 'Explosive Winger', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'bel-leandro-trossard', name: 'Leandro Trossard', shortName: 'TROSSARD', country: 'Belgium', countryCode: 'BEL', position: 'LW/SS', role: PlayerRole.attacker, rating: 82, trait: 'Technical Forward', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'bel-youri-tielemans', name: 'Youri Tielemans', shortName: 'TIELEMANS', country: 'Belgium', countryCode: 'BEL', position: 'CM', role: PlayerRole.attacker, rating: 82, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  // === CROATIA ===
  PlayerCard(id: 'cro-luka-modric', name: 'Luka Modrić', shortName: 'MODRIC', country: 'Croatia', countryCode: 'CRO', position: 'CM', role: PlayerRole.attacker, rating: 90, trait: 'Tempo Maestro', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'cro-mateo-kovacic', name: 'Mateo Kovačić', shortName: 'KOVACIC', country: 'Croatia', countryCode: 'CRO', position: 'CM', role: PlayerRole.attacker, rating: 83, trait: 'Press Breaker', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'cro-ivan-perisic', name: 'Ivan Perišić', shortName: 'PERISIC', country: 'Croatia', countryCode: 'CRO', position: 'LW/LWB', role: PlayerRole.attacker, rating: 81, trait: 'Big-Game Winger', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'cro-andrej-kramaric', name: 'Andrej Kramarić', shortName: 'KRAMARIC', country: 'Croatia', countryCode: 'CRO', position: 'ST/SS', role: PlayerRole.attacker, rating: 80, trait: 'Support Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'cro-lovro-majer', name: 'Lovro Majer', shortName: 'MAJER', country: 'Croatia', countryCode: 'CRO', position: 'CAM', role: PlayerRole.attacker, rating: 78, trait: 'Creative Playmaker', tier: CardTier.bronze, icon: Icons.psychology),
  PlayerCard(id: 'cro-ante-budimir', name: 'Ante Budimir', shortName: 'BUDIMIR', country: 'Croatia', countryCode: 'CRO', position: 'ST', role: PlayerRole.attacker, rating: 77, trait: 'Box Striker', tier: CardTier.bronze, icon: Icons.sports_soccer),
  // === URUGUAY ===
  PlayerCard(id: 'uru-federico-valverde', name: 'Federico Valverde', shortName: 'VALVERDE', country: 'Uruguay', countryCode: 'URU', position: 'CM/RW', role: PlayerRole.attacker, rating: 91, trait: 'Engine Midfielder', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'uru-darwin-nunez', name: 'Darwin Núñez', shortName: 'NUNEZ', country: 'Uruguay', countryCode: 'URU', position: 'ST', role: PlayerRole.attacker, rating: 86, trait: 'Power Forward', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'uru-rodrigo-bentancur', name: 'Rodrigo Bentancur', shortName: 'BENTANCUR', country: 'Uruguay', countryCode: 'URU', position: 'CM', role: PlayerRole.attacker, rating: 82, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'uru-giorgian-de-arrascaeta', name: 'Giorgian De Arrascaeta', shortName: 'ARRASCAETA', country: 'Uruguay', countryCode: 'URU', position: 'CAM', role: PlayerRole.attacker, rating: 82, trait: 'Final Pass Specialist', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'uru-facundo-pellistri', name: 'Facundo Pellistri', shortName: 'PELLISTRI', country: 'Uruguay', countryCode: 'URU', position: 'RW', role: PlayerRole.attacker, rating: 77, trait: 'Direct Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'uru-maximiliano-araujo', name: 'Maximiliano Araújo', shortName: 'M. ARAUJO', country: 'Uruguay', countryCode: 'URU', position: 'LW/LB', role: PlayerRole.attacker, rating: 76, trait: 'Wide Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  // === COLOMBIA ===
  PlayerCard(id: 'col-luis-diaz', name: 'Luis Díaz', shortName: 'LUIS DIAZ', country: 'Colombia', countryCode: 'COL', position: 'LW', role: PlayerRole.attacker, rating: 88, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'col-james-rodriguez', name: 'James Rodríguez', shortName: 'JAMES', country: 'Colombia', countryCode: 'COL', position: 'CAM', role: PlayerRole.attacker, rating: 86, trait: 'Master Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'col-jhon-arias', name: 'Jhon Arias', shortName: 'ARIAS', country: 'Colombia', countryCode: 'COL', position: 'RW/CAM', role: PlayerRole.attacker, rating: 81, trait: 'Wide Creator', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'col-jhon-duran', name: 'Jhon Durán', shortName: 'DURAN', country: 'Colombia', countryCode: 'COL', position: 'ST', role: PlayerRole.attacker, rating: 82, trait: 'Power Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'col-luis-sinisterra', name: 'Luis Sinisterra', shortName: 'SINISTERRA', country: 'Colombia', countryCode: 'COL', position: 'LW', role: PlayerRole.attacker, rating: 81, trait: 'Inside Forward', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'col-richard-rios', name: 'Richard Ríos', shortName: 'RIOS', country: 'Colombia', countryCode: 'COL', position: 'CM', role: PlayerRole.attacker, rating: 78, trait: 'Press Breaker', tier: CardTier.bronze, icon: Icons.sync_alt),
  // === USA ===
  PlayerCard(id: 'usa-christian-pulisic', name: 'Christian Pulisic', shortName: 'PULISIC', country: 'USA', countryCode: 'USA', position: 'LW/RW', role: PlayerRole.attacker, rating: 87, trait: 'Captain Creator', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'usa-weston-mckennie', name: 'Weston McKennie', shortName: 'MCKENNIE', country: 'USA', countryCode: 'USA', position: 'CM', role: PlayerRole.attacker, rating: 82, trait: 'Box-to-Box', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'usa-folarin-balogun', name: 'Folarin Balogun', shortName: 'BALOGUN', country: 'USA', countryCode: 'USA', position: 'ST', role: PlayerRole.attacker, rating: 82, trait: 'Clinical Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'usa-tim-weah', name: 'Tim Weah', shortName: 'WEAH', country: 'USA', countryCode: 'USA', position: 'RW/RWB', role: PlayerRole.attacker, rating: 77, trait: 'Direct Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'usa-gio-reyna', name: 'Gio Reyna', shortName: 'REYNA', country: 'USA', countryCode: 'USA', position: 'CAM/RW', role: PlayerRole.attacker, rating: 77, trait: 'Flair Playmaker', tier: CardTier.bronze, icon: Icons.psychology),
  PlayerCard(id: 'usa-yunus-musah', name: 'Yunus Musah', shortName: 'MUSAH', country: 'USA', countryCode: 'USA', position: 'CM', role: PlayerRole.attacker, rating: 77, trait: 'Press Breaker', tier: CardTier.bronze, icon: Icons.sync_alt),
  // === MEXICO ===
  PlayerCard(id: 'mex-santiago-gimenez', name: 'Santiago Giménez', shortName: 'SANTI', country: 'Mexico', countryCode: 'MEX', position: 'ST', role: PlayerRole.attacker, rating: 83, trait: 'Clinical Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'mex-raul-jimenez', name: 'Raúl Jiménez', shortName: 'RAUL', country: 'Mexico', countryCode: 'MEX', position: 'ST', role: PlayerRole.attacker, rating: 80, trait: 'Target Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'mex-hirving-lozano', name: 'Hirving Lozano', shortName: 'LOZANO', country: 'Mexico', countryCode: 'MEX', position: 'LW/RW', role: PlayerRole.attacker, rating: 82, trait: 'Explosive Winger', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'mex-luis-chavez', name: 'Luis Chávez', shortName: 'CHAVEZ', country: 'Mexico', countryCode: 'MEX', position: 'CM', role: PlayerRole.attacker, rating: 76, trait: 'Set-Piece Creator', tier: CardTier.bronze, icon: Icons.sync_alt),
  // === CANADA ===
  PlayerCard(id: 'can-jonathan-david', name: 'Jonathan David', shortName: 'J. DAVID', country: 'Canada', countryCode: 'CAN', position: 'ST', role: PlayerRole.attacker, rating: 87, trait: 'Clinical Finisher', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'can-tajon-buchanan', name: 'Tajon Buchanan', shortName: 'BUCHANAN', country: 'Canada', countryCode: 'CAN', position: 'RW/RWB', role: PlayerRole.attacker, rating: 81, trait: 'Direct Runner', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'can-ismael-kone', name: 'Ismaël Koné', shortName: 'KONE', country: 'Canada', countryCode: 'CAN', position: 'CM', role: PlayerRole.attacker, rating: 80, trait: 'Ball Carrier', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'can-cyle-larin', name: 'Cyle Larin', shortName: 'LARIN', country: 'Canada', countryCode: 'CAN', position: 'ST', role: PlayerRole.attacker, rating: 80, trait: 'Box Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  // === JAPAN ===
  PlayerCard(id: 'jpn-kaoru-mitoma', name: 'Kaoru Mitoma', shortName: 'MITOMA', country: 'Japan', countryCode: 'JPN', position: 'LW', role: PlayerRole.attacker, rating: 87, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'jpn-takefusa-kubo', name: 'Takefusa Kubo', shortName: 'KUBO', country: 'Japan', countryCode: 'JPN', position: 'RW/CAM', role: PlayerRole.attacker, rating: 86, trait: 'Technical Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'jpn-takumi-minamino', name: 'Takumi Minamino', shortName: 'MINAMINO', country: 'Japan', countryCode: 'JPN', position: 'CAM/LW', role: PlayerRole.attacker, rating: 81, trait: 'Support Forward', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'jpn-daichi-kamada', name: 'Daichi Kamada', shortName: 'KAMADA', country: 'Japan', countryCode: 'JPN', position: 'CAM', role: PlayerRole.attacker, rating: 82, trait: 'Final Pass Specialist', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'jpn-ritsu-doan', name: 'Ritsu Doan', shortName: 'DOAN', country: 'Japan', countryCode: 'JPN', position: 'RW', role: PlayerRole.attacker, rating: 82, trait: 'Cut-In Winger', tier: CardTier.silver, icon: Icons.directions_run),
  // === SOUTH KOREA ===
  PlayerCard(id: 'kor-son-heung-min', name: 'Son Heung-min', shortName: 'SON', country: 'South Korea', countryCode: 'KOR', position: 'LW/ST', role: PlayerRole.attacker, rating: 90, trait: 'Captain Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'kor-lee-kang-in', name: 'Lee Kang-in', shortName: 'KANG-IN', country: 'South Korea', countryCode: 'KOR', position: 'CAM/RW', role: PlayerRole.attacker, rating: 86, trait: 'Creative Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'kor-hwang-hee-chan', name: 'Hwang Hee-chan', shortName: 'HWANG', country: 'South Korea', countryCode: 'KOR', position: 'ST/LW', role: PlayerRole.attacker, rating: 82, trait: 'Direct Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'kor-hwang-in-beom', name: 'Hwang In-beom', shortName: 'IN-BEOM', country: 'South Korea', countryCode: 'KOR', position: 'CM', role: PlayerRole.attacker, rating: 81, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'kor-oh-hyeon-gyu', name: 'Oh Hyeon-gyu', shortName: 'OH', country: 'South Korea', countryCode: 'KOR', position: 'ST', role: PlayerRole.attacker, rating: 77, trait: 'Box Striker', tier: CardTier.bronze, icon: Icons.sports_soccer),
  PlayerCard(id: 'kor-lee-jae-sung', name: 'Lee Jae-sung', shortName: 'JAE-SUNG', country: 'South Korea', countryCode: 'KOR', position: 'CAM', role: PlayerRole.attacker, rating: 77, trait: 'Link-Up Creator', tier: CardTier.bronze, icon: Icons.psychology),
  // === AUSTRALIA ===
  PlayerCard(id: 'aus-riley-mcgree', name: 'Riley McGree', shortName: 'MCGREE', country: 'Australia', countryCode: 'AUS', position: 'CAM/LW', role: PlayerRole.attacker, rating: 76, trait: 'Chance Creator', tier: CardTier.bronze, icon: Icons.psychology),
  PlayerCard(id: 'aus-nestory-irankunda', name: 'Nestory Irankunda', shortName: 'IRANKUNDA', country: 'Australia', countryCode: 'AUS', position: 'RW', role: PlayerRole.attacker, rating: 76, trait: 'Explosive Prospect', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'aus-martin-boyle', name: 'Martin Boyle', shortName: 'BOYLE', country: 'Australia', countryCode: 'AUS', position: 'RW', role: PlayerRole.attacker, rating: 76, trait: 'Direct Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'aus-mitchell-duke', name: 'Mitchell Duke', shortName: 'DUKE', country: 'Australia', countryCode: 'AUS', position: 'ST', role: PlayerRole.attacker, rating: 75, trait: 'Target Forward', tier: CardTier.bronze, icon: Icons.sports_soccer),
];

const defenders = [
  // === ARGENTINA ===
  PlayerCard(id: 'arg-cristian-romero', name: 'Cristian Romero', shortName: 'ROMERO', country: 'Argentina', countryCode: 'ARG', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aggressive Stopper', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'arg-lisandro-martinez', name: 'Lisandro Martínez', shortName: 'LISANDRO', country: 'Argentina', countryCode: 'ARG', position: 'CB', role: PlayerRole.defender, rating: 85, trait: 'Ball-Winning CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'arg-nahuel-molina', name: 'Nahuel Molina', shortName: 'MOLINA', country: 'Argentina', countryCode: 'ARG', position: 'RB', role: PlayerRole.defender, rating: 79, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === BRAZIL ===
  PlayerCard(id: 'bra-casemiro', name: 'Casemiro', shortName: 'CASEMIRO', country: 'Brazil', countryCode: 'BRA', position: 'CDM', role: PlayerRole.defender, rating: 87, trait: 'Shield Midfielder', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'bra-marquinhos', name: 'Marquinhos', shortName: 'MARQUINHOS', country: 'Brazil', countryCode: 'BRA', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Leader CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'bra-gabriel-magalhaes', name: 'Gabriel Magalhães', shortName: 'GABRIEL', country: 'Brazil', countryCode: 'BRA', position: 'CB', role: PlayerRole.defender, rating: 85, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  // === FRANCE ===
  PlayerCard(id: 'fra-aurelien-tchouameni', name: 'Aurélien Tchouaméni', shortName: 'TCHOUAMENI', country: 'France', countryCode: 'FRA', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Ball Winner', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'fra-william-saliba', name: 'William Saliba', shortName: 'SALIBA', country: 'France', countryCode: 'FRA', position: 'CB', role: PlayerRole.defender, rating: 89, trait: 'Ball-Playing CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'fra-dayot-upamecano', name: 'Dayot Upamecano', shortName: 'UPAMECANO', country: 'France', countryCode: 'FRA', position: 'CB', role: PlayerRole.defender, rating: 84, trait: 'Power Stopper', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'fra-jules-kounde', name: 'Jules Koundé', shortName: 'KOUNDE', country: 'France', countryCode: 'FRA', position: 'RB/CB', role: PlayerRole.defender, rating: 84, trait: 'Recovery Defender', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'fra-theo-hernandez', name: 'Theo Hernández', shortName: 'THEO', country: 'France', countryCode: 'FRA', position: 'LB', role: PlayerRole.defender, rating: 84, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'fra-n-golo-kante', name: "N'Golo Kanté", shortName: 'KANTE', country: 'France', countryCode: 'FRA', position: 'CDM', role: PlayerRole.defender, rating: 84, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  // === ENGLAND ===
  PlayerCard(id: 'eng-declan-rice', name: 'Declan Rice', shortName: 'RICE', country: 'England', countryCode: 'ENG', position: 'CDM/CM', role: PlayerRole.defender, rating: 89, trait: 'Shield Midfielder', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'eng-john-stones', name: 'John Stones', shortName: 'STONES', country: 'England', countryCode: 'ENG', position: 'CB', role: PlayerRole.defender, rating: 84, trait: 'Ball-Playing CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'eng-reece-james', name: 'Reece James', shortName: 'R. JAMES', country: 'England', countryCode: 'ENG', position: 'RB', role: PlayerRole.defender, rating: 83, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  // === PORTUGAL ===
  PlayerCard(id: 'por-joao-neves', name: 'João Neves', shortName: 'J. NEVES', country: 'Portugal', countryCode: 'POR', position: 'CM/CDM', role: PlayerRole.defender, rating: 85, trait: 'Press Breaker', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'por-nuno-mendes', name: 'Nuno Mendes', shortName: 'N. MENDES', country: 'Portugal', countryCode: 'POR', position: 'LB', role: PlayerRole.defender, rating: 88, trait: 'Attacking Fullback', tier: CardTier.gold, icon: Icons.swap_horiz),
  PlayerCard(id: 'por-ruben-dias', name: 'Rúben Dias', shortName: 'DIAS', country: 'Portugal', countryCode: 'POR', position: 'CB', role: PlayerRole.defender, rating: 89, trait: 'Leader CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'por-joao-cancelo', name: 'João Cancelo', shortName: 'CANCELO', country: 'Portugal', countryCode: 'POR', position: 'RB/LB', role: PlayerRole.defender, rating: 83, trait: 'Attacking Fullback', tier: CardTier.silver, icon: Icons.swap_horiz),
  // === SPAIN ===
  PlayerCard(id: 'esp-rodri', name: 'Rodri', shortName: 'RODRI', country: 'Spain', countryCode: 'ESP', position: 'CDM', role: PlayerRole.defender, rating: 93, trait: 'Tempo Controller', tier: CardTier.platinum, icon: Icons.security),
  PlayerCard(id: 'esp-dean-huijsen', name: 'Dean Huijsen', shortName: 'HUIJSEN', country: 'Spain', countryCode: 'ESP', position: 'CB', role: PlayerRole.defender, rating: 83, trait: 'Ball-Playing CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'esp-pau-cubarsi', name: 'Pau Cubarsí', shortName: 'CUBARSI', country: 'Spain', countryCode: 'ESP', position: 'CB', role: PlayerRole.defender, rating: 79, trait: 'Ball-Playing CB', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'esp-dani-carvajal', name: 'Dani Carvajal', shortName: 'CARVAJAL', country: 'Spain', countryCode: 'ESP', position: 'RB', role: PlayerRole.defender, rating: 84, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'esp-martin-zubimendi', name: 'Martin Zubimendi', shortName: 'ZUBIMENDI', country: 'Spain', countryCode: 'ESP', position: 'CDM', role: PlayerRole.defender, rating: 84, trait: 'Ball Winner', tier: CardTier.silver, icon: Icons.security),
  // === GERMANY ===
  PlayerCard(id: 'ger-joshua-kimmich', name: 'Joshua Kimmich', shortName: 'KIMMICH', country: 'Germany', countryCode: 'GER', position: 'CDM/RB', role: PlayerRole.defender, rating: 88, trait: 'Tempo Controller', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'ger-antonio-rudiger', name: 'Antonio Rüdiger', shortName: 'RUDIGER', country: 'Germany', countryCode: 'GER', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aggressive Stopper', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'ger-leon-goretzka', name: 'Leon Goretzka', shortName: 'GORETZKA', country: 'Germany', countryCode: 'GER', position: 'CM', role: PlayerRole.defender, rating: 82, trait: 'Box-to-Box Enforcer', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'ger-jonathan-tah', name: 'Jonathan Tah', shortName: 'TAH', country: 'Germany', countryCode: 'GER', position: 'CB', role: PlayerRole.defender, rating: 83, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'ger-david-raum', name: 'David Raum', shortName: 'RAUM', country: 'Germany', countryCode: 'GER', position: 'LB', role: PlayerRole.defender, rating: 78, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === NETHERLANDS ===
  PlayerCard(id: 'ned-virgil-van-dijk', name: 'Virgil van Dijk', shortName: 'VAN DIJK', country: 'Netherlands', countryCode: 'NED', position: 'CB', role: PlayerRole.defender, rating: 92, trait: 'Leader CB', tier: CardTier.platinum, icon: Icons.shield),
  PlayerCard(id: 'ned-denzel-dumfries', name: 'Denzel Dumfries', shortName: 'DUMFRIES', country: 'Netherlands', countryCode: 'NED', position: 'RB/RWB', role: PlayerRole.defender, rating: 83, trait: 'Power Fullback', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'ned-micky-van-de-ven', name: 'Micky van de Ven', shortName: 'VAN DE VEN', country: 'Netherlands', countryCode: 'NED', position: 'CB/LB', role: PlayerRole.defender, rating: 84, trait: 'Recovery Defender', tier: CardTier.silver, icon: Icons.shield),
  // === BELGIUM ===
  PlayerCard(id: 'bel-amadou-onana', name: 'Amadou Onana', shortName: 'ONANA', country: 'Belgium', countryCode: 'BEL', position: 'CDM', role: PlayerRole.defender, rating: 83, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'bel-timothy-castagne', name: 'Timothy Castagne', shortName: 'CASTAGNE', country: 'Belgium', countryCode: 'BEL', position: 'RB/LB', role: PlayerRole.defender, rating: 77, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'bel-arthur-theate', name: 'Arthur Theate', shortName: 'THEATE', country: 'Belgium', countryCode: 'BEL', position: 'CB/LB', role: PlayerRole.defender, rating: 77, trait: 'Flexible Defender', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'bel-axel-witsel', name: 'Axel Witsel', shortName: 'WITSEL', country: 'Belgium', countryCode: 'BEL', position: 'CDM/CB', role: PlayerRole.defender, rating: 76, trait: 'Veteran Shield', tier: CardTier.bronze, icon: Icons.security),
  // === CROATIA ===
  PlayerCard(id: 'cro-josko-gvardiol', name: 'Joško Gvardiol', shortName: 'GVARDIOL', country: 'Croatia', countryCode: 'CRO', position: 'CB/LB', role: PlayerRole.defender, rating: 88, trait: 'Ball-Playing CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'cro-marcelo-brozovic', name: 'Marcelo Brozović', shortName: 'BROZOVIC', country: 'Croatia', countryCode: 'CRO', position: 'CDM', role: PlayerRole.defender, rating: 83, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'cro-josip-stanisic', name: 'Josip Stanišić', shortName: 'STANISIC', country: 'Croatia', countryCode: 'CRO', position: 'RB/CB', role: PlayerRole.defender, rating: 82, trait: 'Flexible Defender', tier: CardTier.silver, icon: Icons.swap_horiz),
  // === URUGUAY ===
  PlayerCard(id: 'uru-ronald-araujo', name: 'Ronald Araújo', shortName: 'ARAUJO', country: 'Uruguay', countryCode: 'URU', position: 'CB/RB', role: PlayerRole.defender, rating: 87, trait: 'Recovery Defender', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'uru-jose-maria-gimenez', name: 'José María Giménez', shortName: 'GIMENEZ', country: 'Uruguay', countryCode: 'URU', position: 'CB', role: PlayerRole.defender, rating: 83, trait: 'Aggressive Stopper', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'uru-manuel-ugarte', name: 'Manuel Ugarte', shortName: 'UGARTE', country: 'Uruguay', countryCode: 'URU', position: 'CDM', role: PlayerRole.defender, rating: 82, trait: 'Ball Winner', tier: CardTier.silver, icon: Icons.security),
  // === COLOMBIA ===
  PlayerCard(id: 'col-jefferson-lerma', name: 'Jefferson Lerma', shortName: 'LERMA', country: 'Colombia', countryCode: 'COL', position: 'CDM', role: PlayerRole.defender, rating: 81, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'col-daniel-munoz', name: 'Daniel Muñoz', shortName: 'D. MUNOZ', country: 'Colombia', countryCode: 'COL', position: 'RB', role: PlayerRole.defender, rating: 82, trait: 'Attacking Fullback', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'col-davinson-sanchez', name: 'Davinson Sánchez', shortName: 'DAVINSON', country: 'Colombia', countryCode: 'COL', position: 'CB', role: PlayerRole.defender, rating: 81, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  // === USA ===
  PlayerCard(id: 'usa-tyler-adams', name: 'Tyler Adams', shortName: 'ADAMS', country: 'USA', countryCode: 'USA', position: 'CDM', role: PlayerRole.defender, rating: 82, trait: 'Ball Winner', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'usa-antonee-robinson', name: 'Antonee Robinson', shortName: 'A. ROBINSON', country: 'USA', countryCode: 'USA', position: 'LB', role: PlayerRole.defender, rating: 83, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'usa-chris-richards', name: 'Chris Richards', shortName: 'RICHARDS', country: 'USA', countryCode: 'USA', position: 'CB', role: PlayerRole.defender, rating: 78, trait: 'Ball-Playing CB', tier: CardTier.bronze, icon: Icons.shield),
  // === MEXICO ===
  PlayerCard(id: 'mex-edson-alvarez', name: 'Edson Álvarez', shortName: 'EDSON', country: 'Mexico', countryCode: 'MEX', position: 'CDM/CB', role: PlayerRole.defender, rating: 82, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'mex-johan-vasquez', name: 'Johan Vásquez', shortName: 'VASQUEZ', country: 'Mexico', countryCode: 'MEX', position: 'CB', role: PlayerRole.defender, rating: 77, trait: 'Ball-Playing CB', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'mex-cesar-montes', name: 'César Montes', shortName: 'MONTES', country: 'Mexico', countryCode: 'MEX', position: 'CB', role: PlayerRole.defender, rating: 77, trait: 'Aerial Defender', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'mex-jorge-sanchez', name: 'Jorge Sánchez', shortName: 'J. SANCHEZ', country: 'Mexico', countryCode: 'MEX', position: 'RB', role: PlayerRole.defender, rating: 76, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'mex-jesus-gallardo', name: 'Jesús Gallardo', shortName: 'GALLARDO', country: 'Mexico', countryCode: 'MEX', position: 'LB', role: PlayerRole.defender, rating: 76, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === CANADA ===
  PlayerCard(id: 'can-alphonso-davies', name: 'Alphonso Davies', shortName: 'DAVIES', country: 'Canada', countryCode: 'CAN', position: 'LB/LW', role: PlayerRole.defender, rating: 88, trait: 'Explosive Fullback', tier: CardTier.gold, icon: Icons.swap_horiz),
  PlayerCard(id: 'can-stephen-eustaquio', name: 'Stephen Eustáquio', shortName: 'EUSTAQUIO', country: 'Canada', countryCode: 'CAN', position: 'CM/CDM', role: PlayerRole.defender, rating: 81, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'can-alistair-johnston', name: 'Alistair Johnston', shortName: 'JOHNSTON', country: 'Canada', countryCode: 'CAN', position: 'RB', role: PlayerRole.defender, rating: 77, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'can-moise-bombito', name: 'Moïse Bombito', shortName: 'BOMBITO', country: 'Canada', countryCode: 'CAN', position: 'CB', role: PlayerRole.defender, rating: 77, trait: 'Recovery Defender', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'can-derek-cornelius', name: 'Derek Cornelius', shortName: 'CORNELIUS', country: 'Canada', countryCode: 'CAN', position: 'CB', role: PlayerRole.defender, rating: 76, trait: 'Aerial Defender', tier: CardTier.bronze, icon: Icons.shield),
  // === JAPAN ===
  PlayerCard(id: 'jpn-wataru-endo', name: 'Wataru Endo', shortName: 'ENDO', country: 'Japan', countryCode: 'JPN', position: 'CDM', role: PlayerRole.defender, rating: 82, trait: 'Captain Shield', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'jpn-takehiro-tomiyasu', name: 'Takehiro Tomiyasu', shortName: 'TOMIYASU', country: 'Japan', countryCode: 'JPN', position: 'CB/RB', role: PlayerRole.defender, rating: 82, trait: 'Flexible Defender', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'jpn-ko-itakura', name: 'Ko Itakura', shortName: 'ITAKURA', country: 'Japan', countryCode: 'JPN', position: 'CB', role: PlayerRole.defender, rating: 81, trait: 'Ball-Playing CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'jpn-hidemasa-morita', name: 'Hidemasa Morita', shortName: 'MORITA', country: 'Japan', countryCode: 'JPN', position: 'CM', role: PlayerRole.defender, rating: 78, trait: 'Tempo Controller', tier: CardTier.bronze, icon: Icons.security),
  // === SOUTH KOREA ===
  PlayerCard(id: 'kor-kim-min-jae', name: 'Kim Min-jae', shortName: 'KIM MJ', country: 'South Korea', countryCode: 'KOR', position: 'CB', role: PlayerRole.defender, rating: 87, trait: 'Leader CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'kor-paik-seung-ho', name: 'Paik Seung-ho', shortName: 'PAIK', country: 'South Korea', countryCode: 'KOR', position: 'CM/CDM', role: PlayerRole.defender, rating: 76, trait: 'Ball Winner', tier: CardTier.bronze, icon: Icons.security),
  PlayerCard(id: 'kor-seol-young-woo', name: 'Seol Young-woo', shortName: 'SEOL', country: 'South Korea', countryCode: 'KOR', position: 'RB/LB', role: PlayerRole.defender, rating: 76, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === AUSTRALIA ===
  PlayerCard(id: 'aus-harry-souttar', name: 'Harry Souttar', shortName: 'SOUTTAR', country: 'Australia', countryCode: 'AUS', position: 'CB', role: PlayerRole.defender, rating: 80, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'aus-jackson-irvine', name: 'Jackson Irvine', shortName: 'IRVINE', country: 'Australia', countryCode: 'AUS', position: 'CM', role: PlayerRole.defender, rating: 80, trait: 'Engine Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'aus-aziz-behich', name: 'Aziz Behich', shortName: 'BEHICH', country: 'Australia', countryCode: 'AUS', position: 'LB/LWB', role: PlayerRole.defender, rating: 76, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'aus-lewis-miller', name: 'Lewis Miller', shortName: 'MILLER', country: 'Australia', countryCode: 'AUS', position: 'RB/RWB', role: PlayerRole.defender, rating: 75, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'aus-alessandro-circati', name: 'Alessandro Circati', shortName: 'CIRCATI', country: 'Australia', countryCode: 'AUS', position: 'CB', role: PlayerRole.defender, rating: 77, trait: 'Recovery Defender', tier: CardTier.bronze, icon: Icons.shield),
];

const goalkeepers = [
  PlayerCard(id: 'arg-emiliano-martinez', name: 'Emiliano Martínez', shortName: 'EMI', country: 'Argentina', countryCode: 'ARG', position: 'GK', role: PlayerRole.goalkeeper, rating: 89, trait: 'Penalty Wall', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'bra-alisson-becker', name: 'Alisson Becker', shortName: 'ALISSON', country: 'Brazil', countryCode: 'BRA', position: 'GK', role: PlayerRole.goalkeeper, rating: 89, trait: 'Sweeper Keeper', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'bra-ederson-moraes', name: 'Ederson Moraes', shortName: 'EDERSON', country: 'Brazil', countryCode: 'BRA', position: 'GK', role: PlayerRole.goalkeeper, rating: 85, trait: 'Sweeper Keeper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'fra-mike-maignan', name: 'Mike Maignan', shortName: 'MAIGNAN', country: 'France', countryCode: 'FRA', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Shot Stopper', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'eng-jordan-pickford', name: 'Jordan Pickford', shortName: 'PICKFORD', country: 'England', countryCode: 'ENG', position: 'GK', role: PlayerRole.goalkeeper, rating: 84, trait: 'Shot Stopper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'por-diogo-costa', name: 'Diogo Costa', shortName: 'D. COSTA', country: 'Portugal', countryCode: 'POR', position: 'GK', role: PlayerRole.goalkeeper, rating: 84, trait: 'Shot Stopper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'esp-unai-simon', name: 'Unai Simón', shortName: 'SIMON', country: 'Spain', countryCode: 'ESP', position: 'GK', role: PlayerRole.goalkeeper, rating: 83, trait: 'Shot Stopper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'ger-oliver-baumann', name: 'Oliver Baumann', shortName: 'BAUMANN', country: 'Germany', countryCode: 'GER', position: 'GK', role: PlayerRole.goalkeeper, rating: 78, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'ned-bart-verbruggen', name: 'Bart Verbruggen', shortName: 'VERBRUGGEN', country: 'Netherlands', countryCode: 'NED', position: 'GK', role: PlayerRole.goalkeeper, rating: 79, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'bel-thibaut-courtois', name: 'Thibaut Courtois', shortName: 'COURTOIS', country: 'Belgium', countryCode: 'BEL', position: 'GK', role: PlayerRole.goalkeeper, rating: 89, trait: 'Penalty Wall', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'cro-dominik-livakovic', name: 'Dominik Livaković', shortName: 'LIVAKOVIC', country: 'Croatia', countryCode: 'CRO', position: 'GK', role: PlayerRole.goalkeeper, rating: 82, trait: 'Penalty Keeper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'uru-sergio-rochet', name: 'Sergio Rochet', shortName: 'ROCHET', country: 'Uruguay', countryCode: 'URU', position: 'GK', role: PlayerRole.goalkeeper, rating: 77, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'col-camilo-vargas', name: 'Camilo Vargas', shortName: 'VARGAS', country: 'Colombia', countryCode: 'COL', position: 'GK', role: PlayerRole.goalkeeper, rating: 77, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'usa-matt-turner', name: 'Matt Turner', shortName: 'TURNER', country: 'USA', countryCode: 'USA', position: 'GK', role: PlayerRole.goalkeeper, rating: 77, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'mex-luis-malagon', name: 'Luis Malagón', shortName: 'MALAGON', country: 'Mexico', countryCode: 'MEX', position: 'GK', role: PlayerRole.goalkeeper, rating: 77, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'can-dayne-st-clair', name: 'Dayne St. Clair', shortName: 'ST. CLAIR', country: 'Canada', countryCode: 'CAN', position: 'GK', role: PlayerRole.goalkeeper, rating: 76, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'jpn-zion-suzuki', name: 'Zion Suzuki', shortName: 'ZION', country: 'Japan', countryCode: 'JPN', position: 'GK', role: PlayerRole.goalkeeper, rating: 78, trait: 'Reflex Keeper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'kor-kim-seung-gyu', name: 'Kim Seung-gyu', shortName: 'KIM SG', country: 'South Korea', countryCode: 'KOR', position: 'GK', role: PlayerRole.goalkeeper, rating: 77, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'aus-mathew-ryan', name: 'Mathew Ryan', shortName: 'RYAN', country: 'Australia', countryCode: 'AUS', position: 'GK', role: PlayerRole.goalkeeper, rating: 81, trait: 'Veteran Keeper', tier: CardTier.silver, icon: Icons.pan_tool),
];

const allPlayerCards = [...attackers, ...defenders, ...goalkeepers];

/// A base action archetype. Each blueprint is expanded into four collectible
/// [ActionCard]s — one per [CardTier] — by [_buildActionCards]. The [basePower]
/// is the gold-tier value; other tiers scale it via [_tierPowerFactor]. The
/// [effectTemplate] uses `{p}` as a placeholder for the resolved tier power.
class _ActionBlueprint {
  const _ActionBlueprint({
    required this.baseId,
    required this.title,
    required this.category,
    required this.basePower,
    required this.risky,
    required this.icon,
    required this.effectTemplate,
  });

  final String baseId;
  final String title;
  final ActionCategory category;
  final int basePower;
  final bool risky;
  final IconData icon;
  final String effectTemplate;
}

const _actionBlueprints = <_ActionBlueprint>[
  _ActionBlueprint(baseId: 'act1', title: 'Through Ball', category: ActionCategory.attack, basePower: 15, risky: false, icon: Icons.trending_up, effectTemplate: '+{p} Attack Power'),
  _ActionBlueprint(baseId: 'act2', title: 'Power Shot', category: ActionCategory.attack, basePower: 20, risky: false, icon: Icons.sports_soccer, effectTemplate: '+{p} Attack, -5 Accuracy'),
  _ActionBlueprint(baseId: 'act3', title: 'Skill Move', category: ActionCategory.attack, basePower: 12, risky: false, icon: Icons.auto_awesome, effectTemplate: '+{p} Attack, Bypass Trait'),
  _ActionBlueprint(baseId: 'act4', title: 'Cut Inside', category: ActionCategory.attack, basePower: 10, risky: false, icon: Icons.turn_right, effectTemplate: '+{p} Attack, +5 Scenario'),
  _ActionBlueprint(baseId: 'act5', title: 'Long Shot', category: ActionCategory.attack, basePower: 25, risky: true, icon: Icons.my_location, effectTemplate: '+{p} Attack, High Risk'),
  _ActionBlueprint(baseId: 'act6', title: 'Quick Break', category: ActionCategory.attack, basePower: 18, risky: false, icon: Icons.flash_on, effectTemplate: '+{p} Counter Bonus'),
  _ActionBlueprint(baseId: 'act7', title: 'Slide Tackle', category: ActionCategory.defense, basePower: 15, risky: false, icon: Icons.swipe_down, effectTemplate: '+{p} Defense Power'),
  _ActionBlueprint(baseId: 'act8', title: 'Press High', category: ActionCategory.defense, basePower: 12, risky: false, icon: Icons.compress, effectTemplate: '+{p} Defense, Disrupt'),
  _ActionBlueprint(baseId: 'act9', title: 'Block Lane', category: ActionCategory.defense, basePower: 10, risky: false, icon: Icons.block, effectTemplate: '+{p} Defense, +5 Position'),
  _ActionBlueprint(baseId: 'act10', title: 'Tight Marking', category: ActionCategory.defense, basePower: 14, risky: false, icon: Icons.person_pin_circle, effectTemplate: '+{p} Defense Power'),
  _ActionBlueprint(baseId: 'act11', title: 'Intercept', category: ActionCategory.defense, basePower: 18, risky: false, icon: Icons.call_split, effectTemplate: '+{p} Defense, Read Play'),
  _ActionBlueprint(baseId: 'act12', title: 'Last-Ditch Tackle', category: ActionCategory.defense, basePower: 22, risky: true, icon: Icons.warning, effectTemplate: '+{p} Defense, Foul Risk'),
  _ActionBlueprint(baseId: 'act13', title: 'All In', category: ActionCategory.special, basePower: 30, risky: true, icon: Icons.local_fire_department, effectTemplate: '+{p} Power, Red Card Risk'),
  _ActionBlueprint(baseId: 'act14', title: 'Tactical Foul', category: ActionCategory.special, basePower: 8, risky: true, icon: Icons.flag, effectTemplate: '+{p} Disrupt, Yellow Risk'),
  _ActionBlueprint(baseId: 'act15', title: 'Mind Game', category: ActionCategory.special, basePower: 10, risky: false, icon: Icons.psychology, effectTemplate: '-{p} Opponent Power'),
  _ActionBlueprint(baseId: 'act16', title: 'Fast Recovery', category: ActionCategory.special, basePower: 8, risky: false, icon: Icons.healing, effectTemplate: '+{p} All Stats'),
];

/// Power multiplier applied to a blueprint's [_ActionBlueprint.basePower] for
/// each tier. Gold is the authored base; bronze/silver sit below, platinum above.
const _tierPowerFactor = <CardTier, double>{
  CardTier.bronze: 0.6,
  CardTier.silver: 0.8,
  CardTier.gold: 1.0,
  CardTier.platinum: 1.2,
};

int _tierPower(int basePower, CardTier tier) =>
    (basePower * _tierPowerFactor[tier]!).round();

/// Every base action expanded across all four tiers (16 × 4 = 64 cards). Tier
/// ids follow `<baseId>-<tier>`, e.g. `act1-bronze`, `act1-platinum`.
List<ActionCard> _buildActionCards() => [
  for (final bp in _actionBlueprints)
    for (final tier in CardTier.values)
      ActionCard(
        id: '${bp.baseId}-${tier.name}',
        title: bp.title,
        category: bp.category,
        tier: tier,
        power: _tierPower(bp.basePower, tier),
        risky: bp.risky,
        icon: bp.icon,
        effect: bp.effectTemplate.replaceAll(
          '{p}',
          '${_tierPower(bp.basePower, tier)}',
        ),
      ),
];

final actionCards = _buildActionCards();

const scenarios = [
  ScenarioCard(id: 'sc1', title: 'Counter Attack', description: 'Quick transition, spaces open up', attackBonus: 8, defenseBonus: 3, icon: Icons.run_circle),
  ScenarioCard(id: 'sc2', title: '1v1 Final Third', description: 'Face to face with the last defender', attackBonus: 5, defenseBonus: 5, icon: Icons.adjust),
  ScenarioCard(id: 'sc3', title: 'Set Piece Chance', description: 'Free kick from a dangerous position', attackBonus: 6, defenseBonus: 6, icon: Icons.sports),
  ScenarioCard(id: 'sc4', title: 'Last Minute Pressure', description: 'Everything on the line, final push', attackBonus: 10, defenseBonus: 2, icon: Icons.timer),
  ScenarioCard(id: 'sc5', title: 'Box Defense', description: 'Packed defense, tight spaces', attackBonus: 2, defenseBonus: 10, icon: Icons.grid_view),
  ScenarioCard(id: 'sc6', title: 'Wide Break', description: 'Overlapping run down the flank', attackBonus: 7, defenseBonus: 4, icon: Icons.open_in_full),
  ScenarioCard(id: 'sc7', title: 'Penalty Box Chaos', description: 'Scramble in the box, anything goes', attackBonus: 8, defenseBonus: 8, icon: Icons.shuffle),
];

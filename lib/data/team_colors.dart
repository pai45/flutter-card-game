import 'package:flutter/material.dart';

/// A central repository of primary team colors, mapped by the team's short code.
/// This prevents blank or missing colors from the API from rendering invisible logos,
/// and ensures a vibrant, consistent aesthetic across the app.
const Map<String, Color> kTeamColors = {
  // International Football (FIFA)
  'FRA': Color(0xff002395), // France
  'ARG': Color(0xff74acdf), // Argentina
  'ALG': Color(0xff059669), // Algeria
  'AUT': Color(0xffef4444), // Austria
  'JOR': Color(0xffb91c1c), // Jordan
  'GHA': Color(0xfffacc15), // Ghana
  'PAN': Color(0xff2563eb), // Panama
  'ENG': Color(0xffcc0000), // England (using a red cross rather than blank white)
  'CRO': Color(0xff1d4ed8), // Croatia
  'POR': Color(0xffb91c1c), // Portugal
  'COD': Color(0xff38bdf8), // Congo DR
  'UZB': Color(0xff22d3ee), // Uzbekistan
  'COL': Color(0xfffacc15), // Colombia
  'BRA': Color(0xfffacc15), // Brazil
  'JPN': Color(0xff00008b), // Japan (dark blue rather than blank white)
  'GER': Color(0xff000000), // Germany (black/gold rather than blank white)
  'SWE': Color(0xfffacc15), // Sweden
  'MAR': Color(0xffc1272d), // Morocco
  'CAN': Color(0xffef4444), // Canada
  'ESP': Color(0xfff59e0b), // Spain
  'USA': Color(0xff2563eb), // United States
  'BEL': Color(0xfffacc15), // Belgium
  'MEX': Color(0xff16a34a), // Mexico
  'EGY': Color(0xffdc2626), // Egypt
  'SUI': Color(0xffef4444), // Switzerland
  'NED': Color(0xffff7a00), // Netherlands
  'RSA': Color(0xff16a34a), // South Africa
  'CPV': Color(0xff2563eb), // Cabo Verde
  'DEN': Color(0xffc60c30), // Denmark
  'EST': Color(0xff0072ce), // Estonia
  'GIBR': Color(0xffe2001a), // Gibraltar
  'HUN': Color(0xff436f4d), // Hungary
  'ROM': Color(0xfffcd116), // Romania
  'SRB': Color(0xffc6363c), // Serbia

  // English Premier League
  'LFC': Color(0xffc8102e), // Liverpool
  'MCI': Color(0xff6cabdd), // Man City
  'CFC': Color(0xff1f4fd6), // Chelsea
  'NEW': Color(0xff000000), // Newcastle (black rather than light grey)
  'MU':  Color(0xffd5122a), // Man Utd
  'WHU': Color(0xff7a263a), // West Ham
  'ARS': Color(0xffef0107), // Arsenal
  'AVL': Color(0xff7a003c), // Aston Villa
  'BHA': Color(0xff0057b8), // Brighton
  'EVE': Color(0xff003399), // Everton
  'BUR': Color(0xff6c1d45), // Burnley

  // International & Domestic Cricket (IPL)
  'IND': Color(0xff1d4ed8), // India
  'WI':  Color(0xff7a0016), // West Indies
  'SL':  Color(0xff002b54), // Sri Lanka
  'SRH': Color(0xffff822e), // Hyderabad
  'MI':  Color(0xff2856a5), // Mumbai
  'PJK': Color(0xffdcd9cf), // Punjab
  'KKR': Color(0xfff0c419), // KKR
  'CSK': Color(0xfff9cd05), // Chennai
  'RCB': Color(0xffd81920), // Bangalore
};

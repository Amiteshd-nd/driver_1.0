/// Maps the platform geocoder's `administrativeArea` to ISO 3166-2:IN codes
/// (the `regions.code` values the server validates against). Includes common
/// variants, diacritics, legacy names and abbreviations returned by iOS/Android geocoders.
library;

const Map<String, String> _indiaStateByName = {
  // States
  'andhra pradesh': 'IN-AP',
  'andhrapradesh': 'IN-AP',
  'arunachal pradesh': 'IN-AR',
  'assam': 'IN-AS',
  'bihar': 'IN-BR',
  'chhattisgarh': 'IN-CT',
  'chattisgarh': 'IN-CT',
  'chhatisgarh': 'IN-CT',
  'goa': 'IN-GA',
  'gujarat': 'IN-GJ',
  'haryana': 'IN-HR',
  'himachal pradesh': 'IN-HP',
  'jharkhand': 'IN-JH',
  'karnataka': 'IN-KA',
  'karnātaka': 'IN-KA',
  'mysore': 'IN-KA',
  'kerala': 'IN-KL',
  'madhya pradesh': 'IN-MP',
  'maharashtra': 'IN-MH',
  'mahārāshtra': 'IN-MH',
  'manipur': 'IN-MN',
  'meghalaya': 'IN-ML',
  'mizoram': 'IN-MZ',
  'nagaland': 'IN-NL',
  'odisha': 'IN-OR',
  'orissa': 'IN-OR',
  'punjab': 'IN-PB',
  'rajasthan': 'IN-RJ',
  'rājasthān': 'IN-RJ',
  'sikkim': 'IN-SK',
  'tamil nadu': 'IN-TN',
  'tamilnadu': 'IN-TN',
  'tamil nādu': 'IN-TN',
  'telangana': 'IN-TG',
  'telengana': 'IN-TG',
  'tripura': 'IN-TR',
  'uttar pradesh': 'IN-UP',
  'uttarakhand': 'IN-UT',
  'uttaranchal': 'IN-UT',
  'west bengal': 'IN-WB',
  'paschim banga': 'IN-WB',
  // Union territories
  'andaman and nicobar islands': 'IN-AN',
  'andaman & nicobar islands': 'IN-AN',
  'andaman and nicobar': 'IN-AN',
  'chandigarh': 'IN-CH',
  'dadra and nagar haveli and daman and diu': 'IN-DH',
  'dadra and nagar haveli': 'IN-DH',
  'daman and diu': 'IN-DH',
  'delhi': 'IN-DL',
  'nct of delhi': 'IN-DL',
  'national capital territory of delhi': 'IN-DL',
  'new delhi': 'IN-DL',
  'jammu and kashmir': 'IN-JK',
  'jammu & kashmir': 'IN-JK',
  'ladakh': 'IN-LA',
  'lakshadweep': 'IN-LD',
  'puducherry': 'IN-PY',
  'pondicherry': 'IN-PY',
};

/// Two-letter abbreviations some geocoders return (e.g. "KA", "MH", "DL").
const Map<String, String> _indiaStateByAbbrev = {
  'ap': 'IN-AP', 'ar': 'IN-AR', 'as': 'IN-AS', 'br': 'IN-BR', 'ct': 'IN-CT', 'cg': 'IN-CT', 'ga': 'IN-GA',
  'gj': 'IN-GJ', 'hr': 'IN-HR', 'hp': 'IN-HP', 'jh': 'IN-JH', 'ka': 'IN-KA', 'kl': 'IN-KL', 'mp': 'IN-MP',
  'mh': 'IN-MH', 'mn': 'IN-MN', 'ml': 'IN-ML', 'mz': 'IN-MZ', 'nl': 'IN-NL', 'or': 'IN-OR', 'od': 'IN-OR',
  'pb': 'IN-PB', 'rj': 'IN-RJ', 'sk': 'IN-SK', 'tn': 'IN-TN', 'tg': 'IN-TG', 'ts': 'IN-TG', 'tr': 'IN-TR',
  'up': 'IN-UP', 'ut': 'IN-UT', 'uk': 'IN-UT', 'wb': 'IN-WB', 'an': 'IN-AN', 'ch': 'IN-CH', 'dh': 'IN-DH',
  'dn': 'IN-DH', 'dd': 'IN-DH', 'dl': 'IN-DL', 'jk': 'IN-JK', 'la': 'IN-LA', 'ld': 'IN-LD', 'py': 'IN-PY',
};

String _fold(String s) {
  const from = 'āáàâäãēéèêëīíìîïōóòôöõūúùûüñ';
  const to = 'aaaaaaeeeeeiiiiiooooouuuuun';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Returns the ISO 3166-2:IN code for a geocoder `administrativeArea`, or null when unknown.
/// Pass `isoCountryCode` when available so a non-Indian placemark never maps to a state.
String? indiaStateCode(String? administrativeArea, {String? isoCountryCode}) {
  if (administrativeArea == null || administrativeArea.trim().isEmpty) return null;
  if (isoCountryCode != null && isoCountryCode.isNotEmpty && isoCountryCode.toUpperCase() != 'IN') return null;
  final raw = administrativeArea.trim();
  if (RegExp(r'^IN-[A-Z]{2}$').hasMatch(raw.toUpperCase())) {
    final code = raw.toUpperCase();
    return _indiaStateByName.containsValue(code) ? code : null;
  }
  final key = _fold(raw);
  final direct = _indiaStateByName[key];
  if (direct != null) return direct;
  final folded = _indiaStateByName[_fold(_fold(raw))];
  if (folded != null) return folded;
  final abbrev = _indiaStateByAbbrev[key];
  if (abbrev != null) return abbrev;
  // Loose contains match, longest key first ("dadra and nagar haveli and daman and diu" before "daman and diu").
  final keys = _indiaStateByName.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    if (key.contains(_fold(k))) return _indiaStateByName[k];
  }
  return null;
}

/// Display name for a state code (for the Settings region dropdown fallback).
String? indiaStateName(String code) {
  for (final e in _indiaStateByName.entries) {
    if (e.value == code) {
      final n = e.key;
      return n.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }
  return null;
}

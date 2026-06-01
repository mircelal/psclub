import 'json_parse.dart';

/// Masa siyahısı (tables API) — paket qiyməti snapshot.
double tablePackagePrice(Map<String, dynamic> table) =>
    jsonToDouble(table['session_set_price']);

bool tableHasPackage(Map<String, dynamic> table) => tablePackagePrice(table) > 0;

/// Sessiya detalı — paket satışı.
double sessionPackagePrice(Map<String, dynamic> session) =>
    jsonToDouble(session['set_price_snapshot']);

bool sessionHasPackage(Map<String, dynamic> session) => sessionPackagePrice(session) > 0;

String? sessionPackageName(Map<String, dynamic> data) {
  final name = data['session_set_name'] as String? ?? data['set_name_snapshot'] as String?;
  if (name == null || name.trim().isEmpty) return null;
  return name.trim();
}

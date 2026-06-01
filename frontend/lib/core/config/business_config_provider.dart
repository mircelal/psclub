import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/pos_service.dart';

import 'media_url.dart';

import 'venue_labels.dart';



class BusinessConfig {

  const BusinessConfig({

    required this.name,

    required this.tagline,

    required this.currency,

    required this.billingMode,

    required this.timeBillingEnabled,

    required this.venueType,

    required this.logoUrl,

    required this.receiptHeader,

    required this.receiptFooter,

    required this.labels,

    required this.minOpenMinutes,

    required this.extendStepMinutes,

    required this.minBillingMinutes,

    required this.billingIncrementMinutes,

    required this.billingGraceMinutes,

  });



  final String name;

  final String tagline;

  final String currency;

  final String billingMode;

  final bool timeBillingEnabled;

  final String venueType;

  final String? logoUrl;

  final String receiptHeader;

  final String receiptFooter;

  final VenueLabels labels;

  final int minOpenMinutes;

  final int extendStepMinutes;

  final int minBillingMinutes;

  final int billingIncrementMinutes;

  final int billingGraceMinutes;

  bool get usesMinHourThenInterval => billingMode == 'min_1h_then_30';

  /// Canlı hesab və kassir kartları üçün rejim.
  String get chargeBillingMode =>
      billingMode == 'min_1h_then_30' ? 'min_1h_then_30' : billingMode;



  /// Müddətli açılış: minimumdan sonra [extendStepMinutes] addımları (məs. 60, 90, 120…).

  List<int> get timedOpenPresets {

    final min = minOpenMinutes;

    final step = extendStepMinutes;

    const maxMinutes = 180; // 3 saat

    final out = <int>[];

    for (var m = min; m <= maxMinutes; m += step) {

      out.add(m);

    }

    return out;

  }



  static const maxTimedOpenMinutes = 180;



  bool isValidTimedOpenMinutes(int minutes) {

    if (minutes < minOpenMinutes || minutes > maxTimedOpenMinutes) return false;

    return (minutes - minOpenMinutes) % extendStepMinutes == 0;

  }



  static const fallback = BusinessConfig(

    name: 'POS',

    tagline: '',

    currency: 'AZN',

    billingMode: 'per_minute',

    timeBillingEnabled: true,

    venueType: 'gaming',

    logoUrl: null,

    receiptHeader: '',

    receiptFooter: '',

    labels: VenueLabels(

      unitSingular: 'Masa',

      unitPlural: 'Masalar',

      rateLabel: 'Saatlıq tarif',

      sessionLabel: 'Sessiya',

    ),

    minOpenMinutes: 60,

    extendStepMinutes: 30,

    minBillingMinutes: 60,

    billingIncrementMinutes: 30,

    billingGraceMinutes: 10,

  );



  factory BusinessConfig.fromApi(Map<String, dynamic> data) {

    final biz = data['business'] as Map<String, dynamic>? ?? {};

    final settings = data['settings'] as Map<String, dynamic>? ?? {};

    final venueType = biz['venue_type']?.toString() ?? 'gaming';

    final timeBilling = biz['time_billing_enabled'];

    return BusinessConfig(

      name: biz['name']?.toString() ?? 'POS',

      tagline: biz['tagline']?.toString() ?? '',

      currency: biz['currency']?.toString() ?? 'AZN',

      billingMode: biz['billing_mode']?.toString() ?? 'per_minute',

      timeBillingEnabled: timeBilling == null || timeBilling == true || timeBilling == 1 || timeBilling == '1',

      venueType: venueType,

      logoUrl: MediaUrl.resolve(biz['logo_url']?.toString()),

      receiptHeader: settings['receipt_header']?.toString() ?? biz['name']?.toString() ?? '',

      receiptFooter: settings['receipt_footer']?.toString() ?? '',

      labels: VenueLabels.fromType(venueType),

      minOpenMinutes: _int(biz['min_open_minutes'], 60),

      extendStepMinutes: _int(biz['extend_step_minutes'], 30),

      minBillingMinutes: _int(biz['min_billing_minutes'], 60),

      billingIncrementMinutes: _int(biz['billing_increment_minutes'], 30),

      billingGraceMinutes: _int(biz['billing_grace_minutes'], 10),

    );

  }



  static int _int(dynamic v, int fallback) {

    if (v == null) return fallback;

    if (v is num) return v.toInt();

    return int.tryParse(v.toString()) ?? fallback;

  }

}



/// Giriş və kassir UI — yalnız public endpoint (JWT / authProvider-dan asılı deyil).

final businessConfigProvider = FutureProvider<BusinessConfig>((ref) async {

  try {

    final data = await ref.read(posServiceProvider).getPublicConfig();

    return BusinessConfig.fromApi(data);

  } catch (_) {

    return BusinessConfig.fallback;

  }

});


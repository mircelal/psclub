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
    );
  }
}

final businessConfigProvider = FutureProvider<BusinessConfig>((ref) async {
  try {
    final data = await ref.read(posServiceProvider).getSettings();
    return BusinessConfig.fromApi(data);
  } catch (_) {
    return BusinessConfig.fallback;
  }
});

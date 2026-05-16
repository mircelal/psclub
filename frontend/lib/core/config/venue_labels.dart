/// Müəssisə tipinə görə UI terminologiyası — PS klub, restoran, otaq kirayəsi və s.
class VenueLabels {
  const VenueLabels({
    required this.unitSingular,
    required this.unitPlural,
    required this.rateLabel,
    required this.sessionLabel,
  });

  final String unitSingular;
  final String unitPlural;
  final String rateLabel;
  final String sessionLabel;

  static VenueLabels fromType(String? type) => switch (type) {
        'restaurant' => const VenueLabels(
          unitSingular: 'Stol',
          unitPlural: 'Stollar',
          rateLabel: 'Servis / saat',
          sessionLabel: 'Sifariş',
        ),
        'room_rental' => const VenueLabels(
          unitSingular: 'Otaq',
          unitPlural: 'Otaqlar',
          rateLabel: 'Kirayə / saat',
          sessionLabel: 'Kirayə',
        ),
        'gaming' || _ => const VenueLabels(
          unitSingular: 'Masa',
          unitPlural: 'Masalar',
          rateLabel: 'Saatlıq tarif',
          sessionLabel: 'Sessiya',
        ),
      };

  static const venueTypes = [
    ('gaming', 'PS / Oyun klubu'),
    ('restaurant', 'Restoran / Kafe'),
    ('room_rental', 'Otaq kirayəsi'),
  ];
}

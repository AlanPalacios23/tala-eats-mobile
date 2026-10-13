enum DocumentStatus { verified, pending, expired }

class DriverDocument {
  const DriverDocument({required this.name, required this.status});

  final String name;
  final DocumentStatus status;
}

class DriverProfile {
  const DriverProfile({
    required this.firstName,
    required this.fullName,
    required this.zone,
    required this.vehicleType,
    required this.plateSuffix,
    required this.verified,
    required this.documents,
  });

  final String firstName;
  final String fullName;
  final String zone;
  final String vehicleType;

  /// Solo la terminación de la placa: la UI no muestra placas completas.
  final String plateSuffix;
  final bool verified;
  final List<DriverDocument> documents;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  bool get documentsUpToDate =>
      documents.every((doc) => doc.status == DocumentStatus.verified);
}

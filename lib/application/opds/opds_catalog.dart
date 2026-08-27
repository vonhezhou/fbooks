class OpdsCatalog {
  const OpdsCatalog({
    required this.title,
    required this.publications,
    required this.navigation,
  });

  final String title;
  final List<OpdsPublication> publications;
  final List<OpdsNavigationLink> navigation;
}

class OpdsPublication {
  const OpdsPublication({
    required this.title,
    required this.authors,
    required this.acquisitions,
    this.description,
    this.coverUri,
  });

  final String title;
  final List<String> authors;
  final List<OpdsAcquisition> acquisitions;
  final String? description;
  final Uri? coverUri;
}

class OpdsAcquisition {
  const OpdsAcquisition({required this.href, this.mediaType});

  final Uri href;
  final String? mediaType;
}

class OpdsNavigationLink {
  const OpdsNavigationLink({required this.title, required this.href});

  final String title;
  final Uri href;
}

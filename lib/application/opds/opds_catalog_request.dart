/// Identifies one OPDS request while retaining the credential-owning source.
class OpdsCatalogRequest {
  const OpdsCatalogRequest({required this.sourceId, required this.endpoint});

  final String sourceId;
  final Uri endpoint;

  @override
  bool operator ==(Object other) =>
      other is OpdsCatalogRequest &&
      sourceId == other.sourceId &&
      endpoint == other.endpoint;

  @override
  int get hashCode => Object.hash(sourceId, endpoint);
}

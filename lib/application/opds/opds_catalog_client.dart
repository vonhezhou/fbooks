import 'package:fbooks/application/opds/opds_catalog.dart';

abstract interface class OpdsCatalogClient {
  Future<OpdsCatalog> fetch(Uri endpoint);
}

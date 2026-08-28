import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';

abstract interface class OpdsCatalogClient {
  Future<OpdsCatalog> fetch(Uri endpoint, {OpdsCredentials? credentials});
}

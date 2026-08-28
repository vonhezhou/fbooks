import 'dart:convert';

import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_catalog_client.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class HttpOpdsCatalogClient implements OpdsCatalogClient {
  HttpOpdsCatalogClient(this._client);

  final http.Client _client;

  @override
  Future<OpdsCatalog> fetch(
    Uri endpoint, {
    OpdsCredentials? credentials,
  }) async {
    final response = await _client.get(
      endpoint,
      headers: {
        'Accept':
            'application/opds+json, application/atom+xml, application/xml',
        if (credentials != null)
          'Authorization': credentials.authorizationHeader,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'OPDS server returned ${response.statusCode}',
        endpoint,
      );
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (body.startsWith('{')) {
      return _parseJsonCatalog(body, endpoint);
    }
    if (body.startsWith('<')) {
      return _parseAtomCatalog(body, endpoint);
    }
    throw const FormatException(
      'The OPDS response is neither JSON nor Atom XML',
    );
  }

  OpdsCatalog _parseJsonCatalog(String body, Uri endpoint) {
    final map = jsonDecode(body) as Map<String, Object?>;
    final metadata = map['metadata'] as Map<Object?, Object?>?;
    final publications = ((map['publications'] as List<Object?>?) ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map((publication) => _jsonPublication(publication, endpoint))
        .toList(growable: false);
    final navigation = ((map['navigation'] as List<Object?>?) ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map((link) => _jsonNavigation(link, endpoint))
        .whereType<OpdsNavigationLink>()
        .toList(growable: false);
    return OpdsCatalog(
      title: metadata?['title'] as String? ?? 'OPDS catalog',
      publications: publications,
      navigation: navigation,
    );
  }

  OpdsPublication _jsonPublication(
    Map<Object?, Object?> publication,
    Uri endpoint,
  ) {
    final metadata =
        publication['metadata'] as Map<Object?, Object?>? ?? const {};
    final authors = ((metadata['author'] as List<Object?>?) ?? const [])
        .map(
          (author) => switch (author) {
            String value => value,
            Map<Object?, Object?> value => value['name'] as String? ?? '',
            _ => '',
          },
        )
        .where((author) => author.isNotEmpty)
        .toList(growable: false);
    final acquisitions = ((publication['links'] as List<Object?>?) ?? const [])
        .whereType<Map<Object?, Object?>>()
        .where((link) => _isAcquisition(link['rel']))
        .map(
          (link) => _opdsAcquisition(
            endpoint,
            href: link['href'],
            mediaType: link['type'],
          ),
        )
        .whereType<OpdsAcquisition>()
        .toList(growable: false);
    return OpdsPublication(
      title: metadata['title'] as String? ?? 'Untitled',
      authors: authors,
      acquisitions: acquisitions,
      description: _nonEmptyString(metadata['description']),
      coverUri: _coverFromJsonLinks(publication['links'], endpoint),
    );
  }

  OpdsNavigationLink? _jsonNavigation(
    Map<Object?, Object?> link,
    Uri endpoint,
  ) {
    final href = _resolveHref(endpoint, link['href']);
    if (href == null) {
      return null;
    }
    return OpdsNavigationLink(
      title: link['title'] as String? ?? href.toString(),
      href: href,
    );
  }

  OpdsCatalog _parseAtomCatalog(String body, Uri endpoint) {
    final document = XmlDocument.parse(body);
    final publications = document
        .findAllElements('entry')
        .map((entry) => _atomPublication(entry, endpoint))
        .toList(growable: false);
    final navigation = document.rootElement
        .findElements('link')
        .where((link) => _isNavigation(link.getAttribute('rel')))
        .map((link) => _atomNavigation(link, endpoint))
        .whereType<OpdsNavigationLink>()
        .toList(growable: false);
    return OpdsCatalog(
      title: _elementText(document.rootElement, 'title') ?? 'OPDS catalog',
      publications: publications,
      navigation: navigation,
    );
  }

  OpdsPublication _atomPublication(XmlElement entry, Uri endpoint) {
    final authors = entry
        .findElements('author')
        .map((author) => _elementText(author, 'name') ?? '')
        .where((author) => author.isNotEmpty)
        .toList(growable: false);
    final acquisitions = entry
        .findElements('link')
        .where((link) => _isAcquisition(link.getAttribute('rel')))
        .map(
          (link) => _opdsAcquisition(
            endpoint,
            href: link.getAttribute('href'),
            mediaType: link.getAttribute('type'),
          ),
        )
        .whereType<OpdsAcquisition>()
        .toList(growable: false);
    return OpdsPublication(
      title: _elementText(entry, 'title') ?? 'Untitled',
      authors: authors,
      acquisitions: acquisitions,
      description:
          _elementText(entry, 'summary') ?? _elementText(entry, 'content'),
      coverUri: _coverFromAtomLinks(entry, endpoint),
    );
  }

  Uri? _coverFromJsonLinks(Object? value, Uri endpoint) {
    final links = (value as List<Object?>?) ?? const [];
    for (final link in links.whereType<Map<Object?, Object?>>()) {
      final rel = link['rel'];
      if (rel is String && (rel == 'cover' || rel == 'thumbnail')) {
        final cover = _resolveHref(endpoint, link['href']);
        if (cover != null) {
          return cover;
        }
      }
    }
    return null;
  }

  Uri? _coverFromAtomLinks(XmlElement entry, Uri endpoint) {
    for (final link in entry.findElements('link')) {
      final rel = link.getAttribute('rel');
      if (rel == 'http://opds-spec.org/image' ||
          rel == 'http://opds-spec.org/image/thumbnail') {
        final cover = _resolveHref(endpoint, link.getAttribute('href'));
        if (cover != null) {
          return cover;
        }
      }
    }
    return null;
  }

  OpdsNavigationLink? _atomNavigation(XmlElement link, Uri endpoint) {
    final href = _resolveHref(endpoint, link.getAttribute('href'));
    if (href == null) {
      return null;
    }
    return OpdsNavigationLink(
      title: link.getAttribute('title') ?? href.toString(),
      href: href,
    );
  }

  String? _elementText(XmlElement element, String localName) {
    for (final child in element.childElements) {
      if (child.name.local == localName) {
        return child.innerText.trim();
      }
    }
    return null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isAcquisition(Object? rel) {
    return rel is String && rel.contains('acquisition');
  }

  bool _isNavigation(String? rel) {
    return rel == 'subsection' || rel == 'navigation';
  }

  Uri? _resolveHref(Uri endpoint, Object? href) {
    return href is String && href.isNotEmpty ? endpoint.resolve(href) : null;
  }

  OpdsAcquisition? _opdsAcquisition(
    Uri endpoint, {
    required Object? href,
    required Object? mediaType,
  }) {
    final resolvedHref = _resolveHref(endpoint, href);
    return resolvedHref == null
        ? null
        : OpdsAcquisition(
            href: resolvedHref,
            mediaType: mediaType is String ? mediaType : null,
          );
  }
}

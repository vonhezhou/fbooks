import 'package:fbooks/data/opds/http_opds_catalog_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses an OPDS 2 JSON catalog and resolves relative URLs', () async {
    final client = HttpOpdsCatalogClient(
      MockClient(
        (request) async => http.Response('''{
          "metadata": {"title": "Library"},
          "navigation": [{"title": "Fiction", "href": "fiction.json"}],
          "publications": [{
            "metadata": {"title": "Book", "author": [{"name": "Ada"}]},
            "links": [{"rel": "http://opds-spec.org/acquisition", "href": "book.epub"}]
          }]
        }''', 200),
      ),
    );

    final catalog = await client.fetch(
      Uri.parse('https://books.example.org/opds/root.json'),
    );

    expect(catalog.title, 'Library');
    expect(
      catalog.navigation.single.href,
      Uri.parse('https://books.example.org/opds/fiction.json'),
    );
    expect(catalog.publications.single.authors, ['Ada']);
    expect(
      catalog.publications.single.acquisitions.map(
        (acquisition) => acquisition.href,
      ),
      [Uri.parse('https://books.example.org/opds/book.epub')],
    );
  });

  test('parses an OPDS 1 Atom acquisition feed', () async {
    final client = HttpOpdsCatalogClient(
      MockClient(
        (request) async => http.Response('''<?xml version="1.0"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Library</title>
            <entry>
              <title>Book</title>
              <author><name>Ada</name></author>
              <link rel="http://opds-spec.org/acquisition" href="book.epub" />
            </entry>
          </feed>''', 200),
      ),
    );

    final catalog = await client.fetch(
      Uri.parse('https://books.example.org/opds/root.xml'),
    );

    expect(catalog.title, 'Library');
    expect(catalog.publications.single.title, 'Book');
    expect(catalog.publications.single.authors, ['Ada']);
  });
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:michelle_frerk_management/constants.dart';

const String shopifyQuery = '''
{
  collections(first: 10) {
    edges {
      node {
        id
        title
        handle
        products(first: 100) {
          edges {
            node {
              id
              title
            }
          }
        }
      }
    }
  }
}
''';

Future<List<Map<String, dynamic>>> fetchShopifyProducts() async {
  final Uri url = Uri.https(shopifyDomain, '/api/2025-04/graphql.json');

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Storefront-Access-Token': accessToken,
    },
    body: jsonEncode({'query': shopifyQuery}),
  );

  if (response.statusCode != 200) {
    print('Fehler beim Laden der Produkte: ${response.body}');
    return [];
  }
  final data = jsonDecode(response.body);
  final collections = data['data']['collections']['edges'] as List;

  List<Map<String, dynamic>> availableProductsWithCategories = [];

  Set<String> seenIds = {};

  for (var collection in collections) {
    final products = collection['node']['products']['edges'];
    var productObjects =
        products
            .map<Map<String, dynamic>>((e) {
              final node = e['node'];

              return {'id': node['id'], 'title': node['title']};
            })
            .where((p) {
              // Filter duplicates by id
              if (seenIds.contains(p['id'])) {
                return false;
              } else {
                seenIds.add(p['id']);
                return true;
              }
            })
            .toList();

    availableProductsWithCategories.addAll(productObjects);
  }
  availableProductsWithCategories.sort(
    (a, b) => a['title'].compareTo(b['title']),
  );
  return availableProductsWithCategories;
}

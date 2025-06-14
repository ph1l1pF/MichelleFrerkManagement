import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart';
import 'package:michelle_frerk_management/get-products.dart';

void main() => runApp(PushApp());

class PushApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: PushNotificationScreen());
  }
}

class PushNotificationScreen extends StatefulWidget {
  @override
  _PushNotificationScreenState createState() => _PushNotificationScreenState();
}

class _PushNotificationScreenState extends State<PushNotificationScreen> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  List<Map<String, dynamic>> products = [];
  String? selectedProductId;
  bool isLoading = true;
  bool isTestMode = true; // Checkbox state

  @override
  void initState() {
    super.initState();
    loadProducts();
    titleController.addListener(() => setState(() {}));
    bodyController.addListener(() => setState(() {}));
  }

  Future<void> loadProducts() async {
    final fetchedProducts = await fetchShopifyProducts();
    setState(() {
      products = fetchedProducts;
      if (products.isNotEmpty) {
        selectedProductId = products.first['id'];
      }
      isLoading = false;
    });
  }

  Future<void> sendPushNotification() async {
    final title = titleController.text;
    final body = bodyController.text;
    final serviceAccountJson = await rootBundle.loadString(
      'assets/service-account.json',
    );
    final serviceAccount = auth.ServiceAccountCredentials.fromJson(
      serviceAccountJson,
    );

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    try {
      final client = await auth.clientViaServiceAccount(serviceAccount, scopes);

      final projectId = jsonDecode(serviceAccountJson)['project_id'] as String;

      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      // We had a version where the client was listening to 'all_devices' topic, but I switches to a new topic.
      // In order for the old clients to still receive notifications, we need to send to both topics.

      var testTopics = ['all_devices_test'];
      var prodTopics = [
        'all_devices_prod' /*'all_devices'*/,
      ]; // TODO: include second topic after release of 1.0.1

      var topics = isTestMode ? testTopics : prodTopics;
      List<Response> responses = [];

      for (var topic in topics) {
        final response = await client.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "message": {
              "topic": topic,
              "data": {"id": selectedProductId},
              "notification": {"title": title, "body": body},
            },
          }),
        );
        responses.add(response);
      }
      client.close();

      var failedResponses = responses.where((r) => r.statusCode != 200);

      if (failedResponses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Push-Benachrichtigung gesendet!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fehler beim Senden der Benachrichtigung an die folgenden Topics: ${failedResponses.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fehler beim Senden der Benachrichtigung: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  Future<void> handleSendButton() async {
    if (isTestMode) {
      await sendPushNotification();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Achtung'),
              content: Text(
                'Du bist NICHT im Testmodus!\n'
                'Willst du wirklich eine Notification an ALLE Geräte schicken?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Ja, senden'),
                ),
              ],
            ),
      );
      if (confirmed == true) {
        await sendPushNotification();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🐭Mäuschen Management Platform🐭')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: isTestMode,
                          onChanged: (value) {
                            setState(() {
                              isTestMode = value ?? true;
                            });
                          },
                        ),
                        Text('Test Modus'),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedProductId,
                      items:
                          products
                              .map(
                                (product) => DropdownMenuItem<String>(
                                  value: product['id'],
                                  child: Text(product['title'] ?? ''),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedProductId = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Produkt auswählen',
                      ),
                    ),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Titel'),
                    ),
                    TextField(
                      controller: bodyController,
                      decoration: InputDecoration(labelText: 'Nachricht'),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed:
                          (titleController.text.isEmpty ||
                                  bodyController.text.isEmpty)
                              ? null
                              : handleSendButton,
                      child: Text('Senden'),
                    ),
                  ],
                ),
      ),
    );
  }
}

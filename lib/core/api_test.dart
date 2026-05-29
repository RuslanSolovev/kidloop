import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestApiButton extends StatelessWidget {
  const TestApiButton({super.key});

  Future<void> sendTest() async {
    final url = Uri.parse(
      'https://functions.yandexcloud.net/d4euctluka7dnot8sosh',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "user_id": "u1",
        "name": "Ruslan",
        "city": "Riga",
        "bio": "Test from Flutter",
        "telegram": "@test",
        "age": 25
      }),
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: sendTest,
      child: const Text("ТЕСТ API"),
    );
  }
}
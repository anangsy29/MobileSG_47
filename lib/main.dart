import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'pages/login_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
  
//   debugPrint('📥 Background notification received');
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();


  final settings = await FirebaseMessaging.instance.requestPermission();
  debugPrint('🔔 Notifikasi diizinkan: ${settings.authorizationStatus}');


  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);


  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("🔥 Diterima onMessage: ${message.data}");

    if (message.data['type'] == 'verification') {
      final userId = message.data['user_id'];
      final tagUid = message.data['tag_uid'];
      _showVerificationDialog(userId, tagUid);
    }
  });


  FirebaseMessaging.instance.getToken().then((token) {
    if (token != null) {
      debugPrint('✅ Initial FCM Token: $token');
    } else {
      debugPrint('⚠️ FCM Token initial null!');
    }
  });

  runApp(const SmartGateApp());
}

class SmartGateApp extends StatelessWidget {
  const SmartGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Gate',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),

      home: const LoginPage(),
    );
  }
}

Future<void> saveFcmToken(String userId) async {
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken == null) {
      debugPrint('⚠️ FCM token null (tidak tersedia saat ini)');
      return;
    }

    debugPrint('📡 Mengirim FCM token ke server: $fcmToken');

    final response = await http.post(
      Uri.parse('https://b6b4-103-164-80-99.ngrok-free.app/api/save-fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'user_id': userId, 'fcm_token': fcmToken}),
    );

    debugPrint('✅ Token saved response: ${response.statusCode} ${response.body}');
  } catch (e) {
    debugPrint('❌ Gagal simpan token ke server: $e');
  }
}

void _showVerificationDialog(String userId, String tagUid) {
  debugPrint("🧪 Menampilkan dialog verifikasi untuk $tagUid oleh user $userId");

  showDialog(
    context: navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Verifikasi Akses'),
        content: Text('User ID $userId ingin membuka gate untuk tag $tagUid. Setujui?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendVerificationResponse(userId, tagUid, false);
            },
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: _isSendingResponse
            ? null
            : () {
              Navigator.of(context).pop();
              _sendVerificationResponse(userId, tagUid, true);
            },
            child: const Text('YES'),
          ),
        ],
      );
    },
  );
}

bool _isSendingResponse = false;

Future<void> _sendVerificationResponse(String userId, String tagUid, bool approved) async {
  if (_isSendingResponse) {
    debugPrint('⏳ Respon sedang dikirim, abaikan input duplikat');
    return;
  }

  _isSendingResponse = true;

  try {
    final response = await http.post(
      Uri.parse('https://b6b4-103-164-80-99.ngrok-free.app/api/verify-response'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'tag_uid': tagUid,
        'response': approved ? 'yes' : 'no',
      }),
    );

    debugPrint('📤 Respon verifikasi dikirim: ${response.statusCode}');
    debugPrint('📨 Body: ${response.body}');

    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text('Respon "${approved ? 'YES' : 'NO'}" telah dikirim.'),
      ),
    );

    if (response.statusCode != 200) {
      debugPrint('❌ Gagal: respons bukan 200');
    }
  } catch (e) {
    debugPrint('❌ Gagal kirim respon verifikasi: $e');
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      const SnackBar(content: Text('❌ Gagal mengirim respon.')),
    );
  } finally {
    // Reset hanya setelah semua selesai
    _isSendingResponse = false;
  }
}

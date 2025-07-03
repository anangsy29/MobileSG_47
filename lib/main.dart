import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'pages/login_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] == 'verification') {
    // ❌ Jangan panggil showLocalNotification di background
    debugPrint('📥 Background notification received');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔔 Izin notifikasi
  final settings = await FirebaseMessaging.instance.requestPermission();
  debugPrint('🔔 Notifikasi diizinkan: ${settings.authorizationStatus}');

  // 🔔 Inisialisasi Local Notification
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payloadJson = response.payload ?? '{}';
      final data = jsonDecode(payloadJson);
      final userId = data['user_id'];
      final tagUid = data['tag_uid'];
      if (response.actionId == 'yes') {
        debugPrint(
          '✅ Pengguna memilih YES untuk user_id: $userId, tag: $tagUid',
        );
        _sendVerificationResponse(userId, tagUid, true);
      } else if (response.actionId == 'no') {
        debugPrint(
          '❌ Pengguna memilih NO untuk user_id: $userId, tag: $tagUid',
        );
        _sendVerificationResponse(userId, tagUid, false);
      }
    },
  );

  // 🔄 Handler background message
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 📩 Saat user klik notifikasi dari tray
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.data['type'] == 'verification') {
      showLocalNotification(message.data['user_id'], message.data['tag_uid']);
    }
  });

  // 🔁 Debug token awal
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      navigatorKey: navigatorKey,
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
      Uri.parse(
        'https://4986-103-164-80-99.ngrok-free.app/api/save-fcm-token',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'user_id': userId, 'fcm_token': fcmToken}),
    );

    debugPrint(
      '✅ Token saved response: ${response.statusCode} ${response.body}',
    );
  } catch (e) {
    debugPrint('❌ Gagal simpan token ke server: $e');
  }
}

Future<void> showLocalNotification(String userId, String tagUid) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'verification_channel',
        'Verifikasi Smart Gate',
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('yes', 'Yes'),
          AndroidNotificationAction('no', 'No'),
        ],
      );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  final payload = jsonEncode({'user_id': userId, 'tag_uid': tagUid}); // ✅

  await flutterLocalNotificationsPlugin.show(
    0,
    'Verifikasi Akses',
    'Apakah anda ingin membuka gate?',
    platformChannelSpecifics,
    payload: payload,
  );
}

Future<void> _sendVerificationResponse(String userId, String tagUid, bool approved) async {
  try {
    final response = await http.post(
      Uri.parse(
        'https://4986-103-164-80-99.ngrok-free.app/api/verify-response',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'tag_uid': tagUid,
        'approved': approved,
      }),
    );

    debugPrint('📤 Respon verifikasi dikirim: ${response.statusCode}');
  } catch (e) {
    debugPrint('❌ Gagal kirim respon verifikasi: $e');
  }
}

/// Dialog konfirmasi verifikasi
// void _showVerificationDialog(String userId) {
//   showDialog(
//     context: navigatorKey.currentContext!,
//     builder: (_) => AlertDialog(
//       title: const Text('Verifikasi Akses'),
//       content: const Text('Apakah Anda ingin membuka gate?'),
//       actions: [
//         TextButton(
//           onPressed: () async {
//             Navigator.pop(navigatorKey.currentContext!);
//             await _sendVerificationResponse(userId, false);
//           },
//           child: const Text('TIDAK'),
//         ),
//         ElevatedButton(
//           onPressed: () async {
//             Navigator.pop(navigatorKey.currentContext!);
//             await _sendVerificationResponse(userId, true);
//           },
//           child: const Text('YA'),
//         ),
//       ],
//     ),
//   );
// }

// /// Kirim respon verifikasi ke backend
// Future<void> _sendVerificationResponse(String userId, bool approved) async {
//   try {
//     final response = await http.post(
//       Uri.parse('https://a1b6-103-164-80-99.ngrok-free.app/api/open-gate'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'user_id': userId, 'approved': approved}),
//     );
//     final result = jsonDecode(response.body);
//     debugPrint('✅ Respon server: $result');
//     _showSnackbar(result['message'] ?? 'Respon terkirim');
//   } catch (e) {
//     debugPrint('❌ Gagal kirim respon: $e');
//     _showSnackbar('Gagal kirim ke server.');
//   }
// }

// /// Tampilkan snackbar di bawah
// void _showSnackbar(String message) {
//   ScaffoldMessenger.of(
//     navigatorKey.currentContext!,
//   ).showSnackBar(SnackBar(content: Text(message)));
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'pages/login_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Tambahkan logika jika perlu
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      final tagId = 'TAG123'; // Ganti ini kalau tag_id dikirim lewat FCM

      if (payload == 'yes' || payload == 'no') {
        final action = (payload == 'yes') ? 'approve' : 'reject';
        final backendUrl =
            'https://192.168.100.20:8000/api/gate-response'; // Ganti URL

        final result = await http.post(
          Uri.parse(backendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'tag_id': tagId, 'response': action}),
        );

        print('🔁 Respon "$action" dikirim ke backend: ${result.statusCode}');
      }
    },
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const SmartGateApp());
}

class SmartGateApp extends StatefulWidget {
  const SmartGateApp({super.key});
  @override
  State<SmartGateApp> createState() => _SmartGateAppState();
}

class _SmartGateAppState extends State<SmartGateApp> {
  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['notification_type'] == 'gate_verification') {
        _showGateVerificationNotification();
      }
    });

    _sendFcmTokenToBackend();
  }

  Future<void> _sendFcmTokenToBackend() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token == null) {
        print('❌ Token FCM masih null!');
        return;
      }

      print('✅ Token FCM berhasil diambil: $token');

      final response = await http.post(
        Uri.parse('https://192.168.100.20:8000/api/save-fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 2, 'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        print("✅ Token berhasil dikirim ke backend.");
      } else {
        print("⚠️ Gagal kirim token. Status code: ${response.statusCode}");
        print("🪵 Response: ${response.body}");
      }
    } catch (e) {
      print('❌ Error saat kirim token FCM ke backend: $e');
    }
  }

  void _showGateVerificationNotification() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'gate_verif_channel',
          'Gate Verification',
          channelDescription: 'Verifikasi kendaraan masuk gate',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('yes', 'YES', showsUserInterface: true),
            AndroidNotificationAction('no', 'NO', showsUserInterface: true),
          ],
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    flutterLocalNotificationsPlugin.show(
      0,
      'Verifikasi Akses',
      'Izinkan kendaraan melewati gate?',
      notificationDetails,
      payload: 'yes',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Gate',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

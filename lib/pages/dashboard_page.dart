import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;

  const DashboardPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> accessLogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAccessLogs();
  }

  Future<void> fetchAccessLogs() async {
    final url = Uri.parse(
      'https://b6b4-103-164-80-99.ngrok-free.app/api/access-logs/${widget.userId}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          accessLogs = data['logs'];
          isLoading = false;
        });
      } else {
        debugPrint('❌ Gagal mengambil log: ${response.statusCode}');
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil log akses')),
        );
      }
    } catch (e) {
      debugPrint('❌ Exception ambil log akses: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat mengambil log')),
      );
    }
  }

  Future<void> _refreshLogs() async {
    setState(() => isLoading = true);
    await fetchAccessLogs();
  }

  Future<void> _sendVerificationResponse(
    String userId,
    String tagUid,
    bool approved,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://b6b4-103-164-80-99.ngrok-free.app/api/verify-response',
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Respon "${approved ? 'YES' : 'NO'}" telah dikirim.'),
        ),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Gagal: respons bukan 200');
      }
    } catch (e) {
      debugPrint('❌ Gagal kirim respon verifikasi: $e');
    }
  }

  void _showVerificationDialog(String userId, String tagUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verifikasi Akses'),
        content: const Text('Apakah Anda ingin membuka gate?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendVerificationResponse(userId, tagUid, false);
            },
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendVerificationResponse(userId, tagUid, true);
            },
            child: const Text('YES'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${widget.userName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: 'Tes Kirim Notifikasi dari Laravel',
            onPressed: () async {
              final tagUid = 'E2804850'; // tag test kamu
              final userId = widget.userId;

              final response = await http.post(
                Uri.parse('https://b6b4-103-164-80-99.ngrok-free.app/api/send-verification'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({'user_id': userId, 'tag_uid': tagUid}),
              );

              if (response.statusCode == 200) {
                debugPrint('✅ Notifikasi dikirim: ${response.body}');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifikasi berhasil dikirim!')),
                );
              } else {
                debugPrint('❌ Gagal kirim notifikasi: ${response.statusCode}');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal kirim notifikasi')),
                );
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Tes Verifikasi Gate',
            onPressed: () async {
              if (accessLogs.isNotEmpty) {
                final lastLog = accessLogs.first;
                final tagUid = lastLog['tags_id'].toString();
                debugPrint(
                  '🔔 Testing verifikasi dialog dengan tag_uid: $tagUid',
                );
                _showVerificationDialog(widget.userId.toString(), tagUid);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tidak ada log untuk uji verifikasi'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    userId: widget.userId,
                    userName: widget.userName,
                    userEmail: widget.userEmail,
                  ),
                ),
              ).then((_) => _refreshLogs());
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : accessLogs.isEmpty
          ? const Center(child: Text('Belum ada log akses'))
          : RefreshIndicator(
              onRefresh: _refreshLogs,
              child: ListView.builder(
                itemCount: accessLogs.length,
                itemBuilder: (context, index) {
                  final log = accessLogs[index];
                  return ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text('Tag ID: ${log['tags_id']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${log['status']}'),
                        if (log['note'] != null)
                          Text('Catatan: ${log['note']}'),
                      ],
                    ),
                    trailing: Text('${log['accessed_at']}'),
                  );
                },
              ),
            ),
    );
  }
}

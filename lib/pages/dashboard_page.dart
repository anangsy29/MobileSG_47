import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_page.dart';
import '../main.dart' show showLocalNotification;

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
      'https://a1b6-103-164-80-99.ngrok-free.app/api/access-logs/${widget.userId}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${widget.userName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Tes Notifikasi',
            onPressed: () {
              showLocalNotification(widget.userId.toString());
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
              ).then(
                (_) => _refreshLogs(),
              ); // Refresh setelah kembali dari profil
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

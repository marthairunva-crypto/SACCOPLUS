import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendToAll() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in both title and message.'),
          backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _sending = true);
    try {
      final snap = await FirebaseService.getAllFarmers().first;
      final farmers = snap.docs;
      for (final f in farmers) {
        final data = f.data() as Map<String, dynamic>;
        final farmerName = (data['name'] as String? ??
                data['fullName'] as String? ??
                'Member')
            .trim();
        final phone = data['phone'] as String? ?? '';
        final personalMsg = 'Dear $farmerName, $msg';

        // Save in-app notification
        await FirebaseService.sendNotification(f.id, title, personalMsg);
        // Also send SMS
        if (phone.isNotEmpty) {
          FirebaseService.sendSmsToPhone(phone, '$title: $personalMsg');
        }
      }
      if (mounted) {
        _titleCtrl.clear();
        _msgCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Notification sent to ${farmers.length} farmer(s).'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compose card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text('Send Notification',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      prefixIcon: Icon(Icons.message_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Send to All Farmers',
                    loading: _sending,
                    onPressed: _sendToAll,
                    icon: Icons.send_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SectionHeader(title: 'Sent Notifications'),
            const SizedBox(height: 12),

            // Stream of all notifications (admin-sent ones)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.getAllNotifications(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                // Deduplicate by title+message to show unique broadcasts
                final seen = <String>{};
                final unique = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final key = '${data['title']}__${data['message']}';
                  if (seen.contains(key)) return false;
                  seen.add(key);
                  return true;
                }).toList();

                if (unique.isEmpty) {
                  return const EmptyState(
                      message: 'No notifications sent yet.',
                      icon: Icons.notifications_off_outlined);
                }

                return Column(
                  children: unique.map((d) {
                    final n = d.data() as Map<String, dynamic>;
                    final ts = n['createdAt'];
                    String timeStr = '';
                    if (ts is Timestamp) {
                      timeStr = DateFormat('MMM d, HH:mm')
                          .format(ts.toDate());
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.notifications_rounded,
                                color: AppTheme.primary,
                                size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                          n['title'] as String? ?? '',
                                          style: GoogleFonts.poppins(
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 13)),
                                    ),
                                    Text(timeStr,
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color:
                                                Colors.grey.shade400)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(n['message'] as String? ?? '',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                        height: 1.4)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.info.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text('All Farmers',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppTheme.info,
                                          fontWeight:
                                              FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

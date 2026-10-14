import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/birthday_service.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _testingSending = false;

  Future<void> _sendTestBirthday() async {
    setState(() => _testingSending = true);
    final uid = FirebaseService.sessionUid;
    final profile = await FirebaseService.getUserProfile(uid);
    if (profile != null) {
      await BirthdayService.forceSend(uid: uid, profile: profile);
    }
    if (mounted) {
      setState(() => _testingSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Birthday notification sent! Check your list.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.sessionUid;

    return FarmerScaffold(
      title: 'Notifications',
      actions: [
        // ── Debug-only: send a test birthday notification ──────────────
        if (kDebugMode)
          _testingSending
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  tooltip: 'Test Birthday Notification',
                  icon: const Icon(Icons.cake_rounded, color: Colors.white),
                  onPressed: _sendTestBirthday,
                ),
        TextButton(
          onPressed: () async {
            final snap = await FirebaseService.getUserNotifications(uid).first;
            for (final doc in snap.docs) {
              final d = doc.data() as Map<String, dynamic>;
              if (d['read'] == false) {
                await FirebaseService.markNotificationRead(doc.id);
              }
            }
          },
          child: Text('Mark all read',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 12)),
        ),
      ],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getUserNotifications(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final docs = snap.data?.docs ?? [];

          // Sort by createdAt descending client-side (avoids composite index requirement)
          final sorted = [...docs]..sort((a, b) {
              final aTs = (a.data() as Map<String, dynamic>)['createdAt'];
              final bTs = (b.data() as Map<String, dynamic>)['createdAt'];
              if (aTs is Timestamp && bTs is Timestamp) {
                return bTs.compareTo(aTs);
              }
              return 0;
            });

          if (sorted.isEmpty) {
            return const EmptyState(
              message: 'No notifications yet.',
              icon: Icons.notifications_off_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final d = sorted[i].data() as Map<String, dynamic>;
              final isRead = d['read'] as bool? ?? true;
              final title = d['title'] as String? ?? 'Notification';
              final message = d['message'] as String? ?? '';
              final notifType = d['type'] as String? ?? '';
              final isBirthday = notifType == 'birthday';
              final ts = d['createdAt'];
              String timeStr = '';
              if (ts is Timestamp) {
                timeStr = DateFormat('MMM d, yyyy  h:mm a').format(ts.toDate());
              }

              return isBirthday
                  ? _BirthdayNotifCard(
                      title: title,
                      message: message,
                      timeStr: timeStr,
                      isRead: isRead,
                      onTap: () {
                        if (!isRead) {
                          FirebaseService.markNotificationRead(sorted[i].id);
                        }
                      },
                    )
                  : GestureDetector(
                onTap: () {
                  if (!isRead) {
                    FirebaseService.markNotificationRead(sorted[i].id);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.white
                        : AppTheme.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead
                          ? Colors.grey.shade200
                          : AppTheme.primary.withOpacity(0.2),
                    ),
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
                        child: const Icon(Icons.notifications_rounded,
                            color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(title,
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppTheme.textPrimary)),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(message,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.4)),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(timeStr,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade400)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Birthday Notification Card ───────────────────────────────────────────────
class _BirthdayNotifCard extends StatelessWidget {
  final String title;
  final String message;
  final String timeStr;
  final bool isRead;
  final VoidCallback onTap;

  const _BirthdayNotifCard({
    required this.title,
    required this.message,
    required this.timeStr,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top navy header bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  // Navy icon box with orange cake icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cake_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Navy-style verified tick in orange
                            const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.accent,
                              size: 15,
                            ),
                          ],
                        ),
                        Text(
                          'SACCOPLUS Pro — Developer',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),

            // ── Message body ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppTheme.textPrimary,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Footer: time + developer badge ────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.accent,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Developer',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

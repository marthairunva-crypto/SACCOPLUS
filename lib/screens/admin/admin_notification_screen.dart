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
  bool _sendToAll = true;
  List<String> _selectedMemberIds = [];
  List<Map<String, dynamic>> _allMembers = [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await FirebaseService.getAllFarmersOnce();
      if (mounted) {
        setState(() {
          _allMembers = members;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  void _showMemberSelectionDialog() {
    final searchController = TextEditingController();
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter members based on search query
          final filteredMembers = searchQuery.isEmpty
              ? _allMembers
              : _allMembers.where((member) {
                  final name = (member['name'] ?? member['fullName'] ?? '').toString().toLowerCase();
                  final phone = (member['phone'] ?? '').toString().toLowerCase();
                  final query = searchQuery.toLowerCase();
                  return name.contains(query) || phone.contains(query);
                }).toList();
          
          return AlertDialog(
            title: Text('Select Members', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                searchController.clear();
                                setDialogState(() => searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setDialogState(() => searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Select/Deselect all
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedMemberIds.length} selected${searchQuery.isNotEmpty ? " · ${filteredMembers.length} shown" : ""}', 
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (_selectedMemberIds.length == _allMembers.length) {
                              _selectedMemberIds.clear();
                            } else {
                              _selectedMemberIds = _allMembers.map((m) => m['id'] as String).toList();
                            }
                          });
                          setState(() {}); // Update parent state too
                        },
                        child: Text(_selectedMemberIds.length == _allMembers.length ? 'Deselect All' : 'Select All'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  
                  // Member list
                  Expanded(
                    child: filteredMembers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No members found',
                                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredMembers.length,
                            itemBuilder: (context, index) {
                              final member = filteredMembers[index];
                              final memberId = member['id'] as String;
                              final memberName = member['name'] ?? member['fullName'] ?? 'Unknown';
                              final memberPhone = member['phone'] ?? '';
                              final isSelected = _selectedMemberIds.contains(memberId);
                              
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      _selectedMemberIds.add(memberId);
                                    } else {
                                      _selectedMemberIds.remove(memberId);
                                    }
                                  });
                                  setState(() {}); // Update parent state too
                                },
                                title: Text(memberName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                                subtitle: memberPhone.isNotEmpty
                                    ? Text(memberPhone, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey))
                                    : Text('No phone number', style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade300)),
                                dense: true,
                                activeColor: AppTheme.primary,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in both title and message.'),
          backgroundColor: AppTheme.error));
      return;
    }
    
    if (!_sendToAll && _selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select at least one member.'),
          backgroundColor: AppTheme.error));
      return;
    }
    
    setState(() => _sending = true);
    try {
      List<String> targetMemberIds;
      
      if (_sendToAll) {
        final snap = await FirebaseService.getAllFarmers().first;
        targetMemberIds = snap.docs.map((doc) => doc.id).toList();
      } else {
        targetMemberIds = _selectedMemberIds;
      }
      
      int sentCount = 0;
      int skippedCount = 0;
      
      for (final memberId in targetMemberIds) {
        final member = _allMembers.firstWhere(
          (m) => m['id'] == memberId,
          orElse: () => <String, dynamic>{},
        );
        
        final farmerName = (member['name'] as String? ??
                member['fullName'] as String? ??
                'Member')
            .trim();
        final phone = member['phone'] as String? ?? '';
        
        debugPrint('📱 Notification - Member: ${member['name'] ?? member['fullName']}');
        debugPrint('   Phone: "${phone}" (isEmpty: ${phone.isEmpty})');
        
        // ONLY send to members with phone numbers
        if (phone.isEmpty) {
          debugPrint('   ⏭️ Skipped - no phone number');
          skippedCount++;
          continue;
        }
        
        final personalMsg = 'Dear $farmerName, $msg';

        // Save in-app notification
        await FirebaseService.sendNotification(memberId, title, personalMsg);
        
        // Also send SMS
        FirebaseService.sendSmsToPhone(phone, '$title: $personalMsg');
        sentCount++;
      }
      
      if (mounted) {
        _titleCtrl.clear();
        _msgCtrl.clear();
        _selectedMemberIds.clear();
        
        String resultMsg = 'Notification sent to $sentCount member(s).';
        if (skippedCount > 0) {
          resultMsg += ' ($skippedCount skipped - no phone number)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(resultMsg),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4)));
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
                  
                  // Recipient selection
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('All Members', style: GoogleFonts.poppins(fontSize: 13)),
                          value: true,
                          groupValue: _sendToAll,
                          onChanged: (value) => setState(() => _sendToAll = value!),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('Selected Members', style: GoogleFonts.poppins(fontSize: 13)),
                          value: false,
                          groupValue: _sendToAll,
                          onChanged: (value) => setState(() => _sendToAll = value!),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  
                  if (!_sendToAll) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadingMembers ? null : _showMemberSelectionDialog,
                      icon: const Icon(Icons.people, size: 18),
                      label: Text(
                        _selectedMemberIds.isEmpty 
                            ? 'Select Members' 
                            : '${_selectedMemberIds.length} member(s) selected',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: _sendToAll ? 'Send to All Members' : 'Send to Selected Members',
                    loading: _sending,
                    onPressed: _sendNotification,
                    icon: Icons.send_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Sent Notifications',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            // Stream of all notifications - show ALL sent notifications, not just unique ones
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('saccoplus-notifications')
                  .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snap.hasError) {
                  return Center(
                    child: Text('Error loading notifications: ${snap.error}', 
                        style: GoogleFonts.poppins(color: Colors.red)),
                  );
                }
                
                final docs = snap.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications sent yet',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                // Group notifications by date for better organization
                final notificationsByDate = <String, List<QueryDocumentSnapshot>>{};
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  if (createdAt != null) {
                    final dateKey = DateFormat('MMMM d, yyyy').format(createdAt);
                    notificationsByDate.putIfAbsent(dateKey, () => []).add(doc);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: notificationsByDate.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            entry.key,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        ...entry.value.map((d) {
                          final n = d.data() as Map<String, dynamic>;
                          final recipient = n['recipientName'] as String? ?? n['farmerName'] as String? ?? 'Member';
                          final ts = n['createdAt'];
                          String timeStr = '';
                          if (ts is Timestamp) {
                            timeStr = DateFormat('HH:mm').format(ts.toDate());
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_rounded,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n['title'] as String? ?? 'Notification',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            timeStr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n['message'] as String? ?? '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.info.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'To: $recipient',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppTheme.info,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
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

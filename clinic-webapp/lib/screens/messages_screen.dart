import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../widgets/top_bar.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  final void Function(String)? onNavigate;
  const MessagesScreen({super.key, this.onNavigate});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;

  // Contacts (staff + patients)
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  Map<String, dynamic>? _selectedContact;

  // Messages in current conversation
  List<Map<String, dynamic>> _messages = [];

  // Last message previews per contact and unread counts
  Map<String, Map<String, dynamic>> _previews = {};
  Map<String, int> _unreadCounts = {};

  // Realtime channels
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _globalChannel;

  // Controllers
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // State flags
  bool _loadingContacts = true;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _uploading = false;
  bool _isContactTyping = false;
  Timer? _typingTimer;
  DateTime? _lastTypingSent;
  int _contactTab = 0; // 0=All, 1=Staff, 2=Patients

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _messageController.addListener(_onTypingChanged);
    _subscribeGlobalMessages();
  }

  @override
  void dispose() {
    _messageChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _globalChannel?.unsubscribe();
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  // ─── DATA LOADING ──────────────────────────────────────────

  Future<void> _loadContacts() async {
    try {
      final myId = _supabase.auth.currentUser?.id;

      // Load staff profiles
      final staffData = await _supabase
          .from('profiles')
          .select('id, full_name, role, department, photo_url')
          .neq('id', myId ?? '');

      final staffContacts = (staffData as List)
          .map<Map<String, dynamic>>((p) => {
                ...Map<String, dynamic>.from(p),
                'contact_type': 'staff',
              })
          .toList();

      // Load patients
      List<Map<String, dynamic>> patientContacts = [];
      try {
        final patientData = await _supabase
            .from('patients')
            .select('id, name, condition, risk_level');
        patientContacts = (patientData as List)
            .map<Map<String, dynamic>>((p) => {
                  'id': p['id'],
                  'full_name': p['name'] ?? 'Unknown',
                  'role': 'patient',
                  'department': p['condition'] ?? '',
                  'risk_level': p['risk_level'] ?? 'Medium',
                  'contact_type': 'patient',
                })
            .toList();
      } catch (e) {
        debugPrint('Error loading patients: $e');
      }

      // Load message previews
      await _loadPreviews(myId ?? '');

      if (mounted) {
        _allContacts = [...staffContacts, ...patientContacts];
        _loadingContacts = false;
        _filterContacts();
      }
    } catch (e) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  Future<void> _loadPreviews(String myId) async {
    try {
      final allMessages = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false);

      _previews.clear();
      _unreadCounts.clear();

      for (final msg in (allMessages as List)) {
        final senderId = msg['sender_id'] as String?;
        final receiverId = msg['receiver_id'] as String?;
        final patientId = msg['receiver_patient_id'] as String?;

        String? partnerId;
        if (senderId == myId) {
          partnerId = patientId ?? receiverId;
        } else {
          partnerId = senderId;
        }
        if (partnerId == null) continue;

        // Store first (latest) message per partner as preview
        if (!_previews.containsKey(partnerId)) {
          _previews[partnerId] = Map<String, dynamic>.from(msg);
        }

        // Count unread (messages TO me that are not read)
        if (receiverId == myId && msg['is_read'] == false) {
          _unreadCounts[partnerId] = (_unreadCounts[partnerId] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint('Error loading previews: $e');
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    var filtered = _allContacts.where((c) {
      // Filter by tab
      if (_contactTab == 1 && c['contact_type'] != 'staff') return false;
      if (_contactTab == 2 && c['contact_type'] != 'patient') return false;

      // Filter by search
      if (query.isEmpty) return true;
      final name = (c['full_name'] as String? ?? '').toLowerCase();
      final role = (c['role'] as String? ?? '').toLowerCase();
      final dept = (c['department'] as String? ?? '').toLowerCase();
      return name.contains(query) ||
          role.contains(query) ||
          dept.contains(query);
    }).toList();

    // Sort: contacts with recent messages first, then alphabetically
    filtered.sort((a, b) {
      final aPreview = _previews[a['id']];
      final bPreview = _previews[b['id']];
      if (aPreview != null && bPreview != null) {
        return (bPreview['created_at'] as String)
            .compareTo(aPreview['created_at'] as String);
      }
      if (aPreview != null) return -1;
      if (bPreview != null) return 1;
      return (a['full_name'] as String? ?? '')
          .compareTo(b['full_name'] as String? ?? '');
    });

    setState(() => _filteredContacts = filtered);
  }

  // ─── CONVERSATION ──────────────────────────────────────────

  Future<void> _selectContact(Map<String, dynamic> contact) async {
    _messageChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _typingTimer?.cancel();

    setState(() {
      _selectedContact = contact;
      _messages = [];
      _loadingMessages = true;
      _isContactTyping = false;
    });

    final contactId = contact['id'] as String;
    final isPatient = contact['contact_type'] == 'patient';

    await _loadMessages(contactId, isPatient);
    if (!isPatient) {
      await _markAsRead(contactId);
    }
    _subscribeToMessages(contactId, isPatient);
    if (!isPatient) {
      _subscribeToTyping(contactId);
    }
  }

  Future<void> _loadMessages(String contactId, bool isPatient) async {
    try {
      final myId = _supabase.auth.currentUser?.id ?? '';
      List<dynamic> data;

      if (isPatient) {
        data = await _supabase
            .from('messages')
            .select()
            .eq('sender_id', myId)
            .eq('receiver_patient_id', contactId)
            .order('created_at', ascending: true);
      } else {
        data = await _supabase
            .from('messages')
            .select()
            .or('and(sender_id.eq.$myId,receiver_id.eq.$contactId),and(sender_id.eq.$contactId,receiver_id.eq.$myId)')
            .order('created_at', ascending: true);
      }

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _markAsRead(String contactId) async {
    final myId = _supabase.auth.currentUser?.id ?? '';
    try {
      await _supabase
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('sender_id', contactId)
          .eq('receiver_id', myId)
          .eq('is_read', false);

      // Update local state
      setState(() {
        for (final msg in _messages) {
          if (msg['sender_id'] == contactId && msg['receiver_id'] == myId) {
            msg['is_read'] = true;
            msg['read_at'] = DateTime.now().toUtc().toIso8601String();
          }
        }
        _unreadCounts.remove(contactId);
      });

      // Refresh badge count in provider
      if (mounted) {
        context.read<AppProvider>().refreshUnreadMessages();
      }
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  // ─── REALTIME ──────────────────────────────────────────────

  void _subscribeGlobalMessages() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    _globalChannel = _supabase.channel('global_msgs_$myId');
    _globalChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final msg = payload.newRecord;
        final senderId = msg['sender_id'] as String?;
        final receiverId = msg['receiver_id'] as String?;

        if (receiverId == myId && senderId != null) {
          // Skip if this is from the currently active conversation
          if (_selectedContact != null &&
              _selectedContact!['id'] == senderId &&
              _selectedContact!['contact_type'] == 'staff') {
            setState(() {
              _previews[senderId] = Map<String, dynamic>.from(msg);
            });
            return;
          }

          setState(() {
            _previews[senderId] = Map<String, dynamic>.from(msg);
            _unreadCounts[senderId] =
                (_unreadCounts[senderId] ?? 0) + 1;
            _filterContacts();
          });
        }
      },
    );
    _globalChannel!.subscribe();
  }

  void _subscribeToMessages(String contactId, bool isPatient) {
    final myId = _supabase.auth.currentUser?.id ?? '';
    _messageChannel = _supabase.channel('conv_${myId}_$contactId');

    // Listen for new messages (INSERT)
    _messageChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newMsg = payload.newRecord;
        if (!_belongsToConversation(newMsg, myId, contactId, isPatient)) {
          return;
        }

        // Deduplicate (don't add if already present from optimistic update)
        if (_messages.any((m) => m['id'] == newMsg['id'])) return;
        // Remove matching optimistic message
        _messages.removeWhere((m) =>
            m['id'].toString().startsWith('temp_') &&
            m['content'] == newMsg['content'] &&
            m['sender_id'] == newMsg['sender_id']);

        if (mounted) {
          setState(() => _messages.add(newMsg));
          _scrollToBottom();

          // Auto-mark as read if from the contact
          if (newMsg['sender_id'] == contactId && !isPatient) {
            _markAsRead(contactId);
          }
        }
      },
    );

    // Listen for message updates (read receipts)
    _messageChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final updated = payload.newRecord;
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m['id'] == updated['id']);
            if (idx != -1) {
              _messages[idx] = Map<String, dynamic>.from(updated);
            }
          });
        }
      },
    );

    _messageChannel!.subscribe();
  }

  bool _belongsToConversation(Map<String, dynamic> msg, String myId,
      String contactId, bool isPatient) {
    if (isPatient) {
      return msg['sender_id'] == myId &&
          msg['receiver_patient_id'] == contactId;
    }
    final senderId = msg['sender_id'] as String?;
    final receiverId = msg['receiver_id'] as String?;
    return (senderId == myId && receiverId == contactId) ||
        (senderId == contactId && receiverId == myId);
  }

  void _subscribeToTyping(String contactId) {
    final myId = _supabase.auth.currentUser?.id ?? '';
    final key = _conversationKey(myId, contactId);
    _typingChannel = _supabase.channel('typing_$key');

    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final typingUserId = payload['user_id'] as String?;
        if (typingUserId == contactId && mounted) {
          setState(() => _isContactTyping = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isContactTyping = false);
          });
        }
      },
    );

    _typingChannel!.subscribe();
  }

  String _conversationKey(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  void _onTypingChanged() {
    if (_selectedContact == null ||
        _selectedContact!['contact_type'] == 'patient') return;
    if (_messageController.text.isEmpty) return;

    final now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!).inSeconds < 2) return;
    _lastTypingSent = now;

    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _supabase.auth.currentUser?.id ?? ''},
    );
  }

  // ─── SEND MESSAGE ─────────────────────────────────────────

  Future<void> _sendMessage(
      {String? content,
      String messageType = 'text',
      String? fileUrl,
      String? fileName}) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty && fileUrl == null) return;
    if (_selectedContact == null) return;

    final myId = _supabase.auth.currentUser?.id ?? '';
    final isPatient = _selectedContact!['contact_type'] == 'patient';
    if (content == null) _messageController.clear();

    // Optimistically add message to local list
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = {
      'id': tempId,
      'sender_id': myId,
      'receiver_id': isPatient ? null : _selectedContact!['id'],
      'receiver_patient_id': isPatient ? _selectedContact!['id'] : null,
      'content': text,
      'message_type': messageType,
      'file_url': fileUrl,
      'file_name': fileName,
      'is_read': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _messages.add(optimisticMsg);
      _sending = messageType == 'text';
    });
    _scrollToBottom();

    try {
      final insertData = <String, dynamic>{
        'sender_id': myId,
        'content': text,
        'message_type': messageType,
      };

      if (isPatient) {
        insertData['receiver_patient_id'] = _selectedContact!['id'];
      } else {
        insertData['receiver_id'] = _selectedContact!['id'];
      }

      if (fileUrl != null) insertData['file_url'] = fileUrl;
      if (fileName != null) insertData['file_name'] = fileName;

      await _supabase.from('messages').insert(insertData);

      // Update preview
      _previews[_selectedContact!['id']] = optimisticMsg;
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*,video/*,.pdf,.doc,.docx,.txt,.xlsx,.csv';
    input.click();

    await input.onChange.first;
    if (input.files?.isEmpty ?? true) return;

    final file = input.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final bytes = Uint8List.fromList((reader.result as List<int>));
    final fileName = file.name;
    final mimeType = file.type ?? 'application/octet-stream';

    // Determine message type
    String messageType = 'file';
    if (mimeType.startsWith('image/')) messageType = 'image';
    if (mimeType.startsWith('video/')) messageType = 'video';

    setState(() => _uploading = true);

    try {
      final myId = _supabase.auth.currentUser?.id ?? '';
      final path =
          '$myId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _supabase.storage.from('chat-files').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final publicUrl =
          _supabase.storage.from('chat-files').getPublicUrl(path);

      await _sendMessage(
        content: fileName,
        messageType: messageType,
        fileUrl: publicUrl,
        fileName: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── BUILD METHODS ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      children: [
        TopBar(
          onProfileTap: () => widget.onNavigate?.call('/settings'),
          onNavigate: widget.onNavigate,
        ),
        Expanded(
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildContactList(),
        Expanded(
          child: _selectedContact == null
              ? _buildEmptyState()
              : _buildChatArea(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedContact == null) {
      return _buildContactList(fullWidth: true);
    }
    return Column(
      children: [
        _buildMobileChatHeader(),
        Expanded(child: _buildChatMessages()),
        if (_isContactTyping) _buildTypingIndicator(),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMobileChatHeader() {
    final t = AppColors.themed(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedContact = null),
          ),
          _contactAvatar(_selectedContact!, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedContact!['full_name'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isContactTyping)
                  Text('typing...',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                          fontStyle: FontStyle.italic))
                else
                  Text(
                    _selectedContact!['contact_type'] == 'patient'
                        ? 'Patient · ${_selectedContact!['department'] ?? ''}'
                        : '${_capitalize(_selectedContact!['role'] as String? ?? '')} · ${_selectedContact!['department'] ?? ''}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CONTACT LIST ──────────────────────────────────────────

  Widget _buildContactList({bool fullWidth = false}) {
    final t = AppColors.themed(context);
    return Container(
      width: fullWidth ? double.infinity : 300,
      decoration: BoxDecoration(
        color: t.surface,
        border: fullWidth
            ? null
            : Border(right: BorderSide(color: t.divider)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Messages',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.themed(context).textPrimary),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterContacts(),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle:
                    TextStyle(fontSize: 13, color: AppColors.themed(context).textHint),
                prefixIcon:
                    Icon(Icons.search, size: 18, color: AppColors.themed(context).textHint),
                filled: true,
                fillColor: AppColors.themed(context).surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // Tabs: All / Staff / Patients
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildTabChip('All', 0),
                const SizedBox(width: 6),
                _buildTabChip('Staff', 1),
                const SizedBox(width: 6),
                _buildTabChip('Patients', 2),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contact list
          Expanded(
            child: _loadingContacts
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Text('No contacts found',
                            style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (_, i) =>
                            _buildContactTile(_filteredContacts[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final selected = _contactTab == index;
    final t = AppColors.themed(context);
    return GestureDetector(
      onTap: () {
        _contactTab = index;
        _filterContacts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E88E5) : t.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : t.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact) {
    final isSelected = _selectedContact?['id'] == contact['id'];
    final preview = _previews[contact['id']];
    final unread = _unreadCounts[contact['id']] ?? 0;
    final isPatient = contact['contact_type'] == 'patient';

    // Build preview text
    String? previewText;
    String? previewTime;
    if (preview != null) {
      final msgType = preview['message_type'] as String? ?? 'text';
      if (msgType == 'image') {
        previewText = '📷 Image';
      } else if (msgType == 'video') {
        previewText = '🎬 Video';
      } else if (msgType == 'file') {
        previewText = '📎 ${preview['file_name'] ?? 'File'}';
      } else {
        previewText = preview['content'] as String?;
      }

      if (preview['created_at'] != null) {
        final dt = DateTime.tryParse(preview['created_at'] as String);
        if (dt != null) {
          final now = DateTime.now();
          final local = dt.toLocal();
          if (now.difference(local).inDays == 0) {
            previewTime = DateFormat('h:mm a').format(local);
          } else if (now.difference(local).inDays < 7) {
            previewTime = DateFormat('EEE').format(local);
          } else {
            previewTime = DateFormat('MMM d').format(local);
          }
        }
      }
    }

    return InkWell(
      onTap: () => _selectContact(contact),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E88E5).withOpacity(0.08)
              : null,
          border:
              Border(bottom: BorderSide(color: AppColors.themed(context).divider)),
        ),
        child: Row(
          children: [
            // Avatar with patient badge
            Stack(
              children: [
                _contactAvatar(contact, radius: 22),
                if (isPatient)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.person, size: 10,
                          color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact['full_name'] as String? ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (previewTime != null)
                        Text(
                          previewTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: unread > 0
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade500,
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          previewText ??
                              (isPatient
                                  ? contact['department'] ?? ''
                                  : '${_capitalize(contact['role'] as String? ?? '')} · ${contact['department'] ?? ''}'),
                          style: TextStyle(
                            fontSize: 12,
                            color: unread > 0
                                ? Colors.grey.shade800
                                : Colors.grey.shade500,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
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

  // ─── CHAT AREA ─────────────────────────────────────────────

  Widget _buildChatArea() {
    final t = AppColors.themed(context);
    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(bottom: BorderSide(color: t.divider)),
          ),
          child: Row(
            children: [
              _contactAvatar(_selectedContact!, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedContact!['full_name'] as String? ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (_isContactTyping)
                      Text('typing...',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                              fontStyle: FontStyle.italic))
                    else
                      Text(
                        _selectedContact!['contact_type'] == 'patient'
                            ? 'Patient · ${_selectedContact!['department'] ?? ''}'
                            : '${_capitalize(_selectedContact!['role'] as String? ?? '')} · ${_selectedContact!['department'] ?? ''}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildChatMessages()),
        if (_isContactTyping) _buildTypingIndicator(),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (_) {
                return Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_selectedContact?['full_name']?.toString().split(' ').first ?? ''} is typing...',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    return _loadingMessages
        ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty
            ? Center(
                child: Text(
                  'No messages yet.\nSay hello!',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  final isMe =
                      msg['sender_id'] == _supabase.auth.currentUser?.id;
                  return _buildMessageBubble(msg, isMe);
                },
              );
  }

  Widget _buildMessageInput() {
    final t = AppColors.themed(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          // Attachment button
          _uploading
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
              : IconButton(
                  icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
                  onPressed: _pickAndSendFile,
                  tooltip: 'Send file, image or video',
                ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFF1E88E5),
                  iconSize: 28,
                  onPressed: _sendMessage,
                ),
        ],
      ),
    );
  }

  // ─── MESSAGE BUBBLE ────────────────────────────────────────

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final time = msg['created_at'] != null
        ? DateFormat('h:mm a')
            .format(DateTime.parse(msg['created_at'] as String).toLocal())
        : '';
    final messageType = msg['message_type'] as String? ?? 'text';
    final fileUrl = msg['file_url'] as String?;
    final fileName = msg['file_name'] as String?;
    final isRead = msg['is_read'] == true;
    final readAt = msg['read_at'] as String?;

    Widget contentWidget;

    if (messageType == 'image' && fileUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _showImageViewer(fileUrl, fileName),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                fileUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    )),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 100,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    SizedBox(width: 3),
                    Text('View', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (messageType == 'video' && fileUrl != null) {
      contentWidget = Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => html.window.open(fileUrl, '_blank'),
              child: Icon(Icons.play_circle_fill,
                  color: isMe ? Colors.white : Colors.blue, size: 32),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: InkWell(
                onTap: () => html.window.open(fileUrl, '_blank'),
                child: Text(
                  fileName ?? 'Video',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.grey.shade900,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _downloadFile(fileUrl, fileName),
              child: Tooltip(
                message: 'Download',
                child: Icon(Icons.download_rounded,
                    color: isMe ? Colors.white70 : Colors.blue.shade700,
                    size: 20),
              ),
            ),
          ],
        ),
      );
    } else if (messageType == 'file' && fileUrl != null) {
      contentWidget = Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => html.window.open(fileUrl, '_blank'),
              child: Icon(Icons.insert_drive_file,
                  color: isMe ? Colors.white70 : Colors.blue, size: 28),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: InkWell(
                onTap: () => html.window.open(fileUrl, '_blank'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName ?? 'File',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.grey.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tap to open',
                      style: TextStyle(
                        color: isMe ? Colors.white60 : Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _downloadFile(fileUrl, fileName),
              child: Tooltip(
                message: 'Download',
                child: Icon(Icons.download_rounded,
                    color: isMe ? Colors.white70 : Colors.blue.shade700,
                    size: 20),
              ),
            ),
          ],
        ),
      );
    } else {
      contentWidget = Text(
        msg['content'] as String? ?? '',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.grey.shade900,
          fontSize: 14,
        ),
      );
    }

    // Seen info tooltip
    String statusText = time;
    if (isMe && isRead && readAt != null) {
      final seenTime = DateTime.tryParse(readAt);
      if (seenTime != null) {
        statusText +=
            ' · Seen ${DateFormat('h:mm a').format(seenTime.toLocal())}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _roleColor(
                  _selectedContact?['role'] as String? ?? ''),
              child: Text(
                (_selectedContact?['full_name'] as String? ?? '?')[0]
                    .toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.45),
                padding: EdgeInsets.symmetric(
                  horizontal: messageType != 'text' ? 4 : 14,
                  vertical: messageType != 'text' ? 4 : 10,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF1E88E5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: contentWidget,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: statusText,
                    child: Text(time,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: isRead ? 'Seen' : 'Delivered',
                      child: Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead
                            ? const Color(0xFF1E88E5)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a contact to start messaging',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── MEDIA VIEWER & DOWNLOAD ────────────────────────────────────────────

  void _showImageViewer(String url, String? fileName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dismiss on background tap
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.transparent),
            ),
            // Zoomable image
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
            // Top action bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black45,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (fileName != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            fileName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                      tooltip: 'Download',
                      onPressed: () => _downloadFile(url, fileName),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new,
                          color: Colors.white),
                      tooltip: 'Open in new tab',
                      onPressed: () => html.window.open(url, '_blank'),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url, String? name) async {
    try {
      final request =
          await html.HttpRequest.request(url, responseType: 'blob');
      final blob = request.response as html.Blob;
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: objectUrl)
        ..download = name ?? 'download'
        ..click();
      html.Url.revokeObjectUrl(objectUrl);
    } catch (_) {
      // Fallback: open in new tab
      html.window.open(url, '_blank');
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return const Color(0xFF1E88E5);
      case 'nurse':
        return const Color(0xFF43A047);
      case 'admin':
        return const Color(0xFF8E24AA);
      case 'patient':
        return const Color(0xFFFF7043);
      default:
        return Colors.grey;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _contactAvatar(Map<String, dynamic> contact, {double radius = 22}) {
    final photoUrl = contact['photo_url'] as String?;
    final name = contact['full_name'] as String? ?? '?';
    final role = contact['role'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bgColor = _roleColor(role);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
        child: const SizedBox.shrink(),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

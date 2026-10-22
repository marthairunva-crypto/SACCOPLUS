import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import 'farmer_scaffold.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _Msg {
  final String role;   // 'user' | 'assistant'
  final String text;
  final bool isError;
  _Msg({required this.role, required this.text, this.isError = false});
  bool get isUser => role == 'user';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl    = TextEditingController();
  final _scroll  = ScrollController();
  final _msgs    = <_Msg>[];
  bool _loading  = false;

  // Suggested starter questions
  static const _suggestions = [
    'How do I deposit money to my wallet?',
    'What are the loan requirements?',
    'How does Fixed Deposit work?',
    'How do I buy airtime or data?',
    'Explain SACCO shares to me',
  ];

  @override
  void initState() {
    super.initState();
    // Greeting
    _msgs.add(_Msg(
      role: 'assistant',
      text: 'Hi there! 👋 I\'m your MBADIFA SACCO AI Assistant. I can help you with your wallet, savings, loans, airtime, bill payments, and anything else about the app. What can I help you with today?',
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _loading) return;

    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg(role: 'user', text: text));
      _loading = true;
    });
    _scrollToBottom();

    try {
      // Build history (last 10 exchanges to keep tokens low)
      final history = _msgs
          .where((m) => !m.isError)
          .take(_msgs.length)
          .toList()
          .reversed
          .take(20)
          .toList()
          .reversed
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();

      final uri = Uri.parse('${AppConstants.renderProxyUrl}/ai/chat');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Proxy-Key': AppConstants.marzPayProxyKey,
            },
            body: jsonEncode({'messages': history}),
          )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json.containsKey('reply')) {
        setState(() => _msgs.add(_Msg(role: 'assistant', text: json['reply'] as String)));
      } else {
        final err = json['error'] as String? ?? 'Something went wrong. Please try again.';
        setState(() => _msgs.add(_Msg(role: 'assistant', text: err, isError: true)));
      }
    } catch (e) {
      setState(() => _msgs.add(_Msg(
          role: 'assistant',
          text: 'Connection error. Check your internet and try again.',
          isError: true)));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = FirebaseService.sessionProfile?['name'] as String? ?? 'Member';
    return FarmerScaffold(
      title: 'AI Assistant',
      showBack: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded),
          tooltip: 'Clear chat',
          onPressed: () => setState(() {
            _msgs.clear();
            _msgs.add(_Msg(
              role: 'assistant',
              text: 'Chat cleared. How can I help you, $name?',
            ));
          }),
        ),
      ],
      body: Column(
        children: [
          // ── Messages ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _msgs.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _msgs.length) return _TypingIndicator();
                final msg = _msgs[i];
                return _BubbleRow(msg: msg, onCopy: () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                });
              },
            ),
          ),

          // ── Suggestions (only when just greeting shown) ────────────────
          if (_msgs.length == 1 && !_loading)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _send(_suggestions[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
                    ),
                    child: Text(_suggestions[i],
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          if (_msgs.length == 1 && !_loading) const SizedBox(height: 8),

          // ── Input bar ──────────────────────────────────────────────────
          _InputBar(
            ctrl: _ctrl,
            loading: _loading,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

// ─── Bubble ───────────────────────────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  final _Msg msg;
  final VoidCallback onCopy;
  const _BubbleRow({required this.msg, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            // AI avatar — clean sparkle icon, no star
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: msg.isUser
                      ? AppTheme.accent
                      : msg.isError
                          ? const Color(0xFFFFF0F0)
                          : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                    bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                  ),
                  border: msg.isUser
                      ? null
                      : Border.all(
                          color: msg.isError
                              ? AppTheme.error.withOpacity(0.25)
                              : const Color(0xFFE4E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // User bubbles stay plain text; AI bubbles get markdown rendering
                child: msg.isUser
                    ? Text(
                        msg.text,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5, color: Colors.white, height: 1.5,
                        ),
                      )
                    : _MarkdownText(
                        text: msg.text,
                        isError: msg.isError,
                      ),
              ),
            ),
          ),

          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Lightweight markdown renderer ────────────────────────────────────────────
// Handles: **bold**, *italic*, numbered lists, bullet lists, plain paragraphs.
// No external dependency needed.

class _MarkdownText extends StatelessWidget {
  final String text;
  final bool isError;
  const _MarkdownText({required this.text, this.isError = false});

  static const _textColor   = AppTheme.textPrimary;
  static const _errorColor  = AppTheme.error;
  static const _accentColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final baseColor = isError ? _errorColor : _textColor;
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip empty lines — add a small gap instead
      if (trimmed.isEmpty) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Numbered list item: "1. text", "2. text"
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmed);
      if (numMatch != null) {
        widgets.add(_ListItem(
          bullet: '${numMatch.group(1)}.',
          content: numMatch.group(2)!,
          baseColor: baseColor,
          accentColor: _accentColor,
          numbered: true,
        ));
        continue;
      }

      // Bullet list item: "- text" or "• text" or "* text"
      final bulletMatch = RegExp(r'^[-•*]\s+(.+)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(_ListItem(
          bullet: '•',
          content: bulletMatch.group(1)!,
          baseColor: baseColor,
          accentColor: _accentColor,
          numbered: false,
        ));
        continue;
      }

      // Plain paragraph line — render inline bold/italic
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _InlineText(text: trimmed, baseColor: baseColor),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

// Renders inline **bold** and *italic* within a single line.
class _InlineText extends StatelessWidget {
  final String text;
  final Color baseColor;
  const _InlineText({required this.text, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    final spans = _parseInline(text, baseColor);
    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }

  static List<TextSpan> _parseInline(String text, Color baseColor) {
    final spans = <TextSpan>[];
    // Match **bold** or *italic*
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int last = 0;

    final baseStyle = GoogleFonts.poppins(
      fontSize: 13.5, color: baseColor, height: 1.5,
    );

    for (final match in pattern.allMatches(text)) {
      // Text before match
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null) {
        // `code`
        spans.add(TextSpan(
          text: match.group(3),
          style: GoogleFonts.robotoMono(
            fontSize: 12.5, color: const Color(0xFF1565C0),
            backgroundColor: const Color(0xFFE8F0FE),
          ),
        ));
      }
      last = match.end;
    }

    // Remaining text
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return spans.isEmpty
        ? [TextSpan(text: text, style: baseStyle)]
        : spans;
  }
}

// A single list item row with bullet/number + content.
class _ListItem extends StatelessWidget {
  final String bullet;
  final String content;
  final Color baseColor;
  final Color accentColor;
  final bool numbered;
  const _ListItem({
    required this.bullet,
    required this.content,
    required this.baseColor,
    required this.accentColor,
    required this.numbered,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: numbered ? 22 : 16,
            child: Text(
              bullet,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: accentColor,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _InlineText(text: content, baseColor: baseColor),
          ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: const Color(0xFFE4E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final t = (_anim.value - delay).clamp(0.0, 1.0);
                    final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onSend;
  const _InputBar({required this.ctrl, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask me anything about MBADIFA SACCO...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFAAAAAA)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.surface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 44, height: 44,
                    child: Center(child: SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accent))),
                  )
                : Material(
                    key: const ValueKey('send'),
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: onSend,
                      child: const SizedBox(
                        width: 44, height: 44,
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

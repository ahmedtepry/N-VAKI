import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';

/// Live support chat. Customers: opens/continues their conversation. Staff: pass [convId] + [staff].
class ChatScreen extends StatefulWidget {
  final String? subject, orderId, convId, title;
  final bool staff;
  const ChatScreen({this.subject, this.orderId, this.convId, this.staff = false, this.title});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? conv;
  Object? error;
  Json? meta;
  StreamSubscription? sub, metaSub;
  List<Json> msgs = [];
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      conv = widget.convId ?? await Api.supportOpen(subject: widget.subject, orderId: widget.orderId);
      sub = App.i.db.from('support_messages').stream(primaryKey: ['id']).eq('conversation_id', conv!).order('created_at').listen((rows) {
        if (!mounted) return;
        setState(() => msgs = rows.map((e) => Json.from(e)).toList());
        Api.markRead(conv!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        });
      }, onError: (e) => setState(() => error = e));
      metaSub = App.i.db.from('support_conversations').stream(primaryKey: ['id']).eq('id', conv!).listen((rows) {
        if (mounted && rows.isNotEmpty) setState(() => meta = Json.from(rows.first));
      }, onError: (_) {});
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    metaSub?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty || conv == null || sending) return;
    setState(() => sending = true);
    input.clear();
    try {
      await Api.sendMessage(conv!, t, staff: widget.staff);
    } catch (e) {
      input.text = t;
      toastError(e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _close() async {
    if (!await confirmDialog(context, tr('تقفل المحادثة؟', 'Close this conversation?'))) return;
    try {
      await Api.closeConv(conv!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = meta?['status'] == 'closed';
    final agent = meta?['agent_name'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.title ?? (widget.staff ? tr('محادثة عميل', 'CUSTOMER') : tr('خدمة العملاء', 'SUPPORT')), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          if (!widget.staff && agent != null) Text(agent, style: const TextStyle(fontSize: 11, color: C.mute, fontWeight: FontWeight.w500)),
        ]),
        actions: [if (conv != null && !closed) IconButton(onPressed: _close, tooltip: tr('قفل', 'Close'), icon: const Icon(Icons.done_all_rounded))],
      ),
      body: error != null
          ? ErrorRetry(error!, () {
              setState(() => error = null);
              _start();
            })
          : conv == null
              ? const Loading()
              : Column(children: [
                  Expanded(
                    child: msgs.isEmpty
                        ? Empty(tr('ابدأ المحادثة...', 'Say hello…'), icon: Icons.chat_bubble_outline_rounded)
                        : ListView.builder(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: msgs.length,
                            itemBuilder: (_, i) => _bubble(msgs[i]),
                          ),
                  ),
                  if (closed)
                    Padding(padding: const EdgeInsets.all(16), child: Text(tr('المحادثة اتقفلت.', 'This conversation is closed.'), style: const TextStyle(color: C.mute)))
                  else
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(hintText: tr('اكتب رسالة...', 'Type a message…'), filled: true, fillColor: C.card, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.ink))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(color: C.neon, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: _send, child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.arrow_upward_rounded, size: 22)))),
                        ]),
                      ),
                    ),
                ]),
    );
  }

  Widget _bubble(Json m) {
    final kind = m['sender_kind'] as String;
    final mine = widget.staff ? kind == 'staff' : kind == 'customer';
    final bot = kind == 'bot';
    final bg = bot ? Colors.transparent : (mine ? C.ink : C.card);
    final fg = bot ? C.mute : (mine ? Colors.white : C.ink);
    return Align(
      alignment: bot ? Alignment.center : (mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (bot ? 0.9 : 0.76)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: mine ? null : Border.all(color: bot ? Colors.transparent : C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['body'], textAlign: bot ? TextAlign.center : TextAlign.start, style: TextStyle(color: fg, height: 1.4, fontSize: bot ? 12 : 14, fontStyle: bot ? FontStyle.italic : FontStyle.normal)),
          if (!bot) Padding(padding: const EdgeInsets.only(top: 3), child: Text(fmtDate(m['created_at']).split('  ').last, style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 9.5))),
        ]),
      ),
    );
  }
}

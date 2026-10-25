import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../screens/notifications.dart' show fmtAgo;
import 'dash_work.dart' show openUrl, waNumber;

/// Internal team chat. [threadId] null = the general channel everyone on the team sees; otherwise a private 1-to-1 thread.
class TeamChatScreen extends StatefulWidget {
  final String? threadId;
  final String title;
  const TeamChatScreen({this.threadId, required this.title});
  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  StreamSubscription? sub;
  List<Json> msgs = [];
  Map<String, Json> people = {};
  Object? error;
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;

  bool get general => widget.threadId == null;

  @override
  void initState() {
    super.initState();
    final base = App.i.db.from('team_messages').stream(primaryKey: ['id']);
    final q = general ? base.eq('channel', 'general') : base.eq('thread_id', widget.threadId!);
    sub = q.order('created_at').listen((rows) async {
      final list = rows.map((e) => Json.from(e)).toList();
      final ids = list.map((e) => e['sender_id']).whereType<String>().toSet().difference(people.keys.toSet());
      if (ids.isNotEmpty) {
        try {
          people = {...people, ...await Api.profilesByIds(ids)};
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => msgs = list);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    }, onError: (e) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    input.clear();
    try {
      await App.i.db.from('team_messages').insert({
        'channel': general ? 'general' : 'direct',
        if (!general) 'thread_id': widget.threadId,
        'sender_id': App.i.user!.id,
        'body': t,
      });
    } catch (e) {
      input.text = t;
      toastError(e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = App.i.user?.id;
    return Scaffold(
      appBar: AppBar(
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          Text(general ? tr('الكل في الفريق بيشوفها', 'Visible to the whole team') : tr('محادثة خاصة', 'Private'), style: TextStyle(fontSize: 11, color: C.mute, fontWeight: FontWeight.w500)),
        ]),
      ),
      body: error != null
          ? ErrorRetry(error!, () => setState(() => error = null))
          : Column(children: [
              Expanded(
                child: msgs.isEmpty
                    ? Empty(tr('ابدأ المحادثة...', 'Say hello…'), icon: Icons.chat_bubble_outline_rounded)
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) {
                          final m = msgs[i];
                          final mine = m['sender_id'] == me;
                          final fg = mine ? C.onNeon : C.ink;
                          return Align(
                            alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(color: mine ? C.neon : C.card, borderRadius: BorderRadius.circular(16), border: mine ? null : Border.all(color: C.line)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (!mine) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${people[m['sender_id']]?['full_name'] ?? ''}', style: TextStyle(color: C.neon, fontSize: 11, fontWeight: FontWeight.w900))),
                                Text('${m['body']}', style: TextStyle(color: fg, height: 1.4)),
                                Padding(padding: const EdgeInsets.only(top: 3), child: Text(fmtDate(m['created_at']).split('  ').last, style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 9.5))),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
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
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(hintText: tr('اكتب رسالة...', 'Type a message…'), filled: true, fillColor: C.card, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: C.line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: C.line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: C.ink))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(color: C.neon, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: _send, child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.arrow_upward_rounded, size: 22, color: C.onNeon)))),
                  ]),
                ),
              ),
            ]),
    );
  }
}

/// The "Team" filter in the inbox: the general channel on top, then private threads.
class TeamInbox extends StatefulWidget {
  const TeamInbox();
  @override
  State<TeamInbox> createState() => _TeamInboxState();
}

class _TeamInboxState extends State<TeamInbox> {
  List<Json> threads = [];
  Map<String, Json> people = {};
  StreamSubscription? sub;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    sub = App.i.db.from('team_threads').stream(primaryKey: ['id']).order('last_at', ascending: false).listen((rows) async {
      final list = rows.map((e) => Json.from(e)).toList();
      final me = App.i.user?.id;
      final ids = list.map((e) => e['a'] == me ? e['b'] : e['a']).whereType<String>().toSet().difference(people.keys.toSet());
      if (ids.isNotEmpty) {
        try {
          people = {...people, ...await Api.profilesByIds(ids)};
        } catch (_) {}
      }
      if (mounted) setState(() {
            threads = list;
            loaded = true;
          });
    }, onError: (_) {
      if (mounted) setState(() => loaded = true);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = App.i.user?.id;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: C.neon, shape: BoxShape.circle), child: Icon(Icons.groups_rounded, color: C.onNeon)),
        title: Text(tr('محادثة الفريق العامة', 'Team general chat'), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(tr('كل الفريق بيشوفها', 'Everyone on the team'), style: TextStyle(fontSize: 12, color: C.mute)),
        onTap: () => Navigator.of(context).push(fadeRoute(TeamChatScreen(title: tr('الفريق', 'TEAM')))),
      ),
      const Divider(height: 1),
      if (!loaded) const Padding(padding: EdgeInsets.all(30), child: Loading()),
      if (loaded && threads.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Text(tr('مفيش محادثات خاصة لسه. دوس "محادثة جديدة".', 'No private chats yet. Tap "New chat".'), textAlign: TextAlign.center, style: TextStyle(color: C.mute))),
      for (final t in threads)
        Builder(builder: (_) {
          final peer = people[t['a'] == me ? t['b'] : t['a']];
          final name = '${peer?['full_name'] ?? tr('عضو', 'Member')}';
          return Column(children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: C.card, shape: BoxShape.circle, border: Border.all(color: C.line)), child: Text(name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900))),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t['last_body'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.mute)),
              trailing: Text(fmtAgo(t['last_at']), style: TextStyle(fontSize: 10.5, color: C.mute)),
              onTap: () => Navigator.of(context).push(fadeRoute(TeamChatScreen(threadId: t['id'], title: name))),
            ),
            const Divider(height: 1),
          ]);
        }),
    ]);
  }
}

/// "New conversation": WhatsApp to a customer, the general team channel, or a private chat with one teammate.
Future<void> startNewChat(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.bg,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(tr('محادثة جديدة', 'New conversation'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))),
        ListTile(leading: const Icon(Icons.chat_outlined), title: Text(tr('واتساب مع عميل', 'WhatsApp a customer'), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(tr('تكتب رقمه وبتفتح واتساب', 'Enter a number and WhatsApp opens')), onTap: () => Navigator.pop(ctx, 'wa')),
        ListTile(leading: const Icon(Icons.groups_rounded), title: Text(tr('محادثة الفريق العامة', 'Team general chat'), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(tr('رسالة يشوفها كل الفريق', 'A message the whole team sees')), onTap: () => Navigator.pop(ctx, 'general')),
        ListTile(leading: const Icon(Icons.lock_outline_rounded), title: Text(tr('محادثة خاصة مع عضو', 'Private chat with a teammate'), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(tr('بينك وبينه بس', 'Just between you two')), onTap: () => Navigator.pop(ctx, 'private')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'general') {
    Navigator.of(context).push(fadeRoute(TeamChatScreen(title: tr('الفريق', 'TEAM'))));
  } else if (choice == 'wa') {
    final phone = TextEditingController(), msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: Text(tr('واتساب', 'WhatsApp')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('رقم العميل', 'Customer number'))),
          TextField(controller: msg, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: tr('الرسالة (اختياري)', 'Message (optional)'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('رجوع', 'Back'), style: TextStyle(color: C.mute))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('افتح واتساب', 'Open WhatsApp'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    final digits = waNumber(phone.text);
    final text = msg.text.trim();
    phone.dispose();
    msg.dispose();
    if (ok != true) return;
    if (digits.length < 8) {
      toast(tr('الرقم مش صحيح', 'Invalid number'));
      return;
    }
    await openUrl('https://wa.me/$digits${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
  } else {
    List<Json> team;
    try {
      team = ((await App.i.db.rpc('list_team')) as List).map((e) => Json.from(e)).toList();
    } catch (e) {
      toastError(e);
      return;
    }
    if (!context.mounted) return;
    final peer = await showModalBottomSheet<Json>(
      context: context,
      backgroundColor: C.bg,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          Text(tr('اختار العضو', 'Choose a teammate'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (team.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Text(tr('مفيش أعضاء تانيين.', 'No other members.'), style: TextStyle(color: C.mute))),
          for (final m in team)
            ListTile(
              leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: m['online'] == true ? C.ok : C.line, shape: BoxShape.circle)),
              title: Text('${m['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(roleLabel('${m['role']}')),
              onTap: () => Navigator.pop(ctx, m),
            ),
        ]),
      ),
    );
    if (peer == null || !context.mounted) return;
    try {
      final id = await App.i.db.rpc('open_team_thread', params: {'p_peer': peer['id']});
      if (context.mounted) Navigator.of(context).push(fadeRoute(TeamChatScreen(threadId: '$id', title: '${peer['full_name']}')));
    } catch (e) {
      toastError(e);
    }
  }
}

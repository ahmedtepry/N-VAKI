import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen();
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Json>? rows;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.notifications();
      if (!mounted) return;
      setState(() {
        rows = r;
        error = null;
      });
      if (r.any((e) => e['read_at'] == null)) {
        await Api.markNotificationsRead();
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  IconData _icon(String k) {
    switch (k) {
      case 'order_status':
      case 'order_new':
      case 'order_assigned':
      case 'order_cancelled':
        return Icons.inventory_2_outlined;
      case 'chat_message':
      case 'chat_assigned':
        return Icons.chat_bubble_outline_rounded;
      case 'team':
        return Icons.groups_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('الإشعارات', 'NOTIFICATIONS'))),
      body: error != null
          ? ErrorRetry(error!, _load)
          : rows == null
              ? const Loading()
              : rows!.isEmpty
                  ? Empty(tr('مفيش إشعارات.', 'Nothing yet.'), icon: Icons.notifications_none_rounded)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: C.ink,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: rows!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = rows![i];
                          final unread = r['read_at'] == null;
                          final body = (App.i.ar ? r['body_ar'] : r['body_en']) as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(color: unread ? C.neon : C.card, shape: BoxShape.circle, border: Border.all(color: unread ? C.ink : C.line)),
                                child: Icon(_icon(r['kind'] ?? ''), size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(App.i.ar ? r['title_ar'] : r['title_en'], style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w600)),
                                  if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(body, style: const TextStyle(color: C.mute, fontSize: 13, height: 1.4))),
                                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(fmtAgo(r['created_at']), style: const TextStyle(color: C.mute, fontSize: 10.5))),
                                ]),
                              ),
                            ]),
                          );
                        },
                      ),
                    ),
    );
  }
}

String fmtAgo(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return tr('دلوقتي', 'just now');
  if (diff.inMinutes < 60) return tr('من ${diff.inMinutes} دقيقة', '${diff.inMinutes} min ago');
  if (diff.inHours < 24) return tr('من ${diff.inHours} ساعة', '${diff.inHours} h ago');
  return tr('من ${diff.inDays} يوم', '${diff.inDays} d ago');
}

import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app.dart';
import '../core/common.dart';
import '../core/theme.dart';
import '../dash/dash.dart';

/// Hidden entrance to the team area (opened by tapping the logo 5 times).
/// Already-signed-in staff go straight in; anyone else is asked for team credentials.
Future<void> openStaffArea(BuildContext context) async {
  if (App.i.isStaff) {
    Navigator.of(context).push(fadeRoute(const DashboardScreen()));
    return;
  }
  final ok = await showDialog<bool>(context: context, barrierDismissible: true, builder: (_) => const _StaffDialog());
  if (ok == true && context.mounted) Navigator.of(context).push(fadeRoute(const DashboardScreen()));
}

class _StaffDialog extends StatefulWidget {
  const _StaffDialog();
  @override
  State<_StaffDialog> createState() => _StaffDialogState();
}

class _StaffDialogState extends State<_StaffDialog> {
  final user = TextEditingController(), pass = TextEditingController();
  bool busy = false, hide = true;
  String? err;
  static int _fails = 0;
  static DateTime? _lockUntil;

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_lockUntil != null && DateTime.now().isBefore(_lockUntil!)) {
      setState(() => err = tr('استنى شوية وحاول تاني', 'Please wait a bit and try again'));
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await Api.signIn(user.text, pass.text);
      if (!App.i.isStaff) {
        await App.i.signOut();
        throw Exception('no');
      }
      _fails = 0;
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _fails++;
      if (_fails >= 5) {
        _lockUntil = DateTime.now().add(const Duration(minutes: 2));
        _fails = 0;
      }
      if (mounted) {
        setState(() {
          busy = false;
          err = tr('بيانات غير صحيحة', 'Incorrect details');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: C.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(tr('دخول الفريق', 'Team access'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: user, autocorrect: false, enableSuggestions: false, decoration: InputDecoration(labelText: tr('المستخدم', 'Username'))),
        const SizedBox(height: 6),
        TextField(
          controller: pass,
          obscureText: hide,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(labelText: tr('كلمة السر', 'Password'), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => setState(() => hide = !hide))),
        ),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: C.danger, fontSize: 12.5))),
      ]),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(false), child: Text(tr('إلغاء', 'Cancel'), style: TextStyle(color: C.mute))),
        TextButton(onPressed: busy ? null : _go, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('دخول', 'Enter'), style: const TextStyle(fontWeight: FontWeight.w900))),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import 'widgets.dart';

/// Welcome + sign-in with a one-time code (phone SMS or email).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _phone = true;
  bool _codeSent = false;
  bool _busy = false;
  final _id = TextEditingController();
  final _code = TextEditingController();

  String get _identifier {
    final v = _id.text.trim();
    if (!_phone) return v;
    // Accept 05xxxxxxxx, 5xxxxxxxx or +9665xxxxxxxx.
    final digits = v.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    if (digits.startsWith('0')) return '+966${digits.substring(1)}';
    return '+966$digits';
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_phone) {
        await auth.signInWithOtp(phone: _identifier);
      } else {
        await auth.signInWithOtp(email: _identifier);
      }
      setState(() => _codeSent = true);
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, context.t('تعذر الإرسال، تأكد من الاتصال', 'Could not send, check your connection'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_phone) {
        await auth.verifyOTP(phone: _identifier, token: _code.text.trim(), type: OtpType.sms);
      } else {
        await auth.verifyOTP(email: _identifier, token: _code.text.trim(), type: OtpType.email);
      }
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
                selected: {app.language},
                onSelectionChanged: (s) => app.setLanguage(s.first),
              ),
            ),
            const SizedBox(height: 48),
            Icon(Icons.account_balance_wallet_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(context.t('مُدبِّر', 'Mudabbir'), textAlign: TextAlign.center, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              context.t('ادفع لنفسك أولاً: ادّخر واستثمر من أول يوم، واعرف كم تقدر تصرف كل يوم.',
                  'Pay yourself first: save and invest from day one, and know what you can spend each day.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            if (!_codeSent) ...[
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(context.t('رقم الجوال', 'Phone')), icon: const Icon(Icons.phone_iphone)),
                  ButtonSegment(value: false, label: Text(context.t('البريد', 'Email')), icon: const Icon(Icons.alternate_email)),
                ],
                selected: {_phone},
                onSelectionChanged: (s) => setState(() => _phone = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _id,
                keyboardType: _phone ? TextInputType.phone : TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: _phone ? context.t('رقم الجوال', 'Mobile number') : context.t('البريد الإلكتروني', 'Email'),
                  hintText: _phone ? '05xxxxxxxx' : 'name@example.com',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(context.t('أرسل رمز التحقق', 'Send code')),
              ),
            ] else ...[
              Text(context.t('أدخل الرمز المرسل إلى $_identifier', 'Enter the code sent to $_identifier'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _verify, child: Text(context.t('دخول', 'Sign in'))),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _codeSent = false),
                child: Text(context.t('تغيير الرقم/البريد', 'Change number/email')),
              ),
            ],
            if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

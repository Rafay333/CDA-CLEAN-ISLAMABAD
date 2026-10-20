import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _cnic = TextEditingController();
  String? _error;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _cnic.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final digits = _cnic.text.replaceAll(RegExp(r'\D'), '');
    final error = Validators.cnic(digits);
    if (error != null) {
      setState(() {
        _error = error;
        _message = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
      _message = null;
    });
    try {
      final message = await SupervisorApi().forgotPassword(digits);
      if (!mounted) return;
      setState(() => _message = message);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Forgot Password',
      bottom: PrimaryButton(
        label: 'Continue',
        loading: _busy,
        onPressed: _busy ? null : _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const InlineMessage(
            message: 'Enter your 13-digit CNIC. If an account exists, reset instructions are sent.',
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'CNIC',
            controller: _cnic,
            hint: '13 digits',
            keyboardType: TextInputType.number,
            errorText: _error,
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            InlineMessage(
              tone: InlineTone.success,
              message: _message!,
            ),
          ],
        ],
      ),
    );
  }
}

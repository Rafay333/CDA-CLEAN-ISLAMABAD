import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _cnic = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _cnic.dispose();
    super.dispose();
  }

  void _submit() {
    final error = Validators.cnic(_cnic.text);
    setState(() {
      _error = error;
      _sent = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Forgot Password',
      bottom: PrimaryButton(label: 'Continue', onPressed: _submit),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const InlineMessage(
            message: 'Password reset will be available when accounts are connected. Nothing is sent from this screen.',
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'CNIC',
            controller: _cnic,
            hint: 'e.g. 12345-1234567-1',
            keyboardType: TextInputType.number,
            errorText: _error,
          ),
          if (_sent) ...[
            const SizedBox(height: 16),
            const InlineMessage(
              tone: InlineTone.success,
              message: 'CNIC format looks valid. Reset instructions are not sent until messaging is connected.',
            ),
          ],
        ],
      ),
    );
  }
}

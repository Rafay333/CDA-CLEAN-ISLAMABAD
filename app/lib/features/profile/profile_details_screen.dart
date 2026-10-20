import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/display_format.dart';
import '../../utils/validators.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  late final TextEditingController _father;
  late final TextEditingController _mobile;
  DateTime? _dob;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = AppStateScope.read(context).profile;
    _father = TextEditingController(text: profile.fatherName);
    _mobile = TextEditingController(text: profile.mobile);
    _dob = profile.dob;
  }

  @override
  void dispose() {
    _father.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    final mobileError = _mobile.text.trim().isEmpty ? null : Validators.mobile(_mobile.text);
    if (mobileError != null) {
      setState(() => _error = mobileError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final row = await SupervisorApi().updateProfile(
        session.cnic,
        fatherName: _father.text.trim(),
        mobile: _mobile.text.trim(),
        dob: _dob == null ? null : supervisorDate(_dob!),
      );
      if (!mounted) return;
      final saved = ProfileDetails.fromSupervisor(row);
      final current = AppStateScope.read(context).profile;
      AppStateScope.read(context).saveProfile(
        ProfileDetails(
          name: saved.name.isEmpty ? current.name : saved.name,
          fatherName: saved.fatherName.isEmpty ? _father.text.trim() : saved.fatherName,
          cnic: saved.cnic.isEmpty ? session.cnic : saved.cnic,
          mobile: saved.mobile.isEmpty ? _mobile.text.trim() : saved.mobile,
          dob: saved.dob ?? _dob,
          contractorName: saved.contractorName.isEmpty ? current.contractorName : saved.contractorName,
          accountType: saved.accountType.isEmpty ? current.accountType : saved.accountType,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppStateScope.of(context).profile;
    return AppPage(
      title: 'Profile Details',
      bottom: PrimaryButton(
        label: 'Save',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(child: AppAvatar(name: profile.name, size: 84)),
          const SizedBox(height: 16),
          if (_error != null) ...[
            InlineMessage(tone: InlineTone.error, message: _error!),
            const SizedBox(height: 12),
          ],
          InfoCard(label: 'Name', value: displayOr(profile.name, AppCopy.notProvided)),
          const SizedBox(height: 8),
          InfoCard(label: 'CNIC', value: displayOr(profile.cnic, AppCopy.notProvided)),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Contractor',
            value: displayOr(profile.contractorName, AppCopy.notProvided),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Account type',
            value: displayOr(profile.accountType, AppCopy.notProvided),
          ),
          const SizedBox(height: 16),
          TextInput(label: 'Father name', controller: _father, hint: 'Optional'),
          const SizedBox(height: 16),
          TextInput(
            label: 'Mobile number',
            controller: _mobile,
            hint: 'Optional',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          ListItem(
            title: 'Date of birth',
            subtitle: _dob == null ? AppCopy.notProvided : formatDate(_dob!),
            leading: const Icon(Icons.cake_outlined),
            onTap: _pickDob,
          ),
        ],
      ),
    );
  }
}

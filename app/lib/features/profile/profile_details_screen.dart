import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
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
          accountType: row.roleLabel.isNotEmpty
              ? row.roleLabel
              : (current.accountType.isNotEmpty ? current.accountType : saved.accountType),
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
        label: 'Save profile',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          ModuleHero(
            icon: Icons.badge_outlined,
            title: displayOr(profile.name, AppCopy.roleLabel),
            subtitle: 'Update optional contact details. Name and CNIC come from your account.',
            colors: ModulePalette.profile,
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ModulePalette.profileAccent.withValues(alpha: 0.25), width: 2),
                boxShadow: AppShadows.soft,
              ),
              child: AppAvatar(name: profile.name, size: 88),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            InlineMessage(tone: InlineTone.error, message: _error!),
            const SizedBox(height: 12),
          ],
          ModulePanel(
            title: 'Account',
            subtitle: 'Read-only details from the supervisor server.',
            accent: ModulePalette.profileAccent,
            child: ModuleMetaCard(
              accent: ModulePalette.profileAccent,
              rows: [
                (Icons.person_outline, 'Name', displayOr(profile.name, AppCopy.notProvided)),
                (Icons.badge_outlined, 'CNIC', displayOr(profile.cnic, AppCopy.notProvided)),
                (
                  Icons.business_outlined,
                  'Contractor',
                  displayOr(profile.contractorName, AppCopy.notProvided)
                ),
                (
                  Icons.verified_user_outlined,
                  'Account',
                  displayOr(
                    profile.accountType.isNotEmpty
                        ? profile.accountType
                        : AppStateScope.of(context).session?.roleLabel,
                    AppCopy.notProvided,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ModulePanel(
            title: 'Editable details',
            subtitle: 'These fields sync when you tap Save profile.',
            accent: ModulePalette.profileAccent,
            child: Column(
              children: [
                TextInput(label: 'Father name', controller: _father, hint: 'Optional'),
                const SizedBox(height: 14),
                TextInput(
                  label: 'Mobile number',
                  controller: _mobile,
                  hint: 'Optional',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                Material(
                  color: ModulePalette.panel,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDob,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ModulePalette.profileAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.cake_outlined,
                              color: ModulePalette.profileAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date of birth',
                                  style: AppType.label.copyWith(color: ModulePalette.ink),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _dob == null ? AppCopy.notProvided : formatDate(_dob!),
                                  style: AppType.caption.copyWith(color: ModulePalette.muted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.calendar_month_outlined, color: ModulePalette.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_assets.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/validators.dart';

const _titleGreen = Color(0xFF137A47);
const _buttonTeal = Color(0xFF1C9B98);
const _loginGradient = LinearGradient(
  colors: [Color(0xFF00695C), Color(0xFF0A4A62), Color(0xFF12304A)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const _fieldFill = Color(0xFFF5F5F5);
const _hintColor = Color(0xFF8E939A);
const _iconColor = Color(0xFFC4C8CE);
const _labelColor = Color(0xFF2C2C2E);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cnic = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _cnic.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cnicError = Validators.cnic(_cnic.text);
    if (cnicError != null) {
      setState(() => _error = cnicError);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await SupervisorApi().login(
        cnic: _cnic.text.replaceAll(RegExp(r'\D'), ''),
        password: _password.text,
      );
      if (!mounted) return;
      await AppStateScope.read(context).signIn(
        user,
        remember: AppStateScope.read(context).rememberMe,
      );
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remember = AppStateScope.of(context).rememberMe;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2420),
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _AerialBackground()),
            const Positioned.fill(child: _LegibilityScrim()),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
                    final cardMin = (constraints.maxHeight * 0.52).clamp(340.0, 520.0);
                    return SingleChildScrollView(
                      reverse: keyboardOpen,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _BrandHeader(),
                            _LoginSheet(
                              minHeight: cardMin,
                              bottomSafe: bottomSafe,
                              cnic: _cnic,
                              password: _password,
                              obscurePassword: _obscurePassword,
                              onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                              busy: _busy,
                              error: _error,
                              remember: remember,
                              onRemember: (value) => AppStateScope.read(context).setRememberMe(value),
                              onSubmit: _submit,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AerialBackground extends StatelessWidget {
  const _AerialBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.islamabadAerial,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.18),
      filterQuality: FilterQuality.high,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: 'Aerial view of Islamabad',
      errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFF1A2420)),
    );
  }
}

class _LegibilityScrim extends StatelessWidget {
  const _LegibilityScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x73000000),
            Color(0x33000000),
            Color(0x00000000),
            Color(0x14000000),
            Color(0x59000000),
          ],
          stops: [0, 0.16, 0.38, 0.62, 1],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
      child: Column(
        children: [
          Image.asset(
            AppAssets.logo,
            height: 68,
            fit: BoxFit.contain,
            semanticLabel: 'CDA',
          ),
          const SizedBox(height: 12),
          Text(
            'Clean Islamabad',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _titleGreen,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.6,
              shadows: const [
                Shadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 1)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Log in to stay on top of\nyour tasks and projects.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.28,
              letterSpacing: -0.2,
              shadows: const [
                Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginSheet extends StatelessWidget {
  const _LoginSheet({
    required this.minHeight,
    required this.bottomSafe,
    required this.cnic,
    required this.password,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.busy,
    required this.error,
    required this.remember,
    required this.onRemember,
    required this.onSubmit,
  });

  final double minHeight;
  final double bottomSafe;
  final TextEditingController cnic;
  final TextEditingController password;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final bool busy;
  final String? error;
  final bool remember;
  final ValueChanged<bool> onRemember;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.topCenter,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x2E000000), blurRadius: 22, offset: Offset(0, -8)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 30, 22, 28 + bottomSafe),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Login',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the 13-digit CNIC and password on your supervisor account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _hintColor, fontSize: 13.5, height: 1.35),
              ),
              const SizedBox(height: 18),
              _PillField(
                controller: cnic,
                hint: 'CNIC',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 13,
              ),
              const SizedBox(height: 14),
              _PillField(
                controller: password,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => onSubmit(),
                suffix: IconButton(
                  onPressed: onTogglePassword,
                  tooltip: obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: _iconColor,
                    size: 22,
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFFB42318), fontSize: 13.5, height: 1.35),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: _RememberMe(value: remember, onChanged: onRemember),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: _loginGradient,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: FilledButton(
                    onPressed: busy ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: const StadiumBorder(),
                      textStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Login'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  const _PillField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.obscure = false,
    this.suffix,
    this.inputFormatters,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscure,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      autocorrect: false,
      cursorColor: _buttonTeal,
      style: GoogleFonts.inter(
        color: const Color(0xFF1F1F1F),
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: _hintColor,
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: _fieldFill,
        prefixIcon: Icon(icon, color: _iconColor, size: 22),
        prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 48),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        counterText: '',
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: _buttonTeal, width: 1.4),
        ),
      ),
    );
  }
}

class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? _buttonTeal : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: value ? _buttonTeal : const Color(0xFFD0D5DD), width: 1.5),
              ),
              child: value ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Remember Me',
              style: GoogleFonts.inter(
                color: _labelColor,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

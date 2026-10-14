import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Track hover states for smooth color transitions
  bool _isGoogleHovered = false;
  bool _isAppleHovered = false;

  // Hover colors: red for Google, green for Apple
  static const Color googleHoverColor = Color(0xffF1F3F5);
  static const Color appleHoverColor = Color(0xff212529);

  // Clean Palette (No Navy)
  static const Color accentPeriwinkle = Color(0xFF5B6DF6);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color borderGrey = Color(0xFFD1D5DB);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF64748B);

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithApple();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple Sign-In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showApple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Center Logo
                  Hero(
                    tag: 'auth_logo',
                    child: Image.asset(
                      'assets/icons/logo.png',
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Description line
                  const Text(
                    'Sign in to track spending, manage monthly budgets, and save smarter across all your devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Action Buttons or Loading Spinner
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(accentPeriwinkle),
                      ),
                    )
                  else ...[
                    // Google Sign-In
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isGoogleHovered = true),
                      onExit: (_) => setState(() => _isGoogleHovered = false),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleGoogleSignIn,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isGoogleHovered ? googleHoverColor : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _isGoogleHovered ? googleHoverColor : borderGrey,
                              width: 1.2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10.0),
                                  child: Image.asset(
                                    'assets/icons/google.png',
                                    height: 22,
                                    width: 22,
                                  ),
                                ),
                              ),
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Apple Sign-In
                    if (showApple) ...[
                      const SizedBox(height: 14),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _isAppleHovered = true),
                        onExit: (_) => setState(() => _isAppleHovered = false),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleAppleSignIn,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isAppleHovered ? appleHoverColor : Colors.black,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10.0),
                                    child: Image.asset(
                                      'assets/icons/apple.png',
                                      height: 22,
                                      width: 22,
                                      color: Colors.white,
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Sign in with Apple',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
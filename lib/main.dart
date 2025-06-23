import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_messenger_app/firebase_options.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:image_picker/image_picker.dart'; // For avatar image selection
import 'dart:io'; // For File (ImagePicker)
import 'dart:async'; // For Timer and Completer
import 'dart:math'; // For Random in TriangleEyePainter
import 'package:shared_preferences/shared_preferences.dart'; // For AccountManager
import 'dart:convert'; // For jsonEncode/jsonDecode in AccountManager
import 'package:http/http.dart' as http; // Correct import for http package
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:flutter_localizations/flutter_localizations.dart'; // For date localization

// --- Main function and Firebase initialization ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PixelgramApp());
}

// --- Class for managing saved accounts (uses SharedPreferences) ---
class AccountManager {
  static const String _accountsKey = 'saved_accounts';
  static const int _maxAccounts = 10; // Maximum number of accounts to save

  // Saves a list of accounts to SharedPreferences
  static Future<void> saveAccounts(List<Map<String, String>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(accounts);
    await prefs.setString(_accountsKey, encodedData);
  }

  // Loads a list of accounts from SharedPreferences
  static Future<List<Map<String, String>>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_accountsKey);
    if (encodedData != null) {
      final List<dynamic> decodedList = jsonDecode(encodedData);
      return decodedList.map((item) => Map<String, String>.from(item)).toList();
    }
    return [];
  }

  // Adds a new account to the list of saved accounts if it's not already there
  static Future<void> addAccount(String uid, String email) async {
    List<Map<String, String>> accounts = await loadAccounts();
    // Check if the account already exists
    if (!accounts.any((acc) => acc['uid'] == uid)) {
      // If the maximum number of accounts is reached, remove the oldest one
      if (accounts.length >= _maxAccounts) {
        accounts.removeAt(0);
      }
      accounts.add({'uid': uid, 'email': email});
      await saveAccounts(accounts);
    }
  }

  // Removes an account from the list of saved accounts (if the user wants to remove it from the UI)
  static Future<void> removeAccount(String uid) async {
    List<Map<String, String>> accounts = await loadAccounts();
    accounts.removeWhere((acc) => acc['uid'] == uid);
    await saveAccounts(accounts);
  }

  // Clears all saved accounts
  static Future<void> clearAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
  }
}

// --- Main Pixelgram app widget ---
class PixelgramApp extends StatelessWidget {
  const PixelgramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixelgram',
      debugShowCheckedModeBanner: false, // Remove "Debug" banner
      theme: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Dark background
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 32,
            color: Colors.greenAccent,
            letterSpacing: 2,
          ),
          labelLarge: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: Colors.white70,
          ),
          titleLarge: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: Colors.greenAccent,
            letterSpacing: 1,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.greenAccent,
            textStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'PressStart2P', fontSize: 12),
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.greenAccent), borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.greenAccent, width: 2), borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.withOpacity(0.1),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ru', ''), // Russian
      ],
      locale: const Locale('ru', ''), // Set Russian locale by default
      home: const SplashScreen(),
    );
  }
}

// --- SplashScreen: Displays splash screen and handles automatic login ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  final Duration _minimumSplashDuration = const Duration(seconds: 3); // Minimum splash screen display time

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Animation duration
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _positionAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward(); // Start animation

    _initializeAndNavigate(); // Start initialization and navigation
  }

  Future<void> _initializeAndNavigate() async {
    // Wait for animation to finish and minimum splash duration
    final splashAnimationCompleter = Completer<void>();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        splashAnimationCompleter.complete();
      }
    });

    final minimumDurationCompleter = Completer<void>();
    Timer(_minimumSplashDuration, () {
      minimumDurationCompleter.complete();
    });

    // Wait until splash animation completes AND minimum time passes
    await Future.wait([
      splashAnimationCompleter.future,
      minimumDurationCompleter.future,
    ]);

    // Now that splash animation is complete, start loading app data
    if (!mounted) return; // Check if the widget is still in the tree

    try {
      final user = FirebaseAuth.instance.currentUser; // Get current Firebase user

      if (user == null) {
        // If user is not authenticated, navigate to login page
        _navigateTo(const EmailAuthPage());
      } else {
        // If user is authenticated, check Email and profile
        await user.reload(); // Refresh Firebase user data

        if (!user.emailVerified) {
          // If Email is not verified, navigate to Email verification page
          _navigateTo(EmailVerificationPage(user: user, isNewRegistration: false));
        } else {
          // Email is verified, check if user profile exists in Firestore
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (userDoc.exists) {
            // Profile exists, add it to AccountManager and navigate to HomePage
            await AccountManager.addAccount(user.uid, user.email ?? 'Без Email');
            _navigateTo(const HomePage());
          } else {
            // Profile does not exist, navigate to profile setup page
            _navigateTo(const ProfileSetupPage());
          }
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase error during SplashScreen initialization: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.message}. Please try again.')),
        );
        // In case of critical error, navigate to login page
        _navigateTo(const EmailAuthPage());
      }
    } catch (e) {
      debugPrint('Unexpected error during SplashScreen initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e. Please try again.')),
        );
        _navigateTo(const EmailAuthPage());
      }
    }
  }

  // Function for navigation with a beautiful transition animation
  void _navigateTo(Widget page) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700), // Transition duration
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation, // Fade animation
            child: page,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Release animation controller resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background for splash screen
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation, // Apply opacity animation
          child: SlideTransition(
            position: _positionAnimation, // Apply slide animation
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: TriangleEyePainter(), // Draw background triangle eyes
                  ),
                ),
                Text(
                  'Pixelgram',
                  style: Theme.of(context).textTheme.displayLarge!.copyWith(
                        fontSize: 48,
                        color: Colors.greenAccent,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.greenAccent.withOpacity(0.5),
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                ),
                // Add loading indicator which will be visible during initialization
                Positioned(
                  bottom: 50,
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.greenAccent), // Progress indicator
                      const SizedBox(height: 10),
                      Text(
                        'Загрузка...', // "Loading..." text
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- CustomPainter for drawing random triangle eyes ---
class TriangleEyePainter extends CustomPainter {
  final Random _random = Random();
  final bool isSingle; // If true, draws only one eye in the center

  TriangleEyePainter({this.isSingle = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.5) // Triangle color
      ..style = PaintingStyle.fill; // Fill

    final eyePaint = Paint()
      ..color = Colors.white // Eyeball color
      ..style = PaintingStyle.fill;

    if (isSingle) {
      // Draw one large triangle with an eye in the center
      final double triangleSize = size.shortestSide * 0.8;
      final double centerX = size.width / 2;
      final double centerY = size.height / 2;

      final Path trianglePath = Path();
      trianglePath.moveTo(centerX, centerY - triangleSize / 2);
      trianglePath.lineTo(centerX - triangleSize / 2, centerY + triangleSize / 2);
      trianglePath.lineTo(centerX + triangleSize / 2, centerY + triangleSize / 2);
      trianglePath.close();

      canvas.drawPath(trianglePath, paint);
      canvas.drawCircle(Offset(centerX, centerY + triangleSize / 6), triangleSize / 8, eyePaint);
    } else {
      // Draw many random small triangle eyes
      for (int i = 0; i < 50; i++) {
        final double centerX = _random.nextDouble() * size.width;
        final double centerY = _random.nextDouble() * size.height;
        final double triangleSize = (10 + _random.nextDouble() * 20).toDouble(); // Random size

        final Path trianglePath = Path();
        trianglePath.moveTo(centerX, centerY - triangleSize / 2);
        trianglePath.lineTo(centerX - triangleSize / 2, centerY + triangleSize / 2);
        trianglePath.lineTo(centerX + triangleSize / 2, centerY + triangleSize / 2);
        trianglePath.close();

        canvas.drawPath(trianglePath, paint);
        canvas.drawCircle(Offset(centerX, centerY), triangleSize / 5, eyePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Redraw if mode changed (single/multiple)
    if (oldDelegate is TriangleEyePainter && oldDelegate.isSingle != isSingle) {
      return true;
    }
    return false;
  }
}

// --- Email Login and Registration Page ---
class EmailAuthPage extends StatefulWidget {
  final String? initialEmail;
  final bool isAddingAccount; // Flag indicating that we are adding a new account

  const EmailAuthPage({super.key, this.initialEmail, this.isAddingAccount = false});

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLogin = true; // Flag: true for login, false for registration
  bool _isLoading = false; // Loading state flag
  bool _isSwitchingAccount = false; // Flag for UI when switching accounts

  late AnimationController _formAnimationController;
  late Animation<double> _formOpacityAnimation;
  late Animation<Offset> _formSlideAnimation;

  @override
  void initState() {
    super.initState();
    // If initialEmail is passed and it's not in adding account mode, it's an account switch
    if (widget.initialEmail != null && !widget.isAddingAccount) {
      _emailController.text = widget.initialEmail!;
      _isLogin = true; // In this mode, always start with login
      _isSwitchingAccount = true;
    }

    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _formOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formAnimationController, curve: Curves.easeIn),
    );
    _formSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _formAnimationController, curve: Curves.easeOutCubic),
    );
    _formAnimationController.forward(); // Start form appearance animation
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _formAnimationController.dispose();
    super.dispose();
  }

  // Function to submit form data (login or registration)
  Future<void> _submitAuthForm() async {
    setState(() {
      _errorMessage = ''; // Clear previous errors
      _isLoading = true; // Set loading state
    });

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, заполните все поля.';
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential;
      if (_isLogin) {
        // Login logic
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        debugPrint('User logged in: ${userCredential.user?.email}');
      } else {
        // Registration logic
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        debugPrint('User registered: ${userCredential.user?.email}');

        // If it's a new registration, send email verification
        await userCredential.user!.sendEmailVerification();
        debugPrint('Verification email sent to: ${userCredential.user?.email}');
      }

      if (!mounted) return; // Check if the widget is still in the tree

      // After successful login/registration
      if (userCredential.user != null) {
        final user = userCredential.user!;
        await user.reload(); // Refresh user data

        if (!user.emailVerified && !_isLogin) {
          // If it's a new registration and email is not verified, navigate to verification page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => EmailVerificationPage(user: user, isNewRegistration: true)),
          );
        } else {
          // If email is verified or it was a login, check for profile existence
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (userDoc.exists) {
            // Profile exists, add account and navigate to home page
            await AccountManager.addAccount(user.uid, user.email ?? 'Без Email');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else {
            // Profile does not exist, navigate to profile setup page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'Пароль слишком простой.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'Этот Email уже используется.';
        } else if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          _errorMessage = 'Неверный Email или пароль.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'Некорректный формат Email.';
        } else if (e.code == 'too-many-requests') {
          _errorMessage = 'Слишком много попыток входа. Попробуйте позже.';
        } else {
          _errorMessage = 'Ошибка аутентификации: ${e.message}';
        }
        debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла непредвиденная ошибка: $e';
        debugPrint('Unexpected authentication error: $e');
      });
    } finally {
      setState(() {
        _isLoading = false; // End loading state
      });
    }
  }

  // Function to show account selection dialog
  Future<void> _showAccountPicker() async {
    final List<Map<String, String>> accounts = await AccountManager.loadAccounts();
    if (!mounted) return;

    // If no saved accounts, immediately exit
    if (accounts.isEmpty) {
      setState(() {
        _isLogin = false; // Switch to registration, as there are no accounts to log in
        _emailController.clear();
        _passwordController.clear();
        _isSwitchingAccount = false;
      });
      return;
    }

    final selectedAccount = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      backgroundColor: Colors.transparent, // Make background transparent
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A), // Dark background for modal window
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.greenAccent, width: 2),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Выбрать аккаунт',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              // List of saved accounts
              ...accounts.map((account) {
                return Card(
                  color: Colors.black54, // Card background color
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.account_circle, color: Colors.white70),
                    title: Text(
                      account['email']!,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context, account); // Return selected account
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {'action': 'add_new'}); // Signal to add new account
                },
                child: Text('Добавить новый аккаунт', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );

    if (selectedAccount != null) {
      if (selectedAccount.containsKey('action') && selectedAccount['action'] == 'add_new') {
        // If user chose to add new account
        if (mounted) {
          setState(() {
            _isLogin = false; // Switch to registration mode
            _emailController.clear();
            _passwordController.clear();
            _isSwitchingAccount = false;
          });
        }
      } else {
        // If user selected an existing account
        if (mounted) {
          setState(() {
            _emailController.text = selectedAccount['email']!;
            _isLogin = true;
            _isSwitchingAccount = true;
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin && !_isSwitchingAccount ? 'Вход в Pixelgram' : (_isLogin && _isSwitchingAccount ? 'Переключить аккаунт' : 'Регистрация в Pixelgram'), textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.greenAccent,
        leading: widget.isAddingAccount || _isSwitchingAccount ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 500),
                      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                        opacity: animation,
                        child: const SplashScreen(),
                      ),
                    ),
                    (route) => false,
                  );
                }
              });
            }
          },
        ) : null,
      ),
      body: FadeTransition(
        opacity: _formOpacityAnimation,
        child: SlideTransition(
          position: _formSlideAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isSwitchingAccount)
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 14),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          widget.initialEmail!,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                    ),
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.greenAccent)
                      : ElevatedButton(
                          onPressed: _submitAuthForm,
                          child: Text(
                            _isLogin ? (_isSwitchingAccount ? 'Войти' : 'Войти') : 'Зарегистрироваться',
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black, fontSize: 16),
                          ),
                        ),
                  const SizedBox(height: 20),
                  if (!_isSwitchingAccount)
                    TextButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = '';
                          });
                        }
                      },
                      child: Text(
                        _isLogin ? 'У меня нет аккаунта? Зарегистрироваться' : 'У меня уже есть аккаунт? Войти',
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.greenAccent),
                      ),
                    ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Email Verification Page ---
class EmailVerificationPage extends StatefulWidget {
  final User user;
  final bool isNewRegistration;
  const EmailVerificationPage({super.key, required this.user, this.isNewRegistration = false});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _canResendEmail = true;
  int _countdownSeconds = 60;

  late AnimationController _contentAnimationController;
  late Animation<double> _contentOpacityAnimation;
  late Animation<Offset> _contentSlideAnimation;

  @override
  void initState() {
    super.initState();

    _contentAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _contentOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentAnimationController, curve: Curves.easeIn),
    );
    _contentSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentAnimationController, curve: Curves.easeOutCubic),
    );
    _contentAnimationController.forward();


    _checkEmailVerified();
    _startTimerForEmailCheck();

    if (widget.isNewRegistration) {
      _sendVerificationEmail();
    } else {
      _countdownSeconds = 0;
      _canResendEmail = true;
    }
  }

  void _startTimerForEmailCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _contentAnimationController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await widget.user.reload();
      if (widget.user.emailVerified) {
        _timer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email уже подтвержден! Перенаправляем...')),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                  opacity: animation,
                  child: const HomePage(), // Navigate directly to HomePage
                ),
              ),
            );
          }
        });
        return;
      }

      await widget.user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Письмо с подтверждением отправлено. Проверьте свой Email.')),
        );
        setState(() {
          _canResendEmail = false;
          _countdownSeconds = 60;
        });
      }
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          if (_countdownSeconds == 0) {
            setState(() {
              _canResendEmail = true;
            });
          } else {
            setState(() {
              _countdownSeconds--;
            });
          }
        } else {
          timer.cancel();
        }
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки письма: ${e.message}')),
        );
      }
      debugPrint('Error sending email: ${e.code} - ${e.message}');
    }
  }

  Future<void> _checkEmailVerified() async {
    await widget.user.reload();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.emailVerified) {
      _timer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email успешно подтвержден!')),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 500),
              pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                opacity: animation,
                child: const HomePage(), // Navigate directly to HomePage
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтвердите Email', textAlign: TextAlign.center),
        backgroundColor: Colors.greenAccent,
      ),
      body: FadeTransition(
        opacity: _contentOpacityAnimation,
        child: SlideTransition(
          position: _contentSlideAnimation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.email,
                    size: 80,
                    color: Theme.of(context).textTheme.labelLarge!.color,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Пожалуйста, подтвердите свой Email',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Мы отправили письмо на ${widget.user.email ?? 'ваш адрес Email'}.',
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.greenAccent),
                  const SizedBox(height: 10),
                  Text(
                    'Ожидание подтверждения...',
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _canResendEmail ? _sendVerificationEmail : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    ),
                    child: Text(
                      _canResendEmail ? 'Отправить письмо повторно' : 'Повторная отправка через $_countdownSeconds с',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 500),
                            pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                              opacity: animation,
                              child: const EmailAuthPage(),
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(
                      'Выйти',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- HomePage: Main app screen with "Chats" and "Profile" tabs ---
class HomePage extends StatefulWidget {
  final int initialIndex;

  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // List of widgets for each tab
  static final List<Widget> _widgetOptions = <Widget>[
    const ChatsTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const EmailAuthPage()),
            (route) => false,
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pixelgram', style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Чаты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white70,
        backgroundColor: Colors.black,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
        unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

// --- ProfileSetupPage: Screen for initial profile setup ---
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String? _avatarBase64;
  File? _selectedImage;
  String _errorMessage = '';
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _lastNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _avatarBase64 = base64Encode(bytes);
        });
      }
    }
  }

  Future<bool> _isNicknameUnique(String nickname) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return querySnapshot.docs.isEmpty;
  }

  Future<void> _createProfile() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: Пользователь не авторизован.')),
        );
      }
      setState(() { _isLoading = false; });
      return;
    }

    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Никнейм обязателен.';
        });
      }
      setState(() { _isLoading = false; });
      return;
    }

    final isUnique = await _isNicknameUnique(nickname);
    if (!isUnique) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Этот никнейм уже занят. Пожалуйста, выберите другой.';
        });
      }
      setState(() { _isLoading = false; });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'nickname': nickname,
        'lastName': _lastNameController.text.trim(),
        'avatarBase64': _avatarBase64,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль успешно создан!')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                  opacity: animation,
                  child: const HomePage(),
                ),
              ),
              (route) => false,
            );
          }
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('Error creating Firestore profile: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при создании профиля: ${e.message}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error creating profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Непредвиденная ошибка: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка профиля', textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.orangeAccent,
        automaticallyImplyLeading: false,
      ),
      body: FadeTransition(
        opacity: _opacityAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.greenAccent.withOpacity(0.2),
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_avatarBase64 != null
                              ? MemoryImage(base64Decode(_avatarBase64!))
                              : null) as ImageProvider<Object>?,
                      child: _selectedImage == null && _avatarBase64 == null
                          ? Icon(Icons.camera_alt, size: 50, color: Colors.greenAccent.withOpacity(0.7))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Нажмите, чтобы выбрать аватар',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Никнейм (обязательно)',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Фамилия (необязательно)',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 30),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.greenAccent)
                      : ElevatedButton(
                          onPressed: _createProfile,
                          child: Text(
                            'Создать профиль',
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- ChatsTab: Tab for displaying and managing chats ---
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  Stream<QuerySnapshot>? _chatsStream;
  String? currentUserId;
  final TextEditingController _searchNicknameController = TextEditingController(); // Controller for nickname search

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _chatsStream = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots();
    }
  }

  Future<void> _createOrOpenChat(BuildContext context, String otherUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    List<String> participants = [currentUserId, otherUserId];
    participants.sort();
    String chatId = participants.join('_');

    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, otherUserId: otherUserId),
        ),
      );
    }
  }

  // New function to search for user by nickname and open chat
  Future<void> _findUserAndOpenChat() async {
    final nicknameToSearch = _searchNicknameController.text.trim();
    if (nicknameToSearch.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, введите никнейм для поиска.')),
        );
      }
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nicknameToSearch)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final otherUserId = querySnapshot.docs.first.id;
        if (otherUserId == currentUserId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Вы не можете начать чат с самим собой.')),
            );
          }
          return;
        }
        await _createOrOpenChat(context, otherUserId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь с таким никнеймом не найден.')),
          );
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('Error searching user: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка поиска пользователя: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error while searching user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Непредвиденная ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return Center(
        child: Text('Пожалуйста, войдите в систему, чтобы просматривать чаты.', style: Theme.of(context).textTheme.labelLarge, textAlign: TextAlign.center,),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchNicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Никнейм для поиска',
                    hintText: 'Введите никнейм...',
                    prefixIcon: Icon(Icons.person_search, color: Colors.greenAccent),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  onSubmitted: (_) => _findUserAndOpenChat(), // Submit on Enter
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _findUserAndOpenChat,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.search, color: Colors.black, size: 24),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
              }
              if (snapshot.hasError) {
                if (snapshot.error.toString().contains('permission-denied')) {
                  return Center(child: Text('Ошибка доступа к чатам. Проверьте правила безопасности Firestore.', style: Theme.of(context).textTheme.labelLarge, textAlign: TextAlign.center,));
                }
                return Center(child: Text('Ошибка загрузки чатов: ${snapshot.error}', style: Theme.of(context).textTheme.labelLarge));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('У вас пока нет чатов. Начните новый!', style: Theme.of(context).textTheme.labelLarge, textAlign: TextAlign.center,));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final chatDoc = snapshot.data!.docs[index];
                  final chatData = chatDoc.data() as Map<String, dynamic>;
                  final participants = List<String>.from(chatData['participants']);
                  final otherUserId = participants.firstWhere((id) => id != currentUserId);

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          title: Text('Загрузка пользователя...', style: TextStyle(color: Colors.white70)),
                        );
                      }
                      if (userSnapshot.hasError) {
                        return ListTile(
                          title: Text('Ошибка: ${userSnapshot.error}', style: const TextStyle(color: Colors.red)),
                        );
                      }
                      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                        return ListTile(
                          leading: Icon(Icons.person, color: Colors.grey.withOpacity(0.7)),
                          title: Text('Неизвестный пользователь (${otherUserId.substring(0, 6)}...)', style: Theme.of(context).textTheme.labelLarge),
                          subtitle: Text(
                            chatData['lastMessage'] ?? 'Нет сообщений',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            chatData['lastMessageTime'] != null
                                ? _formatTimestamp(chatData['lastMessageTime'] as Timestamp)
                                : '',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 8),
                          ),
                          onTap: () {
                            _createOrOpenChat(context, otherUserId);
                          },
                        );
                      }

                      final otherUserData = userSnapshot.data!.data() as Map<String, dynamic>;
                      final otherUserNickname = otherUserData['nickname'] ?? 'Неизвестный';
                      final otherUserAvatarBase64 = otherUserData['avatarBase64'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        color: Colors.grey.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.greenAccent.withOpacity(0.2),
                            backgroundImage: otherUserAvatarBase64 != null
                                ? MemoryImage(base64Decode(otherUserAvatarBase64))
                                : null,
                            child: otherUserAvatarBase64 == null
                                ? Icon(Icons.person, size: 25, color: Colors.greenAccent.withOpacity(0.7))
                                : null,
                          ),
                          title: Text(
                            otherUserNickname,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          subtitle: Text(
                            chatData['lastMessage'] ?? 'Нет сообщений',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            chatData['lastMessageTime'] != null
                                ? _formatTimestamp(chatData['lastMessageTime'] as Timestamp)
                                : '',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 8),
                          ),
                          onTap: () {
                            _createOrOpenChat(context, otherUserId);
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final aWeekAgo = now.subtract(const Duration(days: 7));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Вчера';
    } else if (date.isAfter(aWeekAgo)) {
      return DateFormat('EEEE', 'ru').format(date);
    } else {
      return DateFormat('dd.MM.yy').format(date);
    }
  }
}

// --- ProfileTab: Tab for displaying profile information and managing accounts ---
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  List<Map<String, String>> _savedAccounts = [];

  Completer<void> _loadingCompleter = Completer<void>(); // Used to track loading state for FutureBuilder

  @override
  void initState() {
    super.initState();
    _loadProfileAndAccounts(); // Load profile and saved accounts when the widget initializes
  }

  // Loads the current user's profile and the list of saved accounts
  Future<void> _loadProfileAndAccounts() async {
    _loadingCompleter = Completer<void>(); // Reset completer for new loading operation
    _currentUser = FirebaseAuth.instance.currentUser; // Get current Firebase user
    if (_currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        setState(() {
          _userProfile = doc.data(); // Update profile data
        });
      }
    }
    _savedAccounts = await AccountManager.loadAccounts(); // Load saved accounts from SharedPreferences
    if (mounted) {
      setState(() {}); // Trigger rebuild to show updated accounts
    }
    _loadingCompleter.complete(); // Mark loading as complete
  }

  // Function to switch to another account (now only by password)
  Future<void> _switchAccount(String uid, String email) async {
    if (_currentUser?.uid == uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы уже вошли в этот аккаунт.')),
        );
      }
      return;
    }

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Redirect to login page with pre-filled email
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => EmailAuthPage(initialEmail: email, isAddingAccount: false)),
            (route) => false, // Remove all previous routes from stack
          );
        }
      });
    }
  }

  // Function to show confirmation dialog for signing out
  Future<void> _showSignOutConfirmationDialog() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text('Выйти из аккаунта?', style: Theme.of(context).textTheme.titleLarge),
          content: Text('Вы уверены, что хотите выйти из текущего аккаунта?', style: Theme.of(context).textTheme.bodyLarge),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Нет', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.blueAccent)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text('Да', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      _signOut();
    }
  }

  // Function to sign out
  Future<void> _signOut() async {
    try {
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUid != null) {
        // Remove current account from saved accounts
        await AccountManager.removeAccount(currentUid);
      }

      await FirebaseAuth.instance.signOut(); // Sign out from Firebase

      // Check if there are any other accounts saved in SharedPreferences
      List<Map<String, String>> remainingAccounts = await AccountManager.loadAccounts();

      if (mounted) {
        if (remainingAccounts.isEmpty) {
          // If no accounts left, navigate to login/registration page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const EmailAuthPage()),
            (route) => false,
          );
        } else {
          // If there are other accounts, navigate to the first one or a picker
          final String nextEmail = remainingAccounts.first['email']!;
          final String nextUid = remainingAccounts.first['uid']!;
          // Attempt to sign in to the next available account
          // This requires user interaction (password), so redirect to EmailAuthPage
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => EmailAuthPage(initialEmail: nextEmail, isAddingAccount: false)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выходе: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Center(
        child: Text('Профиль не загружен. Пожалуйста, войдите снова.', style: Theme.of(context).textTheme.labelLarge),
      );
    }

    final avatarBase64 = _userProfile?['avatarBase64'] as String?;
    final nickname = _userProfile?['nickname'] ?? 'Неизвестный никнейм';
    final lastName = _userProfile?['lastName'] ?? '';

    return FutureBuilder<void>(
      future: _loadingCompleter.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.greenAccent.withOpacity(0.2),
                backgroundImage: avatarBase64 != null
                    ? MemoryImage(base64Decode(avatarBase64))
                    : null,
                child: avatarBase64 == null
                    ? Icon(Icons.person, size: 80, color: Colors.greenAccent.withOpacity(0.7))
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                nickname,
                style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 28),
              ),
              if (lastName.isNotEmpty)
                Text(
                  lastName,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfilePage()),
                    ).then((_) => _loadProfileAndAccounts());
                  }
                },
                icon: const Icon(Icons.edit, color: Colors.black),
                label: Text('Редактировать профиль', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 20),
              // Button "Sign out" with trash icon
              ElevatedButton.icon(
                onPressed: _showSignOutConfirmationDialog, // Call confirmation dialog
                icon: const Icon(Icons.delete, color: Colors.black), // Trash icon
                label: Text('Выйти из аккаунта', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  if (_savedAccounts.length < AccountManager._maxAccounts) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EmailAuthPage(isAddingAccount: true)),
                    ).then((_) => _loadProfileAndAccounts());
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Достигнут лимит в 10 аккаунтов на устройстве.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add, color: Colors.black),
                label: Text('Добавить аккаунт', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Сохраненные аккаунты (${_savedAccounts.length}/${AccountManager._maxAccounts})',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _savedAccounts.length,
                itemBuilder: (context, index) {
                  final account = _savedAccounts[index];
                  if (account['uid'] == null || account['email'] == null) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.grey.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      leading: const Icon(Icons.account_circle, color: Colors.white70),
                      title: Text(
                        account['email']!,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 12),
                      ),
                      subtitle: Text(
                        account['uid'] == _currentUser?.uid ? 'Активен' : 'Сохранен',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: account['uid'] == _currentUser?.uid ? Colors.green : Colors.white70),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (account['uid'] != _currentUser?.uid) // Show switch only for inactive accounts
                            IconButton(
                              icon: const Icon(Icons.switch_account, color: Colors.blueAccent),
                              onPressed: () => _switchAccount(account['uid']!, account['email']!),
                              tooltip: 'Переключить на этот аккаунт',
                            ),
                          // No trash icon here. The previous request was to remove the 'delete my profile' button.
                          // The trash icon next to saved accounts in the list was also removed in a previous iteration.
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- UserProfilePage: A new screen to display another user's profile ---
class UserProfilePage extends StatefulWidget {
  final String userId; // The ID of the user whose profile we want to view

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // Load user profile when the widget initializes
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() {
          _userProfile = doc.data(); // Set profile data
        });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Профиль пользователя не найден.';
          });
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('Error loading user profile: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки профиля: ${e.message}';
        });
      }
    } catch (e) {
      debugPrint('Unexpected error loading user profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Непредвиденная ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профиль пользователя', textAlign: TextAlign.center),
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.greenAccent),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профиль пользователя', textAlign: TextAlign.center),
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.greenAccent),
        ),
        body: Center(
          child: Text(
            _errorMessage,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final avatarBase64 = _userProfile?['avatarBase64'] as String?;
    final nickname = _userProfile?['nickname'] ?? 'Неизвестный никнейм';
    final lastName = _userProfile?['lastName'] ?? '';
    final email = _userProfile?['email'] ?? 'Неизвестный Email'; // Добавляем отображение Email

    return Scaffold(
      appBar: AppBar(
        title: Text(nickname, style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.greenAccent),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 80,
                backgroundColor: Colors.greenAccent.withOpacity(0.2),
                backgroundImage: avatarBase64 != null
                    ? MemoryImage(base64Decode(avatarBase64))
                    : null,
                child: avatarBase64 == null
                    ? Icon(Icons.person, size: 90, color: Colors.greenAccent.withOpacity(0.7))
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                nickname,
                style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              if (lastName.isNotEmpty)
                Text(
                  lastName,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
              Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Можно добавить кнопки для взаимодействия, например, начать чат
              ElevatedButton.icon(
                onPressed: () {
                  // Логика для начала чата с этим пользователем
                  // Можно использовать Navigator.pop(context) чтобы вернуться к предыдущему чату
                  // или Navigator.pushReplacement, чтобы начать новый чат и заменить текущую страницу
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  if (currentUserId != null && currentUserId != widget.userId) {
                    List<String> participants = [currentUserId, widget.userId];
                    participants.sort();
                    String chatId = participants.join('_');

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: chatId, otherUserId: widget.userId),
                      ),
                    );
                  } else if (currentUserId == widget.userId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Вы не можете начать чат с самим собой.')),
                    );
                  }
                },
                icon: const Icon(Icons.chat, color: Colors.black),
                label: Text('Начать чат', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// --- SearchUsersScreen: This class is no longer used directly, its functionality has been moved to ChatsTab.
// However, I will keep it in case you want to bring it back.
class SearchUsersScreen extends StatefulWidget {
  final Function(String userId) onUserSelected;

  const SearchUsersScreen({super.key, required this.onUserSelected});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Введите никнейм для поиска.';
        });
      }
      return;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isGreaterThanOrEqualTo: query)
          .where('nickname', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _searchResults = result.docs.where((doc) => doc.id != _currentUserId).toList();
          if (_searchResults.isEmpty) {
            _errorMessage = 'Пользователь с таким никнеймом не найден.';
          }
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('Error searching users: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка поиска: ${e.message}';
        });
      }
    } catch (e) {
      debugPrint('Unexpected error while searching users: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Непредвиденная ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Найти человека', textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.greenAccent),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Никнейм для поиска',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.greenAccent),
                  onPressed: () => _searchUsers(_searchController.text),
                ),
              ),
              onSubmitted: _searchUsers,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.greenAccent)
            else if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final userData = _searchResults[index].data() as Map<String, dynamic>;
                    final userId = _searchResults[index].id;
                    final nickname = userData['nickname'] ?? 'Неизвестный';
                    final avatarBase64 = userData['avatarBase64'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: Colors.grey.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.greenAccent.withOpacity(0.2),
                          backgroundImage: avatarBase64 != null
                              ? MemoryImage(base64Decode(avatarBase64))
                              : null,
                          child: avatarBase64 == null
                              ? Icon(Icons.person, size: 25, color: Colors.greenAccent.withOpacity(0.7))
                              : null,
                        ),
                        title: Text(
                          nickname,
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14),
                        ),
                        onTap: () {
                          widget.onUserSelected(userId);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- ChatScreen: Screen for exchanging messages ---
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({super.key, required this.chatId, required this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  String? _otherUserNickname;
  String? _otherUserAvatarBase64;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadOtherUserProfile();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherUserProfile() async {
    if (widget.otherUserId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _otherUserNickname = data?['nickname'] ?? 'Неизвестный';
          _otherUserAvatarBase64 = data?['avatarBase64'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading other user profile: $e');
      if (mounted) {
        setState(() {
          _otherUserNickname = 'Error loading';
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
            'senderId': _currentUserId,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        title: GestureDetector( // Wrap with GestureDetector to make it tappable
          onTap: () {
            if (widget.otherUserId != FirebaseAuth.instance.currentUser?.uid) { // Prevent opening own profile from chat
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(userId: widget.otherUserId),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Вы уже находитесь на своем профиле.')),
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.greenAccent.withOpacity(0.2),
                backgroundImage: _otherUserAvatarBase64 != null
                    ? MemoryImage(base64Decode(_otherUserAvatarBase64!))
                    : null,
                child: _otherUserAvatarBase64 == null
                    ? Icon(Icons.person, size: 20, color: Colors.greenAccent.withOpacity(0.7))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded( // Use Expanded to prevent overflow if nickname is long
                child: Text(
                  _otherUserNickname ?? 'Загрузка...',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis, // Add ellipsis for long nicknames
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading messages: ${snapshot.error}', style: Theme.of(context).textTheme.labelLarge));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Начните новую беседу!', style: Theme.of(context).textTheme.labelLarge));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final messageDoc = snapshot.data!.docs[index];
                    final messageData = messageDoc.data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == _currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.greenAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              messageData['text'] as String,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (messageData['timestamp'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  _formatMessageTimestamp(messageData['timestamp'] as Timestamp),
                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 8, color: Colors.white54),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent, size: 30),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('HH:mm').format(date);
  }
}

// --- EditProfilePage: Screen for editing an existing profile ---
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String? _avatarBase64;
  File? _selectedImage;
  String _errorMessage = '';
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  final ImagePicker _picker = ImagePicker();
  User? _currentUser;
  Map<String, dynamic>? _initialProfileData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _lastNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: Пользователь не авторизован.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists && mounted) {
        _initialProfileData = doc.data();
        _nicknameController.text = _initialProfileData?['nickname'] ?? '';
        _lastNameController.text = _initialProfileData?['lastName'] ?? '';
        _avatarBase64 = _initialProfileData?['avatarBase64'] as String?;
      }
    } on FirebaseException catch (e) {
      debugPrint('Error loading profile for editing: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки профиля: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _avatarBase64 = base64Encode(bytes);
        });
      }
    }
  }

  Future<bool> _isNicknameUnique(String nickname) async {
    if (nickname == (_initialProfileData?['nickname'] ?? '')) {
      return true;
    }
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return querySnapshot.docs.isEmpty;
  }

  Future<void> _updateProfile() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: Пользователь не авторизован.')),
        );
      }
      setState(() { _isLoading = false; });
      return;
    }

    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Никнейм обязателен.';
        });
      }
      setState(() { _isLoading = false; });
      return;
    }

    final isUnique = await _isNicknameUnique(nickname);
    if (!isUnique) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Этот никнейм уже занят. Пожалуйста, выберите другой.';
        });
      }
      setState(() { _isLoading = false; });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
        'nickname': nickname,
        'lastName': _lastNameController.text.trim(),
        'avatarBase64': _avatarBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль успешно обновлен!')),
        );
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      debugPrint('Error updating Firestore profile: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при обновлении профиля: ${e.message}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error updating profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Непредвиденная ошибка: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _initialProfileData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Редактировать профиль', textAlign: TextAlign.center),
          centerTitle: true,
          backgroundColor: Colors.orange,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль', textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FadeTransition(
        opacity: _opacityAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.greenAccent.withOpacity(0.2),
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_avatarBase64 != null
                              ? MemoryImage(base64Decode(_avatarBase64!))
                              : null) as ImageProvider<Object>?,
                      child: _selectedImage == null && _avatarBase64 == null
                          ? Icon(Icons.camera_alt, size: 50, color: Colors.greenAccent.withOpacity(0.7))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Нажмите, чтобы изменить аватар',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Никнейм (обязательно)',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Фамилия (необязательно)',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 30),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.greenAccent)
                      : ElevatedButton(
                          onPressed: _updateProfile,
                          child: Text(
                            'Сохранить изменения',
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.black),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

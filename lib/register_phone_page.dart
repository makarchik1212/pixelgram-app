import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final List<Map<String, String>> _countries = [
    {'name': 'Россия', 'code': '+7'},
    {'name': 'Казахстан', 'code': '+7'},
    {'name': 'США', 'code': '+1'},
    {'name': 'Украина', 'code': '+380'},
    {'name': 'Беларусь', 'code': '+375'},
    {'name': 'Швейцария', 'code': '+41'},
    {'name': 'Германия', 'code': '+49'},
    {'name': 'Франция', 'code': '+33'},
  ];

  String? _selectedCountryCode = '+7';
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    final phone = '${_selectedCountryCode}${_phoneController.text.trim()}';
    setState(() {
      _loading = true;
    });
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Автоматическое подтверждение (на Android)
        await _auth.signInWithCredential(credential);
        _onAuthSuccess();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка верификации: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _loading = false;
          _codeSent = true;
          _verificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _signInWithCode() async {
    final code = _codeController.text.trim();
    if (_verificationId == null) return;

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    try {
      await _auth.signInWithCredential(credential);
      _onAuthSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный код подтверждения')),
      );
    }
  }

  void _onAuthSuccess() {
    // Успешный вход — например, перейти на главную страницу
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WelcomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'РЕГИСТРАЦИЯ',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: Colors.greenAccent,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  if (!_codeSent) ...[
                    const Text(
                      'Выберите страну и введите номер:',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.greenAccent,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    DropdownButton<String>(
                      dropdownColor: Colors.black,
                      value: _selectedCountryCode,
                      isExpanded: true,
                      iconEnabledColor: Colors.greenAccent,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.greenAccent,
                        letterSpacing: 1.5,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedCountryCode = value;
                        });
                      },
                      items: _countries.map((country) {
                        return DropdownMenuItem<String>(
                          value: country['code'],
                          child: Text('${country['name']} (${country['code']})'),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _phoneController,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.greenAccent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
                        ),
                        hintText: 'Введите номер',
                        hintStyle: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: Colors.greenAccent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        textStyle: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: Colors.black,
                        ),
                      ),
                      onPressed: () {
                        final phone = _phoneController.text.trim();
                        if (phone.isEmpty || _selectedCountryCode == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Введите номер телефона')),
                          );
                          return;
                        }
                        _verifyPhone();
                      },
                      child: const Text('ОТПРАВИТЬ КОД'),
                    ),
                  ] else ...[
                    const Text(
                      'Введите код подтверждения:',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.greenAccent,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.greenAccent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
                        ),
                        hintText: 'Код из SMS',
                        hintStyle: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: Colors.greenAccent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        textStyle: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: Colors.black,
                        ),
                      ),
                      onPressed: _signInWithCode,
                      child: const Text('ПОДТВЕРДИТЬ КОД'),
                    ),
                  ]
                ],
              ),
      ),
    );
  }
}

// Заглушка главной страницы после успешного входа
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добро пожаловать'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Text(
          'Вы вошли как ${user?.phoneNumber ?? 'неизвестный пользователь'}',
          style: const TextStyle(
            fontSize: 20,
            fontFamily: 'PressStart2P',
            color: Colors.greenAccent,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

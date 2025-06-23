// lib/screens/phone_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  bool _codeSent = false;

  String _errorMessage = '';

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _errorMessage = '';
    });

    if (_phoneNumberController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, введите номер телефона.';
      });
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumberController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() {
            _errorMessage = 'Автоматическая верификация завершена.';
          });
          await _auth.signInWithCredential(credential);
          _navigateToHomePage();
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = 'Ошибка верификации: ${e.message}';
          });
          print('Ошибка верификации: ${e.code} - ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _errorMessage = 'Код отправлен на ваш номер.';
          });
          print('Код отправлен. ID верификации: $verificationId');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          setState(() {
            _errorMessage = 'Время на автоматическое получение кода истекло.';
          });
          print('Время на авто-получение истекло: $verificationId');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла непредвиденная ошибка: $e';
      });
      print('Непредвиденная ошибка при отправке кода: $e');
    }
  }

  Future<void> _signInWithCode() async {
    setState(() {
      _errorMessage = '';
    });

    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'Сначала отправьте код.';
      });
      return;
    }
    if (_smsCodeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, введите полученный код.';
      });
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text,
      );
      await _auth.signInWithCredential(credential);
      _navigateToHomePage();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Ошибка подтверждения кода: ${e.message}';
      });
      print('Ошибка подтверждения кода: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла непредвиденная ошибка: $e';
      });
      print('Непредвиденная ошибка при входе: $e');
    }
  }

  void _navigateToHomePage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Успех!'),
        content: const Text('Вы успешно вошли в аккаунт!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Здесь должна быть ваша логика перехода на главный экран после успешной аутентификации.
              // Например: Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
            },
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход по телефону')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Номер телефона (например, +14005550100)',
                  border: OutlineInputBorder(),
                  prefixText: '+',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _verifyPhoneNumber,
                child: const Text('Отправить код'),
              ),
            ] else ...[
              TextField(
                controller: _smsCodeController,
                decoration: const InputDecoration(
                  labelText: 'Код из SMS',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signInWithCode,
                child: const Text('Подтвердить код'),
              ),
            ],
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            StreamBuilder<User?>(
              stream: _auth.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Проверка статуса...');
                }
                if (snapshot.hasData) {
                  return Text('Вы вошли как: ${snapshot.data!.phoneNumber ?? 'Неизвестно'}');
                }
                return const Text('Вы не вошли.');
              },
            ),
          ],
        ),
      ),
    );
  }
}
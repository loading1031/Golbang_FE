import 'dart:developer';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:golbang/pages/signup/widgets/welcome_header_widget.dart';
import '../../services/user_service.dart';
import 'additional_info.dart';
import 'widgets/signup_widgets.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true; // 비밀번호(확인) 필드의 숨김 상태

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double padding = MediaQuery.of(context).size.width * 0.08;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WelcomeHeader(topPadding: 0.1), // 화면 높이의 10%만 여백으로 설정

                // 회원가입 폼
                IdField(controller: _idController),
                const SizedBox(height: 16.0),
                EmailField(controller: _emailController),
                const SizedBox(height: 16.0),
                PasswordField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  toggleObscureText: _togglePasswordVisibility,
                ),
                const SizedBox(height: 16.0),
                ConfirmPasswordField(
                  controller: _confirmPasswordController,
                  passwordController: _passwordController,
                  obscureText: _obscurePassword,
                  toggleObscureText: _togglePasswordVisibility,
                ),
                const SizedBox(height: 26.0),
                SubmitButton(onPressed: () => _signupStep1(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signupStep1(BuildContext ctx) async {
    if (_formKey.currentState!.validate()) {
      log('_idController.text: ${_idController.text}');
      log('_emailController.text: ${_emailController.text}');
      log('_passwordController.text: ${_passwordController.text}');

      try {
        var response = await UserService.saveUser(
          userId: _idController.text, //TODO: AccountId로 수정
          email: _emailController.text,
          password1: _passwordController.text,
          password2: _confirmPasswordController.text,
        );
        var data = json.decode(utf8.decode(response.bodyBytes));

        if (response.statusCode == 201) {

          Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (ctx) => AdditionalInfoPage(
                userId: data['data']['user_id'],
              ),
            ),
          );
        } else {
          // errors 딕셔너리 추출
          var errors = data['errors'];

          // 모든 에러 메시지 하나의 문자열로 결합
          String errorMessage = errors.entries.map((entry) {
            String messages = entry.value.join(', '); // 해당 필드의 에러 메시지 리스트를 문자열로 변환
            return messages; // 각 필드와 메시지를 조합
          }).join('\n'); // 여러 에러 메시지를 줄바꿈으로 연결

          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('$errorMessage \n회원가입에 실패했습니다. 다시 시도해 주세요.')),
          );
        }
      } catch (e) {
        log('Error: $e');
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }
}

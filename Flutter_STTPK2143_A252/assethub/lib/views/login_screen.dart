import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
  bool isLoading = false;

  // ⚠️ CHANGE BASED ON PLATFORM
  String apiUrl = "http://localhost/assethub/api/login.php";
  // Android emulator:
  // String apiUrl = "http://10.0.2.2/assethub/api/login.php";

  @override
  void initState() {
    super.initState();
    loadRememberedUser();
  }

  // 🔁 LOAD SAVED SESSION
  Future<void> loadRememberedUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool isRemembered = prefs.getBool("remember_me") ?? false;

    if (isRemembered) {
      emailController.text = prefs.getString("email") ?? "";
      rememberMe = true;

      // Auto-login (optional)
      // Navigator.pushReplacementNamed(context, '/home');
    }

    setState(() {});
  }

  // 🔐 LOGIN FUNCTION
  Future<void> loginUser() async {

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text,
        }),
      );

      var data = jsonDecode(response.body);
      print("Response: ${response.body}");
      print(data);

      setState(() => isLoading = false);

      if (data["status"] == "success") {

        SharedPreferences prefs = await SharedPreferences.getInstance();

        if (rememberMe) {
          await prefs.setBool("remember_me", true);
          await prefs.setString("email", emailController.text.trim());
          await prefs.setString("user_name", data["user"]["name"]);
          await prefs.setString("user_role", data["user"]["role"]);
        } else {
          await prefs.clear();
        }

        Navigator.pushReplacementNamed(context, '/home');

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"]),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double getResponsiveWidth(double width) {
    if (width > 900) return 400;
    if (width > 600) return 500;
    return width * 0.9;
  }

  @override
  Widget build(BuildContext context) {

    double width = MediaQuery.of(context).size.width;
    double formWidth = getResponsiveWidth(width);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: formWidth,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: width > 600
                  ? [const BoxShadow(color: Colors.black12, blurRadius: 10)]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔹 Logo
                Center(
                  child: Image.asset('assets/logo.png', width: 100),
                ),

                const SizedBox(height: 25),

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  "Login to continue",
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 25),

                // 🔹 Email
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // 🔹 Password
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 🔹 Remember Me
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() => rememberMe = value!);
                      },
                    ),
                    const Text("Remember Me"),
                  ],
                ),

                const SizedBox(height: 15),

                // 🔹 Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : loginUser,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Login",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          color: Color(0xFFFACC15),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
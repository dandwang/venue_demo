import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'listener_page.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final urlController = TextEditingController();
  final sportIdController = TextEditingController();
  final departIdController = TextEditingController();
  final dateController = TextEditingController();
  final tokenController = TextEditingController();

  final intervalController = TextEditingController();
  final continueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// 初始化数据（带默认值）
  void _initData() async {
    final prefs = await SharedPreferences.getInstance();

    /// 明天日期
    // String defaultDate = _getTomorrowDate();

    setState(() {
      urlController.text = getValue(prefs.getString("url"), "https://api.52jiayundong.com/field/list");

      sportIdController.text = getValue(prefs.getString("sportId"), "4028f0ce5551abf3015551b0aae50001");

      departIdController.text = getValue(prefs.getString("departId"), '1543');

      tokenController.text = getValue(
        prefs.getString("token"),
        'Utjme990Ea/N7yo8z0jARKzP6xjk8LgDMSmNj+wsBvvojxjVCnWOQA==',
      );

      dateController.text = _getTomorrowDate();
      intervalController.text = getValue(prefs.getString("interval"), "10");

      continueController.text = getValue(prefs.getString("continue"), "4");
    });
  }

  /// 获取明天日期
  String _getTomorrowDate() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return "${tomorrow.year}-${_twoDigits(tomorrow.month)}-${_twoDigits(tomorrow.day)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 点击保存
  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("url", urlController.text);
    await prefs.setString("sportId", sportIdController.text);
    await prefs.setString("departId", departIdController.text);
    // await prefs.setString("date", dateController.text);
    await prefs.setString("token", tokenController.text);
    await prefs.setString("interval", intervalController.text);
    await prefs.setString("continue", continueController.text);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("保存成功 ✅")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("表单")),
      // Use a SingleChildScrollView to handle overflow when the keyboard appears
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            // Constrain the column to the minimum height needed
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField("URL", urlController),
              _buildField("Sport ID", sportIdController),
              _buildField("Depart ID", departIdController),
              _buildField("Date", dateController),
              _buildField("间隔（分钟）", intervalController),
              _buildField("连续时间段", continueController),

              _buildField("Token", tokenController, maxLines: 3, minLines: 2),

              const SizedBox(height: 20), // Increased spacing slightly

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: _saveData, child: const Text("保存")),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListenerPage(
                            url: urlController.text,
                            sportId: sportIdController.text,
                            departId: departIdController.text,
                            date: dateController.text,
                            token: tokenController.text,
                            intervalMinutes: int.tryParse(intervalController.text) ?? 10,
                            continueSlots: int.tryParse(continueController.text) ?? 4,
                          ),
                        ),
                      );
                    },
                    child: const Text("开始监听"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 可复用输入框
  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1, // 默认1行（普通输入框）
    int? minLines, // 最小行数
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          // 当是多行时，让内容从顶部开始
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  String getValue(String? value, String defaultValue) {
    if (value == null || value.isEmpty) {
      return defaultValue;
    }
    return value;
  }
}

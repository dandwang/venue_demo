import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersistTextField extends StatefulWidget {
  final String storageKey;
  final String label;

  const PersistTextField({super.key, required this.storageKey, required this.label});

  @override
  State<PersistTextField> createState() => _PersistTextFieldState();
}

class _PersistTextFieldState extends State<PersistTextField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 读取缓存
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? value = prefs.getString(widget.storageKey);

    if (value != null) {
      _controller.text = value;
    }
  }

  /// 保存缓存
  void _saveData(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.storageKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
        onChanged: _saveData, // 自动保存
      ),
    );
  }
}

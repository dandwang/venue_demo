import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';

final logger = Logger();

class ListenerPage extends StatefulWidget {
  final String url;
  final String sportId;
  final String departId;
  final String date;
  final String token;
  final int intervalMinutes;

  const ListenerPage({
    super.key,
    required this.url,
    required this.sportId,
    required this.departId,
    required this.date,
    required this.token,
    required this.intervalMinutes,
  });

  @override
  State<ListenerPage> createState() => _ListenerPageState();
}

class _ListenerPageState extends State<ListenerPage> {
  Timer? _timer;
  String result = "等待请求...";
  List<dynamic> fieldList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _request();
    _timer = Timer.periodic(Duration(minutes: widget.intervalMinutes), (timer) {
      _request();
    });
  }

  String getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  Future<void> _request() async {
    final url = "${widget.url}?sportId=${widget.sportId}&departId=${widget.departId}&date=${widget.date}";

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .get(Uri.parse(url), headers: {"token": widget.token})
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setResultState(data);
      } else {
        setState(() {
          result = "请求失败: ${response.statusCode}";
          fieldList = [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = "请求失败: $e";
        fieldList = [];
        isLoading = false;
      });
    }
  }

  void setResultState(dynamic data) {
    setState(() {
      try {
        if (data == null || data is! Map) {
          result = "数据格式错误";
          fieldList = [];
          isLoading = false;
          return;
        }

        final code = data['code'] ?? '未知';
        final msg = data['msg'] ?? '';
        result = "${getCurrentTime()} 状态码: $code msg: $msg";

        final fieldData = data['data'];

        if (fieldData == null) {
          fieldList = [];
        } else if (fieldData is List) {
          if (fieldData.isNotEmpty) {
            final firstItem = fieldData[0];
            if (firstItem is Map && firstItem.containsKey('fieldList')) {
              final nestedList = firstItem['fieldList'];
              fieldList = nestedList is List ? nestedList : [];
            } else {
              fieldList = fieldData;
            }
          } else {
            fieldList = [];
          }
        } else if (fieldData is Map) {
          if (fieldData.containsKey('fieldList')) {
            final nestedList = fieldData['fieldList'];
            fieldList = nestedList is List ? nestedList : [];
          } else {
            fieldList = [fieldData];
          }
        } else {
          fieldList = [];
        }

        isLoading = false;
        logger.d("加载了 ${fieldList.length} 个场地");
      } catch (e) {
        logger.e("数据处理错误: $e");
        result = "数据处理失败";
        fieldList = [];
        isLoading = false;
      }
    });
  }

  void _stopListening() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("场地查询"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopListening();
            Navigator.pop(context);
          },
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _request)],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(child: Text(result, style: const TextStyle(fontSize: 12))),
                if (isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),

          // 场地列表
          Expanded(
            child: fieldList.isEmpty
                ? Center(child: isLoading ? const CircularProgressIndicator() : const Text("暂无场地数据"))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: fieldList.length,
                    itemBuilder: (context, index) {
                      final field = fieldList[index];
                      if (field is! Map) return const SizedBox.shrink();

                      return FieldCard(fieldData: field);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _stopListening();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.stop),
              label: const Text("停止监听"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(onPressed: _request, icon: const Icon(Icons.refresh), label: const Text("立即刷新")),
          ],
        ),
      ),
    );
  }
}

// 场地卡片组件
class FieldCard extends StatelessWidget {
  final Map fieldData;

  const FieldCard({super.key, required this.fieldData});

  @override
  Widget build(BuildContext context) {
    final fieldName = fieldData['fieldName'] ?? '未知场地';
    final priceList = fieldData['priceList'] as List? ?? [];

    // 筛选可用时间段 (status == "0")
    final availableSlots = priceList.where((slot) {
      return slot is Map && slot['status'] == "0" && slot['price'] == '15.00';
    }).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 场地标题
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_tennis, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(fieldName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: availableSlots.isNotEmpty ? Colors.green.shade600 : Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("${availableSlots.length}个可用", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),

          // 时间段列表
          if (availableSlots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text("暂无可用时间段", style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableSlots.map((slot) {
                  if (slot is! Map) return const SizedBox.shrink();

                  final startTime = slot['startTime'] ?? '';
                  final endTime = slot['endTime'] ?? '';
                  final price = slot['price'] ?? '';

                  return TimeSlotChip(startTime: startTime, endTime: endTime, price: price);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// 时间段标签组件
class TimeSlotChip extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String price;

  const TimeSlotChip({super.key, required this.startTime, required this.endTime, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$startTime-$endTime",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.green.shade800),
          ),
          // if (price.isNotEmpty) ...[
          //   const SizedBox(height: 2),
          //   Text(
          //     "¥$price",
          //     style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
          //   ),
          // ],
        ],
      ),
    );
  }
}

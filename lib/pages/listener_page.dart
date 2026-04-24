import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';
import '../services/alarm_service.dart';

import '../services/mock_data_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final logger = Logger();

class ListenerPage extends StatefulWidget {
  final String url;
  final String sportId;
  final String departId;
  final String date;
  final String token;
  final int intervalMinutes;
  final int continueSlots;
  const ListenerPage({
    super.key,
    required this.url,
    required this.sportId,
    required this.departId,
    required this.date,
    required this.token,
    required this.intervalMinutes,
    required this.continueSlots,
  });

  @override
  State<ListenerPage> createState() => _ListenerPageState();
}

class _ListenerPageState extends State<ListenerPage> {
  Timer? _timer;
  String result = "等待请求...";
  List<dynamic> fieldList = [];
  bool isLoading = false;

  // 测试模式相关
  bool _testMode = false;
  String _testScenario = 'continuous';

  final AlarmService _alarmService = AlarmService();
  bool _alarmEnabled = true; // 是否启用闹钟

  final Set<String> _triggeredAlarms = {}; // 记录已触发的闹钟，避免重复触发

  @override
  void initState() {
    super.initState();
    _initializeAlarm();
    _startListening();

    // 页面初始化时，启用唤醒锁，防止熄屏
    WakelockPlus.enable();
  }

  Future<void> _initializeAlarm() async {
    try {
      await _alarmService.initialize();
      logger.i('闹钟服务初始化成功');
    } catch (e) {
      logger.e('闹钟服务初始化失败: $e');
    }
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
    setState(() {
      isLoading = true;
    });

    try {
      if (_testMode) {
        // 使用模拟数据
        await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
        final mockData = MockDataService.getScenarioData(_testScenario);
        setResultState(mockData);
      } else {
        // 真实请求
        final url = "${widget.url}?sportId=${widget.sportId}&departId=${widget.departId}&date=${widget.date}";

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

        // 检查是否有符合条件的连续时间段
        if (_alarmEnabled) {
          _checkForContinuousSlots();
        }
      } catch (e) {
        logger.e("数据处理错误: $e");
        result = "数据处理失败";
        fieldList = [];
        isLoading = false;
      }
    });
  }

  // 检查连续可用时间段
  void _checkForContinuousSlots() {
    for (var field in fieldList) {
      if (field is! Map) continue;

      final fieldName = field['fieldName'] ?? '未知场地';
      final priceList = field['priceList'] as List? ?? [];

      // 筛选出可用且价格为15.00的时间段
      final availableSlots = <Map>[];
      for (var slot in priceList) {
        if (slot is Map && slot['status'] == "0" && slot['price'] == "15.00") {
          availableSlots.add(slot);
        }
      }

      if (availableSlots.length < widget.continueSlots) continue;

      // 按时间排序
      availableSlots.sort((a, b) {
        final timeA = a['startTime'] ?? '';
        final timeB = b['startTime'] ?? '';
        return timeA.compareTo(timeB);
      });

      // 查找连续的时间段
      final continuousGroups = _findContinuousSlots(availableSlots);

      for (var group in continuousGroups) {
        if (group.length >= widget.continueSlots) {
          final startTime = group.first['startTime'] ?? '';
          final endTime = group.last['endTime'] ?? '';
          final alarmKey = "$fieldName-$startTime-$endTime";

          // 避免重复触发
          if (!_triggeredAlarms.contains(alarmKey)) {
            _triggeredAlarms.add(alarmKey);

            logger.i('🎯 检测到连续可用: $fieldName 从 $startTime 到 $endTime (${group.length}个时间段)');

            _alarmService.triggerAlarm(
              fieldName: fieldName,
              continuousCount: group.length,
              startTime: startTime,
              endTime: endTime,
            );

            // 显示SnackBar提示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔔 $fieldName 有${group.length}个连续可用时间段！'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(label: '知道了', textColor: Colors.white, onPressed: () {}),
                ),
              );
            }
          }
        }
      }
    }
  }

  // 查找连续的时间段
  List<List<Map>> _findContinuousSlots(List<Map> slots) {
    if (slots.isEmpty) return [];

    final groups = <List<Map>>[];
    var currentGroup = <Map>[slots.first];

    for (int i = 1; i < slots.length; i++) {
      final previousSlot = slots[i - 1];
      final currentSlot = slots[i];

      final previousEndTime = previousSlot['endTime'] ?? '';
      final currentStartTime = currentSlot['startTime'] ?? '';

      // 检查是否连续（结束时间等于开始时间）
      if (previousEndTime == currentStartTime) {
        currentGroup.add(currentSlot);
      } else {
        groups.add(List.from(currentGroup));
        currentGroup = [currentSlot];
      }
    }

    // 添加最后一组
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  // 清除闹钟记录（可选，比如每天重置）
  void _clearTriggeredAlarms() {
    _triggeredAlarms.clear();
  }

  void _stopListening() {
    _timer?.cancel();
    _timer = null;
    _alarmService.stopAlarm();
  }

  @override
  void dispose() {
    // 页面销毁时，禁用唤醒锁，恢复系统自动熄屏
    // 这一步很重要，能避免应用在后台时仍保持屏幕常亮，从而节省电量
    WakelockPlus.disable();

    _stopListening();
    _alarmService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_testMode ? "测试模式 - ${_getScenarioName()}" : "场地查询"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopListening();
            Navigator.pop(context);
          },
        ),
        actions: [
          // 测试模式开关
          IconButton(
            icon: Icon(_testMode ? Icons.science : Icons.science_outlined, color: _testMode ? Colors.purple : null),
            onPressed: _showTestMenu,
          ),
          // 闹钟开关
          IconButton(
            icon: Icon(
              _alarmEnabled ? Icons.alarm : Icons.alarm_off,
              color: _alarmEnabled ? Colors.orange : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _alarmEnabled = !_alarmEnabled;
                if (!_alarmEnabled) {
                  _alarmService.stopAlarm();
                }
              });
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _request),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(result, style: const TextStyle(fontSize: 12))),
                    if (isLoading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                if (_alarmEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '监控中: 连续${widget.continueSlots}个¥15.00时段',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
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

                      return FieldCard(
                        fieldData: field,
                        onContinuousFound: (count, startTime, endTime) {
                          // 可以在这里添加额外的处理
                        },
                      );
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
              onPressed: _clearTriggeredAlarms,
              icon: const Icon(Icons.clear_all),
              label: const Text("重置闹钟"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _stopListening();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.stop),
              label: const Text("停止"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(onPressed: _request, icon: const Icon(Icons.refresh), label: const Text("刷新")),
          ],
        ),
      ),
    );
  }

  String _getScenarioName() {
    switch (_testScenario) {
      case 'continuous':
        return '连续时段';
      case 'no_continuous':
        return '无连续时段';
      case 'empty':
        return '空数据';
      case 'error':
        return '错误响应';
      default:
        return '测试';
    }
  }

  void _showTestMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('测试模式设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('启用测试模式'),
                subtitle: Text(_testMode ? '当前使用模拟数据' : '当前使用真实API'),
                value: _testMode,
                onChanged: (value) {
                  setState(() {
                    _testMode = value;
                    if (value) {
                      _testScenario = 'continuous';
                    }
                  });
                  Navigator.pop(context);
                  _request(); // 刷新数据
                },
              ),
              if (_testMode) ...[
                const Divider(),
                const Text('选择测试场景:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('连续4个时段'),
                      selected: _testScenario == 'continuous',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _testScenario = 'continuous');
                          Navigator.pop(context);
                          _request();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('无连续时段'),
                      selected: _testScenario == 'no_continuous',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _testScenario = 'no_continuous');
                          Navigator.pop(context);
                          _request();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('空数据'),
                      selected: _testScenario == 'empty',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _testScenario = 'empty');
                          Navigator.pop(context);
                          _request();
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('错误响应'),
                      selected: _testScenario == 'error',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _testScenario = 'error');
                          Navigator.pop(context);
                          _request();
                        }
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
            ],
          ),
        );
      },
    );
  }
}

// 场地卡片组件（稍作修改）
class FieldCard extends StatelessWidget {
  final Map fieldData;
  final Function(int count, String startTime, String endTime)? onContinuousFound;

  const FieldCard({super.key, required this.fieldData, this.onContinuousFound});

  // 查找连续的时间段
  List<List<Map>> _findContinuousSlots(List<Map> slots) {
    if (slots.isEmpty) return [];

    final groups = <List<Map>>[];
    var currentGroup = <Map>[slots.first];

    for (int i = 1; i < slots.length; i++) {
      final previousSlot = slots[i - 1];
      final currentSlot = slots[i];

      final previousEndTime = previousSlot['endTime'] ?? '';
      final currentStartTime = currentSlot['startTime'] ?? '';

      if (previousEndTime == currentStartTime) {
        currentGroup.add(currentSlot);
      } else {
        groups.add(List.from(currentGroup));
        currentGroup = [currentSlot];
      }
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final fieldName = fieldData['fieldName'] ?? '未知场地';
    final priceList = fieldData['priceList'] as List? ?? [];

    // 筛选可用且价格为15.00的时间段
    final availableSlots = priceList
        .where((slot) {
          return slot is Map && slot['status'] == "0" && slot['price'] == "15.00";
        })
        .map((slot) => slot as Map)
        .toList();

    // 按时间排序
    availableSlots.sort((a, b) {
      final timeA = a['startTime'] ?? '';
      final timeB = b['startTime'] ?? '';
      return timeA.compareTo(timeB);
    });

    // 查找连续组
    final continuousGroups = _findContinuousSlots(availableSlots);

    // 找出最大的连续组
    List<Map> maxContinuousGroup = [];
    for (var group in continuousGroups) {
      if (group.length > maxContinuousGroup.length) {
        maxContinuousGroup = group;
      }
    }

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
              color: maxContinuousGroup.length >= 4 ? Colors.orange.shade100 : Colors.blue.shade100,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_tennis, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fieldName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (maxContinuousGroup.length >= 4)
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '连续${maxContinuousGroup.length}个时段可用！',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
                child: Text("暂无¥15.00可用时间段", style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (continuousGroups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '发现${continuousGroups.length}组连续时段',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSlots.map((slot) {
                      final startTime = slot['startTime'] ?? '';
                      final endTime = slot['endTime'] ?? '';
                      final price = slot['price'] ?? '';

                      // 检查这个时段是否在某个连续组中
                      bool isInLongGroup = false;
                      for (var group in continuousGroups) {
                        if (group.length >= 4 && group.contains(slot)) {
                          isInLongGroup = true;
                          break;
                        }
                      }

                      return TimeSlotChip(
                        startTime: startTime,
                        endTime: endTime,
                        price: price,
                        isInLongGroup: isInLongGroup,
                      );
                    }).toList(),
                  ),
                ],
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
  final bool isInLongGroup;

  const TimeSlotChip({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.price,
    this.isInLongGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isInLongGroup ? Colors.orange.shade50 : Colors.green.shade50,
        border: Border.all(
          color: isInLongGroup ? Colors.orange.shade400 : Colors.green.shade300,
          width: isInLongGroup ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isInLongGroup
            ? [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$startTime-$endTime",
            style: TextStyle(
              fontSize: 13,
              fontWeight: isInLongGroup ? FontWeight.bold : FontWeight.w500,
              color: isInLongGroup ? Colors.orange.shade800 : Colors.green.shade800,
            ),
          ),
          if (price.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              "¥$price",
              style: TextStyle(
                fontSize: 12,
                color: isInLongGroup ? Colors.deepOrange : Colors.orange.shade700,
                fontWeight: isInLongGroup ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

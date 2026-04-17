import 'dart:convert';

class MockDataService {
  // 是否使用模拟数据
  static bool useMockData = true;

  // 模拟场地数据 - 包含连续4个¥15.00可用时间段
  static Map<String, dynamic> getMockDataWithContinuousSlots() {
    return {
      "code": 200,
      "msg": "success",
      "data": [
        {
          "fieldName": "测试场地-有连续时段",
          "id": 9999,
          "fieldPeriod": 0.5,
          "priceList": _generatePriceListWithContinuousSlots(),
        },
        {
          "fieldName": "测试场地-无连续时段",
          "id": 8888,
          "fieldPeriod": 0.5,
          "priceList": _generatePriceListWithoutContinuousSlots(),
        },
      ],
    };
  }

  // 生成有连续4个可用时间段的数据
  static List<Map<String, dynamic>> _generatePriceListWithContinuousSlots() {
    List<Map<String, dynamic>> slots = [];

    // 生成从 08:00 到 22:00 的时间段
    int hour = 8;
    int minute = 0;
    int id = 10000;

    while (hour < 22) {
      String startTime = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

      // 计算结束时间
      int endHour = hour;
      int endMinute = minute + 30;
      if (endMinute >= 60) {
        endHour++;
        endMinute = 0;
      }
      String endTime = "${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";

      // 创建时间段
      // 在 14:00 - 16:00 之间创建连续4个可用且价格为15.00的时间段
      bool isAvailableSlot = (hour >= 14 && hour < 16);

      slots.add({
        "id": id++,
        "startTime": startTime,
        "endTime": endTime,
        "price": isAvailableSlot ? "15.00" : "7.50",
        "status": isAvailableSlot ? "0" : "1", // 0=可用，1=不可用
        "seriesId": "",
        "specialOnlinePrice": false,
      });

      minute += 30;
      if (minute >= 60) {
        hour++;
        minute = 0;
      }
    }

    return slots;
  }

  // 生成没有连续可用时间段的数据
  static List<Map<String, dynamic>> _generatePriceListWithoutContinuousSlots() {
    List<Map<String, dynamic>> slots = [];

    int hour = 8;
    int minute = 0;
    int id = 20000;

    while (hour < 22) {
      String startTime = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

      int endHour = hour;
      int endMinute = minute + 30;
      if (endMinute >= 60) {
        endHour++;
        endMinute = 0;
      }
      String endTime = "${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";

      // 创建散落的可用时间段（不连续）
      bool isAvailableSlot =
          (hour == 10 && minute == 0) ||
          (hour == 12 && minute == 30) ||
          (hour == 15 && minute == 0) ||
          (hour == 18 && minute == 30);

      slots.add({
        "id": id++,
        "startTime": startTime,
        "endTime": endTime,
        "price": isAvailableSlot ? "15.00" : "7.50",
        "status": isAvailableSlot ? "0" : "1",
        "seriesId": "",
        "specialOnlinePrice": false,
      });

      minute += 30;
      if (minute >= 60) {
        hour++;
        minute = 0;
      }
    }

    return slots;
  }

  // 模拟不同的测试场景
  static Map<String, dynamic> getScenarioData(String scenario) {
    switch (scenario) {
      case 'continuous':
        return getMockDataWithContinuousSlots();
      case 'no_continuous':
        return {
          "code": 200,
          "msg": "success",
          "data": [
            {"fieldName": "测试场地", "id": 7777, "priceList": _generatePriceListWithoutContinuousSlots()},
          ],
        };
      case 'empty':
        return {"code": 200, "msg": "success", "data": []};
      case 'error':
        return {"code": 500, "msg": "服务器错误", "data": null};
      default:
        return getMockDataWithContinuousSlots();
    }
  }
}

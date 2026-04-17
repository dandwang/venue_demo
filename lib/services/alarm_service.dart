import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  // 初始化方法
  Future<void> initialize() async {
    logger.i('AlarmService 初始化开始');
    try {
      // 确保在初始化时创建新的播放器实例
      _audioPlayer = AudioPlayer();

      // 设置释放模式
      await _audioPlayer?.setReleaseMode(ReleaseMode.stop);

      // 检查音频文件
      await _checkAsset();

      logger.i('✅ AlarmService 初始化完成');
    } catch (e) {
      logger.e('AlarmService 初始化失败: $e');
    }
  }

  // 检查资源文件
  Future<void> _checkAsset() async {
    try {
      await rootBundle.load('assets/sounds/alarm.mp3');
      logger.i('✅ 音频文件加载成功');
    } catch (e) {
      logger.w('⚠️ 本地音频文件不存在，将使用系统提示音');
    }
  }

  // 触发闹钟
  Future<void> triggerAlarm({
    required String fieldName,
    required int continuousCount,
    required String startTime,
    required String endTime,
  }) async {
    logger.i('🔔 触发闹钟: $fieldName 连续$continuousCount个可用时间段 ($startTime - $endTime)');

    // 确保播放器存在且有效
    if (_audioPlayer == null) {
      logger.w('播放器未初始化，重新创建');
      _audioPlayer = AudioPlayer();
      await _audioPlayer?.setReleaseMode(ReleaseMode.stop);
    }

    // 先振动
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      logger.e('振动失败: $e');
    }

    // 播放声音
    await _playAlarmSound();
  }

  // 播放闹钟声音
  Future<void> _playAlarmSound() async {
    if (_audioPlayer == null) {
      logger.e('播放器未初始化');
      return;
    }

    try {
      // 如果正在播放，先停止
      if (_isPlaying) {
        await _audioPlayer?.stop();
        _isPlaying = false;
      }

      // 尝试播放本地文件
      try {
        logger.i('尝试播放本地音频文件');
        await _audioPlayer?.play(AssetSource('sounds/alarm.mp3'));
        _isPlaying = true;
        logger.i('🔊 开始播放闹钟');
      } catch (e) {
        logger.w('本地音频播放失败: $e');
        // 如果本地文件失败，尝试播放网络音频
        try {
          logger.i('尝试播放网络音频');
          await _audioPlayer?.play(UrlSource('https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3'));
          _isPlaying = true;
          logger.i('🔊 播放网络闹钟');
        } catch (e2) {
          logger.e('网络音频播放也失败: $e2');
          // 最后的备选：使用系统声音
          await _playSystemSound();
          return;
        }
      }

      // 等待播放完成
      if (_audioPlayer != null) {
        _audioPlayer!.onPlayerComplete.listen((_) {
          logger.i('闹钟播放完成');
          _isPlaying = false;
        });
      }

      // 重复播放2次
      for (int i = 0; i < 2; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (_isPlaying && _audioPlayer != null) {
          try {
            await _audioPlayer?.play(AssetSource('sounds/alarm.mp3'));
          } catch (e) {
            try {
              await _audioPlayer?.play(UrlSource('https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3'));
            } catch (e2) {
              // 忽略重复播放失败
            }
          }
          logger.i('🔊 第${i + 2}次播放闹钟');
        }
      }

      // 播放完成后重置状态
      await Future.delayed(const Duration(seconds: 3));
      _isPlaying = false;
    } catch (e) {
      logger.e('播放闹钟失败: $e');
      _isPlaying = false;

      // 如果所有方法都失败，至少让手机振动
      await _playSystemSound();
    }
  }

  // 使用系统声音作为备选
  Future<void> _playSystemSound() async {
    logger.i('使用系统提示音');
    for (int i = 0; i < 5; i++) {
      try {
        await HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        logger.e('系统提示音失败: $e');
      }
    }
  }

  // 停止闹钟
  Future<void> stopAlarm() async {
    try {
      if (_isPlaying && _audioPlayer != null) {
        await _audioPlayer?.stop();
        _isPlaying = false;
        logger.i('闹钟已停止');
      }
    } catch (e) {
      logger.e('停止闹钟失败: $e');
    }
  }

  // 释放资源
  void dispose() {
    try {
      _audioPlayer?.dispose();
      _audioPlayer = null;
      _isPlaying = false;
      logger.i('AlarmService 已释放');
    } catch (e) {
      logger.e('释放资源失败: $e');
    }
  }
}

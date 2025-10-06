import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/core_ml_service.dart';

// リアルタイム音声分析と波形表示ウィジェット

class AudioAnalysisWidget extends StatefulWidget {
  const AudioAnalysisWidget({super.key});

  @override
  State<AudioAnalysisWidget> createState() => _AudioAnalysisWidgetState();
}

class _AudioAnalysisWidgetState extends State<AudioAnalysisWidget> {
  List<ClassificationResult> _realtimeAudioResults = [];
  List<double> _audioWaveform = [];
  bool _isLoading = false;
  bool _isAudioRecording = false;
  String? _errorMessage;
  String? _audioClassificationError;

  // 波形表示用の設定
  static const int maxWaveformPoints = 200;
  static const double waveformUpdateInterval = 0.1; // 100ms間隔

  @override
  void dispose() {
    // 音声分類が実行中なら停止
    if (CoreMLService.isAudioClassificationActive) {
      CoreMLService.stopAudioClassification();
    }
    super.dispose();
  }

  Future<void> _toggleRealtimeAudioClassification() async {
    if (_isAudioRecording) {
      await _stopRealtimeAudioClassification();
    } else {
      await _startRealtimeAudioClassification();
    }
  }

  Future<void> _startRealtimeAudioClassification() async {
    try {
      print('📱 Widget: Starting realtime audio classification...');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _audioClassificationError = null;
        _realtimeAudioResults = [];
        _audioWaveform = [];
      });

      final success = await CoreMLService.startAudioClassification(
        onClassification: (results) {
          print('📱 Widget: Received realtime classification: $results');
          print('📱 Widget: Classification results count: ${results.length}');
          setState(() {
            _realtimeAudioResults = results;
          });
        },
        onError: (error) {
          print('❌ Widget: Realtime classification error: $error');
          setState(() {
            _audioClassificationError = error;
          });
        },
        onWaveform: (waveformData) {
          setState(() {
            // 新しい波形データを追加
            _audioWaveform.addAll(waveformData);

            // BLEチャートと同様にスライディングウィンドウを維持
            while (_audioWaveform.length > maxWaveformPoints) {
              _audioWaveform.removeAt(0);
            }
          });
        },
      );

      setState(() {
        _isAudioRecording = success;
        _isLoading = false;
      });

      if (!success) {
        setState(() {
          _errorMessage = 'リアルタイム音声分析の開始に失敗しました';
        });
      }
    } catch (e) {
      print('❌ Widget: Error starting realtime audio classification: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isAudioRecording = false;
      });
    }
  }

  Future<void> _stopRealtimeAudioClassification() async {
    try {
      print('📱 Widget: Stopping realtime audio classification...');
      setState(() {
        _isLoading = true;
      });

      final success = await CoreMLService.stopAudioClassification();

      setState(() {
        _isAudioRecording = false;
        _isLoading = false;
        _audioClassificationError = null;
      });

      if (!success) {
        setState(() {
          _errorMessage = 'リアルタイム音声分析の停止に失敗しました';
        });
      }
    } catch (e) {
      print('❌ Widget: Error stopping realtime audio classification: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isAudioRecording = false;
      });
    }
  }

  List<FlSpot> _buildWaveformSpots() {
    return _audioWaveform
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音声分析'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 音声コントロール
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'リアルタイム音声分析',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // リアルタイム音声分析ボタン
                    ElevatedButton.icon(
                      onPressed:
                          _isLoading
                              ? null
                              : _toggleRealtimeAudioClassification,
                      icon: Icon(_isAudioRecording ? Icons.stop : Icons.mic),
                      label: Text(
                        _isAudioRecording ? 'リアルタイム分析を停止' : 'リアルタイム音声分析を開始',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAudioRecording ? Colors.red : null,
                        foregroundColor:
                            _isAudioRecording ? Colors.white : null,
                      ),
                    ),

                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],

                    if (_audioClassificationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '音声分析エラー: $_audioClassificationError',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 音声波形表示
            if (_isAudioRecording)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '音声波形',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child:
                            _audioWaveform.isEmpty
                                ? const Center(child: Text('音声データを待機中...'))
                                : LineChart(
                                  LineChartData(
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _buildWaveformSpots(),
                                        isCurved: false,
                                        barWidth: 1.5,
                                        color: Colors.green,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.green.withOpacity(0.1),
                                        ),
                                      ),
                                    ],
                                    minX: 0,
                                    maxX: maxWaveformPoints.toDouble(),
                                    minY: -1.0,
                                    maxY: 1.0,
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 0.5,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 50,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      drawHorizontalLine: true,
                                      verticalInterval: 50,
                                      horizontalInterval: 0.5,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey.withOpacity(0.3),
                                          strokeWidth: 1,
                                        );
                                      },
                                      getDrawingVerticalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey.withOpacity(0.3),
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(
                                        color: Colors.grey,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // リアルタイム音声分類結果
            if (_realtimeAudioResults.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'リアルタイム音声分類結果',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _realtimeAudioResults.length,
                            itemBuilder: (context, index) {
                              final result = _realtimeAudioResults[index];
                              return ListTile(
                                title: Text(result.identifier),
                                subtitle: Text(
                                  '信頼度: ${(result.confidence * 100).toStringAsFixed(1)}%',
                                ),
                                trailing: SizedBox(
                                  width: 60,
                                  child: LinearProgressIndicator(
                                    value: result.confidence,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      result.confidence > 0.7
                                          ? Colors.green
                                          : result.confidence > 0.4
                                          ? Colors.orange
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

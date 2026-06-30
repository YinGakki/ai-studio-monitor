import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import 'account_session_manager.dart';

/// JS：点击所有"查看更多"按钮展开完整模型列表
const clickShowMoreJs = r'''
(function() {
    try {
        var clicked = 0;
        var expandButtons = document.querySelectorAll('button, [role="button"], a');
        for (var b = 0; b < expandButtons.length; b++) {
            var btn = expandButtons[b];
            var text = (btn.innerText || '').trim().toLowerCase();
            if (text.includes('more') || text.includes('更多') || text.includes('展开') ||
                text.includes('show') || text.includes('expand') || text.includes('view all') ||
                text.includes('查看全部') || text.includes('显示全部')) {
                try { btn.click(); clicked++; } catch(e) {}
            }
        }
        return clicked;
    } catch(e) {
        return 0;
    }
})();
''';

/// JS：提取 AI Studio 用量表格
const extractUsageJs = r'''
(function() {
    try {
        var result = {
            url: window.location.href,
            timestamp: new Date().toISOString(),
            models: []
        };

        // 方法1: 解析表格
        var tables = document.querySelectorAll('table');
        for (var t = 0; t < tables.length; t++) {
            var rows = tables[t].querySelectorAll('tr');
            var headers = [];
            for (var r = 0; r < rows.length; r++) {
                var cells = rows[r].querySelectorAll('th, td');
                var rowData = [];
                for (var c = 0; c < cells.length; c++) {
                    rowData.push(cells[c].innerText.trim());
                }
                if (r === 0) {
                    headers = rowData;
                } else if (rowData.length > 0) {
                    var entry = {};
                    for (var i = 0; i < headers.length && i < rowData.length; i++) {
                        entry[headers[i]] = rowData[i];
                    }
                    result.models.push(entry);
                }
            }
        }

        // 方法2: 解析卡片/列表式布局
        if (result.models.length === 0) {
            var allElements = document.querySelectorAll('[class*="model"], [class*="rate"], [class*="quota"], [class*="limit"]');
            var cardData = [];
            for (var e = 0; e < allElements.length; e++) {
                var el = allElements[e];
                var elText = el.innerText || '';
                if (elText.toLowerCase().includes('gemini') || elText.toLowerCase().includes('imagen') ||
                    elText.toLowerCase().includes('gemma')) {
                    cardData.push(elText);
                }
            }
            if (cardData.length > 0) {
                result.raw = cardData.join('\n---\n');
            }
        }

        // 方法3: 从页面文本提取
        if (result.models.length === 0 && !result.raw) {
            var bodyText = document.body ? document.body.innerText : '';
            var lines = bodyText.split('\n').filter(function(l) {
                var ll = l.toLowerCase();
                return ll.includes('rpm') || ll.includes('tpm') || ll.includes('rpd') ||
                       ll.includes('模型') || ll.includes('类别') ||
                       ll.includes('gemini') || ll.includes('flash') ||
                       ll.includes('pro') || ll.includes('ultra') ||
                       ll.includes('imagen') || ll.includes('gemma') ||
                       ll.includes('quota') || ll.includes('limit');
            });
            result.raw = lines.slice(0, 80).join('\n');
            result.fullText = bodyText.substring(0, 12000);
        }

        return JSON.stringify(result);
    } catch(e) {
        return JSON.stringify({ error: e.message });
    }
})();
''';

/// 工具方法集合 - 对应原 main.py 中的解析逻辑
class UsageParser {
  /// 解析数字，支持 1.5K / 2M 后缀
  static int parseNum(String s) {
    s = s.trim().replaceAll(',', '');
    if (s.isEmpty || s == '-' || s == '—') return 0;
    int mult = 1;
    if (s.toUpperCase().endsWith('K')) {
      mult = 1000;
      s = s.substring(0, s.length - 1);
    } else if (s.toUpperCase().endsWith('M')) {
      mult = 1000000;
      s = s.substring(0, s.length - 1);
    }
    return (double.parse(s) * mult).toInt();
  }

  /// 解析 RPM/RPD 值，返回 (current, max)
  /// "2 / 5" → (2, 5), "- / 5" → (0, 5), "0 / 1.5K" → (0, 1500)
  static (int?, int?) parseRpm(dynamic val) {
    if (val == null) return (null, null);
    final s = val.toString().trim();
    if (s.isEmpty) return (null, null);
    if (s.contains('/')) {
      final parts = s.split('/');
      final curStr = parts.first.trim();
      final maxStr = parts.last.trim();
      int? cur;
      if (curStr == '-' || curStr == '—' || curStr.isEmpty) {
        cur = 0;
      } else {
        try {
          cur = parseNum(curStr);
        } catch (_) {
          cur = 0;
        }
      }
      int maxVal;
      try {
        maxVal = parseNum(maxStr);
      } catch (_) {
        maxVal = 0;
      }
      return (cur, maxVal);
    }
    try {
      final v = parseNum(s);
      return (v, v);
    } catch (_) {
      return (0, 0);
    }
  }

  /// 统一速率限制 URL（对应原 _normalize_rate_limit_url）
  static String normalizeRateLimitUrl(String url) {
    final uri = Uri.parse(url);
    if (!uri.path.contains('rate-limit')) return url;
    final project = uri.queryParameters['project'];
    if (project == null || project.isEmpty) return url;
    return uri.replace(queryParameters: {
      'timeRange': 'last-1-day',
      'project': project,
    }).toString();
  }

  /// 从 JS 提取结果解析出 UsageEntry 列表
  static List<UsageEntry> parseExtractResult(String jsonStr) {
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final models = (data['models'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      return models.map((m) {
        final name = (m['模型'] ?? m['Model'] ?? m['name'] ?? '').toString();
        final (rpmCur, rpmMax) =
            parseRpm(m['RPM'] ?? m['rpm']);
        final (tpmCur, tpmMax) =
            parseRpm(m['TPM'] ?? m['tpm']);
        final (rpdCur, rpdMax) =
            parseRpm(m['RPD'] ?? m['rpd']);
        return UsageEntry(
          modelName: name,
          rpmCur: rpmCur,
          rpmMax: rpmMax,
          tpmCur: tpmCur,
          tpmMax: tpmMax,
          rpdCur: rpdCur,
          rpdMax: rpdMax,
        );
      }).where((e) => e.modelName.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}

/// 刷新进度回调
typedef OnRefreshProgress = void Function(RefreshState state);

enum RefreshState {
  started,
  loadingPage,
  extracting,
  saved,
  finished,
  failed,
}

/// 刷新协调器 - 使用 WebViewController 串行提取所有项目用量
/// 对应原 AIFloatingWindow._refresh_all_usage_dashboard / _extract_next_project
///
/// 多账号场景下，每个项目提取前会通过 [AccountSessionManager] 切换到
/// 该项目所属账号的 Cookie 上下文，保证跨账号刷新时登录态正确隔离。
class UsageExtractor {
  final WebViewController controller;
  final List<Account> accounts;
  final OnRefreshProgress? onProgress;
  final AccountSessionManager? sessionManager;
  final void Function(HttpAuthRequest)? onHttpAuthRequest;

  bool _running = false;
  int _successCount = 0;
  int _failCount = 0;

  int get successCount => _successCount;
  int get failCount => _failCount;

  UsageExtractor({
    required this.controller,
    required this.accounts,
    this.onProgress,
    this.sessionManager,
    this.onHttpAuthRequest,
  });

  /// 收集所有需要刷新的项目（按账号分组，便于 Cookie 切换）
  List<({String accountName, String projectName, String url})> get allProjects {
    final list = <({String accountName, String projectName, String url})>[];
    for (final acc in accounts) {
      for (final proj in acc.projects) {
        list.add((
          accountName: acc.name,
          projectName: proj.name,
          url: proj.url,
        ));
      }
    }
    return list;
  }

  /// 串行刷新所有项目用量
  Future<void> refreshAll() async {
    if (_running) return;
    _running = true;
    _successCount = 0;
    _failCount = 0;
    onProgress?.call(RefreshState.started);

    final projects = allProjects;
    String? lastAccount;
    for (final proj in projects) {
      try {
        // 跨账号切换：仅当账号变化时才切换 Cookie 上下文（避免同账号多次切换）
        if (sessionManager != null && proj.accountName != lastAccount) {
          final acc = accounts.firstWhere(
            (a) => a.name == proj.accountName,
            orElse: () => accounts.first,
          );
          final defaultUrl = acc.lastUrl.isNotEmpty
              ? acc.lastUrl
              : 'https://aistudio.google.com/projects';
          await sessionManager!.switchTo(
            targetAccount: proj.accountName,
            currentUrl: '', // 后台刷新不依赖当前页面，不保存
            defaultUrl: defaultUrl,
          );
          lastAccount = proj.accountName;
          // 等待 Cookie 应用稳定
          await Future.delayed(const Duration(milliseconds: 300));
        }
        await _extractOne(proj.accountName, proj.projectName, proj.url);
        _successCount++;
        onProgress?.call(RefreshState.saved);
      } catch (e) {
        _failCount++;
        onProgress?.call(RefreshState.failed);
      }
    }

    _running = false;
    onProgress?.call(RefreshState.finished);
  }

  /// 提取单个项目的用量
  Future<void> _extractOne(
      String accountName, String projectName, String url) async {
    final navUrl = UsageParser.normalizeRateLimitUrl(url);

    // 等待页面加载完成
    final loaded = Completer<bool>();
    final navDelegate = NavigationDelegate(
      onPageFinished: (_) {
        if (!loaded.isCompleted) loaded.complete(true);
      },
      onHttpAuthRequest: onHttpAuthRequest,
    );
    controller.setNavigationDelegate(navDelegate);

    onProgress?.call(RefreshState.loadingPage);
    await controller.loadRequest(Uri.parse(navUrl));

    // 等待页面加载（最多 30 秒）
    await loaded.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => true,
    );
    // 额外等待 SPA 渲染
    await Future.delayed(const Duration(seconds: 4));

    // 点击"查看更多"
    onProgress?.call(RefreshState.extracting);
    int clicked = 0;
    try {
      final clickResult =
          await controller.runJavaScriptReturningResult(clickShowMoreJs);
      if (clickResult is num) {
        clicked = clickResult.toInt();
      } else if (clickResult is String) {
        clicked = int.tryParse(clickResult) ?? 0;
      }
    } catch (_) {}

    // 等待展开
    await Future.delayed(
        Duration(seconds: clicked > 0 ? 3 : 2));

    // 提取用量数据
    String resultStr = '';
    try {
      final result =
          await controller.runJavaScriptReturningResult(extractUsageJs);
      if (result is String) {
        resultStr = result;
      } else {
        resultStr = result.toString();
      }
      // webview_flutter v4 可能给字符串额外包一层引号
      if (resultStr.startsWith('"') && resultStr.endsWith('"')) {
        resultStr = resultStr
            .substring(1, resultStr.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
    } catch (_) {}

    if (resultStr.isEmpty) {
      throw Exception('提取结果为空');
    }

    // 保存到数据库
    await DatabaseHelper.saveUsage(accountName, projectName, resultStr);
  }
}

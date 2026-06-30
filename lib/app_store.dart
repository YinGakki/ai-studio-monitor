import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'db/database_helper.dart';
import 'services/config_service.dart';
import 'services/usage_extractor.dart';
import 'services/account_session_manager.dart';
import 'services/native_proxy_manager.dart';
import 'services/proxy_tester.dart';
import 'models/models.dart';

/// 全局应用状态 - 对应原 AIFloatingWindow 的状态管理部分
class AppStore extends ChangeNotifier {
  final ConfigService config = ConfigService();
  AccountSessionManager? _sessionManager;
  /// 公开访问器（避免 library_private_types_in_public_api 警告）
  AccountSessionManager? get sessionManager => _sessionManager;

  // 面板数据
  List<UsageRecord> _latestUsage = [];
  List<UsageRecord> get latestUsage => _latestUsage;

  // 视图模式
  String _viewMode = 'model'; // "model" | "project"
  String get viewMode => _viewMode;
  void setViewMode(String mode) {
    _viewMode = mode;
    notifyListeners();
  }

  // 刷新状态
  bool _refreshing = false;
  int _refreshSuccess = 0;
  int _refreshFail = 0;
  int _refreshTotal = 0;
  String _statusText = '';

  bool get isRefreshing => _refreshing;
  int get refreshSuccess => _refreshSuccess;
  int get refreshFail => _refreshFail;
  int get refreshTotal => _refreshTotal;
  String get statusText => _statusText;

  // 操作日志
  final List<OpLog> _logs = [];
  List<OpLog> get logs => List.unmodifiable(_logs);

  void _addLog(String type, String detail) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _logs.insert(0, OpLog(time: time, type: type, detail: detail));
    if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    _statusText = detail;
    notifyListeners();
  }

  Future<void> init({AccountSessionManager? sessionManager}) async {
    _sessionManager = sessionManager;
    await config.load();
    // 应用 WebView 代理（手机不开 VPN 时通过代理访问 AI Studio）
    await _applyProxy();
    // 初始化会话管理器的当前账号
    if (_sessionManager != null && config.accounts.isNotEmpty) {
      _sessionManager!.setCurrent(config.accounts.first.name);
    }
    await reloadUsage();
  }

  /// 从数据库重新加载用量数据
  Future<void> reloadUsage() async {
    final rows = await DatabaseHelper.getAllLatestUsage();
    _latestUsage = rows.map(UsageRecord.fromMap).toList();
    notifyListeners();
  }

  /// 构建面板数据矩阵
  /// key: "account|project" → {modelName: ModelUsage}
  Map<String, Map<String, ModelUsage>> buildProjectModelData() {
    final result = <String, Map<String, ModelUsage>>{};
    final monitored = config.monitoredModels.toSet();

    for (final u in _latestUsage) {
      try {
        final data = json.decode(u.usageData) as Map<String, dynamic>;
        final models = (data['models'] as List? ?? []).cast<Map<String, dynamic>>();
        final pkey = '${u.accountName}|${u.projectName}';
        result.putIfAbsent(pkey, () => {});
        for (final m in models) {
          final mname = (m['模型'] ?? m['Model'] ?? m['name'] ?? '').toString();
          if (mname.isEmpty) continue;
          if (monitored.isNotEmpty && !monitored.contains(mname)) continue;
          final (rpmCur, rpmMax) = UsageParser.parseRpm(m['RPM'] ?? m['rpm']);
          final (tpmCur, tpmMax) = UsageParser.parseRpm(m['TPM'] ?? m['tpm']);
          final (rpdCur, rpdMax) = UsageParser.parseRpm(m['RPD'] ?? m['rpd']);
          final newData = ModelUsage(
            rpmCur: rpmCur, rpmMax: rpmMax,
            tpmCur: tpmCur, tpmMax: tpmMax,
            rpdCur: rpdCur, rpdMax: rpdMax,
          );
          final existing = result[pkey]![mname];
          if (existing == null) {
            result[pkey]![mname] = newData;
          } else if ((newData.rpdMax ?? 0) > (existing.rpdMax ?? 0)) {
            result[pkey]![mname] = newData;
          } else if ((newData.rpdMax ?? 0) == (existing.rpdMax ?? 0) &&
              (newData.rpdCur ?? 0) > (existing.rpdCur ?? 0)) {
            result[pkey]![mname] = newData;
          }
        }
      } catch (_) {}
    }
    return result;
  }

  /// 触发全量刷新
  Future<void> refreshAll(WebViewController controller) async {
    if (_refreshing) return;
    final projects = <({String accountName, String projectName, String url})>[];
    for (final acc in config.accounts) {
      for (final proj in acc.projects) {
        projects.add((
          accountName: acc.name,
          projectName: proj.name,
          url: proj.url,
        ));
      }
    }
    if (projects.isEmpty) {
      _addLog('warn', '没有可刷新的项目');
      return;
    }

    _refreshing = true;
    _refreshSuccess = 0;
    _refreshFail = 0;
    _refreshTotal = projects.length;
    _addLog('info', '开始刷新，共 ${projects.length} 个项目');
    notifyListeners();

    final extractor = UsageExtractor(
      controller: controller,
      accounts: config.accounts,
      sessionManager: _sessionManager,
      onHttpAuthRequest: proxyAuthCallback,
      onProgress: (state) {
        switch (state) {
          case RefreshState.saved:
            _refreshSuccess++;
            _addLog('success', '已提取 $_refreshSuccess/$_refreshTotal');
            notifyListeners();
            break;
          case RefreshState.failed:
            _refreshFail++;
            _addLog('error', '提取失败 $_refreshFail/$_refreshTotal');
            notifyListeners();
            break;
          default:
            break;
        }
      },
    );

    await extractor.refreshAll();
    await reloadUsage();
    _refreshing = false;
    final msg = _refreshFail == 0
        ? '刷新完成 ✓ $_refreshSuccess/$_refreshTotal'
        : '刷新完成 ✗ 失败$_refreshFail 成功$_refreshSuccess';
    _addLog(_refreshFail == 0 ? 'success' : 'error', msg);
    notifyListeners();
  }

  // ---- 配置变更代理 ----
  Future<void> addAccount(String name) async {
    await config.addAccount(name);
    notifyListeners();
  }

  Future<void> deleteAccount(String name) async {
    await config.deleteAccount(name);
    await DatabaseHelper.deleteAccount(name);
    await reloadUsage();
    notifyListeners();
  }

  Future<void> addProject(String acc, String name, String url) async {
    await config.addProject(acc, name, url);
    await DatabaseHelper.addProject(acc, name, url);
    notifyListeners();
  }

  Future<void> deleteProject(String acc, String name) async {
    await config.deleteProject(acc, name);
    notifyListeners();
  }

  Future<void> addMonitoredModel(String model) async {
    await config.addMonitoredModel(model);
    notifyListeners();
  }

  Future<void> removeMonitoredModel(String model) async {
    await config.removeMonitoredModel(model);
    notifyListeners();
  }

  Future<void> updateLastUrl(String acc, String url) async {
    await config.updateLastUrl(acc, url);
  }

  // ---- 代理 ----

  /// 将配置中的代理应用到 WebView
  /// 返回 true 表示应用成功
  Future<bool> _applyProxy() async {
    final proxy = config.proxy;
    if (proxy.isNotEmpty) {
      return await NativeProxyManager.setProxy(proxy);
    } else {
      return await NativeProxyManager.clearProxy();
    }
  }

  /// 更新代理配置（含凭证）并即时应用到 WebView
  /// 返回 true 表示代理已生效
  Future<bool> setProxy(String proxy,
      {String? username, String? password}) async {
    await config.setProxy(proxy);
    if (username != null && password != null) {
      await config.setProxyCredentials(username, password);
    }
    final ok = await _applyProxy();
    notifyListeners();
    return ok;
  }

  /// 测试代理连通性
  Future<ProxyTestResult> testProxy() async {
    return ProxyTester.test(
      proxy: config.proxy,
      username: config.proxyUsername,
      password: config.proxyPassword,
    );
  }

  /// 创建 WebView 代理认证回调
  /// 当代理需要密码（配置了 username）时返回回调，否则返回 null
  /// 用于 NavigationDelegate.onHttpAuthRequest
  void Function(HttpAuthRequest)? get proxyAuthCallback {
    if (config.proxy.isEmpty) return null;
    final user = config.proxyUsername;
    if (user.isEmpty) return null;
    final pass = config.proxyPassword;
    return (HttpAuthRequest request) {
      request.onProceed(
        WebViewCredential(username: user, password: pass),
      );
    };
  }
}

class OpLog {
  final String time;
  final String type; // info/success/warn/error
  final String detail;
  OpLog({required this.time, required this.type, required this.detail});
}

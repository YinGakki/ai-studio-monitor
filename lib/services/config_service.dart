import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../db/database_helper.dart';

const _kPrefKey = 'ai_studio_config';

/// 应用配置服务 - 加载/保存 config（对应原 load_config/save_config）
class ConfigService {
  Map<String, dynamic> _config = {};
  final List<Account> _accounts = [];
  List<String> _monitoredModels = [];
  String _proxy = '';
  String _proxyUsername = '';
  String _proxyPassword = '';
  double _uiScale = 1.0;

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<String> get monitoredModels => List.unmodifiable(_monitoredModels);
  String get proxy => _proxy;
  String get proxyUsername => _proxyUsername;
  String get proxyPassword => _proxyPassword;
  double get uiScale => _uiScale;
  Map<String, dynamic> get raw => Map.unmodifiable(_config);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_kPrefKey);
    if (raw == null) {
      // 首次启动：从 assets 读取默认配置
      raw = await rootBundle.loadString('assets/config.json');
      await prefs.setString(_kPrefKey, raw);
    }
    _config = json.decode(raw) as Map<String, dynamic>;
    _rebuild();
    await syncToDatabase();
  }

  Future<void> save() async {
    _config['accounts'] = _accounts.map((a) => a.toJson()).toList();
    _config['monitored_models'] = _monitoredModels;
    _config['proxy'] = _proxy;
    _config['proxy_username'] = _proxyUsername;
    _config['proxy_password'] = _proxyPassword;
    _config['ui'] = {'scale': _uiScale};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, json.encode(_config));
  }

  void _rebuild() {
    _accounts
      ..clear()
      ..addAll((_config['accounts'] as List? ?? [])
          .map((e) => Account.fromJson(e as Map<String, dynamic>)));
    _monitoredModels = (_config['monitored_models'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    _proxy = _config['proxy']?.toString() ?? '';
    _proxyUsername = _config['proxy_username']?.toString() ?? '';
    _proxyPassword = _config['proxy_password']?.toString() ?? '';
    _uiScale = (_config['ui']?['scale'] ?? 1.0).toDouble();
  }

  // ---- 账号/项目管理 ----
  Future<void> addAccount(String name) async {
    if (_accounts.any((a) => a.name == name)) return;
    _accounts.add(Account(name: name, profileDir: 'profiles/$name'));
    await save();
  }

  Future<void> deleteAccount(String name) async {
    _accounts.removeWhere((a) => a.name == name);
    await save();
  }

  Future<void> addProject(String accountName, String projectName, String url) async {
    final idx = _accounts.indexWhere((a) => a.name == accountName);
    if (idx < 0) return;
    final projs = _accounts[idx].projects;
    if (!projs.any((p) => p.url == url)) {
      projs.add(Project(name: projectName, url: url));
      await save();
    }
  }

  Future<void> deleteProject(String accountName, String projectName) async {
    final idx = _accounts.indexWhere((a) => a.name == accountName);
    if (idx < 0) return;
    _accounts[idx].projects.removeWhere((p) => p.name == projectName);
    await save();
  }

  Future<void> updateLastUrl(String accountName, String url) async {
    final idx = _accounts.indexWhere((a) => a.name == accountName);
    if (idx >= 0) {
      _accounts[idx].lastUrl = url;
      await save();
    }
  }

  // ---- 监控模型管理 ----
  Future<void> setMonitoredModels(List<String> models) async {
    _monitoredModels = List.from(models);
    await save();
  }

  Future<void> addMonitoredModel(String model) async {
    if (!_monitoredModels.contains(model)) {
      _monitoredModels.add(model);
      await save();
    }
  }

  Future<void> removeMonitoredModel(String model) async {
    _monitoredModels.remove(model);
    await save();
  }

  // ---- 代理 ----
  Future<void> setProxy(String proxy) async {
    _proxy = proxy;
    await save();
  }

  Future<void> setProxyCredentials(String username, String password) async {
    _proxyUsername = username;
    _proxyPassword = password;
    await save();
  }

  /// 同步配置中的账号/项目到 SQLite（对应原 _sync_accounts_to_db）
  Future<void> syncToDatabase() async {
    for (final acc in _accounts) {
      await DatabaseHelper.addAccount(acc.name, acc.profileDir);
      for (final proj in acc.projects) {
        await DatabaseHelper.addProject(acc.name, proj.name, proj.url);
      }
    }
  }
}

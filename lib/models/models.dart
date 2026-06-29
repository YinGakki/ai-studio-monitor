/// 数据模型：账号 → 项目 → 用量

class Account {
  final String name;
  final String profileDir;
  final String proxy;
  final List<Project> projects;
  String lastUrl;

  Account({
    required this.name,
    this.profileDir = '',
    this.proxy = '',
    this.projects = const [],
    this.lastUrl = '',
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        name: j['name'] ?? '',
        profileDir: j['profile_dir'] ?? '',
        proxy: j['proxy'] ?? '',
        projects: (j['projects'] as List? ?? [])
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastUrl: j['last_url'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'profile_dir': profileDir,
        'proxy': proxy,
        'projects': projects.map((e) => e.toJson()).toList(),
        'last_url': lastUrl,
      };
}

class Project {
  final String name;
  final String url;

  Project({required this.name, required this.url});

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        name: j['name'] ?? '',
        url: j['url'] ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

/// 从 WebView 提取出的单行用量（模型 | RPM | TPM | RPD）
class UsageEntry {
  final String modelName;
  final int? rpmCur;
  final int? rpmMax;
  final int? tpmCur;
  final int? tpmMax;
  final int? rpdCur;
  final int? rpdMax;

  UsageEntry({
    required this.modelName,
    this.rpmCur,
    this.rpmMax,
    this.tpmCur,
    this.tpmMax,
    this.rpdCur,
    this.rpdMax,
  });
}

/// 数据库中的用量记录
class UsageRecord {
  final String accountName;
  final String projectName;
  final String usageData; // JSON
  final String checkTime;

  UsageRecord({
    required this.accountName,
    required this.projectName,
    required this.usageData,
    required this.checkTime,
  });

  factory UsageRecord.fromMap(Map<String, dynamic> m) => UsageRecord(
        accountName: m['account_name'] ?? '',
        projectName: m['project_name'] ?? '',
        usageData: m['usage_data'] ?? '',
        checkTime: m['check_time'] ?? '',
      );
}

/// 单个模型在某项目下的用量数据（面板矩阵单元格）
class ModelUsage {
  final int? rpmCur;
  final int? rpmMax;
  final int? tpmCur;
  final int? tpmMax;
  final int? rpdCur;
  final int? rpdMax;

  ModelUsage({
    this.rpmCur,
    this.rpmMax,
    this.tpmCur,
    this.tpmMax,
    this.rpdCur,
    this.rpdMax,
  });
}

/// 面板用色块
class BlockData {
  final String name;
  final int? rpd;
  final int? rpdMax;
  final bool changed;
  final bool glow;
  final String accountName;
  final String projectName;

  BlockData({
    required this.name,
    this.rpd,
    this.rpdMax,
    this.changed = false,
    this.glow = false,
    this.accountName = '',
    this.projectName = '',
  });
}

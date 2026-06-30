import 'dart:io';

/// 代理测试结果
class ProxyTestResult {
  final bool success;
  final int latencyMs;
  final String message;

  ProxyTestResult({
    required this.success,
    required this.latencyMs,
    required this.message,
  });
}

/// 解析代理字符串，返回 (host, port)
/// 支持 "host:port" / "http://host:port" / "socks5://host:port"
({String host, int port})? parseProxy(String proxy) {
  var s = proxy.trim();
  if (s.isEmpty) return null;
  // 去掉 scheme
  for (final scheme in ['socks5://', 'socks4://', 'http://', 'https://']) {
    if (s.toLowerCase().startsWith(scheme)) {
      s = s.substring(scheme.length);
      break;
    }
  }
  // 去掉可能的 user:pass@
  final atIdx = s.lastIndexOf('@');
  if (atIdx >= 0) {
    s = s.substring(atIdx + 1);
  }
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final port = int.tryParse(parts[1].trim());
  if (port == null || port < 1 || port > 65535) return null;
  final host = parts[0].trim();
  if (host.isEmpty) return null;
  return (host: host, port: port);
}

/// 代理连通性测试器
///
/// 通过 Dart HttpClient 设置代理并发起测试请求，验证代理是否可用。
/// 注意：此测试使用 Dart HttpClient（独立于 WebView 的 ProxyController），
/// 但两者底层都走同一代理服务器，测试结果对 WebView 同样有参考价值。
class ProxyTester {
  /// 测试代理连通性
  ///
  /// [proxy] 如 "ying.host:7890"
  /// [username]/[password] 可选，用于需要认证的代理
  /// [testUrl] 测试目标 URL，默认用 AI Studio
  static Future<ProxyTestResult> test({
    required String proxy,
    String? username,
    String? password,
    String testUrl = 'https://aistudio.google.com',
  }) async {
    final parsed = parseProxy(proxy);
    if (parsed == null) {
      return ProxyTestResult(
        success: false,
        latencyMs: 0,
        message: '代理地址格式无效，应为 host:port',
      );
    }

    final client = HttpClient();
    client.findProxy = (uri) => 'PROXY ${parsed.host}:${parsed.port}';

    // 如果提供了凭证，添加代理认证
    if (username != null && username.isNotEmpty) {
      client.addProxyCredentials(
        parsed.host,
        parsed.port,
        '', // realm 留空，匹配任意
        HttpClientBasicCredentials(username, password ?? ''),
      );
    }

    final sw = Stopwatch()..start();
    try {
      final request = await client
          .getUrl(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 12));
      final response = await request.close().timeout(const Duration(seconds: 12));
      await response.drain<void>().timeout(const Duration(seconds: 5));
      sw.stop();
      client.close();

      if (response.statusCode < 500) {
        return ProxyTestResult(
          success: true,
          latencyMs: sw.elapsedMilliseconds,
          message: '连接成功 · ${response.statusCode} · ${sw.elapsedMilliseconds}ms',
        );
      } else {
        return ProxyTestResult(
          success: false,
          latencyMs: sw.elapsedMilliseconds,
          message: '代理可达但目标返回 ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      sw.stop();
      client.close();
      final msg = e.message.toLowerCase();
      if (msg.contains('connection refused')) {
        return ProxyTestResult(
          success: false,
          latencyMs: sw.elapsedMilliseconds,
          message: '连接被拒绝，代理未运行或端口错误',
        );
      } else if (msg.contains('timed out') || msg.contains('timeout')) {
        return ProxyTestResult(
          success: false,
          latencyMs: sw.elapsedMilliseconds,
          message: '连接超时，代理不可达或网络不通',
        );
      } else if (msg.contains('failed host lookup')) {
        return ProxyTestResult(
          success: false,
          latencyMs: sw.elapsedMilliseconds,
          message: '无法解析主机名 ${parsed.host}',
        );
      }
      return ProxyTestResult(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        message: '网络错误: ${e.message}',
      );
    } on HttpException catch (e) {
      sw.stop();
      client.close();
      // 代理认证失败通常表现为连接被重置或 407
      return ProxyTestResult(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        message: 'HTTP 错误: ${e.message}',
      );
    } catch (e) {
      sw.stop();
      client.close();
      return ProxyTestResult(
        success: false,
        latencyMs: sw.elapsedMilliseconds,
        message: '测试失败: $e',
      );
    }
  }
}

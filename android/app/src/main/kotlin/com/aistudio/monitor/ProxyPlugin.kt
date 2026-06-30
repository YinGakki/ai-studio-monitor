package com.aistudio.monitor

import android.util.Log
import androidx.webkit.ProxyController
import androidx.webkit.ProxyConfig
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * WebView 代理插件
 *
 * 通过 AndroidX WebKit 的 ProxyController 为 WebView 设置全局 HTTP 代理。
 * 对于需要认证的代理，启动一个本地中转代理服务：
 *   WebView → 本地代理(127.0.0.1:0, 无认证) → 真实代理(带认证)
 * 这样 WebView 不会遇到 407，认证在本地中转层完成。
 *
 * 暴露方法：
 *  - setProxy(proxyRule, username?, password?) → bool
 *  - clearProxy() → bool
 */
class ProxyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var relayServer: LocalProxyRelay? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        relayServer?.stop()
        relayServer = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "setProxy" -> {
                    val proxyRule = call.argument<String>("proxyRule") ?: ""
                    val username = call.argument<String>("username") ?: ""
                    val password = call.argument<String>("password") ?: ""
                    if (proxyRule.isEmpty()) {
                        clearProxyOverride(result)
                        return
                    }
                    setProxyWithAuth(proxyRule, username, password, result)
                }
                "clearProxy" -> {
                    clearProxyOverride(result)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("proxy_error", e.message ?: "unknown", null)
        }
    }

    /**
     * 设置代理，有凭证时启动本地中转服务
     */
    private fun setProxyWithAuth(
        proxyRule: String, username: String, password: String,
        result: MethodChannel.Result
    ) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            result.error("proxy_unsupported", "设备 WebView 不支持 PROXY_OVERRIDE", null)
            return
        }

        // 解析真实代理的 host:port
        var rule = proxyRule.trim()
        var scheme = "http"
        for (sc in listOf("socks5://", "socks4://", "http://", "https://")) {
            if (rule.toLowerCase().startsWith(sc)) {
                scheme = sc.trimEnd('/').trimEnd(':')
                rule = rule.substring(sc.length)
                break
            }
        }
        // 去掉可能的 user:pass@
        val atIdx = rule.lastIndexOf('@')
        if (atIdx >= 0) rule = rule.substring(atIdx + 1)
        val colonIdx = rule.lastIndexOf(':')
        if (colonIdx < 0) {
            result.error("proxy_error", "代理地址缺少端口: $proxyRule", null)
            return
        }
        val remoteHost = rule.substring(0, colonIdx).trim()
        val remotePort = rule.substring(colonIdx + 1).trim().toIntOrNull()
        if (remoteHost.isEmpty() || remotePort == null || remotePort !in 1..65535) {
            result.error("proxy_error", "代理地址无效: $proxyRule", null)
            return
        }

        // 无凭证：直接设置代理
        if (username.isEmpty() || password.isEmpty()) {
            val config = ProxyConfig.Builder()
                .addProxyRule("$scheme://$remoteHost:$remotePort")
                .build()
            ProxyController.getInstance().setProxyOverride(
                config,
                Executor { cmd -> cmd.run() },
                Runnable { result.success(true) }
            )
            return
        }

        // 有凭证：先停旧的本地中转，启动新的
        relayServer?.stop()
        val relay = LocalProxyRelay(remoteHost, remotePort, username, password)
        val localPort = relay.start()
        if (localPort < 0) {
            result.error("proxy_error", "本地中转代理启动失败", null)
            return
        }
        relayServer = relay

        // WebView 代理指向本地中转（无需认证）
        val config = ProxyConfig.Builder()
            .addProxyRule("http://127.0.0.1:$localPort")
            .build()
        ProxyController.getInstance().setProxyOverride(
            config,
            Executor { cmd -> cmd.run() },
            Runnable { result.success(true) }
        )
    }

    private fun clearProxyOverride(result: MethodChannel.Result) {
        relayServer?.stop()
        relayServer = null
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            result.error("proxy_unsupported", "设备 WebView 不支持 PROXY_OVERRIDE", null)
            return
        }
        ProxyController.getInstance().clearProxyOverride(
            Executor { cmd -> cmd.run() },
            Runnable { result.success(true) }
        )
    }

    companion object {
        private const val CHANNEL_NAME = "ai_studio_monitor/proxy"
    }
}

/**
 * 本地 HTTP 代理中转服务
 *
 * 监听 127.0.0.1 随机端口，接收 WebView 请求，
 * 通过带认证的真实代理转发，添加 Proxy-Authorization 头。
 *
 * 仅处理 HTTP CONNECT（HTTPS 隧道）和普通 HTTP 请求。
 */
class LocalProxyRelay(
    private val remoteHost: String,
    private val remotePort: Int,
    private val username: String,
    private val password: String
) {
    private var serverSocket: java.net.ServerSocket? = null
    private val executor = Executors.newCachedThreadPool()
    private var running = false
    private val authHeader = "Basic " + android.util.Base64.encodeToString(
        "$username:$password".toByteArray(), android.util.Base64.NO_WRAP
    )

    /**
     * 启动本地代理，返回监听端口；失败返回 -1
     */
    fun start(): Int {
        return try {
            val ss = java.net.ServerSocket(0, 50, java.net.InetAddress.getByName("127.0.0.1"))
            serverSocket = ss
            running = true
            val port = ss.localPort
            executor.execute { acceptLoop() }
            Log.i(TAG, "本地中转代理启动于 127.0.0.1:$port → $remoteHost:$remotePort")
            port
        } catch (e: Exception) {
            Log.e(TAG, "本地中转代理启动失败", e)
            -1
        }
    }

    fun stop() {
        running = false
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        executor.shutdownNow()
    }

    private fun acceptLoop() {
        while (running) {
            val client = try {
                serverSocket?.accept() ?: break
            } catch (e: Exception) {
                if (running) Log.e(TAG, "accept 失败", e)
                break
            }
            executor.execute { handleClient(client) }
        }
    }

    private fun handleClient(client: java.net.Socket) {
        try {
            client.soTimeout = 30000
            val input = client.getInputStream()
            val output = client.getOutputStream()

            // 读取请求行
            val reqLine = readLine(input) ?: return
            // 读取请求头
            val headers = mutableMapOf<String, String>()
            while (true) {
                val line = readLine(input) ?: break
                if (line.isEmpty()) break
                val idx = line.indexOf(':')
                if (idx > 0) {
                    headers[line.substring(0, idx).trim().lowercase()] = line.substring(idx + 1).trim()
                }
            }

            if (reqLine.startsWith("CONNECT ")) {
                // HTTPS 隧道
                handleConnect(client, reqLine, input, output)
            } else {
                // 普通 HTTP 请求
                handleHttp(reqLine, headers, input, output)
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理请求失败", e)
        } finally {
            try { client.close() } catch (_: Exception) {}
        }
    }

    /**
     * 处理 HTTPS CONNECT 隧道请求
     */
    private fun handleConnect(
        client: java.net.Socket, reqLine: String,
        input: InputStream, output: OutputStream
    ) {
        // 解析目标 host:port
        val parts = reqLine.split(" ")
        if (parts.size < 2) return
        val target = parts[1]
        val colonIdx = target.lastIndexOf(':')
        val host = if (colonIdx > 0) target.substring(0, colonIdx) else target
        val port = if (colonIdx > 0) target.substring(colonIdx + 1).toIntOrNull() ?: 443 else 443

        // 通过真实代理建立 CONNECT 隧道
        val proxySock = java.net.Socket()
        proxySock.connect(java.net.InetSocketAddress(remoteHost, remotePort), 15000)
        proxySock.soTimeout = 30000
        val proxyOut = proxySock.getOutputStream()
        val proxyIn = proxySock.getInputStream()

        // 发送 CONNECT 请求到真实代理，带认证
        val connectReq = "CONNECT $host:$port HTTP/1.1\r\n" +
            "Host: $host:$port\r\n" +
            "Proxy-Authorization: $authHeader\r\n" +
            "Proxy-Connection: keep-alive\r\n\r\n"
        proxyOut.write(connectReq.toByteArray())
        proxyOut.flush()

        // 读取代理响应
        val respLine = readLine(proxyIn) ?: return
        if (!respLine.contains("200")) {
            // 代理拒绝，返回错误给 WebView
            val errResp = "HTTP/1.1 502 Bad Gateway\r\n\r\n"
            output.write(errResp.toByteArray())
            output.flush()
            proxySock.close()
            return
        }
        // 消费剩余响应头
        while (true) {
            val line = readLine(proxyIn) ?: break
            if (line.isEmpty()) break
        }

        // 告诉 WebView 隧道已建立
        output.write("HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray())
        output.flush()

        // 双向转发
        relay(client.getInputStream(), proxyOut, executor)
        relay(proxyIn, output, executor)
    }

    /**
     * 处理普通 HTTP 请求（转发）
     */
    private fun handleHttp(
        reqLine: String, headers: Map<String, String>,
        input: InputStream, output: OutputStream
    ) {
        val parts = reqLine.split(" ")
        if (parts.size < 2) return
        val method = parts[0]
        val urlStr = parts[1]

        try {
            val url = URL(urlStr)
            val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress(remoteHost, remotePort))
            val conn = (url.openConnection(proxy) as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 30000
                instanceFollowRedirects = false
            }
            // 设置请求头（跳过 hop-by-hop 头）
            val skipHeaders = setOf("host", "proxy-authorization", "proxy-connection", "connection", "keep-alive")
            for ((k, v) in headers) {
                if (k !in skipHeaders) conn.setRequestProperty(k, v)
            }
            // 代理认证
            conn.setRequestProperty("Proxy-Authorization", authHeader)

            // 有请求体？
            val hasBody = headers["content-length"]?.toIntOrNull()?.let { it > 0 } ?: false
            if (hasBody) {
                conn.doOutput = true
                val body = input.readBytes()
                conn.outputStream.write(body)
            }

            // 返回响应
            val status = conn.responseCode
            val respHeaders = conn.headerFields
            val sb = StringBuilder("HTTP/1.1 $status ${conn.responseMessage ?: ""}\r\n")
            for ((k, v) in respHeaders) {
                if (k == null) continue
                val lower = k.lowercase()
                if (lower in skipHeaders) continue
                for (val_ in v) {
                    sb.append("$k: $val_\r\n")
                }
            }
            sb.append("\r\n")
            output.write(sb.toString().toByteArray())
            output.flush()

            val respStream = if (status in 200..399) conn.inputStream else conn.errorStream
            if (respStream != null) {
                respStream.copyTo(output)
                output.flush()
            }
            conn.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "HTTP 转发失败: $urlStr", e)
            val errResp = "HTTP/1.1 502 Bad Gateway\r\n\r\n"
            output.write(errResp.toByteArray())
            output.flush()
        }
    }

    /**
     * 双向转发流
     */
    private fun relay(input: InputStream, output: OutputStream, pool: java.util.concurrent.ExecutorService) {
        val future = pool.submit {
            try {
                val buf = ByteArray(8192)
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    output.write(buf, 0, n)
                    output.flush()
                }
            } catch (_: Exception) {}
        }
    }

    /**
     * 从输入流读一行（以 \r\n 结尾）
     */
    private fun readLine(input: InputStream): String? {
        val sb = StringBuilder()
        while (true) {
            val b = input.read()
            if (b < 0) return if (sb.isEmpty()) null else sb.toString()
            if (b == '\r'.code) {
                val next = input.read()
                if (next == '\n'.code) return sb.toString()
                sb.append(b.toChar())
                if (next >= 0) sb.append(next.toChar())
            } else {
                sb.append(b.toChar())
            }
        }
    }

    companion object {
        private const val TAG = "LocalProxyRelay"
    }
}

// lib/main.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Paper Generator',
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  var _loadingPercentage = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.141 Mobile Safari/537.36")
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'Share',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final data = jsonDecode(message.message);
            final String base64 = data['base64'];
            final String fileName = data['fileName'];
            final Uint8List bytes = base64Decode(base64);
            final tempDir = await getTemporaryDirectory();
            final file = await File('${tempDir.path}/$fileName').writeAsBytes(bytes);

            await Share.shareXFiles(
                [XFile(file.path)],
                text: 'Here is the question paper I generated!'
            );
          } catch (e) {
            debugPrint("Error sharing file from WebView: $e");
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) => setState(() => _loadingPercentage = progress),
          onPageStarted: (String url) => setState(() => _loadingPercentage = 0),
          onPageFinished: (String url) => setState(() => _loadingPercentage = 100),
          onWebResourceError: (WebResourceError error) => setState(() => _loadingPercentage = 100),
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.startsWith('whatsapp:') ||
                request.url.startsWith('mailto:') ||
                request.url.startsWith('tel:') ||
                request.url.startsWith('sms:')) {
              if (await canLaunchUrl(Uri.parse(request.url))) {
                await launchUrl(Uri.parse(request.url));
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://questions-generator-app-ihlk.vercel.app/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Generator'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loadingPercentage < 100)
            LinearProgressIndicator(
              value: _loadingPercentage / 100.0,
            ),
        ],
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebAppView(),
    );
  }
}

class WebAppView extends StatefulWidget {
  const WebAppView({super.key});

  @override
  State<WebAppView> createState() => _WebAppViewState();
}

class _WebAppViewState extends State<WebAppView> {
  InAppWebViewController? _controller;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request all necessary permissions upfront
      await [
        Permission.camera,
        Permission.microphone,
        Permission.storage,
        Permission.photos,
      ].request();
    } else if (Platform.isIOS) {
      await [Permission.camera, Permission.photos].request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPressed,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: MediaQuery.of(context).padding,
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.vertical,
            width: MediaQuery.of(context).size.width,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://clinic.thecuredesk.com"),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                allowFileAccess: true,
                javaScriptCanOpenWindowsAutomatically: true,
                // Additional settings for better compatibility
                domStorageEnabled: true,
                databaseEnabled: true,
                clearCache: false,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              // This handles camera and microphone permissions
              androidOnPermissionRequest: (
                controller,
                origin,
                resources,
              ) async {
                // Grant all requested permissions
                return PermissionRequestResponse(
                  resources: resources,
                  action: PermissionRequestResponseAction.GRANT,
                );
              },
              // iOS permission handling
              iosOnNavigationResponse: (controller, navigationResponse) async {
                return IOSNavigationResponseAction.ALLOW;
              },
              onLoadError: (controller, url, code, message) {
                print("Load error: $message");
              },
              onConsoleMessage: (controller, consoleMessage) {
                print("Console: ${consoleMessage.message}");
              },
              onDownloadStartRequest: (controller, request) async {
                await _handleDownload(request.url.toString());
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _handleBackPressed() async {
    if (_controller != null && await _controller!.canGoBack()) {
      _controller!.goBack();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 2),
        ),
      );

      return false;
    }

    return true;
  }

  Future<void> _handleDownload(String url) async {
    try {
      if (Platform.isAndroid) {
        // Check for storage permission
        PermissionStatus status;
        if (Platform.isAndroid &&
            await Permission.storage.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enable storage permission in settings"),
            ),
          );
          return;
        }

        status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission denied")),
          );
          return;
        }
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final fileName = url.split("/").last.split("?").first;

        Directory dir;
        if (Platform.isAndroid) {
          dir = Directory("/storage/emulated/0/Download");
          if (!await dir.exists()) {
            dir =
                await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory();
          }
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final file = File("${dir.path}/$fileName");
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Downloaded: ${file.path}"),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Download error: $e")));
    }
  }
}

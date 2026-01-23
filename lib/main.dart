import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:the_curedesk/Contactpage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    Future.delayed(const Duration(milliseconds: 300), () {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request all necessary permissions upfront
      await [
        Permission.camera,
        Permission.microphone,
        Permission.storage,
        Permission.photos,
        Permission.contacts,
      ].request();
    } else if (Platform.isIOS) {
      await [
        Permission.camera,
        Permission.photos,
        Permission.contacts,
      ].request();
    }
  }

  Future<void> _pickContactAndFill() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const ContactPickerPage()),
    );

    if (result == null || result['phone'] == null) return;

    final phone = result['phone'].toString().replaceAll(" ", "");

    await _controller?.evaluateJavascript(
      source: """
(function () {
  function setNativeValue(element, value) {
    const valueSetter = Object.getOwnPropertyDescriptor(element.__proto__, 'value').set;
    const prototype = Object.getPrototypeOf(element);
    const prototypeValueSetter = Object.getOwnPropertyDescriptor(prototype, 'value').set;

    if (valueSetter && valueSetter !== prototypeValueSetter) {
      prototypeValueSetter.call(element, value);
    } else {
      valueSetter.call(element, value);
    }
  }

  var input =
    document.querySelector('input[type="tel"]') ||
    document.querySelector('input[name*="mobile"]') ||
    document.querySelector('input[placeholder*="mobile"]');

  if (!input) {
    console.log("Mobile input not found");
    return;
  }

  input.focus();
  setNativeValue(input, "$phone");

  input.dispatchEvent(new Event('input', { bubbles: true }));
  input.dispatchEvent(new Event('change', { bubbles: true }));
  input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
  input.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));

  input.blur();

  console.log("Phone injected (native):", "$phone");
})();
""",
    );
  }

  // Future<Map<String, dynamic>?> _pickContact() async {
  //   // Request permission first
  //   PermissionStatus status = await Permission.contacts.status;
  //   if (!status.isGranted) status = await Permission.contacts.request();
  //   if (!status.isGranted) return {"error": "Permission denied"};

  //   // Navigate to the ContactPickerPage and wait for result
  //   final result = await Navigator.push<Map<String, dynamic>?>(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => const ContactPickerPage(),
  //     ),
  //   );

  //   return result;
  // }

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
            // child: InAppWebView(
            //   initialUrlRequest: URLRequest(
            //     url: WebUri("https://dev-clinic.thecuredesk.com"),
            //   ),
            //   initialSettings: InAppWebViewSettings(
            //     javaScriptEnabled: true,
            //     mediaPlaybackRequiresUserGesture: false,
            //     allowFileAccessFromFileURLs: true,
            //     allowUniversalAccessFromFileURLs: true,
            //     allowFileAccess: true,
            //     javaScriptCanOpenWindowsAutomatically: true,
            //     domStorageEnabled: true,
            //     databaseEnabled: true,
            //     clearCache: false,
            //   ),
            //   onWebViewCreated: (controller) {
            //     _controller = controller;
            //   },
            //   androidOnPermissionRequest: (
            //     controller,
            //     origin,
            //     resources,
            //   ) async {
            //     return PermissionRequestResponse(
            //       resources: resources,
            //       action: PermissionRequestResponseAction.GRANT,
            //     );
            //   },
            //   iosOnNavigationResponse: (controller, navigationResponse) async {
            //     return IOSNavigationResponseAction.ALLOW;
            //   },
            //   onLoadError: (controller, url, code, message) {
            //     print("Load error: $message");
            //   },
            //   onConsoleMessage: (controller, consoleMessage) {
            //     print("Console: ${consoleMessage.message}");
            //   },
            //   onDownloadStartRequest: (controller, request) async {
            //     await _handleDownload(request.url.toString());r
            //   },
            // ),
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://clinic.thecuredesk.com/"),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowFileAccess: true,
                allowContentAccess: true,
                mediaPlaybackRequiresUserGesture: false,
                domStorageEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                useHybridComposition: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;

                controller.addJavaScriptHandler(
                  handlerName: 'pickContact',
                  callback: (args) async {
                    await _pickContactAndFill();
                    return {"status": "success"};
                  },
                );
              },

              /// 🔥 THIS IS THE IMPORTANT PART
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;

                if (uri == null) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Handle phone calls
                if (uri.scheme == "tel") {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return NavigationActionPolicy.CANCEL;
                }

                // Handle mail links (optional but recommended)
                if (uri.scheme == "mailto") {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },

              androidOnPermissionRequest: (
                controller,
                origin,
                resources,
              ) async {
                return PermissionRequestResponse(
                  resources: resources,
                  action: PermissionRequestResponseAction.GRANT,
                );
              },

              onConsoleMessage: (controller, consoleMessage) {
                debugPrint("Console: ${consoleMessage.message}");
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

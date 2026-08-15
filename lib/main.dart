import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_constants.dart';
import 'shared/presentation/screens/home_screen.dart';
import 'features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'shared/presentation/providers/theme_provider.dart';
import 'shared/localization/edusheet_localizations.dart';
import 'features/pdf/services/question_paper_service.dart';
import 'features/document_reader/domain/models/document_open_request.dart';
import 'features/document_reader/presentation/providers/document_provider.dart';
import 'features/document_reader/presentation/screens/file_preview_screen.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // Preload PDF fonts in background to avoid delay when opening PDF for the first time
  QuestionPaperService.preloadTheme();

  runApp(ProviderScope(child: MyApp(startupArguments: args)));
}

class MyApp extends ConsumerStatefulWidget {
  final List<String> startupArguments;

  const MyApp({super.key, this.startupArguments = const []});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  static const MethodChannel _documentChannel = MethodChannel(
    'edusheet/document_intents',
  );

  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDocumentActivation();
  }

  void _initDocumentActivation() {
    if (Platform.isAndroid || Platform.isWindows) {
      _documentChannel.setMethodCallHandler(_handleDocumentIntentCall);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openStartupDocument());
  }

  Future<dynamic> _handleDocumentIntentCall(MethodCall call) async {
    switch (call.method) {
      case 'openDocument':
        await _handlePlatformDocument(call.arguments);
        return null;
      case 'openDocumentError':
        _showIncomingFileError(_errorMessageFromArguments(call.arguments));
        return null;
      default:
        throw MissingPluginException('Unknown document intent: ${call.method}');
    }
  }

  Future<void> _openStartupDocument() async {
    final commandLineRequest =
        DocumentOpenRequest.fromCommandLine(widget.startupArguments);
    if (commandLineRequest != null) {
      await _openRequest(commandLineRequest);
      return;
    }

    if (!Platform.isAndroid) return;
    try {
      final document = await _documentChannel
          .invokeMapMethod<String, Object?>('getInitialDocument');
      if (document != null) await _handlePlatformDocument(document);
    } on PlatformException catch (error) {
      _showIncomingFileError(error.message ?? 'Unable to open this document.');
    } on MissingPluginException {
      // Android document activation is optional when running in tests.
    }
  }

  Future<void> _handlePlatformDocument(Object? arguments) async {
    if (arguments is! Map) {
      _showIncomingFileError('Unable to resolve the selected document.');
      return;
    }
    final request = DocumentOpenRequest.fromPlatformMap(arguments);
    await _openRequest(request);
  }

  Future<void> _openRequest(DocumentOpenRequest request) async {
    try {
      final result = await ref
          .read(documentOpenCoordinatorProvider)
          .resolve(request);
      if (!mounted || result.duplicate) return;

      final session = result.session;
      if (session == null) {
        _showIncomingFileError(
          result.errorMessage ?? 'Unable to open this document.',
        );
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                FilePreviewScreen(document: session.document),
          ),
        );
      });
    } catch (_) {
      _showIncomingFileError('Unable to open this document.');
    }
  }

  String _errorMessageFromArguments(Object? arguments) {
    if (arguments is Map) {
      final message = arguments['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return 'Unable to open this document.';
  }

  void _showIncomingFileError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        // ...
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1C1E),
          surfaceContainer: const Color(0xFF202225),
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111315),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1C1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1C1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
      ),
      localizationsDelegates: const [
        EduSheetLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('hi', 'IN')],
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: const HomeScreen(),
    );
  }
}

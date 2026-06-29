import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'app_store.dart';
import 'theme/colors.dart';
import 'utils/color_ext.dart';
import 'services/account_session_manager.dart';
import 'screens/dashboard_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const AiStudioMonitorApp());
}

class AiStudioMonitorApp extends StatelessWidget {
  const AiStudioMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStore()),
      ],
      child: MaterialApp(
        title: 'AI Studio 监控',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg.color,
          colorScheme: ColorScheme.dark(
            surface: AppColors.card.color,
            primary: AppColors.info.color,
            onSurface: AppColors.fg.color,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.header.color,
            foregroundColor: AppColors.fg.color,
            elevation: 0,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageIndex = ValueNotifier(0); // 0=面板 1=浏览器 2=设置
  late final WebViewController _webController;
  final AccountSessionManager _sessionManager = AccountSessionManager();

  @override
  void initState() {
    super.initState();
    _initWebController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStore>().init(sessionManager: _sessionManager);
    });
  }

  void _initWebController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg.color)
      ..enableZoom(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: _pageIndex,
          builder: (_, index, __) {
            return IndexedStack(
              index: index,
              children: [
                DashboardScreen(
                  webController: _webController,
                  onSwitchToBrowser: () => _pageIndex.value = 1,
                ),
                BrowserScreen(
                  controller: _webController,
                  onBackToDashboard: () => _pageIndex.value = 0,
                  sessionManager: _sessionManager,
                ),
                SettingsScreen(
                  onBack: () => _pageIndex.value = 0,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _pageIndex,
        builder: (_, index, __) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.header.color,
              border: Border(top: BorderSide(color: AppColors.borderSolid.color.withValues(alpha: 0.5))),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.info.color.withValues(alpha: 0.3),
              selectedIndex: index,
              onDestinationSelected: (i) => _pageIndex.value = i,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: '面板',
                ),
                NavigationDestination(
                  icon: Icon(Icons.language_outlined),
                  selectedIcon: Icon(Icons.language),
                  label: '浏览器',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

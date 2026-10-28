import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../data/database_helper.dart';
import '../../models/app_user.dart';
import '../../models/settings.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/demo_simulator.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/sheets.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

/// Экран 20. Settings — аккаунт, приватность, тема, уведомления,
/// помощь, о нас.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with ReloadOnDataChange {
  final _settings = Repos.settings;
  AppUser? _user;
  PrivacySettings? _privacy;
  UserPreferences? _prefs;

  int get _uid => Session.instance.userId;

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final user = await Repos.auth.getUser(uid);
    final privacy = await _settings.privacy(uid);
    final prefs = await _settings.preferences(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _privacy = privacy;
      _prefs = prefs;
    });
  }

  Future<void> _choosePrivacy(String field, String title, Visibility3 current) async {
    final value = await showActionSheet<Visibility3>(
      context,
      title: title,
      selected: current,
      actions: const [
        SheetAction(value: Visibility3.everyone, label: 'Все', icon: Icons.public),
        SheetAction(
            value: Visibility3.friends, label: 'Только друзья', icon: Icons.people_outline),
        SheetAction(value: Visibility3.nobody, label: 'Никто', icon: Icons.lock_outline),
      ],
    );
    if (value == null || !mounted) return;
    if (value == current) return;
    await _settings.updatePrivacy(_uid, field, value);
    if (!mounted) return;
    AppMessages.success(context, 'Настройка приватности сохранена');
  }

  Future<void> _chooseTheme() async {
    final value = await showActionSheet<String>(
      context,
      title: 'Тема приложения',
      selected: _prefs?.theme,
      actions: const [
        SheetAction(value: 'Light (System)', label: 'Light (System)'),
        SheetAction(value: 'Light', label: 'Light'),
        SheetAction(value: 'Dark', label: 'Dark', subtitle: 'Только в читалке'),
      ],
    );
    if (value == null || !mounted) return;
    if (value == 'Dark') {
      AppMessages.warning(context,
          'Тёмная тема интерфейса появится в следующей версии. Сейчас её можно включить в настройках читалки');
      return;
    }
    await _settings.updatePreferences(_uid, {'theme': value});
    if (!mounted) return;
    AppMessages.success(context, 'Тема сохранена');
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      AppMessages.success(context, 'Пароль успешно изменён');
    }
  }

  Future<void> _logout() async {
    final ok = await AppMessages.confirm(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Данные останутся на устройстве, вы сможете войти снова.',
      confirmText: 'Выйти',
      destructive: true,
    );
    if (!ok) return;
    await Session.instance.logout();
    MainShell.currentTab.value = MainShell.home;
    if (!mounted) return;
    AppMessages.info(context, 'Вы вышли из аккаунта');
    AppNavigator.resetTo(context, const LoginScreen());
  }

  Future<void> _resetDemo() async {
    final ok = await AppMessages.confirm(
      context,
      title: 'Сбросить данные?',
      message:
          'База SQLite будет удалена и создана заново с демонстрационными данными. Все ваши изменения будут потеряны.',
      confirmText: 'Сбросить',
      destructive: true,
    );
    if (!ok) return;
    await DatabaseHelper.instance.resetDatabase();
    await Session.instance.logout();
    MainShell.currentTab.value = MainShell.home;
    if (!mounted) return;
    AppMessages.success(context, 'База данных восстановлена. Войдите заново');
    AppNavigator.resetTo(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final privacy = _privacy;
    final prefs = _prefs;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const NestedBottomNav(highlighted: MainShell.profile),
      body: SafeArea(
        child: Column(
          children: [
            BackTitleHeader(
              title: 'Настройки и конфиденциальность',
              backBackground: AppColors.surface,
              style: const TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            Expanded(
              child: user == null || privacy == null || prefs == null
                  ? const LoadingView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        const SectionLabel('Аккаунт'),
                        const SizedBox(height: 8),
                        _SettingsGroup(children: [
                          _SettingsTile(
                            label: 'Редактировать профиль',
                            value: user.name,
                            onTap: () => AppNavigator.push(
                                context, const EditProfileScreen()),
                          ),
                          _SettingsTile(
                            label: 'Пароль',
                            value: '••••••••',
                            onTap: _changePassword,
                          ),
                          _SettingsTile(
                            label: 'Email',
                            value: user.email,
                            onTap: () => AppNavigator.push(
                                context, const EditProfileScreen()),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        const SectionLabel('Privacy & Visibility'),
                        const SizedBox(height: 8),
                        _SettingsGroup(children: [
                          _SettingsTile(
                            label: 'Кто может видеть мои книги',
                            value: privacy.libraryVisibility.dbValue,
                            strongValue: true,
                            onTap: () => _choosePrivacy('library_visibility',
                                'Кто может видеть мои книги', privacy.libraryVisibility),
                          ),
                          _SettingsTile(
                            label: 'Кто может видеть мою активность',
                            value: privacy.activityVisibility.dbValue,
                            strongValue: true,
                            onTap: () => _choosePrivacy('activity_visibility',
                                'Кто может видеть мою активность',
                                privacy.activityVisibility),
                          ),
                          _SettingsTile(
                            label: 'Кто может приглашать меня в комнаты?',
                            value: privacy.roomInvitesFrom.dbValue,
                            strongValue: true,
                            onTap: () => _choosePrivacy('room_invites_from',
                                'Кто может приглашать меня в комнаты?',
                                privacy.roomInvitesFrom),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        const SectionLabel('Вид'),
                        const SizedBox(height: 8),
                        _SettingsGroup(children: [
                          _SettingsTile(
                              label: 'Тема', value: prefs.theme, onTap: _chooseTheme),
                        ]),
                        const SizedBox(height: 16),
                        const SectionLabel('Другое'),
                        const SizedBox(height: 8),
                        _SettingsGroup(children: [
                          _SettingsTile(
                            label: 'Уведомление',
                            onTap: () => showNotificationSettingsSheet(context),
                          ),
                          _SettingsTile(
                            label: 'Помощь',
                            onTap: () => AppMessages.alert(
                              context,
                              title: 'Помощь',
                              message:
                                  '• Книги ищутся на вкладке «Главное» → поиск.\n'
                                  '• Долгое нажатие на книгу в библиотеке — смена статуса или удаление.\n'
                                  '• В читалке листайте свайпом или нажатием у края экрана.\n'
                                  '• Reading Room создаётся со страницы книги или из профиля друга.',
                            ),
                          ),
                          _SettingsTile(
                            label: 'О нас',
                            onTap: () => AppMessages.alert(
                              context,
                              title: 'ReadTogether',
                              message:
                                  'Версия 1.0.0\nМобильное приложение для совместного чтения и обсуждения электронных книг.\n'
                                  'Курсовая работа: Flutter + SQLite (локальная база данных из 14 таблиц).',
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _SettingsGroup(children: [
                          Material(
                            color: AppColors.surface,
                            child: SwitchListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(12, 0, 6, 0),
                              activeTrackColor: AppColors.primary,
                              title: const Text('Демо-активность друзей',
                                  style: TextStyle(
                                      fontFamily: AppTextStyles.sans,
                                      fontSize: 14.5)),
                              subtitle: const Text(DemoSimulator.description,
                                  style: AppTextStyles.caption),
                              value: Session.instance.demoActivity,
                              onChanged: (v) async {
                                await Session.instance.setDemoActivity(v);
                                if (!mounted) return;
                                setState(() {});
                                AppMessages.info(
                                    context,
                                    v
                                        ? 'Демо-активность включена'
                                        : 'Демо-активность выключена: друзья «замрут»');
                              },
                            ),
                          ),
                          _SettingsTile(
                            label: 'Сбросить демо-данные',
                            onTap: _resetDemo,
                          ),
                          _SettingsTile(
                            label: 'Выйти из аккаунта',
                            destructive: true,
                            onTap: _logout,
                          ),
                        ]),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final String? value;
  final bool strongValue;
  final bool destructive;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.label,
    this.value,
    this.strongValue = false,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontFamily: AppTextStyles.sans,
                      fontSize: 14.5,
                      color: destructive ? AppColors.error : AppColors.textPrimary,
                    )),
              ),
              if (value != null)
                Flexible(
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 13,
                        fontWeight:
                            strongValue ? FontWeight.w600 : FontWeight.w400,
                        color: strongValue
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      )),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  size: 20,
                  color: destructive ? AppColors.error : AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Настройки уведомлений (push / email) — таблица user_preferences.
Future<void> showNotificationSettingsSheet(BuildContext context) async {
  final repo = Repos.settings;
  final uid = Session.instance.userId;
  final prefs = await repo.preferences(uid);
  if (!context.mounted) return;
  var push = prefs.pushEnabled;
  var email = prefs.emailEnabled;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Уведомления', style: AppTextStyles.centeredHeader),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
                title: const Text('Push-уведомления', style: AppTextStyles.body),
                subtitle: const Text('Приглашения, запросы в друзья, комментарии',
                    style: AppTextStyles.caption),
                value: push,
                onChanged: (v) async {
                  setSheet(() => push = v);
                  await repo.updatePreferences(uid, {'push_enabled': v ? 1 : 0});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
                title: const Text('Уведомления на email', style: AppTextStyles.body),
                subtitle: const Text('Еженедельная сводка и рекомендации',
                    style: AppTextStyles.caption),
                value: email,
                onChanged: (v) async {
                  setSheet(() => email = v);
                  await repo.updatePreferences(uid, {'email_enabled': v ? 1 : 0});
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (context.mounted) {
    AppMessages.success(context, 'Настройки уведомлений сохранены');
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _oldError;
  bool _saving = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _oldError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_old.text == _new.text) {
      setState(() => _oldError = 'Новый пароль совпадает с текущим');
      _formKey.currentState!.validate();
      return;
    }
    setState(() => _saving = true);
    final ok = await Repos.auth
        .changePassword(Session.instance.userId, _old.text, _new.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _oldError = 'Текущий пароль введён неверно';
      });
      _formKey.currentState!.validate();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Смена пароля', style: AppTextStyles.centeredHeader),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledTextField(
                label: 'Текущий пароль',
                controller: _old,
                isPassword: true,
                maxLength: 64,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Введите текущий пароль' : _oldError,
              ),
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'Новый пароль',
                controller: _new,
                isPassword: true,
                maxLength: 64,
                validator: Validators.newPassword,
              ),
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'Повторите пароль',
                controller: _confirm,
                isPassword: true,
                maxLength: 64,
                validator: (v) => Validators.confirmPassword(v, _new.text),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/book.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../books/book_details_screen.dart';

/// Экран 24. Upload Success — подтверждение, «Перейти к книге»,
/// «В библиотеку».
class UploadSuccessScreen extends StatefulWidget {
  final int bookId;
  const UploadSuccessScreen({super.key, required this.bookId});

  @override
  State<UploadSuccessScreen> createState() => _UploadSuccessScreenState();
}

class _UploadSuccessScreenState extends State<UploadSuccessScreen> {
  Book? _book;

  @override
  void initState() {
    super.initState();
    Repos.books.byId(widget.bookId).then((b) {
      if (mounted) setState(() => _book = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 100),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                      color: AppColors.successSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.genreGreen, size: 34),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Книга добавлена!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTextStyles.sans,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(
                '${book?.title ?? 'Книга'} успешно добавлена в вашу библиотеку',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 26),
              if (book != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 12,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: BookCover(
                        book: book, width: 88, height: 126, radius: 5),
                  ),
                ),
              const Spacer(),
              PrimaryButton(
                label: 'Перейти к книге',
                onPressed: () => AppNavigator.replace(
                    context, BookDetailsScreen(bookId: widget.bookId)),
              ),
              const SizedBox(height: 10),
              OutlinedAppButton(
                label: 'В библиотеку',
                darkBorder: true,
                onPressed: () =>
                    MainShell.goToTab(context, MainShell.library),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

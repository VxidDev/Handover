import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/api.dart';
import '../theme/colors.dart';

enum LegalDocument { terms, privacy }

extension LegalDocumentInfo on LegalDocument {
  String get title => switch (this) {
    LegalDocument.terms => 'Terms of Service',
    LegalDocument.privacy => 'Privacy Policy',
  };

  String get key => switch (this) {
    LegalDocument.terms => 'tos',
    LegalDocument.privacy => 'privacy',
  };
}

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  Map<String, dynamic>? _legal;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final legal = await Api.getLegal();
      if (!mounted) return;
      setState(() {
        _legal = legal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final doc = _legal?[widget.document.key] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.document.title),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.terracotta,
                  ),
                ),
              )
            : _error != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Couldn\'t load this document',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (doc != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.sage.withValues(alpha: 0.15)
                                  : AppColors.sageLight,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Version ${doc['version'] ?? '—'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.sage,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Effective ${doc['effective_date'] ?? '—'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Markdown(
                        data: doc['content'] as String? ?? '',
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          h1: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: -0.3,
                          ),
                          h2: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                          h3: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          p: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                          ),
                          listBullet: const TextStyle(
                            color: AppColors.terracotta,
                            fontSize: 16,
                          ),
                          blockquote: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSand.withValues(alpha: 0.5)
                            : AppColors.sand.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Text(
                        'Questions? Contact ${(_legal?['controller']?['email']) ?? 'the Handover team'}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
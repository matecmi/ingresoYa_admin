import 'package:flutter/material.dart';

import '../../../domain/news.dart';
import '../../widgets/admin_ui.dart';

/// «Así la ve el alumno». Se reemplaza por los widgets reales de la app
/// (generados con tool/sync_app_preview.py) cuando existan.
class NewsPreviewPanel extends StatelessWidget {
  const NewsPreviewPanel({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) =>
      const SectionCard(title: 'Así la ve el alumno', child: SizedBox());
}

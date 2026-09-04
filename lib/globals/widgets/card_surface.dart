import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';
import '../themes/app_theme.dart';

class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.spaceMd),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: AppTheme.sombraDeSurface(),
      ),
      child: child,
    );
  }
}
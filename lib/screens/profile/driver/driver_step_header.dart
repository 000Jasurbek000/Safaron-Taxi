import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_ui.dart';

class DriverStepHeader extends StatelessWidget {
  const DriverStepHeader({
    super.key,
    required this.current,
    required this.total,
    required this.title,
  });

  final int current;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const AppBackButton(),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= total; i++) ...[
                      if (i > 1)
                        Container(
                          width: 28,
                          height: 2,
                          color: i <= current ? AppColors.primary : AppColors.cardBorder,
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i <= current ? AppColors.primary : AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i <= current ? AppColors.primary : AppColors.cardBorder,
                            width: 1.5,
                          ),
                        ),
                        child: i < current
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                            : Text(
                                '$i',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: i <= current ? Colors.white : AppColors.textMuted,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

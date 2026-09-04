import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  static const _artboardSize = 382.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        key: const Key('app-splash-screen'),
        color: AppColors.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.min(
              1.0,
              math.min(
                (constraints.maxWidth - 32) / _artboardSize,
                constraints.maxHeight / _artboardSize,
              ),
            );

            return Center(
              child: Transform.translate(
                offset: Offset(0, -64 * scale),
                child: SizedBox.square(
                  dimension: _artboardSize * scale,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox.square(
                      dimension: _artboardSize,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: SvgPicture.asset(
                              'assets/icons/splash_glow.svg',
                              key: const Key('app-splash-glow'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: 123,
                            top: 139,
                            width: 136,
                            height: 90.1,
                            child: SvgPicture.asset(
                              'assets/icons/home_welcome_logo.svg',
                              key: const Key('app-splash-logo'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: 27.5,
                            top: 272,
                            width: 327,
                            child: Text(
                              'POPi\n${AppLocalizations.of(context)!.splashTagline}',
                              key: const Key('app-splash-copy'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: .25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gis;

/// Botón oficial de "Entrar con Google" (GIS) para web. Al pulsarlo, el SDK ejecuta el flujo de
/// Google y, al completarse, emite un evento en `GoogleSignIn.instance.authenticationEvents` (lo
/// escucha `WelcomeScreen`, que toma el ID token y lo envía al backend).
Widget googleSignInButton() => gis.renderButton(
      configuration: gis.GSIButtonConfiguration(
        type: gis.GSIButtonType.standard,
        theme: gis.GSIButtonTheme.outline,
        size: gis.GSIButtonSize.large,
        text: gis.GSIButtonText.signinWith,
        shape: gis.GSIButtonShape.rectangular,
        logoAlignment: gis.GSIButtonLogoAlignment.left,
        locale: 'es',
        minimumWidth: 280,
      ),
    );

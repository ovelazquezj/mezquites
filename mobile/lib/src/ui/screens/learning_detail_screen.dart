import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Detalle de un módulo de "Aprender" (CR-007 §4): `BrandedAppBar` + banner
/// BORRADOR + render del markdown bundleado (`module.assetPath`). Al tocar un
/// enlace abre la URL en el navegador EXTERNO (`url_launcher`).
///
/// La UI SOLO renderiza: el contenido (texto + enlaces "Saber más") lo provee
/// `docs/learning/` (carril A). El texto es BORRADOR (AU2/H4) y NO es asesoría
/// técnica (gates #1/#8). Sin gating (gate #3): se abre siempre desde la lista.
class LearningDetailScreen extends StatefulWidget {
  const LearningDetailScreen({super.key, required this.module});

  final LearningModule module;

  /// Helper de navegación: la lista de módulos abre el detalle con esto.
  static Future<void> open(BuildContext context, LearningModule module) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearningDetailScreen(module: module),
      ),
    );
  }

  @override
  State<LearningDetailScreen> createState() => _LearningDetailScreenState();
}

class _LearningDetailScreenState extends State<LearningDetailScreen> {
  /// Future estable del cuerpo markdown: se resuelve una sola vez (no en cada
  /// rebuild) para no reiniciar el `FutureBuilder` ni parpadear el spinner.
  Future<String>? _body;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Usa el `DefaultAssetBundle` del contexto (sobreescribible en pruebas) en
    // vez del `rootBundle` global, para que la UI sea testeable.
    _body ??= DefaultAssetBundle.of(context).loadString(widget.module.assetPath);
  }

  /// Abre el enlace tocado en el navegador EXTERNO (CR-007 §4, AC2). Si la URL
  /// no se puede abrir, avisa de forma discreta (sin romper la navegación).
  Future<void> _openLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(title: widget.module.title),
      body: ListView(
        key: const Key('learning_detail_content'),
        padding: const EdgeInsets.all(16),
        children: [
          // Marca el carácter de borrador, sin condicionar el uso (gates #1/#3).
          const InfoNote(Copy.learningDraftBanner),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _body,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Text(
                  'No se pudo cargar el contenido del módulo.',
                  key: const Key('learning_detail_error'),
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
              return MarkdownBody(
                key: const Key('learning_detail_markdown'),
                data: snapshot.data!,
                // Enlaces "Saber más" -> navegador externo (AC2).
                onTapLink: (text, href, title) => _openLink(context, href),
                // Ilustraciones EMPAQUETADAS en el bundle, no enlazadas: así los
                // módulos siguen funcionando sin conexión, que es donde de verdad
                // hacen falta (reconocer paxtle o cúscuta frente al árbol, en
                // campo y sin señal).
                imageBuilder: _buildImage,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Pinta una ilustración del módulo desde los **assets** del bundle.
  ///
  /// El markdown las referencia con ruta relativa (`img/archivo.jpg`) para que la
  /// fuente única de `docs/learning/` también se lea bien en GitHub; aquí se
  /// resuelve contra `assets/learning/`. Al ir empaquetadas no hacen ninguna
  /// petición de red: los módulos siguen sirviendo sin conexión.
  ///
  /// Si el archivo faltara (asset mal declarado en `pubspec.yaml`), se muestra el
  /// texto alternativo en vez de un cuadro roto: el módulo se puede seguir leyendo.
  Widget _buildImage(Uri uri, String? title, String? alt) {
    final ruta = uri.hasScheme
        // Una URL absoluta no debería aparecer en estos contenidos; si aparece, no
        // se descarga nada y se degrada al texto alternativo.
        ? null
        : 'assets/learning/${uri.path}';
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final alterno = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            alt?.isNotEmpty == true ? alt! : 'Ilustración no disponible.',
            key: const Key('learning_image_fallback'),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        if (ruta == null) return alterno;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // ALTURA FIJA a propósito. Con solo `width` y sin alto, el alto sale de
            // las dimensiones intrínsecas de la imagen, que valen 0 hasta que
            // termina de decodificarse: la ilustración quedaba con `Size(w, 0)`,
            // es decir en el árbol pero **invisible**. Es la misma trampa que ya
            // nos mordió en la consola con la foto de revisión (CR-029), donde el
            // área se fijó a 280 px por esta razón.
            //
            // `contain` y no `cover`: recortar una foto de reconocimiento puede
            // quitar justo el detalle que hay que distinguir (las motas del paxtle,
            // los hilos de la cúscuta), y una de las tres es vertical (960×1280).
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Image.asset(
                ruta,
                key: const Key('learning_image'),
                fit: BoxFit.contain,
                // Etiqueta para lectores de pantalla.
                semanticLabel: alt,
                errorBuilder: (_, __, ___) => alterno,
              ),
            ),
          ),
        );
      },
    );
  }
}

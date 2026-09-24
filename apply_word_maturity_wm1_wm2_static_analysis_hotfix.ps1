$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$WordView = Join-Path $Root "lib\features\document_reader\presentation\widgets\viewers\word_fidelity_document_view.dart"
$Interop = Join-Path $Root "lib\features\smart_editor\presentation\widgets\smart_editor_interop_embed_builders.dart"

if (-not (Test-Path $WordView)) { throw "Missing: $WordView" }
if (-not (Test-Path $Interop)) { throw "Missing: $Interop" }

# --- Fix 1: Flutter 3.47 ScrollCacheExtent is exposed from flutter/rendering.dart,
# not by material.dart. Reuse the same explicit rendering import already used
# elsewhere in EduSheet.
$word = Get-Content -Raw -Encoding UTF8 $WordView
$renderingImport = "import 'package:flutter/rendering.dart' as rendering show ScrollCacheExtent;"
if ($word -notmatch [regex]::Escape($renderingImport)) {
    $word = $word.Replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';`r`n$renderingImport"
    )
}
$word = $word.Replace(
    "scrollCacheExtent: ScrollCacheExtent.pixels(",
    "scrollCacheExtent: rendering.ScrollCacheExtent.pixels("
)
Set-Content -Encoding UTF8 -NoNewline -Path $WordView -Value $word

# --- Fix 2: move the shared Word-image renderer out of the LayoutBuilder
# closure so both the image embed builder and rich table-cell renderer can call it.
$interop = Get-Content -Raw -Encoding UTF8 $Interop
$startMarker = "class SmartEditorInteropImageEmbedBuilder extends EmbedBuilder {"
$endMarker = "class SmartEditorInteropTableEmbedBuilder extends EmbedBuilder {"
$start = $interop.IndexOf($startMarker)
$end = $interop.IndexOf($endMarker, $start)
if ($start -lt 0 -or $end -lt 0) {
    throw "Could not locate SmartEditorInteropImageEmbedBuilder block. No file changed."
}

$replacement = @'
class SmartEditorInteropImageEmbedBuilder extends EmbedBuilder {
  SmartEditorInteropImageEmbedBuilder({this.onEdit});

  static const keyName = 'smartDocxImage';
  final SmartEditorInteropImageEditCallback? onEdit;

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorInteropImagePayload.fromData(
      embedContext.node.value.data,
    );
    if (payload.bytes.isEmpty) {
      return const _InteropPlaceholder(
        icon: Icons.broken_image_outlined,
        label: 'Image unavailable',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = payload.widthPoints.clamp(48.0, maxWidth).toDouble();
        final sourceHeight =
            payload.heightPoints <= 0 ? 120.0 : payload.heightPoints;
        final sourceWidth =
            payload.widthPoints <= 0 ? 160.0 : payload.widthPoints;
        final height = (sourceHeight * (width / sourceWidth))
            .clamp(36.0, 640.0)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: _interopWordImage(
                    payload,
                    width: width,
                    height: height,
                    error: const _InteropPlaceholder(
                      icon: Icons.broken_image_outlined,
                      label: 'Unsupported Word image',
                    ),
                  ),
                ),
                if (onEdit != null && payload.objectId != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        key: ValueKey(
                          'smart-docx-edit-image-${payload.objectId}',
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Resize imported Word image',
                        onPressed: () => onEdit!(context, payload),
                        icon: const Icon(Icons.open_with_rounded, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _interopWordImage(
  SmartEditorInteropImagePayload payload, {
  required double width,
  required double height,
  required Widget error,
}) {
  final cropLeft = payload.cropLeft.clamp(0.0, 0.999).toDouble();
  final cropTop = payload.cropTop.clamp(0.0, 0.999).toDouble();
  final cropRight = payload.cropRight.clamp(0.0, 0.999).toDouble();
  final cropBottom = payload.cropBottom.clamp(0.0, 0.999).toDouble();
  final visibleWidth = (1 - cropLeft - cropRight).clamp(0.001, 1.0).toDouble();
  final visibleHeight = (1 - cropTop - cropBottom).clamp(0.001, 1.0).toDouble();

  Widget image;
  if (!payload.hasCrop) {
    image = Image.memory(
      payload.bytes,
      width: width,
      height: height,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => error,
    );
  } else {
    final expandedWidth = width / visibleWidth;
    final expandedHeight = height / visibleHeight;
    image = ClipRect(
      key: const ValueKey('smart-docx-image-crop-clip'),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -cropLeft * expandedWidth,
              top: -cropTop * expandedHeight,
              width: expandedWidth,
              height: expandedHeight,
              child: Image.memory(
                payload.bytes,
                width: expandedWidth,
                height: expandedHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (payload.flipHorizontal || payload.flipVertical) {
    image = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        payload.flipHorizontal ? -1.0 : 1.0,
        payload.flipVertical ? -1.0 : 1.0,
        1,
      ),
      child: image,
    );
  }
  if (payload.rotationDegrees != 0) {
    image = Transform.rotate(
      angle: payload.rotationDegrees * math.pi / 180,
      alignment: Alignment.center,
      child: image,
    );
  }
  return SizedBox(width: width, height: height, child: image);
}

'@

$interop = $interop.Substring(0, $start) + $replacement + $interop.Substring($end)
Set-Content -Encoding UTF8 -NoNewline -Path $Interop -Value $interop

# Fast source-level verification before Flutter analyze.
$wordCheck = Get-Content -Raw -Encoding UTF8 $WordView
$interopCheck = Get-Content -Raw -Encoding UTF8 $Interop
if ($wordCheck -notmatch "rendering\.ScrollCacheExtent\.pixels") {
    throw "ScrollCacheExtent fix verification failed."
}
if (($interopCheck | Select-String -Pattern "Widget _interopWordImage\(" -AllMatches).Matches.Count -ne 1) {
    throw "_interopWordImage helper verification failed."
}
if ($interopCheck -match "\)\s*Widget _interopWordImage\(") {
    throw "_interopWordImage is still nested inside a widget expression."
}

Write-Host "Applied WM1+WM2 static-analysis hotfix." -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  flutter analyze --no-pub"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_word_maturity_wm1_wm2_gate.ps1"

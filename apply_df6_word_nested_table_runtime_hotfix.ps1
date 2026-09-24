$ErrorActionPreference = "Stop"

$path = ".\lib\features\document_reader\presentation\widgets\viewers\word_fidelity_document_view.dart"

if (-not (Test-Path $path)) {
    throw "Word fidelity renderer not found: $path"
}

$content = [System.IO.File]::ReadAllText($path)

$startMarker = "class _WordTableView extends StatelessWidget {"
$endMarker = "class _WordTableRowView extends StatelessWidget {"

$start = $content.IndexOf($startMarker)
$end = $content.IndexOf($endMarker)

if ($start -lt 0) {
    throw "Could not find _WordTableView."
}
if ($end -le $start) {
    throw "Could not find _WordTableRowView after _WordTableView."
}

$currentClass = $content.Substring($start, $end - $start)

if (-not $currentClass.Contains("LayoutBuilder(")) {
    if ($currentClass.Contains("FractionallySizedBox(")) {
        Write-Host "DF6 real-document table layout hotfix is already applied." -ForegroundColor Yellow
    }
    else {
        throw "_WordTableView no longer matches the expected DF2/DF5 structure. No file was changed."
    }
}
else {
    $replacement = @'
class _WordTableView extends StatelessWidget {
  const _WordTableView({
    required this.table,
    required this.scale,
    required this.searchQuery,
    required this.skipPageFloating,
  });

  final ConversionTable table;
  final double scale;
  final String searchQuery;
  final bool skipPageFloating;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (table.alignment) {
      ConversionTextAlignment.center => Alignment.center,
      ConversionTextAlignment.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIndex = 0;
            rowIndex < table.rows.length;
            rowIndex++)
          _WordTableRowView(
            table: table,
            row: table.rows[rowIndex],
            rowIndex: rowIndex,
            scale: scale,
            searchQuery: searchQuery,
            skipPageFloating: skipPageFloating,
          ),
      ],
    );

    Widget content;
    final widthPercent = table.widthPercent;
    final widthPoints = table.widthPoints;

    if (widthPercent != null) {
      // Avoid LayoutBuilder here. Word tables can be nested inside a cell whose
      // row is measured by IntrinsicHeight. A LayoutBuilder in that intrinsic
      // measurement path can be asked to lay out re-entrantly on desktop.
      //
      // FractionallySizedBox resolves the same percentage from the finite page
      // or cell width without a layout callback.
      content = FractionallySizedBox(
        alignment: alignment,
        widthFactor: (widthPercent / 100).clamp(0.01, 1.0).toDouble(),
        child: rows,
      );
    } else if (widthPoints != null && widthPoints > 0) {
      // Align supplies loose but finite page/cell constraints. SizedBox requests
      // the Word width and Flutter automatically clamps it to the available
      // width, matching the previous min(requested, available) behavior.
      content = Align(
        alignment: alignment,
        child: SizedBox(
          width: math.max(1.0, widthPoints * scale),
          child: rows,
        ),
      );
    } else {
      // Auto-width Word tables consume the available content width.
      content = rows;
    }

    return Padding(
      padding: EdgeInsets.only(
        top: 2 * scale,
        bottom: 2 * scale,
        left: math.max(0.0, table.indentPoints * scale),
      ),
      child: content,
    );
  }
}

'@

    $updated = $content.Substring(0, $start) + $replacement + $content.Substring($end)

    $newStart = $updated.IndexOf($startMarker)
    $newEnd = $updated.IndexOf($endMarker)
    $newClass = $updated.Substring($newStart, $newEnd - $newStart)

    if ($newClass.Contains("LayoutBuilder(")) {
        throw "Verification failed: _WordTableView still contains LayoutBuilder."
    }
    if (-not $newClass.Contains("FractionallySizedBox(")) {
        throw "Verification failed: percentage table sizing replacement is missing."
    }
    if (-not $newClass.Contains("widthPoints * scale")) {
        throw "Verification failed: fixed Word table width preservation is missing."
    }

    [System.IO.File]::WriteAllText(
        $path,
        $updated,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host "Applied DF6 Word nested-table runtime layout hotfix." -ForegroundColor Green
}

$testSource = ".\word_fidelity_nested_table_runtime_regression_test.dart"
$testDestination = ".\test\features\document_reader\word_fidelity_nested_table_runtime_regression_test.dart"

if (Test-Path $testSource) {
    New-Item -ItemType Directory -Force -Path (Split-Path $testDestination) | Out-Null
    Copy-Item -Force $testSource $testDestination
    Write-Host "Installed nested-table runtime regression test." -ForegroundColor Green
}
elseif (-not (Test-Path $testDestination)) {
    throw "Regression test file is missing. Extract the whole hotfix ZIP into the project root."
}

$gateSource = ".\run_df6_word_real_document_runtime_hotfix_gate.ps1"
$gateDestination = ".\tool\run_df6_word_real_document_runtime_hotfix_gate.ps1"

if (Test-Path $gateSource) {
    New-Item -ItemType Directory -Force -Path (Split-Path $gateDestination) | Out-Null
    Copy-Item -Force $gateSource $gateDestination
    Write-Host "Installed runtime hotfix gate." -ForegroundColor Green
}
elseif (-not (Test-Path $gateDestination)) {
    throw "Runtime hotfix gate file is missing. Extract the whole hotfix ZIP into the project root."
}

Write-Host ""
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_df6_word_real_document_runtime_hotfix_gate.ps1"

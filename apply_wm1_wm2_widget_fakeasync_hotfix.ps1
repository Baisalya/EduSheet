$ErrorActionPreference = "Stop"

$TestFile = Join-Path $PSScriptRoot "test\features\document_reader\word_wm1_wm2_ooxml_style_media_test.dart"
if (-not (Test-Path $TestFile)) {
    throw "WM1+WM2 test file not found: $TestFile"
}

$content = Get-Content -Raw -LiteralPath $TestFile

$fixedNeedle = 'final fixture = (await tester.runAsync<File>(_writeWm12Fixture))!;'
if ($content.Contains($fixedNeedle)) {
    Write-Host "WM1+WM2 widget FakeAsync hotfix is already applied." -ForegroundColor Green
    exit 0
}

$old = @'
  testWidgets('WM1+WM2 viewer applies caps and mounts a crop clip', (tester) async {
    final fixture = await _writeWm12Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });
    final document = await DocxConversionParser.parse(fixture);

    await tester.pumpWidget(
'@

$new = @'
  testWidgets('WM1+WM2 viewer applies caps and mounts a crop clip', (tester) async {
    // File-system and ZIP/XML parsing use real asynchronous I/O. Widget tests
    // execute under FakeAsync, so run those operations outside the fake clock
    // just like the established DF1 real-DOCX widget regression. Without this
    // boundary the test can wait until the global 10-minute timeout even when
    // the renderer itself is healthy.
    final fixture = (await tester.runAsync<File>(_writeWm12Fixture))!;
    addTearDown(
      () => tester.runAsync(() async {
        if (await fixture.parent.exists()) {
          await fixture.parent.delete(recursive: true);
        }
      }),
    );
    final document = (await tester.runAsync<ConversionDocument>(
      () => DocxConversionParser.parse(fixture),
    ))!;

    await tester.pumpWidget(
'@

if (-not $content.Contains($old)) {
    throw "Expected pre-hotfix WM1+WM2 widget-test block was not found. No file was changed."
}

$content = $content.Replace($old, $new)
Set-Content -LiteralPath $TestFile -Value $content -NoNewline -Encoding UTF8

$verify = Get-Content -Raw -LiteralPath $TestFile
if (-not $verify.Contains($fixedNeedle)) {
    throw "Hotfix verification failed: tester.runAsync boundary is missing."
}
if ($verify.Contains('final fixture = await _writeWm12Fixture();')) {
    throw "Hotfix verification failed: direct widget-test file I/O is still present."
}

Write-Host "Applied WM1+WM2 widget FakeAsync timeout hotfix." -ForegroundColor Green
Write-Host ""
Write-Host "Run targeted contract first:"
Write-Host "  flutter test test/features/document_reader/word_wm1_wm2_ooxml_style_media_test.dart"
Write-Host ""
Write-Host "Then rerun the full gate:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\run_word_maturity_wm1_wm2_gate.ps1"

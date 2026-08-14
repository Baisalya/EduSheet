$ErrorActionPreference = 'Stop'

if (-not (Test-Path '.\pubspec.yaml')) {
  throw 'Run this script from the EduSheet project root (the folder containing pubspec.yaml).'
}

$obsoleteFiles = @(
  'lib/features/editor/presentation/widgets/question_editor_sheet.dart',
  'lib/features/geometry_builder/widgets/export_panel.dart',
  'lib/features/geometry_builder/widgets/geometry_toolbar.dart',
  'lib/features/geometry_builder/widgets/shape_picker.dart',
  'lib/features/pdf/presentation/screens/template_designer_screen.dart',
  'lib/features/pdf/presentation/widgets/template_header_preview.dart',
  'lib/features/pdf/presentation/widgets/template_selector.dart',
  'lib/features/templates/data/built_in_content_templates.dart',
  'lib/features/templates/data/content_template_repository.dart',
  'lib/features/templates/domain/models/content_template.dart',
  'lib/features/templates/presentation/providers/content_template_provider.dart',
  'lib/features/templates/presentation/widgets/content_template_picker_sheet.dart',
  'lib/features/templates/services/template_clone_service.dart',
  'test/features/templates/content_template_test.dart'
)

$removed = 0
foreach ($relativePath in $obsoleteFiles) {
  $path = Join-Path (Get-Location) $relativePath
  if (Test-Path $path) {
    Remove-Item -LiteralPath $path -Force
    Write-Host "Removed obsolete file: $relativePath"
    $removed++
  }
}

Write-Host "Cleanup complete. Removed $removed obsolete file(s)."
Write-Host 'Next: flutter analyze; flutter test'

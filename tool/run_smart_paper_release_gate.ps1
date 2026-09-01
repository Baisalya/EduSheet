$ErrorActionPreference = 'Stop'

Write-Host 'EduSheet Smart Paper release gate' -ForegroundColor Cyan
Write-Host '1/4 Formatting check'
dart format --output=none --set-exit-if-changed lib test

Write-Host '2/4 Static analysis'
flutter analyze

Write-Host '3/4 Focused Smart Paper release tests'
flutter test test/release

Write-Host '4/4 Full regression suite'
flutter test

Write-Host 'Smart Paper release gate passed.' -ForegroundColor Green

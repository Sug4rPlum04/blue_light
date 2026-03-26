param(
  [string]$OutDir = ".\screens"
)

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$shots = @(
  '01_sign_in.png',
  '02_create_account.png',
  '03_home.png',
  '04_discover.png',
  '05_friends.png',
  '06_map.png',
  '07_messages_list.png',
  '08_chat_thread.png',
  '09_profile.png',
  '10_emergency_alert_popup.png',
  '11_alert_details_popup.png'
)

Write-Host "Take each screenshot after navigating to the matching screen." -ForegroundColor Cyan
foreach ($name in $shots) {
  $path = Join-Path $OutDir $name
  Write-Host "Capture now: $name" -ForegroundColor Yellow
  flutter screenshot --out $path
}

Write-Host "Done. Screens saved to $OutDir" -ForegroundColor Green

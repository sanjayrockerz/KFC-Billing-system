param(
  [Parameter(Mandatory=$true)]
  [string]$ShopName,
  [Parameter(Mandatory=$true)]
  [string]$ShopNameTamil,
  [Parameter(Mandatory=$true)]
  [string]$ShopPhone,
  [Parameter(Mandatory=$true)]
  [string]$ShopPhoneE164,
  [string]$SupabaseUrl = "",
  [string]$SupabaseAnonKey = "",
  [string]$ShopEmail = "",
  [string]$ShopAddress = "",
  [string]$Subtitle = "Admin Dashboard",
  [string]$NewRepoDir = ""
)

$ShortName = $ShopName -replace '\s+', ''
$ShortNameLower = $ShortName.ToLower()
$ShortNameUpper = $ShortName.ToUpper()
$ShopNameUpper = $ShopName.ToUpper()

if ([string]::IsNullOrEmpty($ShopEmail)) { $ShopEmail = "admin@${ShortNameLower}.local" }
if ([string]::IsNullOrEmpty($ShopAddress)) { $ShopAddress = "Update with your business address" }
if ([string]::IsNullOrEmpty($NewRepoDir)) { $NewRepoDir = "$PSScriptRoot\..\..\..\$ShortNameLower-admin" }

Write-Host "=== NEW SHOP SETUP ===" -ForegroundColor Cyan
Write-Host "Shop Name:     $ShopName"
Write-Host "Short Name:    $ShortName"
Write-Host "Phone:         $ShopPhone"
Write-Host "Output Dir:    $NewRepoDir"
Write-Host ""

# --- 1. COPY ---
Write-Host "[1/6] Copying project to $NewRepoDir ..." -ForegroundColor Yellow
$SourceDir = Resolve-Path "$PSScriptRoot\.."
if (Test-Path $NewRepoDir) {
  Write-Host "  Target exists, removing..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force $NewRepoDir
}
Copy-Item -Recurse -Path $SourceDir -Destination $NewRepoDir
Write-Host "  [OK] Copied" -ForegroundColor Green

# --- 2. Update brand.ts ---
Write-Host "[2/6] Updating brand.ts ..." -ForegroundColor Yellow
$BrandFile = "$NewRepoDir\src\lib\brand.ts"
@"
export const BRAND_EN = '$ShopName'
export const BRAND_TA = '$ShopNameTamil'
export const BRAND_SUBTITLE = '$Subtitle'

export const BRAND_PRIMARY_PHONE_DISPLAY = '$ShopPhone'
export const BRAND_PRIMARY_PHONE_E164 = '$ShopPhoneE164'
export const BRAND_SECONDARY_PHONE_DISPLAY = '$ShopPhone'
export const BRAND_SECONDARY_PHONE_E164 = '$ShopPhoneE164'
export const BRAND_THIRD_PHONE_DISPLAY = '$ShopPhone'
export const BRAND_THIRD_PHONE_E164 = '$ShopPhoneE164'
export const BRAND_PHONE_DISPLAY = BRAND_PRIMARY_PHONE_DISPLAY
export const BRAND_PHONE_E164 = BRAND_PRIMARY_PHONE_E164
export const BRAND_WHATSAPP = BRAND_THIRD_PHONE_DISPLAY
export const WHATSAPP_NUM = BRAND_THIRD_PHONE_E164
export const BRAND_WHATSAPP_LINK = 'https://wa.me/${ShopPhoneE164}'
export const BRAND_EMAIL = '$ShopEmail'
export const BRAND_ADDRESS = '$ShopAddress'
export const BRAND_LOCATION_LINK = '#'
"@ | Set-Content -Path $BrandFile -Encoding UTF8
Write-Host "  [OK] brand.ts updated" -ForegroundColor Green

# --- 3. Update index.html ---
Write-Host "[3/6] Updating index.html ..." -ForegroundColor Yellow
$IndexFile = "$NewRepoDir\index.html"
$IndexContent = Get-Content $IndexFile -Raw
$IndexContent = $IndexContent -replace 'Zera Admin Billing \| Admin Dashboard Template', "$ShopName | $Subtitle"
$IndexContent = $IndexContent -replace 'Zera Admin Billing is a reusable admin dashboard template', "$ShopName is a business management system"
$IndexContent = $IndexContent -replace '"Zera Admin Billing"', "`"$ShopName`""
$IndexContent = $IndexContent -replace '/zera-logo\.png', "/$($ShortNameLower)-logo.png"
Set-Content -Path $IndexFile -Value $IndexContent -Encoding UTF8
Write-Host "  [OK] index.html updated" -ForegroundColor Green

# --- 4. Update .env.example ---
Write-Host "[4/6] Updating .env.example ..." -ForegroundColor Yellow
$EnvFile = "$NewRepoDir\.env.example"
$EnvContent = Get-Content $EnvFile -Raw
$EnvContent = $EnvContent -replace 'VITE_SUPABASE_URL=.*', "VITE_SUPABASE_URL=$SupabaseUrl"
$EnvContent = $EnvContent -replace 'VITE_SUPABASE_ANON_KEY=.*', "VITE_SUPABASE_ANON_KEY=$SupabaseAnonKey"
$EnvContent = $EnvContent -replace 'VITE_WHATSAPP_NUMBER=.*', "VITE_WHATSAPP_NUMBER=$ShopPhoneE164"
Set-Content -Path $EnvFile -Value $EnvContent -Encoding UTF8
Write-Host "  [OK] .env.example updated" -ForegroundColor Green

# --- 5. Replace all brand references in source files ---
Write-Host "[5/6] Replacing brand references in source files ..." -ForegroundColor Yellow

$SourceFiles = Get-ChildItem "$NewRepoDir\src" -Recurse -Include *.ts,*.tsx,*.json `
  | Where-Object { -not $_.FullName.Contains('\node_modules\') }

$Count = 0
foreach ($file in $SourceFiles) {
  $content = Get-Content $file.FullName -Raw
  $orig = $content

  $content = $content -replace 'Zera Admin Billing', $ShopName
  $content = $content -replace 'zera-logo\.png', "$($ShortNameLower)-logo.png"

  if ($content -ne $orig) {
    Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
    $Count++
  }
}

# Targeted replacements in specific files
$SpecialFiles = @(
  @{Path="$NewRepoDir\src\store\store.ts"; Old="'sri-siddha-auth'"; New="'$($ShortNameLower)-auth'"}
  @{Path="$NewRepoDir\src\store\store.ts"; Old="'sri-siddha-cart'"; New="'$($ShortNameLower)-cart'"}
  @{Path="$NewRepoDir\src\store\store.ts"; Old="'sri-siddha-favorites'"; New="'$($ShortNameLower)-favorites'"}
  @{Path="$NewRepoDir\src\store\store.ts"; Old="name: 'ZERA'"; New="name: '$ShopNameUpper'"}
  @{Path="$NewRepoDir\src\store\store.ts"; Old="ownerName: 'Sulficker Roshan N'"; New="ownerName: '$ShopName'"}
  @{Path="$NewRepoDir\src\store\langStore.ts"; Old="'srisiddha-lang'"; New="'$($ShortNameLower)-lang'"}
  @{Path="$NewRepoDir\src\lib\ordersFallback.ts"; Old="'siddha_orders'"; New="'$($ShortNameLower)_orders'"}
  @{Path="$NewRepoDir\src\services\authService.ts"; Old="'siddha_users'"; New="'$($ShortNameLower)_users'"}
  @{Path="$NewRepoDir\src\services\authService.ts"; Old="'siddha_session'"; New="'$($ShortNameLower)_session'"}
  @{Path="$NewRepoDir\src\services\api.ts"; Old="'srisiddha-token'"; New="'$($ShortNameLower)-token'"}
  @{Path="$NewRepoDir\src\pages\Home.tsx"; Old="'siddha_customer_reviews'"; New="'$($ShortNameLower)_customer_reviews'"}
  @{Path="$NewRepoDir\src\components\dashboard\ImageMappingTool.ts"; Old="'naatu-shop-image-mappings'"; New="'$($ShortNameLower)-image-mappings'"}
)

foreach ($item in $SpecialFiles) {
  $sc = Get-Content $item.Path -Raw
  if ($sc.Contains($item.Old)) {
    $sc = $sc -replace [regex]::Escape($item.Old), $item.New
    Set-Content -Path $item.Path -Value $sc -Encoding UTF8 -NoNewline
    $Count++
  }
}

Write-Host "  [OK] Replaced brand references in $Count files" -ForegroundColor Green

# --- 6. Rename logo ---
Write-Host "[6/6] Renaming logo assets ..." -ForegroundColor Yellow
$OldLogo = "$NewRepoDir\public\zera-logo.png"
$NewLogo = "$NewRepoDir\public\$($ShortNameLower)-logo.png"
if (Test-Path $OldLogo) {
  Rename-Item -Path $OldLogo -NewName "$($ShortNameLower)-logo.png"
  Write-Host "  [OK] Logo renamed to $($ShortNameLower)-logo.png" -ForegroundColor Green
}

# --- Init git ---
Write-Host ""
Write-Host "=== INITIALIZING NEW REPO ===" -ForegroundColor Cyan
if (Test-Path "$NewRepoDir\.git") {
  Remove-Item -Recurse -Force "$NewRepoDir\.git"
}
Push-Location $NewRepoDir
git init 2>&1 | Out-Null
git add -A 2>&1 | Out-Null
git commit -m "Initial commit: $ShopName admin billing system" 2>&1 | Out-Null
Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  NEW SHOP READY!" -ForegroundColor Green
Write-Host "  Shop: $ShopName" -ForegroundColor Green
Write-Host "  Location: $NewRepoDir" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green
Write-Host "  Next steps:" -ForegroundColor Green
Write-Host "  1. Set Supabase credentials in .env" -ForegroundColor Green
Write-Host "  2. Replace logo at public/$($ShortNameLower)-logo.png" -ForegroundColor Green
Write-Host "  3. Update tailwind.config.js colors" -ForegroundColor Green
Write-Host "  4. Push to GitHub:" -ForegroundColor Green
Write-Host "     git remote add origin <url>" -ForegroundColor Green
Write-Host "     git push -u origin main" -ForegroundColor Green
Write-Host "  5. Deploy on Vercel (import repo, add env vars)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green


Write-Host "1. Assemblage du jeu en ELF64..." -ForegroundColor Cyan
$Nasm = ".\outils\nasm-3.01\nasm.exe"
$ObjectsDir = "build\objects"
$SourceDir = Resolve-Path ".\src"

if (!(Test-Path $ObjectsDir)) {
    New-Item -ItemType Directory -Path $ObjectsDir | Out-Null
}

Remove-Item "$ObjectsDir\*.o" -Force -ErrorAction SilentlyContinue

$ObjectFiles = @()

$AsmFiles = Get-ChildItem -Path $SourceDir -Recurse -Filter "*.asm"


foreach ($AsmFile in $AsmFiles){
    $RelativePath = $AsmFile.FullName.Substring((Resolve-Path $SourceDir).Path.Length + 1)
    $ObjectName = $RelativePath -replace "\\", "_"
    $ObjectName = $ObjectName -replace "\.asm$", ".o"
    $ObjectPath = Join-Path $ObjectsDir $ObjectName
    
    Write-Host "NASM $RelativePath -> $ObjectPath"
    
    & $Nasm -f elf64 -i "include/" $AsmFile.Fullname -o $ObjectPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur de compilation NASM." -ForegroundColor Red
        exit 1
    }
    
    $ObjectFiles += $ObjectPath
}


Write-Host "Objets generes :" -ForegroundColor DarkCyan
foreach ($ObjectFile in $ObjectFiles) {
    Write-Host "  $ObjectFile"
}

Write-Host "2. Edition de liens (Linker)..." -ForegroundColor Cyan
.\outils\ld.lld.exe -T linker.ld $ObjectFiles -o iso_root/main.elf

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors du Link." -ForegroundColor Red
    exit 1
}

python .\outils\convert.py "assets/images/border_dw_castletown_0.png" "iso_root/ASSETS/BORDER.RAW"
python .\outils\convert.py "assets/images/sprite_sheet/kris_walk.png" "iso_root/ASSETS/KRISWALK.RAW"
python .\outils\convert.py "assets/images/sprite_sheet/kris_bedroom.png" "iso_root/ASSETS/KRIS_BED.RAW"
python .\outils\convert.py "assets/images/aseprite/kris_bedroom_furniture.png" "iso_root/ASSETS/KRIS_FUR.RAW"
Copy-Item -Path "assets/images/sprite_sheet/kris_bedroom.bin" -Destination "iso_root/ASSETS/KRIS_BED.BIN"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors de la conversion de l'image. Arrêt de la compilation." -ForegroundColor Red
    exit 1
}



Write-Host "3. Preparation du dossier ISO..." -ForegroundColor Cyan
Copy-Item -Path "limine.cfg" -Destination "iso_root/limine.cfg" -Force


Write-Host "4. Creation de l'image ISO avec Xorriso..." -ForegroundColor Cyan
.\outils\xorriso.exe -as mkisofs `
    -b limine-cd.bin `
    -no-emul-boot -boot-load-size 4 -boot-info-table `
    --efi-boot limine-cd-efi.bin `
    -efi-boot-part --efi-boot-image --protective-msdos-label `
    -o build/iso/MonJeu.iso iso_root

if ($LASTEXITCODE -ne 0){
    Write-Host "Erreur lors de la création de l'ISO." -ForegroundColor Red
    exit 1
}


Write-Host "5. Installation du secteur de démarrage Limine..." -ForegroundColor Cyan
.\outils\limine-deploy.exe  build/iso/MonJeu.iso

if ($LASTEXITCODE -ne 0){
    Write-Host "Erreur lors de l'installation du secteur d'amorcage Limine." -ForegroundColor Red
    exit 1
}

Write-Host "Succes ! L'image MonJeu.iso est prete pour VMware !" -ForegroundColor Green


Write-Host "1. Assemblage du jeu en ELF64..." -ForegroundColor Cyan
.\outils\nasm-3.01\nasm.exe -f elf64 main.asm -o ./objects/main.o
.\outils\nasm-3.01\nasm.exe -f elf64 pci.asm -o ./objects/pci.o
.\outils\nasm-3.01\nasm.exe -f elf64 hw_limine.asm -o ./objects/hw_limine.o




if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur de compilation NASM." -ForegroundColor Red
    exit 1
}


Write-Host "2. Edition de liens (Linker)..." -ForegroundColor Cyan
.\outils\ld.lld.exe -T linker.ld objects/main.o objects/pci.o objects/hw_limine.o -o iso_root/main.elf

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors du Link." -ForegroundColor Red
    exit 1
}


Write-Host "3. Preparation du dossier ISO..." -ForegroundColor Cyan
Copy-Item -Path "limine.cfg" -Destination "iso_root/limine.cfg" -Force


Write-Host "4. Creation de l'image ISO avec Xorriso..." -ForegroundColor Cyan
.\outils\xorriso.exe -as mkisofs -b limine-cd.bin `
    -no-emul-boot -boot-load-size 4 -boot-info-table `
    -o MonJeu.iso iso_root

if ($LASTEXITCODE -ne 0){
    Write-Host "Erreur lors de la création de l'ISO." -ForegroundColor Red
    exit 1
}


Write-Host "5. Installation du secteur de démarrage Limine..." -ForegroundColor Cyan
.\outils\limine-deploy.exe --cd MonJeu.iso

if ($LASTEXITCODE -ne 0){
    Write-Host "Erreur lors de l'installation du secteur d'amorcage Limine." -ForegroundColor Red
    exit 1
}

Write-Host "Succes ! L'image MonJeu.iso est prete pour VMware !" -ForegroundColor Green

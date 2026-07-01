
Write-Host "1. Assemblage du jeu en ELF64..." -ForegroundColor Cyan
.\outils\nasm-3.01\nasm.exe -f elf64 main.asm -o ./objects/main.o
.\outils\nasm-3.01\nasm.exe -f elf64 pci.asm -o ./objects/pci.o
.\outils\nasm-3.01\nasm.exe -f elf64 hw_limine.asm -o ./objects/hw_limine.o
.\outils\nasm-3.01\nasm.exe -f elf64 -i include/ video.asm -o ./objects/video.o
.\outils\nasm-3.01\nasm.exe -f elf64 -i include/ framebuffer.asm -o ./objects/framebuffer.o
.\outils\nasm-3.01\nasm.exe -f elf64 render.asm -o ./objects/render.o
.\outils\nasm-3.01\nasm.exe -f elf64 input_handler.asm -o ./objects/input_handler.o
.\outils\nasm-3.01\nasm.exe -f elf64 idt.asm -o ./objects/idt.o
.\outils\nasm-3.01\nasm.exe -f elf64 timer.asm -o ./objects/timer.o
.\outils\nasm-3.01\nasm.exe -f elf64 atapi.asm -o ./objects/atapi.o
.\outils\nasm-3.01\nasm.exe -f elf64 vfs_iso9660.asm -o ./objects/vfs_iso9660.o
.\outils\nasm-3.01\nasm.exe -f elf64 limine_reqs.asm -o ./objects/limine_reqs.o
.\outils\nasm-3.01\nasm.exe -f elf64 memory.asm -o ./objects/memory.o




if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur de compilation NASM." -ForegroundColor Red
    exit 1
}


Write-Host "2. Edition de liens (Linker)..." -ForegroundColor Cyan
.\outils\ld.lld.exe -T linker.ld objects/main.o objects/limine_reqs.o objects/memory.o objects/pci.o objects/vfs_iso9660.o objects/timer.o objects/atapi.o objects/idt.o objects/input_handler.o objects/video.o objects/hw_limine.o objects/render.o objects/framebuffer.o -o iso_root/main.elf

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors du Link." -ForegroundColor Red
    exit 1
}

python .\outils\convert.py "assets/images/border_dw_castletown_0.png" "iso_root/ASSETS/BORDER.RAW"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors de la conversion de l'image. Arrêt de la compilation." -ForegroundColor Red
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
.\outils\limine-deploy.exe  MonJeu.iso

if ($LASTEXITCODE -ne 0){
    Write-Host "Erreur lors de l'installation du secteur d'amorcage Limine." -ForegroundColor Red
    exit 1
}

Write-Host "Succes ! L'image MonJeu.iso est prete pour VMware !" -ForegroundColor Green

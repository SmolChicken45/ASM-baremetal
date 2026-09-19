#!/usr/bin/env python3
import os
import sys
import shutil
import platform
import subprocess
from pathlib import Path

# --- Couleurs pour le terminal ---
CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
RESET = "\033[0m"

def log(msg, color=CYAN):
    print(f"{color}{msg}{RESET}")

def run_cmd(cmd, error_msg):
    try:
        subprocess.run(cmd, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        log(f"\n{error_msg}\nDétail : {e}", RED)
        sys.exit(1)

# --- Configuration & Détection OS ---
IS_WIN = platform.system() == "Windows"

PROJECT_ROOT = Path(__file__).parent
SRC_DIR = PROJECT_ROOT / "src"
BUILD_DIR = PROJECT_ROOT / "build"
OBJECTS_DIR = BUILD_DIR / "objects"
ISO_DIR = BUILD_DIR / "iso"
ISO_ROOT = PROJECT_ROOT / "iso_root"
ISO_PATH = ISO_DIR / "MonJeu.iso"
KERNEL_ELF = OBJECTS_DIR / "main.elf"

if IS_WIN:
    NASM = PROJECT_ROOT / "outils" / "windows" / "nasm.exe"
    CC = PROJECT_ROOT / "outils" / "windows" / "clang.exe"
    LD = PROJECT_ROOT / "outils" / "windows" / "ld.lld.exe"
    XORRISO = PROJECT_ROOT / "outils" / "windows" / "xorriso.exe"
    LIMINE = PROJECT_ROOT / "outils" / "windows" / "limine.exe"
else:
    NASM = shutil.which("nasm") or (PROJECT_ROOT / "outils" / "linux" / "nasm")
    CC = shutil.which("clang") or shutil.which("gcc") or (PROJECT_ROOT / "outils" / "linux" / "clang")
    LD = shutil.which("ld") or (PROJECT_ROOT / "outils" / "linux" / "ld.lld")
    XORRISO = shutil.which("xorriso") or (PROJECT_ROOT / "outils" / "linux" / "xorriso")
    LIMINE = shutil.which("limine") or (PROJECT_ROOT / "outils" / "linux" / "limine")

CFLAGS = [
    "-c",
    "-Wall",
    "-Wextra",
    "-O2",
    "-ffreestanding",
    "-fno-stack-protector",
    "-fno-stack-check",
    "-mno-red-zone",
    "-Iinclude",
]

if "clang" in str(CC).lower():
    CFLAGS.extend(["--target=x_64-unknown-elf"])

# Préparation des dossiers
OBJECTS_DIR.mkdir(parents=True, exist_ok=True)
ISO_DIR.mkdir(parents=True, exist_ok=True)
(ISO_ROOT / "ASSETS").mkdir(parents=True, exist_ok=True)

for obj in OBJECTS_DIR.glob("*o"):
    obj.unlink()

object_files = []

# --------- 1. Assemblage et Compilation ---------

log("1. Assemblage des fichiers NASM...")
for asm_file in SRC_DIR.rglob("*.asm"):
    rel_path = asm_file.relative_to(SRC_DIR)
    obj_name = str(rel_path).replace(os.sep,"_").removesuffix(".asm") + "_asm.o"
    obj_path = OBJECTS_DIR / obj_name

    print(f"NASM {rel_path} -> {obj_path}")
    run_cmd(
        [str(NASM), "-f", "elf64", "-i", "include/", str(asm_file), "-o", str(obj_path)],
        f"Erreur de compilation NASM sur {rel_path}"
    )
    object_files.append(obj_path)

# ------------- 2. Compilation C -----------------

log("2. Compilation des fichiers C...")
for c_file in SRC_DIR.rglob("*.c"):
    rel_path = c_file.relative_to(SRC_DIR)
    obj_name = str(rel_path).replace(os.sep,"_").removesuffix(".c") + "_c.o"
    obj_path = OBJECTS_DIR / obj_name

    print(f"CC {rel_path} -> {obj_path}")
    run_cmd(
        [str(CC), *CFLAGS, str(c_file), "-o", str(obj_path)],
        f"Erreur de compilation C sur {rel_path}"
    )
    object_files.append(obj_path)

if not object_files:
    log("Aucun fichier source (.asm ou .c) trouvé.", RED)
    sys.exit(1)

# -------------- 3. Linker (ld.lld) ---------------

log("3. Édition de liens (Linker)...")
run_cmd(
    [str(LD), "-T", "linker.ld", *[str(p) for p in object_files], "-o", str(KERNEL_ELF)],
    "Erreur lors du Link avec ld.lld"
)

# ------ 4. Conversion et copie des assets --------

log("4. Traitement des assets...")
CONVERT_SCRIPT = PROJECT_ROOT / "outils" / "convert.py"

assets_to_convert = [
    ("assets/images/border_dw_castletown_0.png", "iso_root/ASSETS/BORDER.RAW"),
    ("assets/images/sprite_sheet/kris_walk.png", "iso_root/ASSETS/KRISWALK.RAW"),
    ("assets/images/sprite_sheet/kris_bedroom.png", "iso_root/ASSETS/KRIS_BED.RAW"),
    ("assets/images/aseprite/kris_bedroom_furniture.png", "iso_root/ASSETS/KRIS_FUR.RAW"),
]

# assets_to_convert = []

for src, dst in assets_to_convert:
    run_cmd(
        [sys.executable, str(CONVERT_SCRIPT), str(PROJECT_ROOT / src), str(PROJECT_ROOT / dst)],
        f"Erreur lors de la conversion de {src}"
    )

shutil.copyfile(
    PROJECT_ROOT / "assets/images/sprite_sheet/kris_bedroom.bin",
    ISO_ROOT / "ASSETS" / "KRIS_BED.BIN"
)

shutil.copyfile(KERNEL_ELF, ISO_ROOT / "main.elf")
shutil.copyfile(PROJECT_ROOT / "limine.conf", ISO_ROOT / "limine.conf")

# ------ 5. Création de l'ISO avec Xorriso ---------

log("5. Création de l'image ISO avec Xorriso...")
run_cmd(
    [
        str(XORRISO), "-as", "mkisofs",
        "-r",
        "-b", "limine-bios-cd.bin",
        "-no-emul-boot", "-boot-load-size", "4", "-boot-info-table",
        "--efi-boot", "limine-uefi-cd.bin",
        "-efi-boot-part", "--efi-boot-image", "--protective-msdos-label",

        "--sort-weight", "1000", "/limine.conf",
        "--sort-weight", "1000","limine-bios.sys",
        "--sort-weight", "1000", "/main.elf",

        "--sort-weight", "-1000", "/ASSETS",

        "-o", str(ISO_PATH), str(ISO_ROOT)
    ],
    "Erreur lors de la création de l'ISO avec Xorriso"
)

# ------ 6. Installation du secteur d'amorçage Limine ------
log("6. Installation du secteur de démarrage Limine...")
run_cmd(
    [str(LIMINE), "bios-install", str(ISO_PATH)],
    "Erreur lors du déploiement de Limine sur l'ISO"
)



log(f"\nSuccès ! L'image {ISO_PATH} est prête.", GREEN)

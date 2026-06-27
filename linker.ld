OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

PHDRS
{
    text    PT_LOAD FLAGS((1 << 0) | (1 << 2)) ;
    rodata  PT_LOAD FLAGS((1 << 2)) ;
    data    PT_LOAD FLAGS((1 << 1) | (1 << 2)) ;
}

SECTIONS
{
    . = 0xffffffff80200000;

    .text : {
        *(.text .text.*)
    } :text

    . = ALIGN(4K);
    .limine_reqs : {
        KEEP(*(.limine_reqs))
    } :data

    . = ALIGN(4K);
    .rodata : {
        *(.rodata .rodata.*)
    } :rodata

    . = ALIGN(4K);
    .data : {
        *(.data .data.*)
    } :data

    . = ALIGN(4K);
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    } :data
}

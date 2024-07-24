%include "source/shared.inc"

org MINBOOT_ORIGIN
bits 16 ; CODE

; DL MUST CONTAIN A BIOS DRIVE NUMBER
; DS:SI MUST CONTAIN A POINTER TO THE FOLOWING STRUCTURE:
;   READ FUNCTION OFFSET (2 BYTES)
;   KERNEL.SYS BYTE SIZE (2 BYTES)
;   KERNEL.SYS LBA (4 BYTES)

start:
  cli
  cld
  mov [BOOT_INFO.BOOT_DEVICE + 3], dl
  lodsw
  mov [READ_PROC], ax
  lodsw 
  add ax, SECTOR_SIZE - 1
  shr ax, SECTOR_SHIFT
  mov cx, ax
  mov ax, DATA_BUFFER
  shr ax, 4
  mov es, ax
  mov bx, 0
  lodsw
  mov dx, ax
  lodsw
  xchg ax, dx

read_kernel:
  call word [READ_PROC]
  jc read_error
  inc ax
  adc dx, 0
  add bx, SECTOR_SIZE
  loop read_kernel

find_header:
  mov di, 0
  .l0:
    mov ax, [es:di]
    cmp ax, (KERNEL_MAGIC & 0xFFFF)
    jne .next
    mov ax, [es:di + 2]
    cmp ax, (KERNEL_MAGIC >> 16)
    je .e0
  .next:
    inc di
    cmp di, 0x2000
    jb .l0
    jmp no_header
  .e0:

check_header:
  mov ax, [es:di]
  mov dx, [es:di + 2]
  add ax, [es:di + 4]
  adc dx, [es:di + 6]
  add ax, [es:di + 8]
  adc dx, [es:di + 10]
  test ax, ax
  jnz bad_header
  test dx, dx
  jnz bad_header
  mov [VAR_HEADER], di

get_load_offsets:
  mov al, [es:di + 6]
  test al, 1
  jz .use_elf
  mov ax, [es:di + 16]
  mov [LOAD.ADDR], ax
  mov ax, [es:di + 18]
  mov [LOAD.ADDR + 2], ax
  mov ax, [es:di + 12]
  mov dx, [es:di + 14]
  sub ax, [LOAD.ADDR]
  sbb dx, [LOAD.ADDR + 2]
  mov [LOAD.OFFSET], ax
  mov [LOAD.OFFSET + 2], dx
  mov ax, [es:di + 20]
  mov dx, [es:di + 22]
  sub ax, [LOAD.ADDR]
  sbb dx, [LOAD.ADDR + 2]
  mov [LOAD.SIZE], ax
  mov [LOAD.SIZE + 2], dx
  mov ax, [es:di + 24]
  mov dx, [es:di + 26]
  sub ax, [es:di + 20]
  sbb dx, [es:di + 22]
  mov [BSS_SIZE], ax
  mov [BSS_SIZE + 2], dx
  mov ax, [es:di + 28]
  mov [ENTRY_PTR], ax
  mov ax, [es:di + 30]
  mov [ENTRY_PTR + 2], ax
  jmp .end
.use_elf:
  mov si, DATA_BUFFER
  lodsw
  cmp ax, 0x457F
  jne no_address
  lodsw
  cmp ax, 0x464C
  jne no_address
  lodsw
  cmp ax, 0x0101
  jne no_address
  lodsw
  cmp al, 1
  jne no_address
  add si, 8
  lodsw
  cmp ax, 2
  jne no_address
  lodsw
  cmp ax, 3
  jne no_address
  lodsw
  cmp ax, 1
  jne no_address
  lodsw
  test ax, ax
  jnz no_address
  lodsw
  mov [ENTRY_PTR], ax
  lodsw
  mov [ENTRY_PTR + 2], ax
  add si, 8
  lodsw
  test ax, ax
  jnz no_address
  lodsw
  test ax, ax
  jnz no_address
  lodsw
  cmp ax, 52
  jne no_address
  lodsw
  cmp ax, 32
  jne no_address
  lodsw
  test ax, ax
  jz no_address
  lodsw
  cmp ax, 40
  jne no_address
  mov al, 1
  mov [USE_ELF], al
.end:

set_video_mode: ; TODO : NOT YET IMPLEMENTED
  mov al, [es:di + 4]
  test al, 4
  jz .no_vbe
.no_vbe:

get_mem_size:
  clc
  int 0x12
  jc .no_mem
  mov [BOOT_INFO.MEM_LOWER], ax
  mov ah, 0x8A
  int 0x15
  jc .no_mem
  mov [BOOT_INFO.MEM_UPPER], ax
  mov [BOOT_INFO.MEM_UPPER + 2], dx
.set_flag:
  mov al, [BOOT_INFO.FLAGS]
  or al, 1
  mov [BOOT_INFO.FLAGS], al
  jmp .end
.no_mem:
  mov al, [es:di + 4]
  test al, 2
  jz .set_flag
.end:

get_mem_map: ; TODO : NOT YET IMPLEMENTED

get_drives: ; TODO : NOT YET IMPLEMENTED

get_apm_table:
  clc
  mov ax, 0x5300
  mov bx, 0
  int 0x15
  jc .no_apm
  mov [APM.VERSION], ax
  mov [APM.FLAGS], cx
  mov ax, 0x5303
  mov bx, 0
  int 0x15
  jc .no_apm
  mov [APM.CSEG], ax
  mov [APM.OFFSET], ebx
  mov [APM.CSEG_16], cx
  mov [APM.DSEG], dx
  mov [APM.CSEG_LEN], esi
  mov [APM.DSEG_LEN], di
  mov al, [BOOT_INFO.FLAGS + 2]
  or al, 4
  mov [BOOT_INFO.FLAGS + 2], al
.no_apm:

prepare:
  call enable_a20
  jz no_a20_err
  lgdt [GDT.PTR]
  mov eax, cr0
  or al, 1
  mov cr0, eax
  jmp 8:relocate

no_a20_err:
  mov si, STR.NOA20
  jmp error

read_error:
  mov si, STR.READERR
  jmp error

no_header:
  mov si, STR.NOHDR
  jmp error

no_address:
  mov si, STR.NOELF
  jmp error

bad_header:
  mov si, STR.BADHDR
  jmp error

error: ; ERROR STRING IN DS:SI
  lodsb
  test al, al
  jz .spin
  mov ah, 0x0E
  int 0x10
  jmp error
.spin:
  cli
  hlt
  jmp .spin

enable_a20: ; ZF = FAILED
  call .check
  jnz .end
  mov ax, 0x2401
  int 0x15
  call .check
  jnz .end
  call .wait
  mov al, 0xD1
  out 0x64, al
  call .wait
  mov al, 0xDF
  out 0x60, al
  call .wait
  call .check
  jnz .end
  in al, 0x92
  or al, 2
  and al, 0xFE
  out 0x92, al
  jmp .check
.wait:
  in al, 0x64
  test al, 2
  jnz .wait
  ret
.check:
  pusha
  push es
  push ds
  xor ax, ax
  mov ds, ax
  mov si, TEST_BYTE
  not ax
  mov es, ax
  mov di, TEST_BYTE + 0x10
  mov [ds:si], al
  not ax
  mov [es:di], al
  cmp al, [ds:si]
  pop ds
  pop es
  popa
.end:
  ret

bits 32

relocate:
  xor eax, eax
  mov al, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov al, [USE_ELF]
  test al, al
  jz .no_elf
  .do_elf: ; TODO : NOT YET IMPLEMENTED
    mov ebx, DATA_BUFFER
    add ebx, [DATA_BUFFER + 28]
    mov ecx, [DATA_BUFFER + 44]
    and ecx, 0xFFFF
    .lp:
      mov eax, [ebx]
      cmp eax, 1
      jne .next
      mov esi, DATA_BUFFER
      add esi, [ebx + 4]
      mov edi, [ebx + 12]
      mov edx, ecx
      mov ecx, [ebx + 16]
      rep movsb
      mov ecx, [ebx + 20]
      sub ecx, [ebx + 16]
      jbe .skp
        xor eax, eax
        rep stosb
      .skp:
      mov ecx, edx
    .next:
      add ebx, 32
      loop .lp
    jmp .end
  .no_elf:
  mov esi, DATA_BUFFER
  add esi, [LOAD.OFFSET]
  mov edi, [LOAD.ADDR]
  mov ecx, [LOAD.SIZE]
  rep movsb
  mov al, 0
  mov ecx, [BSS_SIZE]
  rep stosb
.end:
  mov eax, LOADER_MAGIC
  mov ebx, BOOT_INFO
  jmp [ENTRY_PTR]

align 16, db 0 ; DATA

GDT:
  dq 0 ; NULL
  dq 0xCF9A000000FFFF
  dq 0xCF92000000FFFF
  .PTR:
    dw $ - GDT - 1
    dd GDT

STR:
  .NAME:    db "MinBoot", 0
  .NOA20:   db "Can not enable A20 line", 0
  .READERR: db "Read error occured", 0
  .NOHDR:   db "Missing multiboot header", 0
  .BADHDR:  db "Bad multiboot header", 0
  .NOELF:   db "Missing address information", 0

USE_ELF: db 0

align 4, db 0

BOOT_INFO:
  .FLAGS:         dd 0x1202
  .MEM_LOWER:     dd 640
  .MEM_UPPER:     dd 14
  .BOOT_DEVICE:   dd 0xFFFFFFFF
  .CMD_LINE:      dd 0
  .MODS_COUNT:    dd 0
  .MODS_ADDR:     dd 0
  .SYMS:  times 4 dd 0
  .MMAP_LENGTH:   dd 0
  .MMAP_ADDR:     dd 0
  .DRIVES_LENGTH: dd 0
  .DRIVES_ADDR:   dd 0
  .CONFIG_TABLE:  dd 0
  .LOADER_NAME:   dd STR.NAME
  .APM_TABLE:     dd APM.VERSION
  .VBE_CTRL_INFO: dd 0
  .VBE_MODE_INFO: dd 0
  .VBE_MODE:      dw 0
  .VBE_SEG:       dw 0
  .VBE_OFF:       dw 0
  .VBE_LEN:       dw 0
  .LFB_ADDR:      dd 0xB8000
  .LFB_PITCH:     dd 80
  .LFB_WIDTH:     dd 80
  .LFB_HEIGHT:    dd 25
  .LFB_BPP:       db 16
  .LFB_TYPE:      db 2
  .COLOR_INFO:    times 6 db 0

align 16, db 0 ; BSS

READ_PROC   equ $
VAR_HEADER  equ $ + 2

LOAD:
  .OFFSET equ $ + 4
  .ADDR   equ $ + 8
  .SIZE   equ $ + 12
BSS_SIZE  equ $ + 16
ENTRY_PTR equ $ + 20

APM:
  .VERSION  equ $ + 24
  .CSEG     equ $ + 26
  .OFFSET   equ $ + 28
  .CSEG_16  equ $ + 32
  .DSEG     equ $ + 34
  .FLAGS    equ $ + 36
  .CSEG_LEN equ $ + 38
  .DSEG_LEN equ $ + 42

TEST_BYTE equ $ + 44

VESA_BUFFER equ $ + 64

DATA_BUFFER equ $ + 1088


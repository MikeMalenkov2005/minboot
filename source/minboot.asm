%include "source/shared.inc"

org MINBOOT_ORIGIN
bits 16 ; CODE

; DX:AX MUST CONTAIN THE LBA OF THE KERNEL.SYS FILE
; CX MUST CONTAIN A KERNEL.SYS SIZE IN BYTES
; BX MUST CONTAIN A NEAR POINTER TO A SINGLE SECTOR LBA READ FUNCTION
; DI:SI MUST CONTAIN A VOLUME PATH

start:
  cli
  cld
  mov [READ_PROC], bx
  mov [BOOT_INFO.BOOT_DEVICE], si
  mov [BOOT_INFO.BOOT_DEVICE + 2], di
  push ax
  mov ax, DATA_BUFFER
  shr ax, 4
  mov es, ax
  mov bx, 0
  pop ax
  add cx, SECTOR_SIZE - 1
  shr cx, SECTOR_SHIFT

read_kernel:
  push ax
  push cx
  push dx
  call near [READ_PROC]
  pop dx
  pop cx
  pop ax
  jc read_error
  add bx, SECTOR_SIZE
  loop read_kernel

find_header:
  mov di, 0
  mov cx, 2048
  .l0:
    push cx
    mov cx, 4
    mov si, KERNEL_MAGIC_DATA
    repe cmpsb
    je .e0
    add di, cx
    pop cx
    loop .l0
    jmp no_header
  .e0:
  pop cx

check_header:
  mov ax, [di]
  mov dx, [di + 2]
  add ax, [di + 4]
  adc dx, [di + 6]
  add ax, [di + 8]
  adc dx, [di + 10]
  test ax, ax
  jnz bad_header
  test dx, dx
  jnz bad_header
  mov [VAR_HEADER], di

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
  mov esi, DATA_BUFFER
  add esi, [LOAD.OFFSET]
  mov edi, [LOAD.ADDR]
  mov ecx, [LOAD.SIZE]
  rep movsb
  mov al, 0
  mov ecx, [BSS_SIZE]
  rep stosb
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

align 4, db 0

KERNEL_MAGIC_DATA: dd KERNEL_MAGIC

BOOT_INFO:
  .FLAGS:         dd 0
  .MEM_LOWER:     dd 0
  .MEM_UPPER:     dd 0
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
  .APM_TABLE:     dd 0
  .

align 16, db 0 ; BSS

VAR_HEADER  equ $
READ_PROC   equ $ + 2

LOAD:
  .OFFSET equ $ + 4
  .ADDR   equ $ + 8
  .SIZE   equ $ + 12
BSS_SIZE  equ $ + 16
ENTRY_PTR equ $ + 20

TEST_BYTE equ $ + 24

DATA_BUFFER equ $ + 32


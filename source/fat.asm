%include "source/shared.inc"

org BOOTSEC_ORIGIN
bits 16

BPB:
  jmp short start
  nop
.OEM_ID:          db "MINBOOT "
.SECTOR_SIZE:     dw SECTOR_SIZE
.CLUSTER_SIZE:    db 1
.RESERVED_SIZE:   dw 1
.FAT_COUNT:       db 2
.ROOT_ENTRIES:    dw 224
.VOLUME_SIZE:     dw 2880
.MEDIA_TYPE:      db 0xF0
.FAT_SIZE:        dw 9
.TRACK_SIZE:      dw 18
.HEAD_COUNT:      dw 2
.HIDDEN_SIZE:     dd 0
.BIG_VOLUME_SIZE: dd 0

EBPB:
.DRIVE:     db 0
.NT_FLAGS:  db 0
.SIGNATURE: db 0x29
.VOLUME_ID: dd __POSIX_TIME__
.VOL_LABEL: db "MINBOOT SYS"
.SYSTEM_ID: db "FAT12   "

start:
  cli
  cld
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov gs, ax
  mov fs, ax
  mov sp, ax
  mov ah, 0x7F
  mov ss, ax
  mov si, 0x7C00
  mov di, $$
  mov cx, SECTOR_SIZE
  rep movsb
  jmp 0:init

init:
  mov [EBPB.DRIVE], dl
  test dl, 0x80
  jz .skp
    mov ah, 8
    int 0x13
    and cx, 0x3F
    mov [BPB.TRACK_SIZE], cx
    mov cl, dh
    inc cx
    mov [BPB.HEAD_COUNT], cx
  .skp:
  mov ax, read
  mov [SYS.READ], ax

load_root:
  mov ax, [BPB.RESERVED_SIZE]
  xor dx, dx
  add ax, [BPB.HIDDEN_SIZE]
  adc dx, [BPB.HIDDEN_SIZE + 2]
  mov cl, [BPB.FAT_COUNT]
  .l0:
    add ax, [BPB.FAT_SIZE]
    adc dx, 0
    loop .l0
  mov bx, MINBOOT_ORIGIN
  mov cx, [BPB.ROOT_ENTRIES]
  shr cx, SECTOR_SHIFT - 5
  .l1:
    call read
    jc read_error
    inc ax
    adc dx, 0
    add bx, SECTOR_SIZE
    loop .l1
  mov [DATA_SECTOR], ax
  mov [DATA_SECTOR + 2], dx

find_kernel:
  mov di, KERNEL_NAME
  mov si, MINBOOT_ORIGIN
  call find
  jc not_found
  mov [SYS.LBA], ax
  mov [SYS.LBA + 2], dx
  mov [SYS.SIZE], cx
  mov ax, [si + 30]
  test ax, ax
  jnz too_big
  cmp cx, 0x10000 - SECTOR_SIZE
  ja too_big

load_minboot:
  mov di, MINBOOT_NAME
  mov si, MINBOOT_ORIGIN
  call find
  jc not_found
  push ax
  mov ax, [si + 30]
  test ax, ax
  pop ax
  jnz too_big
  cmp cx, 0x10000 - MINBOOT_ORIGIN
  ja too_big
  add cx, SECTOR_SIZE - 1
  shr cx, SECTOR_SHIFT
  mov bx, MINBOOT_ORIGIN
  .l0:
    call read
    jc read_error
    inc ax
    adc dx, 0
    add bx, SECTOR_SIZE
    loop .l0
  mov si, SYS
  mov dl, [EBPB.DRIVE]
  jmp MINBOOT_ORIGIN

read_error:
  mov si, MSG.READERR
  call print
  jmp error

not_found: ; FILE NAME IN DS:DI
  mov si, MSG.MISSING
  call print
  mov si, di
  call print
  jmp error

too_big: ; FILE NAME IN DS:DI
  mov si, di
  call print
  mov si, MSG.TOOBIG
  call print
  jmp error

print: ; MESSAGE IN DS:SI
  lodsb
  test al, al
  jz .end
  mov ah, 0x0E
  int 0x10
  loop print
.end:
  ret

find: ; ROOT IN DS:SI, NAME IN ES:DI -> ENTRY IN DS:SI, LBA IN DX:AX, BYTE SIZE IN CX, CF = FAILED
  mov cx, [BPB.ROOT_ENTRIES]
  .l0:
    pusha
    mov cx, 11
    repe cmpsb
    popa
    je .e0
    add si, 32
    loop .l0
  .fail:
    stc
    ret
  .e0:
  mov ax, [si + 26]
  sub ax, 2
  jae .end
  add si, 32
  jmp .l0
.end:
  mov cl, [BPB.CLUSTER_SIZE]
  mov ch, 0
  mul cx
  mov cx, [si + 28]
  add ax, [DATA_SECTOR]
  adc dx, [DATA_SECTOR + 2]
  ret

read: ; LBA IN DX:AX, BUFFER IN ES:BX -> CF = FAILED
  pusha
  div word [BPB.TRACK_SIZE]
  mov cx, dx
  xor dx, dx
  div word [BPB.HEAD_COUNT]
  mov dh, dl
  mov dl, [EBPB.DRIVE]
  mov ch, al
  inc cl
  mov al, 4
.retry:
  push ax
  mov ax, 0x0201
  int 0x13
  test ah, ah
  pop ax
  clc
  jz .end
  dec al
  jnz .retry
  stc
.end:
  popa
  ret

error:
  cli
  hlt
  jmp error

KERNEL_NAME:  db "KERNEL  SYS", 0
MINBOOT_NAME: db "MINBOOT SYS", 0

MSG:
.MISSING: db "Missing ", 0
.READERR: db "Read error", 0
.TOOBIG:  db " is too big", 0

times SECTOR_SIZE - ($ - $$) db 0
dw 0xAA55

SYS:
.READ equ $ + 0
.SIZE equ $ + 2
.LBA  equ $ + 4

DATA_SECTOR equ $ + 8


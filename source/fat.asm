%include "source/shared.inc"

org BOOTSEC_ORIGIN
bits 16

jmp short start
nop

BPB:
.OEM_ID:          db "MINBOOT0"
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
.DRIVE:       db 0
.NT_FLAGS:    db 0
.SIGNATURE:   db 0x29
.VOLUME_ID:   db __POSIX_TIME__
.VOLUME_NAME: db "MINBOOT SYS"
.SYSTEM_ID:   db "FAT12   "

start:
  cli
  cld
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov sp, ax
  mov ax, 0x70
  mov ss, ax
  mov [EBPB.DRIVE], dl
  test dl, 0x80
  jz .no_geometry
    mov ah, 8
    int 0x13
    mov ax, cx
    and ax, 0x3F
    mov [BPB.TRACK_SIZE], ax
    mov al, dh
    mov ah, 0
    inc ax
    mov [BPB.HEAD_COUNT], ax
  .no_geometry:
  mov cx, [BPB.ROOT_ENTRIES]
  shr cx, SECTOR_SHIFT - 5
  mov ax, EOF
  shr ax, 4
  mov es, ax
  mov bx, 0
  .load_root:
    push ax
    push cx
    push dx
    call read
    pop dx
    pop cx
    pop ax
    add bx, SECTOR_SIZE
    loop .load_root
  mov bx, read
  jmp MINBOOT_ORIGIN

read: ; sector LBA in DX:AX, output buffer far pointer in ES:BX -> CF = FAILED
  div word [BPB.TRACK_SIZE]
  mov cx, dx
  xor dx, dx
  div word [BPB.HEAD_COUNT]
  mov dh, dl
  mov dl, [EBPB.DRIVE]
  mov ch, al
  inc cl
  mov al, 4 ; NUMBER OF RETRIES
  .retry:
    push ax
    mov ax, 0x0201
    int 0x13
    clc
    test ah, ah
    pop ax
    jz .end
    dec al
    jnz .retry
    stc
  .end:
  ret

print: ; MESSAGE POINTER IN DS:SI
  mov ah, 0x0E
  .l0:
    lodsb
    test al, al
    jz .e0
    int 0x10
    jmp .l0
  .e0:
  ret

error: ; ERROR CODE IN AL
  dec al
  jnz .n1
    mov si, MSG.READERR
    call print
    jmp .stop
  .n1:
  mov si, MSG.MISSING
  call print
  dec al
  jnz .n2
    mov si, MSG.MINBOOT
    call print
    jmp .stop
  .n2:
  mov si, MSG.KERNEL
  call print
.stop:
  hlt
  jmp .stop

MSG:
  .READERR: db "Read error occured", 0
  .MISSING: db "Missing ", 0
  .MINBOOT: db "/MINBOOT.SYS", 0
  .KERNEL:  db "/KERNEL.SYS", 0

times 510 - ($ - $$) db 0
dw 0xAA55

EOF:


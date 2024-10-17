org 0x100000
bits 32

%include "source/shared.inc"

FLAGS equ 0x10007 ; ALL FLAGS

dd KERNEL_MAGIC
dd FLAGS
dd -(FLAGS + KERNEL_MAGIC)

dd $$
dd $$
dd EOF
dd EOF
dd start

dd 1
dd 0
dd 0
dd 0

start:
  cli
  mov eax, 0x024B024F
  mov [0xB8000], eax
  jmp $

EOF:


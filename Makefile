B = build
S = source

I = $(shell find $S -name "*.inc")

M = MINBOOT.SYS
K = KERNEL.SYS

$M: $S/minboot.asm $I
	nasm -f bin -o $@ $<

$K: $S/kernel-stub.asm $I
	nasm -f bin -o $@ $<

fd1440.img: $B/fat.bin $M $K
	rm -rf $@
	mkfs.fat -C -D 0x00 -M 0xF0 -n "MINBOOT SYS" -r 224 -s 1 -S 512 $@ 1440
	dd of=$@ if=$< bs=1 count=11 conv=notrunc
	dd of=$@ if=$< bs=1 count=448 conv=notrunc seek=62 skip=62
	mcopy -i $@ $M ::/
	mcopy -i $@ $K ::/

$B/%.bin: $S/%.asm $I
	mkdir -p $(dir $@)
	nasm -f bin -o $@ $<

.PHONY: clean
clean:
	rm -rf $B *.img *.sys


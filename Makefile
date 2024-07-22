B = build
S = source
N = minboot

I = $(shell find $S -name "*.inc")

$N.sys: $S/$N.asm $I
	nasm -f bin -o $@ $<

$N-fd1440.img: $N.sys $N-fat.bin $I
	dd of=$@ if=/dev/zero bs=512 count=2880
	mkfs.fat -r 224 -s 1 -S 512 $@
	dd of=$@ if=$N-fat.bin bs=512 count=1 conv=notrunc
	mcopy -i $@ $N.sys ::/MINBOOT.SYS
	mattrib -i $@ +shr ::/MINBOOT.SYS

$N-%.bin: $S/%.asm $I
	nasm -f bin -o $@ $<

.PHONY: clean
clean:
	rm -rf *.img *.bin *.sys


S = source
N = minboot

I = $(shell find $S -name "*.inc")

$N.sys: $S/$N.asm $I
	nasm -f bin -o $@ $<

$N-%.bin: $S/%.asm $I
	nasm -f bin -o $@ $<

.PHONY: clean
clean:
	rm -rf *.img *.bin *.sys


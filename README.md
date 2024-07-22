MinBoot
=========================
A minimal multiboot compliant bootloader for
legacy BIOS with low capacity storage media.

Why
-------------------------
Many operating system developers use multiboot standart for booting their
operating systems, but all the popular multiboot compliant bootloaders take
a lot of storage space with their countless modules (like GRUB does).\
That is precisely why I am developing my very own solution
to this apparently made up problem.

Supported File Systems
-------------------------
 * FAT

Note
-------------------------
For the MinBoot to be able to load your kernel both the MINBOOT.SYS as well as 
the KERNEL.SYS files must be continuously positioned on the storage media.\
KERNEL.SYS is what your kernel file should be renamed to.\
If the KERNEL.SYS file size exceeds 64 KiB the MinBoot would not be able to
laod it correctly.\
The minboot.sys must be renamed to MINBOOT.SYS before installing it
for compatibility with different file systems.


.SUFFIXES: .asm

MPU = 6800
AS = as$(MPU)
CC = chibicc
LD = ld$(MPU)
ASFLAGS = 
CFLAGS = -DINT2 -O -S
LDFLAGS = -b -C0x100 -m a.map
LIBS = /opt/chibicc/lib/clibs.a /opt/chibicc/lib/libc.a

OBJS = crt0-chibi.o main.o dptable.o snd.o file.o midi.o base.o

all: a.bin

a.bin: $(OBJS) ram
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)
	f9dasm -$(MPU) a.bin > a.lst
	./ram $@
	./mkadr.pl nm6800 > a.adr

dptable.c: mktbl.pl
	./mktbl.pl > $@

ram: ram.c
	cc $< -o $@

.asm.o:
	$(AS) $(ASFLAGS) -l$(<:.asm=.lst) -o $@ $(<:.c=.s)

.c.o:
	$(CC) $(CFLAGS) $<
	$(AS) $(ASFLAGS) -l$(<:.c=.lst) -o $@ $(<:.c=.s)

clean:
	rm -f *.{lst,mem,o,s} a.{adr,bin,map,out} dptable.c ram

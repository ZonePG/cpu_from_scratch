ifndef CROSS_COPILE
CROSS_COPILE = mips-sde-elf-
endif
CC = $(CROSS_COPILE)as
LD = $(CROSS_COPILE)ld
OBJCOPY = $(CROSS_COPILE)objcopy
OBJDUMP = $(CROSS_COPILE)objdump

OBJECTS = inst_rom.o

export CROSS_COPILE

# ********************
# Rules of Compilation
# ********************

all: inst_rom.data inst_rom.asm

%.o: %.S
	$(CC) -mips32 $< -o $@

inst_rom.om: ram.ld $(OBJECTS)
	$(LD) -T ram.ld $(OBJECTS) -o $@

inst_rom.asm: inst_rom.om
	$(OBJDUMP) -D inst_rom.om > $@

inst_rom.bin: inst_rom.om
	$(OBJCOPY) -O binary $< $@

inst_rom.data: inst_rom.bin
	./Bin2Mem.exe -f $< -o $@

clean:
	rm -f *.o *.om *.bin *.data *.asm
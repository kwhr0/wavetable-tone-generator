#! /usr/bin/perl

$FS = 48000000 / 512;

print "#include \"types.h\"\nconst u16 dptable[] = {\n";
for ($i = 0; $i < 128; $i++) {
	print "\t" unless $i % 12;
	printf "%d, ", 0x10000 * 440.0 * 2.0 ** (($i - 69) / 12.0) / $FS + 0.5;
	print "\n" if $i % 12 == 11;
}
print "\n};\n";
exit 0;

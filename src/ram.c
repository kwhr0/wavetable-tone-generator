#include <stdio.h>
#include <stdlib.h>

#define N		4
#define AMOUNT	0x8000

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: ram <a.out file>\n");
		return 0;
	}
	FILE *fi = fopen(argv[1], "rb");
	if (!fi) {
		fprintf(stderr, "%s cannot open.\n", argv[1]);
		return 1;
	}
	unsigned char *buf = (unsigned char *)malloc(0x10000);
	int i = fread(buf, 1, 0x10000, fi), j;
	fclose(fi);
	if (i < 1) {
		fprintf(stderr, "%s cannot read.\n", argv[1]);
		return 2;
	}
	printf("%d bytes read.\n", i);
	buf[AMOUNT - 2] = 1;
	buf[AMOUNT - 1] = 0;
	for (i = 0; i < N; i++) {
		char s[16];
		sprintf(s, "ram%d.mem", i);
		fi = fopen(s, "wb");
		if (!fi) return 2;
		for (j = 0; j < AMOUNT / N; j++)
			fprintf(fi, "%02x\n", buf[j * N + i]);
		fclose(fi);
	}
	free(buf);
	printf("ram[0-%d].mem written.\n", N - 1);
	return 0;
}

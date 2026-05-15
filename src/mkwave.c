#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

#define PROG_N	(128 + 28)

int main() {
	int waves[PROG_N][32];
	int i, j;
	int min = INT_MAX, max = INT_MIN;
	for (i = 0; i < PROG_N; i++) {
		char path[16];
		sprintf(path, "raw/%003d.raw", i);
		FILE *fi = fopen(path, "rb");
		if (!fi) {
			fprintf(stderr, "%s not found.\n", path);
			return 1;
		}
		fseek(fi, 4 * 4800, SEEK_SET); // ignore first 4800 samples
		fread(waves[i], 4, 32, fi);
		fclose(fi);
		long long acc = 0;
		for (j = 0; j < 32; j++) {
			int d = waves[i][j];
			acc += d;
		}
		int ofs = acc / 32;
		for (j = 0; j < 32; j++) {
			int d = waves[i][j] -= ofs;
			if (min > d) min = d;
			if (max < d) max = d;
		}
	}
	int smin = min / -127, smax = max / 127;
	int scale = smin;
	if (scale < smax) scale = smax;
	for (i = 0; i < PROG_N; i++) {
		int amin = INT_MAX, aminpos = 0;
		for (j = 0; j < 32; j++) {
			int d = waves[i][j];
			if (amin > abs(d)) {
				amin = abs(d);
				aminpos = j;
			}
		}
		for (j = 0; j < 32; j++)
			printf("%02x\n", waves[i][j + aminpos & 31] / scale & 0xff);
	}
	for (; i < 256; i++)
		for (j = 0; j < 32; j++)
			printf("00\n");
	return 0;
}

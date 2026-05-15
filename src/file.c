// FAT16 512bytes/sector SFN read only

#include "file.h"
#include <string.h>

#define RDE_LEN			0x4000
#define LIM_USERCLUSTER	0xfff7

typedef struct {
	u32 fat, rde, len, ofs;
	u16 cluster, clustershift, clustermask;
} File;

static File sFile;
static u32 sCardAdr;

u8 IOCard(u8 data) {
	SPI = data;
	while (spi_busy())
		;
	return SPI;
}

void IOCardSkip(u16 count) {
	while (count--) IOCard(0xff);
}

static u8 CardCommand(u8 cmd, u32 param) {
	u8 resp;
	u8 *p = (u8 *)&param;
	while (IOCard(0xff) != 0xff) 
		;
	IOCard(cmd | 0x40);
	IOCard(*p++); // big endian
	IOCard(*p++);
	IOCard(*p++);
	IOCard(*p);
	IOCard(0x95); // CRC is only valid when CMD0
	while ((resp = IOCard(0xff)) == 0xff) 
		;
	IOCardSkip(1);
	return resp;
}

static void CardInit(void) {
	CARD = 1;
	IOCardSkip(10);
	CARD = 0;
	while (IOCard(0xff) != 0xff) 
		;
	CardCommand(0, 0);
	while (CardCommand(1, 0))
		;
	sCardAdr = 0;
}

static void CardSetAddress(u32 adr) {
	u16 ofs = sCardAdr & 0x1ff;
	if (ofs) IOCardSkip(0x200 - ofs + 2);
	sCardAdr = adr;
	ofs = sCardAdr & 0x1ff;
	if (ofs) {
		CardCommand(17, sCardAdr & ~0x1ff);
		while (IOCard(0xff) != 0xfe)
			;
		IOCardSkip(ofs);
	}
}

static u8 CardRead(void) {
	u8 data;
	u16 ofs = sCardAdr & 0x1ff;
	if (!ofs) {
		CardCommand(17, sCardAdr);
		while (IOCard(0xff) != 0xfe)
			;
	}
	data = IOCard(0xff);
	if (ofs == 0x1ff) IOCardSkip(2);
	sCardAdr++;
	return data;
}

static u16 CardRead2(void) {
	u16 r = CardRead();
	return r | (u16)CardRead() << 8;
}

static u32 CardRead4(void) {
	u32 r;
	u8 *p = (u8 *)&r + 3;
	*p = CardRead();
	*--p = CardRead();
	*--p = CardRead();
	*--p = CardRead();
	return r;
}

void FileInit(void) {
	File *f = &sFile;
	memset(f, 0, sizeof(File));
	CardInit();
	CardSetAddress(0x1c6); // first sector number
	u32 w = CardRead4() << 9;
	CardSetAddress(w + 13);
	u16 t = CardRead();
	f->clustermask = (t << 9) - 1;
	u8 i;
	for (i = 9; t >>= 1; i++)
		;
	f->clustershift = i;
	f->fat = w + 512;
	CardRead4();
	CardRead4();
	f->rde = f->fat + ((u32)CardRead2() << 10);
}

static void FileSetCluster(u16 c) {
	if (c < LIM_USERCLUSTER) {
		File *f = &sFile;
		u32 adr = f->rde;
		if (c) adr += RDE_LEN + ((u32)(c - 2) << f->clustershift);
		CardSetAddress(adr);
	}
}

void FileOpen(u16 cluster, u32 len) {
	File *f = &sFile;
	FileSetCluster(f->cluster = cluster);
	f->len = len;
	f->ofs = 0;
}

int FileGetChar(void) {
	File *f = &sFile;
	if (f->ofs >= f->len) return -1; 
	if (f->ofs && !(f->ofs & f->clustermask)) {
		CardSetAddress(f->fat + ((u32)f->cluster << 1));
		FileSetCluster(f->cluster = CardRead2());
	}
	f->ofs++;
	return CardRead();
}

void DirOpen(u16 cluster) {
	u16 len = cluster ? 0 : RDE_LEN; // avoid bug
	FileOpen(cluster, len);
}

char *DirRead(void) {
	static char buf[32];
	File *f = &sFile;
	while (!f->len || f->ofs < f->len) {
		int i;
		for (i = 0; i < 32; i++) buf[i] = CardRead();
		f->ofs += 32;
		if (!f->len && !(f->ofs & (u32)f->clustermask)) {
			CardSetAddress(f->fat + ((u32)f->cluster << 1));
			f->cluster = CardRead2();
			if (f->cluster >= LIM_USERCLUSTER) return NULL;
			FileSetCluster(f->cluster);
			f->ofs = 0;
		}
		switch (buf[0]) {
			case 0: case 5: case 0x2e: case 0xe5:
			case 0x5f: // resource fork of extracted tar
			break;
			default:
			if (buf[11] & 0xe) break;
			return buf;
		}
	}
	return NULL;
}

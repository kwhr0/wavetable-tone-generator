#include "base.h"
#include "file.h"
#include "snd.h"
#include "midi.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define STACK_N		4
#define ENTRY_N		300

typedef struct {
	u16 cluster, index, n;
} Stack;

typedef struct {
	char name[8];
	u16 cluster;
	u32 len;
} Entry;

static Stack stack[STACK_N];
static Entry entry[ENTRY_N];
static u8 depth, autokey, volume;
static u8 level[32];

static void print_name() {
	int i;
	Entry *e = &entry[stack[depth].index];
	char *p = e->name;
	for (i = 0; i < 8 && *p > ' '; i++) putchar(*p++);
	if (!e->len) printf("[DIR]");
	printf("\n");
}

#define copy_cluster(dst, src)\
	(((char *)&dst)[0] = src[27], ((char *)&dst)[1] = src[26])

static int cmp_entry(const void *a, const void *b) {
	return strncmp(((Entry *)a)->name, ((Entry *)b)->name, 8);
}

static int list(void) {
	Stack *s = &stack[depth];
	int i;
	while (1) {
		Entry *e;
		char *buf;
		DirOpen(s->cluster);
		for (i = 0; i < ENTRY_N && (buf = DirRead());)
			if (!strncmp(&buf[8], "MID", 3) || buf[11] & 0x10) {
				e = &entry[i++];
				memcpy(e->name, buf, 8);
				copy_cluster(e->cluster, buf);
				((char *)&e->len)[0] = 0;
				((char *)&e->len)[1] = buf[30];
				((char *)&e->len)[2] = buf[29];
				((char *)&e->len)[3] = buf[28];
			}
		if (!i) {
			printf("Error: directory is empty.\n");
			return 1;
		}
		s->n = i;
		qsort(entry, i, sizeof(Entry), cmp_entry);
		print_name();
		while (1) {
			int c;
			e = &entry[s->index];
			c = autokey ? autokey : keydown();
			switch (c) {
			case KEY_LEFT:
				if (s->index > 0) {
					s->index--;
					if (autokey) autokey = KEY_RETURN;
				}
				else autokey = 0;
				for (i = depth + 1; i < STACK_N; i++) stack[i].index = 0;
				print_name();
				break;
			case KEY_RIGHT:
				if (s->index < s->n - 1) {
					s->index++;
					if (autokey) autokey = KEY_RETURN;
				}
				else if (autokey) autokey = KEY_UP;
				for (i = depth + 1; i < STACK_N; i++) stack[i].index = 0;
				print_name();
				break;
			case KEY_UP: case KEY_ESCAPE:
				if (depth > 0) {
					s = &stack[--depth];
					if (autokey) autokey = KEY_RIGHT;
					goto next;
				}
				print_name();
				break;
			case KEY_RETURN:
				if (e->len) {
					printf("PLAY ");
					for (i = 0; i < 8 && e->name[i] > ' '; i++)
						putchar(e->name[i]);
					printf(".MID\n");
					FileOpen(e->cluster, e->len);
					autokey = 0;
					return 0;
				}
				else if (depth < STACK_N) {
					s = &stack[++depth];
					s->cluster = e->cluster;
					goto next;
				}
				print_name();
				break;
			default:
				if (isalnum(c)) {
					c = toupper(c);
					for (i = 0; i < s->n && c > *entry[i].name; i++)
						;
					if (i < s->n) s->index = i;
					print_name();
				}
				break;
			}
		}
next:;
	}
}

int main(void) {
	char *buf;
	VOLUME = 0;
	printf(
		"MIDI PLAYER\n"
		"=\tprevious\n"
		"/\tnext\n"
		"enter\tplay/directory down\n"
		"*\tstop/directory up\n"
		"-\tvolume down\n"
		"+\tvolume up\n"
	);
	SndInit();
	FileInit();
	DirOpen(0);
	while ((buf = DirRead()) && strncmp(buf, "MIDI    ", 8))
		;
	if (!buf) {
		printf("Error: /MIDI not found.\n");
		return 1;
	}
	copy_cluster(stack[0].cluster, buf);
	while (1) {
		int endcount;
		if (list()) break;
		MidiInit();
		if (MidiHeader()) break;
		endcount = 0;
		u8 overcount = 0, overtimer = 0;
		while (1) {
			int c;
			TIMER = 0;
			if (MidiUpdate() && !endcount) endcount = 1;
			SndUpdate();
			switch (c = keydown()) {
			case KEY_UP: case KEY_ESCAPE:
				printf("STOP\n");
				autokey = 0;
				goto next;
			case KEY_LEFT: case KEY_RIGHT:
				autokey = c;
				goto next;
			case KEY_V_UP: case ',':
				if (volume < 7) VOLUME = ++volume;
				printf("volume=%d\n", volume);
				break;
			case KEY_V_DOWN:
				if (volume > 0) VOLUME = --volume;
				printf("volume=%d\n", volume);
				break;
			default:
				if (!endcount || ++endcount < 200) break;
				autokey = KEY_RIGHT;
				goto next;
			}
			if (MidiStarted())
				if (!timer_active()) {
					overcount++;
					overtimer = 100;
				}
				else if (overtimer && !--overtimer) {
					printf("OVER %d\n", overcount);
					overcount = 0;
				}
			while (timer_active())
				;
		}
next:;
		SndInit();
	}
	return 0;
}

#include "base.h"
#include <stddef.h>

u8 keydown(void) {
	if (rx_valid()) {
		u8 c = UART_RX;
//		printf("keydown: %02X\n", c);
		return c;
	}
	return 0;
}

void putchar(char c) {
	while (!tx_rdy())
		;
	UART_TX = c;
}

void printf(const char *format, ...) {
	u16 *ap = (u16 *)&format;
	u8 *p = (u8 *)format;
#ifdef __CHIBICC__
	ap += 2;
#endif
#ifdef STDARG_REV
#define next_ap	(--ap)
#else
#define next_ap	(++ap)
#endif
	while (*p) {
		u8 c[7];
		u8 a, b, f, i, l, n, r, t, u;
		u16 v;
		u8 *q;
		switch (t = *p++) {
		case '%':
			b = ' ';
			l = n = 0;
			switch (t = *p++) {
				case '%': putchar('%'); continue;
				case '0': b = '0'; t = *p++; break;
				case '-': l = 1; t = *p++; break;
				case 'c': putchar(*next_ap); continue;
			}
			if (t >= '1' && t <= '9')
				for (n = t - '0'; (t = *p++) >= '0' && t <= '9';)
					n = 10 * n + t - '0';
			if (t == 's')
				for (q = *(u8 **)next_ap, i = 0; q[i]; i++)
					;
			else {
				if (u = t == 'u') t = *p++;
				switch (t) {
					case 'd': r = 10; break;
					case 'o': r = 8; u = 1; break;
					case 'x': r = 16; u = 1; a = 0x27; break;
					case 'X': r = 16; u = 1; a = 7; break;
					default: continue;
				}
				v = *next_ap;
				if (f = !u && (s16)v < 0) v = -v;
				c[i = sizeof(c) - 1] = 0;
				do {
					u16 d = v / r, t1 = v - d * r + '0';
					c[--i] = t1 > '9' ? t1 + a : t1;
					v = d;
				} while (v);
				if (f) c[--i] = '-';
				q = &c[i];
			}
			i = sizeof(c) - 1 - i;
			if (l) n -= i;
			else while (n-- > i) putchar(b);
			while (*q) putchar(*q++);
			if (l) while (n--) putchar(' ');
			break;
		default:
			if (t == '\n') putchar('\r'); // for terminal
			putchar(t);
			break;
		}
	}
#undef next_ap
}

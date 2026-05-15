#ifndef _MYTYPES_H_
#define _MYTYPES_H_

#ifdef INT2
typedef unsigned long u32;
typedef signed long s32;
#else
typedef unsigned int u32;
typedef signed int s32;
#endif

typedef unsigned char u8;
typedef unsigned short u16;
typedef signed char s8;
typedef signed short s16;
typedef volatile u8 vu8;
typedef volatile u16 vu16;
typedef volatile u32 vu32;

#define INPUT	(*(vu8 *)0xffe0)
#define UART_RX	(*(vu8 *)0xffe4)

#define CARD	(*(vu8 *)0xffe1)
#define TIMER	(*(vu8 *)0xffe2)
#define VOLUME 	(*(vu8 *)0xffe3)
#define UART_TX	(*(vu8 *)0xffe4)
#define SPI		(*(vu8 *)0xffe5)
#define DATA0	(*(vu8 *)0xffe8)
#define DATA1	(*(vu8 *)0xffe9)
#define ADR0	(*(vu8 *)0xffec)

#define KEY_LEFT	'='
#define KEY_RIGHT	'/'
#define KEY_UP		'*'
#define KEY_RETURN	0x0d
#define KEY_ESCAPE	0x1b
#define KEY_V_UP	'+'
#define KEY_V_DOWN	'-'

#define tx_rdy()		(INPUT & 2)
#define timer_active()	(INPUT & 4)
#define rx_valid()		(INPUT & 8)
#define spi_busy()		(INPUT & 16)

#endif

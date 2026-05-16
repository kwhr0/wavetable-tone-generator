	.zp
	.export bp
	.export tmp1
	.export tmp2
	.export tmp3
	.export tmp4
	.export long
bp:	.word	0
tmp1:	.word	0
tmp2:	.word	0
tmp3:	.word	0
tmp4:	.word	0
long:	.word	0
	.word	0

	.code
	.export _exit
start:
	sei
	lds	#$feff	; initial stack
	ldx	#interrupt
	stx	$fff8
	ldx	#__bss_size
	beq	nobss
	clra
	clrb
	subb	#<__bss_size
	sbca	#>__bss_size
	ldx	#__bss
clear_bss:
	clr	,x
	inx
	incb
	bne	clear_bss
	inca
	bne	clear_bss
nobss:
	jsr	_main
_exit:
	wai
	bra	_exit

	.export	_interruptCount
	.export	_interruptHandle
interrupt:
	inc	_interruptCount
	rti

	.bss
_interruptCount:	.byte	0
_interruptHandle:	.word	0

	VDP_DATA:			equ	$C00000
	VDP_CONTROL:		equ	$C00004
	VDP_STATUS_VBLANK:	equ $000008

	jsr		INITIALIZE_TMSS
	jsr		INITIALIZE_GRAPHICS
	lea		VDP_DATA,A0							; Load VDP Data Port.
	lea		4(A0),A1							; Load VDP Control Port.
	clr.l	D0									; Move $0 into D0
	move.l	#$3FFF,D1
	move.l	#$40000000,(A1)						; Write to VRAM.
CLEAR_VRAM_LOOP
	move.l	#$0,(A0)							; Clear out VRAM.
	dbra	D1,CLEAR_VRAM_LOOP					; Loop for next iteration.

	move.l	#$13,D1
	move.l	#$40000010,(A1)						; Write to VSRAM.
CLEAR_VSRAM_LOOP
	move.l	#$0,(A0)							; Clear out VSRAM.
	dbra	D1,CLEAR_VSRAM_LOOP

	jsr		DEFINE_TILES
	jsr		WRITE_TILES_TO_SCREEN

	; Load blacked out palette
	lea		Palette,A0							; Load address of our palette
	move.w	#$1,D0								; Load into palette 1
	move.b	#$3,D1								; Shift palette bits by 3
	jsr		DEFINE_PALETTE						; Load palette

	move.w	#$8C08,(VDP_CONTROL)				; Shadow mode on
	move.w	#$8144,(VDP_CONTROL)				; C00004 reg 1 = 0x44 unblank display

	jsr		FADE_DELAY
	jsr		FADE_DELAY
	jsr		FADE_DELAY
	jsr		FADE_DELAY
	jsr		FADE_DELAY
	jsr		FADE_DELAY
	jsr		PALETTE_FADE_IN
	move.w	#$60,D1
LOGO_DELAY_LOOP
	jsr		WaitVBlank
	dbf		D1,LOGO_DELAY_LOOP
	jsr		PALETTE_FADE_OUT
	jmp		INTRO_END

INITIALIZE_TMSS
	move.b	($A10001),D0
	and.b	#$F,D0
	beq		NO_TMSS
	move.l	#'SEGA',($A14000)
NO_TMSS
	rts

INITIALIZE_GRAPHICS
	lea 	VDPSettings,A5
	move.l	#VDPSettingsEnd-VDPSettings,D1
	move.w	(VDP_CONTROL),D0
	move.l	#$8000,D5
NEXT_BYTE
	move.b	(A5)+,D5
	move.w	D5,(VDP_CONTROL)
	add.w	#$100,D5
	dbra	D1,NEXT_BYTE
	rts

VDPSettings
		DC.b $04 ; 0 mode register 1											---H-1M-
		DC.b $04 ; 1 mode register 2											-DVdP---
		DC.b $30 ; 2 name table base for scroll A (A=top 3 bits)				--AAA--- = $C000
		DC.b $3C ; 3 name table base for window (A=top 4 bits / 5 in H40 Mode)	--AAAAA- = $F000
		DC.b $07 ; 4 name table base for scroll B (A=top 3 bits)				-----AAA = $E000
		DC.b $6C ; 5 sprite attribute table base (A=top 7 bits / 6 in H40)		-AAAAAAA = $D800
		DC.b $00 ; 6 unused register											--------
		DC.b $00 ; 7 background color (P=Palette C=Color)						--PPCCCC
		DC.b $00 ; 8 unused register											--------
		DC.b $00 ; 9 unused register											--------
		DC.b $FF ;10 H interrupt register (L=Number of lines)					LLLLLLLL
		DC.b $00 ;11 mode register 3											----IVHL
		DC.b $00 ;12 mode register 4 (C bits both1 = H40 Cell)					C---SIIC
		DC.b $37 ;13 H scroll table base (A=Top 6 bits)							--AAAAAA = $FC00
		DC.b $00 ;14 unused register											--------
		DC.b $02 ;15 auto increment (After each Read/Write)						NNNNNNNN
		DC.b $01 ;16 scroll size (Horiz & Vert size of ScrollA & B)				--VV--HH = 64x32 tiles
		DC.b $00 ;17 window H position (D=Direction C=Cells)					D--CCCCC
		DC.b $00 ;18 window V position (D=Direction C=Cells)					D--CCCCC
		DC.b $FF ;19 DMA length count low										LLLLLLLL
		DC.b $FF ;20 DMA length count high										HHHHHHHH
		DC.b $00 ;21 DMA source address low										LLLLLLLL
		DC.b $00 ;22 DMA source address mid										MMMMMMMM
		DC.b $80 ;23 DMA source address high (C=CMD)							CCHHHHHH
VDPSettingsEnd
	even

DEFINE_TILES
	lea		SEGA_LOGO,A0
	move.w	#SEGA_LOGO_END-SEGA_LOGO,D1
	move.l	#1*32,D2
	jsr		PREPARE_VRAM
DEFINE_TILES_LOOP
	move.l	(A0)+,D0
	move.l	D0,(VDP_DATA)
	dbra	D1,DEFINE_TILES_LOOP
	rts

WRITE_TILES_TO_SCREEN
	move.l	#$3,D0	; X
	move.l	#$5,D1	; Y

	move.l	#26,D2	; Width
	move.l	#13,D3	; Height

	move.l	#$1,D4
	jsr		FillAreaWithTiles

	move.l	#11,D0	; X
	move.l	#21,D1	; Y

	move.l	#11,D2	; Width
	move.l	#4,D3	; Height
	move.l	#$153,D4
	jsr		FillAreaWithTiles
	rts

DEFINE_PALETTE
	move.l	#$C0000000,(VDP_CONTROL)
	mulu	#$10,D0
	sub.w	#$1,D0
DEFINE_PALETTE_LOOP
	move.b	D1,D2
	move.w	(A0)+,D3
CHANGE_INTENSITY_LOOP
	cmpi.b	#$0,D2
	beq		CHANGE_INTENSITY_LOOP_END
	lsr.w	#$1,D3
	and.w	#%0000111011101110,D3
	sub.b	#$1,D2
	bra		CHANGE_INTENSITY_LOOP
CHANGE_INTENSITY_LOOP_END
	move.w	D3,(VDP_DATA)
	dbf		D0,DEFINE_PALETTE_LOOP
	rts

PREPARE_VRAM									;To select a memory location D2 we need to calculate 
												;the command byte... depending on the memory location
	movem.l	D0-D7/A0-A7,-(SP)					;$7FFF0003 = Vram $FFFF.... $40000000=Vram $0000
	move.l	D2,D0
	and.w	#%1100000000000000,D0				;Shift the top two bits to the far right 
	rol.w	#2,D0
	
	and.l	#%0011111111111111,D2	    		; shift all the other bits left two bytes
	rol.l	#8,D2		
	rol.l	#8,D2
	
	or.l	D0,D2						
	or.l	#$40000000,D2						;Set the second bit from the top to 1
												;#%01000000 00000000 00000000 00000000
	move.l	D2,(VDP_CONTROL)
	movem.l	(SP)+,D0-D7/A0-A7
	rts

FillAreaWithTiles:								;Set area (D0,D1) Wid:D2 Hei:D3
	movem.l	D0-D7/A0-A7,-(SP)
	clr.l	D6
	clr.l	D7
	
	subq.l	#1,D3								;Reduce our counters by 1 for dbra
	subq.l	#1,D2
		
NextTileLine:
	move.l	D2,-(SP)							;Wid
	move.l	#$40000003,d5						;$C000 offset + Vram command
	move.l	#0,D7
	move.b	D1,D7				
	
	rol.l	#8,D7								; Calculate Ypos
	rol.l	#8,D7
	rol.l	#7,D7
	add.l	D7,D5
	
	move.b	D0,D7								;Calculate Xpos
	rol.l	#8,D7
	rol.l	#8,D7
	rol.l	#1,D7
	add.l	D7,D5
		
	move.l	D5,(VDP_CONTROL)					; C00004 Get VRAM address
NextTileb:		
	move.W	D4,(VDP_data)						; C00000 Select tile for mem loc
	addq.w	#$1,d4								; Increase Tilenum
	dbra	D2,NextTileb
	add.w	#$1,D1								; Move down a line
	move.l	(SP)+,D2
	dbra	D3,NextTileLine						; Do next line
	movem.l	(SP)+,D0-D7/A0-A7
	rts

PALETTE_FADE_OUT
	move	#$2,D4
PALETTE_FADE_OUT_LOOP
	move.w	#$8C08,(VDP_CONTROL)				; Shadow mode on
	jsr		FADE_DELAY
	move.w	#$8C00,(VDP_CONTROL)				; Shadow mode off
	lea		Palette,A0							; Load address of our palette
	move.w	#$1,D0								; Load into palette 1
	move.b	#$3,D1								; Shift palette bits by 2
	sub.b	D4,D1	
	jsr		DEFINE_PALETTE						; Load palette
	jsr		FADE_DELAY

	dbf		D4,PALETTE_FADE_OUT_LOOP
	rts

PALETTE_FADE_IN
	move	#$3,D4
PALETTE_FADE_IN_LOOP
	move.w	#$8C08,(VDP_CONTROL)				; Shadow mode on
	lea		Palette,A0							; Load address of our palette
	move.w	#$1,D0								; Load into palette 1
	move.b	D4,D1								; Shift palette bits by 2
	jsr		DEFINE_PALETTE						; Load palette

	jsr		FADE_DELAY
	move.w	#$8C00,(VDP_CONTROL)				; Shadow mode off
	jsr		FADE_DELAY
	dbf		D4,PALETTE_FADE_IN_LOOP
	rts

Palette
	dc.w	%0000000000000000					; ;0	%----BBB-GGG-RRR-
	dc.w	%0000111011101110					; ;1	%----BBB-GGG-RRR-
	dc.w	%0000100010001000					; ;2	%----BBB-GGG-RRR-
	dc.w	%0000001000100010					; ;3	%----BBB-GGG-RRR-
	dc.w	%0000101010101010					; ;4	%----BBB-GGG-RRR-
	dc.w	%0000110011001100					; ;5	%----BBB-GGG-RRR-
	dc.w	%0000011001100110					; ;6	%----BBB-GGG-RRR-
	dc.w	%0000010001000100					; ;7	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;8	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;9	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;10	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;11	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;12	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;13	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;14	%----BBB-GGG-RRR-
	dc.w	%0000000000000000					; ;15	%----BBB-GGG-RRR-
PaletteEnd
	even

FADE_DELAY:
	move.w	#$3,D1
FADE_DELAY_LOOP
	jsr		WaitVBlank
	dbf		D1,FADE_DELAY_LOOP

WaitVBlank:
	bsr.w WaitVBlankStart						; wait for vblank to start
	bsr.w WaitVBlankEnd							; wait for vblank to end
	rts

WaitVBlankStart:
	move.w VDP_CONTROL,D0						; copy VDP status to D0
	andi.w #VDP_STATUS_VBLANK,D0				; check if the vblank status flag is set
	beq.s WaitVBlankStart						; wait for vblank to complete
	rts											; exit

WaitVBlankEnd:
	move.w VDP_CONTROL,D0						; copy VDP status to D0
	andi.w #VDP_STATUS_VBLANK,D0				; check if the vblank status flag is set
	bne WaitVBlankEnd 							; wait for vblank to complete
	rts											; exit

SEGA_LOGO
	incbin	"INTRO_GRAPHICS.RAW"
SEGA_LOGO_END
	even

INTRO_END
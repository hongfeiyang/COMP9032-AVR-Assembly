;
; lab3.asm
;
; Created: 15/10/2023 5:46:14 PM
; Author : Luke
;


; The program gets input from keypad and displays its ascii value on LEDs
; Port F is used for keypad, high 4 bits for column selection, low four bits for reading rows. On the board, RF7-4 connect to C3-0, RF3-0 connect to R3-0.
; Port D is used to display the ASCII value of a key.

;.include "HalfSecondDelay.asm"
.include "m2560def.inc"
.def aa=r3
.def bb=r4
.def xx=r5
.def row=r17		; current row number
.def col=r18		; current column number
.def rmask=r19		; mask for current row
.def cmask=r20		; mask for current column
.def temp1=r21		
.def temp2=r22
.def ten=r23
.def yy=r24
.def zero_=r25


.equ PORTFDIR =0xF0			; use PortD for input/output from keypad: PF7-4, output, PF3-0, input
.equ INITCOLMASK = 0xEF		; scan from the leftmost column, the value to mask output
.equ INITROWMASK = 0x01		; scan from the bottom row
.equ ROWMASK  =0x0F			; low four bits are output from the keypad. This value mask the high 4 bits.
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

;from lectures
.macro lcd_set
	sbi PORTA, @0
.endmacro

;from lectures
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;from lectures
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

;from lectures
.macro do_lcd_data
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

;rjmp	RESET

;from lectures, takes an input from keypad
.macro key_input
	key_start:
		ldi cmask, INITCOLMASK		; initial column mask
		clr	col						; initial column
	colloop:
		cpi col, 4
		breq key_start
		sts	PORTL, cmask				; set column to mask value (one column off)
		ldi temp1, 0xFF
	delay:
		dec temp1
		brne delay

		lds	temp1, PINL				; read PORTD
		andi temp1, ROWMASK
		cpi temp1, 0xF				; check if any rows are on
		breq nextcol
									; if yes, find which row is on
		ldi rmask, INITROWMASK		; initialise row check
		clr	row						; initial row
	rowloop:
		cpi row, 4
		breq nextcol
		mov temp2, temp1
		and temp2, rmask				; check masked bit
		breq convert 				; if bit is clear, convert the bitcode
		inc row						; else move to the next row
		lsl rmask					; shift the mask to the next bit
		jmp rowloop

	nextcol:
		lsl cmask					; else get new mask by shifting and 
		inc col						; increment column value
		jmp colloop					; and check the next column

	convert:
		cpi col, 3					; if column is 3 we have a letter
		breq letters				
		cpi row, 3					; if row is 3 we have a symbol or 0
		breq symbols

		mov temp1, row				; otherwise we have a number in 1-9
		lsl temp1
		add temp1, row				; temp1 = row * 3
		add temp1, col				; add the column address to get the value
		subi temp1, -'1'			; add the value of character '0'
		jmp convert_end

	letters:
		ldi temp1, 'A'
		add temp1, row				; increment the character 'A' by the row value
		jmp convert_end

	symbols:
		cpi col, 0					; check if we have a star
		breq star
		cpi col, 1					; or if we have zero
		breq zero					
		ldi temp1, '#'				; if not we have hash
		jmp convert_end
	star:
		ldi temp1, '*'				; set to star
		jmp convert_end
	zero:
		ldi temp1, '0'				; set to zero
	convert_end:
.endmacro

;to help compute and store the keypad input numbers that are multiple digits 
.macro add_digit
	start_add:
		ldi ten,10     
		mul @0,ten         
		mov @0,r0
		subi temp1,48      
		add @0,temp1
	end_add:
.endmacro

;---------------------------------------------------------------------------------------
;start of program
RESET:
;jmp test
	ldi temp1, PORTFDIR			; columns are outputs, rows are inputs
	sts	DDRL, temp1				;keypad
	ser temp1					;PORTC is LED
	out DDRC, temp1				;set PORTC to output
	;ensuring all values are clear
	clr aa	
	clr bb
	clr xx
	clr yy	
	out PORTC, aa

	;LCD initialisation from lectures 
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

;get keypad input and store value in aa register 
get_a:
	key_input			;get input
	do_lcd_data temp1	;show input on screen
	rcall sleep_50ms	;delay
	rcall sleep_50ms
	rcall sleep_50ms
	cpi temp1,42		;check if * was inputted
	breq get_x			;if * inputted, move to next step 
	add_digit aa		;else, add to value in aa register and repeat until * inputted
	rjmp get_a

;get keypad input and store value in xx register 
get_x:
	key_input			;get input
	do_lcd_data temp1	;display input on LCD
	rcall sleep_50ms	;delay
	rcall sleep_50ms
	rcall sleep_50ms
	cpi temp1,68		;check if D was inputted
	breq get_b			;if D inputted, move to next step
	add_digit xx		;else, add to value in xx and repeat until D inputted
	rjmp get_x	

;get keypad input and store value in bb register 
get_b:
	key_input			;get input
	do_lcd_data temp1	;display input on LCD
	rcall sleep_50ms	;delay
	rcall sleep_50ms
	rcall sleep_50ms
	cpi temp1,35		;check if # inputted
	breq calc			;if # inputted, move to calculations
	add_digit bb		;else, add to value in bb and repeat until # inputted
	rjmp get_b

;calculate result
calc:
	mul aa,xx		; calculate a*x
	ldi zero_,0
	cp r1,zero_
	brne overflow	; branch if overflow
	mov temp1, r0   ; store a*x in temp1
	sub r0,bb		; subtract b
	mov yy,r0		; move to y register
	cp temp1, bb
	brlo convert	; if a*x < b, then y is negative, go to convert
	sbrs yy, 7		; if y is positve and bit 7 is set then overflow
	rjmp convert
	rjmp overflow

;On overflow, LED flashes 3 times and returns to the start
overflow:
	ser r16
	out PORTC,r16
	rcall sleep_50ms
	clr r16
	out PORTC,r16
	rcall sleep_50ms
	ser r16
	out PORTC,r16
	rcall sleep_50ms
	clr r16
	out PORTC,r16
	rcall sleep_50ms
	ser r16
	out PORTC,r16
	rcall sleep_50ms
	clr r16
	out PORTC,r16
	rjmp RESET

; convert to ASCII decimal
convert:		    
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00001110
	sbrs yy, 7       
	rjmp positive
	negative:
		com yy			; two's complement
		inc yy
		ldi temp1, '-'
		do_lcd_data temp1

	positive:
		cp yy, ten
		brlo display_one_digit
		ldi ten, 10
		clr temp1		; make temp1 #-10      (e.g. 123 -> temp1=12, yy=3)
	loop_pos:
		cp yy, ten      ; if yy is less than 10 go to output
		brlo output
		inc temp1       ; else temp1 += 1
		sub yy, ten     ; yy -= 10
		rjmp loop_pos

	output:
		cp temp1, ten   ; if #times -10 is less than 10, which means result is 1/2 digit, go to display
		brlo display         
		ldi temp2, '1'  ; else result is 3-digit
		do_lcd_data temp2    
		sub temp1, ten

	display:
		subi temp1, -'0'
		do_lcd_data temp1

	display_one_digit:
		subi yy, -'0'
		do_lcd_data yy
		rjmp halt


fin:
	rjmp fin

halt:
	rjmp halt
;end
;---------------------------------------------------------------------------


;funcions
lcd_command:
	out PORTF, r16
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
        nop
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

sleep_50ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret



;
; lab3.asm
;
; Created: 15/10/2023 5:46:14 PM
; Author : Luke et al.
;


; The program gets input from keypad and displays its ascii value on LEDs
; Port L is used for keypad, high 4 bits for column selection, low four bits for reading rows. On the board, RF7-4 connect to C3-0, RF3-0 connect to R3-0.
; Port F is used to display the ASCII value of a key.

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
.def temp3=r25



.equ PORTLDIR =0xF0			; use PortL for input/output from keypad: PL7-4, output, PL3-0, input
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

		lds	temp1, PINL				; read PORTL
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
		and temp2, rmask			; check masked bit
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
	ldi temp1, PORTLDIR			; columns are outputs, rows are inputs
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
	tst r1
	brne overflow	; branch if overflow
	mov temp1, r0   ; store a*x in temp1
	sub r0,bb		; subtract b
	mov yy,r0		; move to y register
	cp temp1, bb
	brlo print_dec	; if a*x < b, then y is negative, go to convert
	sbrs yy, 7				; if y is positve and bit 7 is set then overflow
	rjmp print_dec

;On overflow, LED flashes 3 times and returns to the start
overflow:
	rcall flash_three_times
	rjmp RESET

print_dec:
	rcall display_decimal
	ldi temp3, 0
	rjmp wait_loop
print_hex:
	rcall convert_to_hex_and_display
	ldi temp3, 1
wait_loop:
	clr temp1
	key_input
	rcall sleep_200ms			; delay 200ms	
	cpi temp1, 'C'              ; If 'C' was inputted...
	brne wait_loop
	cpi temp3, 0				; 0 means we are currently showing decimal, otherwise we are showing hex
	breq print_hex
	rjmp print_dec

flash_three_times:
	push YL
	push YH
	push r16
	in YL, SPL
	in YH, SPH
	sbiw YH:YL, 5
	out SPH, YH
	out SPL, YL

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

	adiw YH:YL, 5
	out SPH, YH
	out SPL, YL
	pop r16
	pop YH
	pop YL
	ret



display_decimal:
	push YL
	push YH
	push yy
	push temp1
	push temp2
	in YL, SPL
	in YH, SPH
	sbiw YH:YL, 7
	out SPH, YH
	out SPL, YL

	
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


	adiw YH:YL, 7
	out SPH, YH
	out SPL, YL
	pop temp2
	pop temp1
	pop yy
	pop YH
	pop YL
	ret




; Function Name: convert_to_hex_and_display
; Symposis:
; 	Converts an 8 - bit signed binary number located in the yy register to its ASCII hexadecimal representation and displays it on an LCD.
; 	The displayed output will be in the format of either a two - character hexadecimal or - 0xXX for negative numbers.

; Inputs:
; 	yy: Contains the 8 - bit signed binary number that you want to convert.
; Outputs:
; 	LCD Display: The LCD will display the ASCII hexadecimal representation of the input number. Negative numbers will be prefixed with - 0x.
; Registers Used:
; 	yy: Holds the input number and is used as a temporary register during the conversion process.
; 	r17: Acts as a counter to keep track of the number of hex digits that have been converted.
;	r18: Saves the value of yy.
; 	YL and YH: Serve as the frame pointer for local stack operations.
convert_to_hex_and_display:
	
	push YL
	push YH
	push yy
	push r17
	push r18
	in YL, SPL
	in YH, SPH
	sbiw YH:YL, 7
	out SPH, YH
	out SPL, YL
	
	; assume binary is in yy

	do_lcd_command 0b00000001 	; clear display
	do_lcd_command 0b00001110
	
	; check sign
	ldi r17, 0                  ; r17 stores how many hex digit we have converted
	mov r18, yy				 	; r18 stores the absolute value of the original number 
	sbrs yy, 7                  ; check MSB for negative number
	rjmp display_0x
neg_number:
	neg yy                      ; convert to positive to print
	
	mov r18, yy               	; overwrite r18 with the absolute value of the original number
	
	ldi yy, '-'                 ; print '-' on LCD
	do_lcd_data yy

display_0x:

	ldi yy, '0'
	do_lcd_data yy
	ldi yy, 'x'
	do_lcd_data yy
	mov yy, r18              	; restore yy to the original number we first stored to do hex conversion
	
convert_to_ascii_loop:
	swap yy                     ; Convert the highest 4 bit first, swap them to the lower 4 bit for convinence
	andi yy, 0b00001111         ; Keep the 4 bit we are interested in only
	cpi yy, 10                  ; if this digit is larger than 10, we need to represent it with a letter
	brlt convert_to_ascii_number
	subi yy, - ('A' - 10)       ; convert yy to a ASCII letter, first minus yy by 10 to get how much it exceeds 10, then displace it by the ASCII value of 'A'
	rjmp display_to_lcd
convert_to_ascii_number:
	subi yy, - ('0')            ; convert yy to a ASCII number, displace it by the ASCII value of '0'
display_to_lcd:
	do_lcd_data yy              ; display the converted digit on LCD
	inc r17                      ; we now have converted one digit, we then prepare the lower 4 bit for conversion
	mov yy, r18               	; restore yy
	swap yy                     ; swap now so that the lower 4 bit will be correctly placed at the lower 4 bit later when convert_to_ascii_loop is jumped to again
	cpi r17, 2
	brne convert_to_ascii_loop
	
	
	adiw YH:YL, 7
	out SPH, YH
	out SPL, YL
	pop r18
	pop r17
	pop yy
	pop YH
	pop YL
	ret
	


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

sleep_200ms:
	rcall sleep_50ms
	rcall sleep_50ms
	rcall sleep_50ms
	rcall sleep_50ms
	ret

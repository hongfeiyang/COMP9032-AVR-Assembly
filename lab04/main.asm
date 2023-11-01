.include "m2560def.inc"

.equ LCD_RS         =   7
.equ LCD_E          =   6
.equ LCD_RW         =   5
.equ LCD_BE         =   4
.equ PORTD_PIN_TDX2 =   2
.equ PATTERN        =   0b11110000
.def temp          =   	r16
.def leds           =   r20



.macro Clear
	ldi YL, low(@0)              ; load the memory address to Y
	ldi YH, high(@0)
	clr temp
	st Y+ , temp                ; clear the two bytes at @0 in SRAM
	st Y, temp
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	push r16
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
	pop r16
.endmacro

.macro clear_lcd
	do_lcd_command 0b00000001 	; clear display
	do_lcd_command 0b00001110
.endmacro

.dseg
SecondCounter:  	.byte 2                     ; Two - byte counter for counting the number of seconds.
TempCounter:    	.byte 2
RotationCounter: 	.byte 2						; Two - byte counter for counting the number of rotations.

.cseg
.org 0x0000
	jmp RESET
.org INT2addr
	jmp EXT_INT2
.org OVF0addr
	jmp Timer0OVF               ; Jump to the interrupt handler for Timer0 overflow.

	
RESET:
	ser r16                    ; set Port C as output
	out DDRC, r16
	rjmp main
	
Timer0OVF:                      ; interrupt subroutine for Timer0
	push r16
    in r16, SREG
	push r16                   ; Prologue starts.
	push YH                     ; Save all conflict registers in the prologue.
	push YL
	push r25
	push r24                    ; Prologue ends.

	ldi YL, low(TempCounter)    ; Load the address of the temporary
	ldi YH, high(TempCounter)   ; counter.
	ld r24, Y+                  ; Load the value of the temporary counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the temporary counter by one
	
	cpi r24, low(1000)          ; Check if (r25:r24)=1000
	brne NotSecond
	cpi r25, high(1000)
	brne NotSecond
	
	; Now read the number of rotations and display it on the LCD

	ldi YL, low(RotationCounter)
	ldi YH, high(RotationCounter)
	ld r24, Y+
	ld r25, Y

	; Divide number of rotations by 4 since we have 4 holes on the disk
	lsr r25
	ror r24
	lsr r25
	ror r24

	
	; TODO(hongfei): 	the number of rotations, most likely, will be larger than 255
	; 					therefore we need to display the value of r25 together with r24 on screen as well
	; 					the current function display_decimal only displays the value of r24, need to expand its capability
	mov r16, r24
	rcall display_decimal
	Clear RotationCounter       ; Reset the rotation counter.

	Clear TempCounter           ; Reset the temporary counter.
	ldi YL, low(SecondCounter)  ; Load the address of the second
	ldi YH, high(SecondCounter) ; counter.
	ld r24, Y +                 ; Load the value of the second counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the second counter by one.

	st Y, r25                   ; Store the value of the second counter.
	st - Y, r24
	rjmp endif
NotSecond:
	st Y, r25                   ; Store the value of the temporary counter.
	st - Y, r24
endif:
	pop r24                      ; Epilogue starts;
	pop r25                      ; Restore all conflict registers from the stack.
	pop YL
	pop YH
	pop r16
	out SREG, r16
	pop r16                    ; Epilogue ends.
	reti


EXT_INT2:
	push r16
	in r16, SREG
	push r16
	push YH
	push YL
	push r25
	push r24

	ldi YL, low(RotationCounter)
	ldi YH, high(RotationCounter)
	ld r24, Y+
	ld r25, Y

	adiw r25:r24, 1			; Increase the rotation counter by one

	st Y, r25
	st - Y, r24

	
	; Uncomment to show the 'LED not flashing when disk is rotating' problem
	; 	perhaps the waves are not stable at all and we got constant falling edges?
	; com leds
	; out PORTC, leds

	pop r24
	pop r25
	pop YL
	pop YH
	pop r16
	out SREG, r16
	pop r16
	reti


	
main:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16


    ; LCD set up and initialization
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

	; ldi leds, 0xff            ; Init pattern displayed
	; out PORTC, leds
	; ldi leds, PATTERN
	Clear TempCounter         ; Initialize the temporary counter to 0
	Clear SecondCounter       ; Initialize the second counter to 0
	Clear RotationCounter     ; Initialize the rotation counter to 0

	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000011
	out TCCR0B, temp          	; Prescaler value=64, counting 1024 us
	ldi temp, 1<<TOIE0
	sts TIMSK0, temp           	; T / C0 interrupt enable

	ldi temp, 0 << PORTD_PIN_TDX2
	out DDRD, temp          	; Set PD2 bit 2 as input
	ldi temp, 1 << PORTD_PIN_TDX2
	out PORTD, temp           	; Initially PD2 bit 2 is set to high (means no light detected)

	ldi temp, (2 << CS20)
	sts EICRA, temp            	; INT2 falling edge, Since INT2 is connected to OpO pin, and OpO will go low when the detector can see the light

	in temp, EIMSK
	ori temp, 1 << INT2		
	out EIMSK, temp            	; INT2 interrupt enable

	sei							; Enable global interrupt

loop:
	rjmp loop                   ; loop forever




; TODO(hongfei): 	the number of rotations, most likely, will be larger than 255
; 					therefore we need to display the value of r25 together with r24 on screen as well
; 					the current function display_decimal only displays the value of r24, need to expand its capability
; Binary number to display stored in r16
display_decimal:
	push r18
	in r18, SREG
	push r18
	push r16 				; hold binary number to be converted and displayed
    push r19 				; hold number of iterations
    push r17 				; hold temporary value
    push r24				; hold lower two digits of 8 bit BCD formatted number
    push r25 				; hold upper two digits of 8 bit BCD formatted number (8 bits can only have 1 upper digit)

    ; Using the double dabble algorithm
    ; https://en.wikipedia.org/wiki/Double_dabble
    ; Convert to packed BCD format
	; For example, 5 becomes 0101, 10 becomes 0001 0000

    clr r24
    clr r25
    ldi r19, 8		; number of iterations, since we have 8 bits to convert

double_dabble_loop:
    lsl r16
    rol r24
    rol r25

    dec r19
    tst r19
    breq end_double_dabble

check_ones:
    mov r17, r24
    andi r17, 0b00001111
    cpi r17, 5
    brlo check_tens
    subi r24, -3
check_tens:
	mov r17, r24
	swap r17
	andi r17, 0b00001111
	cpi r17, 5
	brlo double_dabble_loop
	subi r24, -3<<4
	rjmp double_dabble_loop
end_double_dabble:

	; Display the BCD

	clear_lcd

	; Display the hundreds
    andi r25, 0b00001111
    subi r25, -'0'
    do_lcd_data r25

	; Display the tens
    mov r17, r24
    swap r17
    andi r17, 0b00001111
    subi r17, -'0'
    do_lcd_data r17

	; Display the ones
    andi r24, 0b00001111
    subi r24, -'0'
    do_lcd_data r24

    pop r25
	pop r24
    pop r17
    pop r19
	pop r16
	pop r18
	out SREG, r18
	pop r18
	ret



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

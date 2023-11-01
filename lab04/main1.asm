	.include "m2560def.inc"
	
    .equ LCD_RS         =   7
    .equ LCD_E          =   6
    .equ LCD_RW         =   5
    .equ LCD_BE         =   4
	.equ PATTERN        =   0b11110000
	.def temp0          =   r18
    .def temp1          =   r19
	.def leds           =   r20
    .def ten            =   r21
    


    .macro Clear
        ldi YL, low(@0)              ; load the memory address to Y
        ldi YH, high(@0)
        clr temp1
        st Y+ , temp1                ; clear the two bytes at @0 in SRAM
        st Y, temp1
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
        mov r16, @0
        rcall lcd_data
        rcall lcd_wait
    .endmacro

	.dseg
SecondCounter:  .byte 2                      ; Two - byte counter for counting the number of seconds.
TempCounter:    .byte 2

	.cseg
	.org 0x0000
	jmp RESET
	.org OVF0addr
	jmp Timer0OVF               ; Jump to the interrupt handler for Timer0 overflow.
	
DEFAULT: reti
RESET:
	ser temp1                    ; set Port C as output
	out DDRC, temp1
	rjmp main
	
Timer0OVF:                      ; interrupt subroutine for Timer0
    in temp1, SREG
	push temp1                   ; Prologue starts.
	push Yh                     ; Save all conflict registers in the prologue.
	push YL
    push r16
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
	com leds
	out PORTC, leds
	Clear TempCounter           ; Reset the temporary counter.
	ldi YL, low(SecondCounter)  ; Load the address of the second
	ldi YH, high(SecondCounter) ; counter.
	ld r24, Y +                 ; Load the value of the second counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the second counter by one.

    ; mov r16, r25
    ; rcall convert_to_hex_and_display

	st Y, r25                   ; Store the value of the second counter.
	st - Y, r24
	rjmp endif
NotSecond:
	st Y, r25                   ; Store the value of the temporary counter.
	st - Y, r24
endif:
	pop r24                      ; Epilogue starts;
	pop r25                      ; Restore all conflict registers from the stack.
    pop r16
	pop YL
	pop YH
	pop temp1
	out SREG, temp1
	reti
	
	
main:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

    ldi ten, 10

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

    jmp test


    ;;;;; TEST

	ldi leds, 0xff               ; Init pattern displayed
	out PORTC, leds
	ldi leds, PATTERN
	Clear TempCounter            ; Initialize the temporary counter to 0
	Clear SecondCounter          ; Initialize the second counter to 0
	ldi temp1, 0b00000000
	out TCCR0A, temp1
	ldi temp1, 0b00000011
	out TCCR0B, temp1             ; Prescaler value=64, counting 1024 us
	ldi temp1, 1<<TOIE0
	sts TIMSK0, temp1             ; T / C0 interrupt enable
	sei                          ; Enable global interrupt

loop:
	rjmp loop                    ; loop forever



display_decimal:
	push r16
	push temp1
	push temp0
	
	
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00001110
	sbrs r16, 7       
	rjmp positive
negative:
	com r16			; two's complement
	inc r16
	ldi temp1, '-'
	do_lcd_data temp1

positive:
	cp r16, ten
	brlo display_one_digit
	ldi ten, 10
	clr temp1		; make temp1 #-10      (e.g. 123 -> temp1=12, r16=3)
loop_pos:
	cp r16, ten      ; if r16 is less than 10 go to output
	brlo output
	inc temp1       ; else temp1 += 1
	sub r16, ten     ; r16 -= 10
	rjmp loop_pos

output:
	cp temp1, ten   ; if #times -10 is less than 10, which means result is 1/2 digit, go to display
	brlo display         
	ldi temp0, '1'  ; else result is 3-digit
	do_lcd_data temp0    
	sub temp1, ten

display:
	subi temp1, -'0'
	do_lcd_data temp1

display_one_digit:
	subi r16, -'0'
	do_lcd_data r16

    ldi r16, 0b01010101
    out PORTC, r16
    
	pop temp0
	pop temp1
	pop r16
	ret


convert_to_hex_and_display:
	
	push YL
	push YH
	push r16
	push r17
	push r18
	in YL, SPL
	in YH, SPH
	sbiw YH:YL, 7
	out SPH, YH
	out SPL, YL
	
	; assume binary is in r16

	do_lcd_command 0b00000001 	; clear display
	do_lcd_command 0b00001110
	
	; check sign
	ldi r17, 0                  ; r17 stores how many hex digit we have converted
	mov r18, r16				 	; r18 stores the absolute value of the original number 
	sbrs r16, 7                  ; check MSB for negative number
	rjmp display_0x
neg_number:
	neg r16                      ; convert to positive to print
	
	mov r18, r16               	; overwrite r18 with the absolute value of the original number
	
	ldi r16, '-'                 ; print '-' on LCD
	do_lcd_data r16

display_0x:

	ldi r16, '0'
	do_lcd_data r16
	ldi r16, 'x'
	do_lcd_data r16
	mov r16, r18              	; restore r16 to the original number we first stored to do hex conversion
	
convert_to_ascii_loop:
	swap r16                     ; Convert the highest 4 bit first, swap them to the lower 4 bit for convinence
	andi r16, 0b00001111         ; Keep the 4 bit we are interested in only
	cpi r16, 10                  ; if this digit is larger than 10, we need to represent it with a letter
	brlt convert_to_ascii_number
	subi r16, - ('A' - 10)       ; convert r16 to a ASCII letter, first minus r16 by 10 to get how much it exceeds 10, then displace it by the ASCII value of 'A'
	rjmp display_to_lcd
convert_to_ascii_number:
	subi r16, - ('0')            ; convert r16 to a ASCII number, displace it by the ASCII value of '0'
display_to_lcd:
	do_lcd_data r16              ; display the converted digit on LCD
	inc r17                      ; we now have converted one digit, we then prepare the lower 4 bit for conversion
	mov r16, r18               	; restore r16
	swap r16                     ; swap now so that the lower 4 bit will be correctly placed at the lower 4 bit later when convert_to_ascii_loop is jumped to again
	cpi r17, 2
	brne convert_to_ascii_loop
	
	
	adiw YH:YL, 7
	out SPH, YH
	out SPL, YL
	pop r18
	pop r17
	pop r16
	pop YH
	pop YL
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

test:
    ser r16
    out DDRC, r16
    out PORTC, r16
    ldi r16, 9
    rcall convert_to_hex_and_display
end:
    rjmp end


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

    ; DO NOT CLEAR
	; M_CLEAR_LCD

	; Display the hundreds
    ; andi r25, 0b00001111
    ; subi r25, -'0'
    ; M_DO_LCD_DATA r25

	; Display the tens
    mov r17, r24
    swap r17
    andi r17, 0b00001111
    subi r17, -'0'
    M_DO_LCD_DATA r17

	; Display the ones
    andi r24, 0b00001111
    subi r24, -'0'
    M_DO_LCD_DATA r24

    pop r25
	pop r24
    pop r17
    pop r19
	pop r16
	pop r18
	out SREG, r18
	pop r18
	ret

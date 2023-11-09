
; Keypad set up and initialization
.macro M_KEYPAD_INIT
	push r16

	ldi r16, PORTLDIR			; columns are outputs, rows are inputs
	sts	DDRL, r16				; set up keypad

    pop r16
.endmacro

;to help compute and store the keypad input numbers that are multiple digits 
.macro M_MULT_TEN
    push r16
    ldi r16, 10
    mul @0, r16
    mov @0, r0
    pop r16
.endmacro

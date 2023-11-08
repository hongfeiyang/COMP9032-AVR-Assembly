
; Keypad set up and initialization
.macro M_KEYPAD_INIT
	push r16

	ldi r16, PORTLDIR			; columns are outputs, rows are inputs
	sts	DDRL, r16				; set up keypad

    pop r16
.endmacro
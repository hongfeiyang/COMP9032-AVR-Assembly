
lcd_command:
	push r16
	out PORTF, r16
	ldi r16, (0<<LCD_RS) | (0<<LCD_RW)		; Write mode to instruction register
	out PORTA, r16
	nop
	sbi PORTA, LCD_E	; turn on the enable pin
	nop				; delay to meet timing req. (Enable pulse width)
	nop
	nop
	cbi PORTA, LCD_E	; turn off the enable pin
	nop				; delay to meet timing req. (Enable cycle time)
	nop
	nop
	pop r16
	ret

lcd_data:
	push r16
	out PORTF, r16
	ldi r16, (1 << LCD_RS) | (0<<LCD_RW); Write mode to data register
	out PORTA, r16 						; RS = 1, RW = 0 for a data write
	nop 								; delay to meet timing (Set up time)
	sbi PORTA, LCD_E 					; turn on the enable pin
	nop									; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi PORTA, LCD_E 					; turn off the enable pin
	nop 								; delay to meet timing (Enable cycle time)
	nop
	nop
	pop r16
	ret


lcd_wait_busy:
	push r16
	clr r16
	out DDRF, r16 												; Make port F as an input port for now
	ldi r16, (0 << LCD_RS) | ( 1 << LCD_RW)						; Instruction register, read mode
	out PORTA, r16 												; RS = 0, RW = 1 for a command port read
busy_loop:
	nop 														; delay to meet set-up time
	sbi PORTA, LCD_E 											; turn on the enable pin
	nop 														; delay to meet timing (Data delay time)
	nop
	nop
	in r16, PINF 												; read value from LCD
	cbi PORTA, LCD_E 											; turn off the enable pin
	sbrc r16, LCD_BF 											; if the busy flag is set
	rjmp busy_loop 												; repeat command read
	clr r16 													; else
	out PORTA, r16 												; turn off read mode, set it up to write mode, instruction register
	ser r16 													; 
	out DDRF, r16 												; make port F an output port again
	pop r16
	ret


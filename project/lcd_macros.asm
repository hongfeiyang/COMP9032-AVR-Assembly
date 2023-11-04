
.macro M_DO_LCD_COMMAND
    push r16
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait_busy
    pop r16
.endmacro

.macro M_DO_LCD_DATA
	push r16
    mov r16, @0
	rcall lcd_data
	rcall lcd_wait_busy
	pop r16
.endmacro

.macro M_CLEAR_LCD
	M_DO_LCD_COMMAND 0b00000001 	; clear display
	M_DO_LCD_COMMAND 0b00001110
.endmacro

; LCD set up and initialization
.macro M_LCD_INIT
    push r16
	
	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	M_DO_LCD_COMMAND 0b00111000 ; 2x5x7
	rcall sleep_5ms
	M_DO_LCD_COMMAND 0b00111000 ; 2x5x7
	rcall sleep_1ms
	M_DO_LCD_COMMAND 0b00111000 ; 2x5x7
	M_DO_LCD_COMMAND 0b00111000 ; 2x5x7
	M_DO_LCD_COMMAND 0b00001000 ; display off
	M_DO_LCD_COMMAND 0b00000001 ; clear display
	M_DO_LCD_COMMAND 0b00000110 ; increment, no display shift
	M_DO_LCD_COMMAND 0b00001110 ; Cursor on, bar, no blink

    pop r16
.endmacro
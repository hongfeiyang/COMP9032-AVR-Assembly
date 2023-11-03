
.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

.macro do_lcd_command
    push r16
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
    pop r16
.endmacro

.macro M_DO_LCD_DATA
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

; LCD set up and initialization
.macro M_LCD_INIT
    push r16
	
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

    pop r16
.endmacro
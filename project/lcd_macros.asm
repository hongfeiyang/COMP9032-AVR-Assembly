
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

.macro M_LCD_GO_HOME
	M_DO_LCD_COMMAND 0b00000010 	; return home
.endmacro

.macro M_CLEAR_LCD
	M_DO_LCD_COMMAND 0b00000001 	; clear display
	M_LCD_GO_HOME
.endmacro

; Set AC mannually and cursor will be set to the position pointed by AC
.macro M_LCD_SET_CURSOR_OFFSET
	push r16
	mov r16, @0
	ori r16, (1<<7)		; DB7 needs to be 1
	rcall lcd_command
	rcall lcd_wait_busy
	pop r16
.endmacro

.macro M_LCD_SET_CURSOR_TO_SECOND_LINE_START
	M_DO_LCD_COMMAND 0x40 | (1<<7)				 ; Set DDRAM address to 0x40 (second line) 40 ~ 67 are the second line, DB7 must be 1
.endmacro

.macro M_LCD_SET_CURSOR_TO_FIRST_LINE_START
	M_DO_LCD_COMMAND 0x00 | (1<<7)				 ; Set DDRAM address to 0x00 (first line) 00 ~ 27 are the first line, DB7 must be 1
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
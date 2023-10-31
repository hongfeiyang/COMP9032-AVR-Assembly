.include "m2560def.inc"

.def row=r18
.def col=r19
.def height=r20
.def direction=r21
.def state=r22
.def spd=r23
.def temp1=r24

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.cseg
map:
    .db 2, 2, 2, 2, 9, 4, 5, 6, 7, 8, 9, 8, 7, 6, 0
    .db 2, 2, 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 0
    .db 2, 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 0
    .db 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 0
    .db 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 0
    .db 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 2, 0
    .db 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 2, 2, 0
    .db 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 0
    .db 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 0
    .db 8, 9, 8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 0
    .db 9, 8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2, 0
    .db 8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 0
    .db 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0
    .db 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0
    .db 5, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0

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

;displays next tile in row
.macro display_row_tile
    lpm r17, z+             ;load next grid element (increment to get next element in row)
    subi r17,-'0'           ;convert to ASCII
    do_lcd_data r17         ;display
.endmacro

;displays next tile in column
.macro display_col_tile
    lpm r17, z              ;load next grid element (dont increment)
    subi r17,-'0'           ;convert to ASCII
    do_lcd_data r17         ;display
    adiw ZH:ZL,16           ;add 16 to get same index element in next row
.endmacro



RESET:
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
    ldi zh,high(map<<1)         ;set pointer to map grid
    ldi zl,low(map<<1)          
    ldi row,14                  ;Initialise start position at last row last col (TODO: change this so its 0,0 not 14,14)
    ldi col,14
    ldi direction,'W'           ;Initialise drone moving west
    ldi state,'F'               ;initialise in flight mode
    ldi height, 1               ;initialise height to 1
    ldi spd, 1                  ;initialise speed to 1
main:
    rcall display               ;call display function



end:
    rjmp end






;------------------------------------------------------------------------
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

;displays a row on the LCD based on drone position
display_row:
    ;prologue
    push YL 
    push YH 
    push r17 
    push r20 
    in YL, SPL 
    in YH, SPH
    sbiw YH:YL, 4
    out SPH, YH 
    out SPL, YL
    ;body
    ldi r20,16          ;set r20 to r16 as it is the length of the row array
    mul row,r20         ;get corresponding row in array
    add ZL,r0           ;assign start of corresponding row to z pointer
    adc ZH,r1
    display_row_tile    ;display row position 15 times
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    display_row_tile
    ;epilogue
    adiw YH:YL,4
    out SPH, YH
    out SPL, YL
    pop r20
    pop r17
    pop YH
    pop YL
    ret

;displays a column on LCD based on drone position
display_col:
    ;prologue
    push YL 
    push YH 
    push r17 
    push r20
    in YL, SPL 
    in YH, SPH
    sbiw YH:YL,4
    out SPH, YH 
    out SPL, YL
    ;body
    ldi r20,0
    add ZL,col          ;get corresponding column and assign to z pointer
    adc ZH,r20
    display_col_tile    ;display column position 15 times
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    display_col_tile
    ;epilogue
    adiw YH:YL,4
    out SPH, YH
    out SPL, YL
    pop r20
    pop r17
    pop YH
    pop YL
    ret

;updates LCD display
display:
    do_lcd_command 0b00000001 	; clear display
    cpi direction, 'E'  ;east direction
    breq east 
    cpi direction, 'S'  ;south direction
    breq south
    cpi direction, 'W'  ;west direction
    breq west
north:
    do_lcd_command 0b00000100   ;decrement, no display shift to display backwards
    do_lcd_command 0b10001111   ;set address to end of first row
    rcall display_col           ;display corresponding column in matrix
    do_lcd_command 0b00000110   ;set back to increment
    rjmp line2
east:
    do_lcd_command 0b00000110   ;increment, no display shift
    rcall display_row           ;display corresponding row in matrix
    rjmp line2
south:
    do_lcd_command 0b00000110   ;increment, no display shift
    rcall display_col           ;display corresponding column in matrix
    rjmp line2
west:
    do_lcd_command 0b00000100   ;decrement, no display shift
    do_lcd_command 0b10001111   ;set address to end of first row
    rcall display_row           ;display corresponding row in matrix
    do_lcd_command 0b00000110   ;set back to increment
;second line of display showing state, position, speed and direction
line2:
    do_lcd_command 0b10101000   ;set address to row 2
display_state:
    do_lcd_data state           ;display state           
    ldi temp1, ' '              ;display 2 spaces
    do_lcd_data temp1
    do_lcd_data temp1
display_position_col:
    ldi temp1, '('              ;display bracket
    do_lcd_data temp1
    cpi col,10                  ;check if column position >= 10
    brlo col_1digit             ;if < 10 skip to col_1digit
    ldi temp1, '1'              ;if >= 10, display a 1
    do_lcd_data temp1      
    mov temp1,col               
    subi temp1,10               ;subtract 10 from col
    subi temp1, -'0'            ;convert to ASCII
    do_lcd_data temp1           ;display
    rjmp display_position_row
col_1digit:
    mov temp1,col               
    subi temp1, -'0'            ;convert to ASCII
    do_lcd_data temp1           ;display
display_position_row:
    ldi temp1, ','              ;display a comma
    do_lcd_data temp1
    cpi row,10                  ;same check for >= 10 as col
    brlo row_1digit
    ldi temp1, '1'
    do_lcd_data temp1
    mov temp1,row
    subi temp1,10
    subi temp1, -'0'
    do_lcd_data temp1
    rjmp display_height
row_1digit:
    mov temp1,row
    subi temp1, -'0'
    do_lcd_data temp1
display_height:
    ldi temp1, ','              ;display comma
    do_lcd_data temp1
    mov temp1,height            
    subi temp1, -'0'            ;convert height to ASCII
    do_lcd_data temp1           ;display height
    ldi temp1, ')'              ;display close bracket
    do_lcd_data temp1
display_speed_direction:
    do_lcd_command 0b10110101   ;set address to end row 2
    mov temp1,spd               
    subi temp1, -'0'            ;convert speed to ASCII
    do_lcd_data temp1           ;display speed
    ldi temp1, '/'              ;display /
    do_lcd_data temp1
    do_lcd_data direction       ;display diection
    ret
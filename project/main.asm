.include "m2560def.inc"

.def curr_tile_height=r2
.def accident_row=r3
.def accident_col=r4
.def visibility=r5
.def row=r18
.def col=r19
.def height=r20
.def direction=r21
.def state=r22
.def spd=r23
.def temp1=r24
.def counter=r25


.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.equ map_size=4



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

.macro Clear
	ldi YL, low(@0)              ; load the memory address to Y
	ldi YH, high(@0)
	clr temp1
	st Y+ , temp1                ; clear the two bytes at @0 in SRAM
	st Y, temp1
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

.dseg
SecondCounter:  	.byte 2                     ; Two - byte counter for counting the number of seconds.
TempCounter:    	.byte 2

.cseg
.org 0x0000
	jmp RESET
.org OVF0addr
	jmp Timer0OVF               ; Jump to the interrupt handler for Timer0 overflow.

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
    .db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2, 1, 0
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
    Clear TempCounter
    ldi temp1, 0b00000000       ;setup timer interrupt for movement
	out TCCR0A, temp1
	ldi temp1, 0b00000011
	out TCCR0B, temp1          	; Prescaler value=64, counting 1024 us
	ldi temp1, 1<<TOIE0
	sts TIMSK0, temp1           	; T / C0 interrupt enable

	sei							; Enable global interrupt
    rjmp main


Timer0OVF:                      ; interrupt subroutine for Timer0
	push r16
    in r16, SREG
	push r16                   ; Prologue starts.
	push YH                     ; Save all conflict registers in the prologue.
	push YL
    push ZH
    push ZL
    push r27
    push r26
	push r25
	push r24                    ; Prologue ends.
    ;body
	ldi YL, low(TempCounter)    ; Load the address of the temporary
	ldi YH, high(TempCounter)   ; counter.
	ld r24, Y+                  ; Load the value of the temporary counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the temporary counter by one
	
	cpi r24, low(1000)          ; Check if (r25:r24)=1000
	brne NotSecond
	cpi r25, high(1000)
	brne NotSecond
check_state:                    ;checks drone state, only moves if in flying state 
    cpi state,'F'
    brne check_accident_found   ;if not in flying state, jumps to accident check
movement:
    check_direction:
        cpi direction, 'E'  ;east direction
        breq move_east 
        cpi direction, 'S'  ;south direction
        breq move_south
        cpi direction, 'W'  ;west direction
        breq move_west
    move_north:
        cpi row,0               ;doesnt move if at upper boundary of map
        breq display_new_pos
        dec row                 ;otherwise decrement row number
        rjmp diagonal_movement
    move_east:
        cpi col,14              ;doesnt move if at right boundary of map
        breq display_new_pos
        inc col                 ;otherwise incremenet col number
        rjmp diagonal_movement
    move_south:
        cpi row,14              ;doesnt move if at bottom boundary of map 
        breq display_new_pos
        inc row                 ;otherwise increment row number
        rjmp diagonal_movement
    move_west:
        cpi col,0               ;doesnt move if at left boundary of map
        breq display_new_pos
        dec col                 ;otherwise decrement col number
diagonal_movement:  ;checking drones diagonal movement and checking for crash
    check_pos_height:   ;find the height of the tile for the new position 
        ldi zh,high(map<<1)         ;set pointer to map grid
        ldi zl,low(map<<1)   
        ldi r27,16
        ldi r26,0
        mul row,r27                 ;get row number
        add ZL,r0                   ;assign start of corresponding row to z pointer
        adc ZH,r1
        add ZL,col                  ;add col number to z pointer to get height for corresponding tile
        adc ZH,r26
        lpm curr_tile_height,z      ;load tile height
        cp curr_tile_height,height  ;if drone height = tile height, increment drone height
        breq diagonal_up
        cp curr_tile_height,height  ;if tile height > drone height, crash 
        brsh crash
        inc curr_tile_height
        cp curr_tile_height,height  ;if tile height is 1 less than drone height, drone hieght stays the same 
        breq check_accident_found
    diagonal_down:                  ;else, decremenet drone height
        dec height
        rjmp check_accident_found
    diagonal_up:
        inc height
        rjmp check_accident_found
crash:  ;in event of crash, change state.
    ldi state, 'C'
check_accident_found:   ;checking if accident has been found
;TODO: IMPLEMENT LOGIC FOR EVENT WHERE ACCIDENT HAS BEEN FOUND IN HOVER STATE FROM ADJUSTING HEIGHT
	cp accident_row,row             ;checking drone coordinates are the same as accident             
    brne display_new_pos
    cp accident_col, col
    brne display_new_pos
    add curr_tile_height,visibility ;if coordinates same, checking if in visibility range
    cp height,curr_tile_height
    brlo accident_found             ;if same coordinates and within visibility range, accident found 
    rjmp display_new_pos
accident_found:
    ldi state, 'R'
    ;TODO: update the display to show the accident location when accident is found 
display_new_pos:    ;update the display and reset tempcounter
    rcall display
    Clear TempCounter
    rjmp endif
NotSecond:
	st Y, r25                   ; Store the value of the temporary counter.
	st - Y, r24
endif:
	pop r24                      ; Epilogue starts;
	pop r25                      ; Restore all conflict registers from the stack.
    pop r26
    pop r27
    pop ZL
    pop ZH
	pop YL
	pop YH
	pop r16
	out SREG, r16
	pop r16                    ; Epilogue ends.
	reti


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
    push ZH
    push ZL
    in YL, SPL 
    in YH, SPH
    sbiw YH:YL, 4
    out SPH, YH 
    out SPL, YL
    ;body
    ldi zh,high(map<<1)         ;set pointer to map grid
    ldi zl,low(map<<1)   
    ldi r20,16          ;set r20 to 16 as it is the length of the row array
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
    pop ZL
    pop ZH
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
    push ZH
    push ZL
    in YL, SPL 
    in YH, SPH
    sbiw YH:YL,4
    out SPH, YH 
    out SPL, YL
    ;body
    ldi zh,high(map<<1)         ;set pointer to map grid
    ldi zl,low(map<<1)   
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
    pop ZL
    pop ZH
    pop r20
    pop r17
    pop YH
    pop YL
    ret



;updates LCD display
;TODO: adapt display for crash and return 
display:
    do_lcd_command 0b00000001 	; clear display
    cpi direction, 'E'  ;east direction
    breq display_east 
    cpi direction, 'S'  ;south direction
    breq display_south
    cpi direction, 'W'  ;west direction
    breq display_west
display_north:
    do_lcd_command 0b00000100   ;decrement, no display shift to display backwards
    do_lcd_command 0b10001111   ;set address to end of first row
    rcall display_col           ;display corresponding column in matrix
    do_lcd_command 0b00000110   ;set back to increment
    rjmp line2
display_east:
    do_lcd_command 0b00000110   ;increment, no display shift
    rcall display_row           ;display corresponding row in matrix
    rjmp line2
display_south:
    do_lcd_command 0b00000110   ;increment, no display shift
    rcall display_col           ;display corresponding column in matrix
    rjmp line2
display_west:
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

;copy map from program memory to data memory
map_to_data:
    ;prologue
    push ZL
    push ZH
    push YL
    push YH
    push temp1
    push counter
    ;body
    map_copy:
        ldi ZL, low(map)		;let Z point to map
        ldi ZH, high(map)
        ldi YL, low(0x0000)     ;let Y point to dseg 0
        ldi YH, high(0x0000)
        ldi counter, map_size	;set counter
    map_copy_loop:
        lpm temp1, Z+			;copy value from map
        st Y+, temp1            ;save value to data memory
        subi counter, 1			;check if all values pushed
        cpi counter, 0
        brne map_copy_loop
    ;epilogue
    pop counter
    pop temp1
    pop YH
    pop YL
    pop ZH
    pop ZL
    ret


;copy map from program memory to data memory and invert
map_to_data_invert:
    ;prologue
    push ZL
    push ZH
    push temp1
    push counter
    ;body
    push_matrix:
        ldi ZL, low(map)		;let Z point to matrix
        ldi ZH, high(map)
        ldi counter, map_size	;set counter
    push_matrix_loop:
        lpm temp1, Z+			;push value from matrix onto stack
        push temp1
        subi counter, 1			;check if all values pushed
        cpi counter, 0
        brne push_matrix_loop
    pop_matrix:
        ldi ZL, low(map)		;let Z point to matrix
        ldi ZH, high(map)
        ldi counter, map_size	;set counter
    pop_matrix_loop:
        pop	temp1				;pop value from stack into memory
        st Z+, temp1
        subi counter, 1			;check if all values popped
        cpi counter, 0
        brne pop_matrix_loop
    ;epilogue
    pop counter
    pop temp1
    pop ZH
    pop ZL
    ret
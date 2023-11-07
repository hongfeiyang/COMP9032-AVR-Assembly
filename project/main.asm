.include "m2560def.inc"

.include "lcd_defs.asm"
.include "keypad_defs.asm"

.include "lcd_macros.asm"
.include "keypad_macros.asm"

.macro Clear
    push r16
	ldi YL, low(@0)              ; load the memory address to Y
	ldi YH, high(@0)
	clr r16
	st Y+, r16                ; clear the two bytes at @0 in SRAM
	st Y, r16
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


.equ MAP_SIZE       =   16
.equ MIN_SPEED      =   1
.equ MAX_SPEED      =   9
.equ VISIBILITY     =   1
.equ MAX_HEIGHT     =   100
.def DroneX         =   r4
.def DroneY         =   r5
.def DroneZ         =   r6
.def Direction      =   r7    ; N: North, S: South, E: East, W: West, U: Up, D: Down
.def Spd            =   r8
.def FlightState    =   r9    ; F: Flight, H: Hover, R: Return, C: Crash
.def AccidentX      =   r10
.def AccidentY      =   r11

.dseg
.org 0x200
    SecondCounter:  	.byte 2                     ; Two - byte counter for counting the number of seconds. Consider this as a clock that counts the number of seconds has elapsed.
    TempCounter:    	.byte 2						; Two - byte counter for counting the number of intervals of 1024 us. Will reset to 0 after 1000 intervals.

.cseg
.org 0x0000
	jmp RESET                   ; Reset interrupt vector
.org INT0addr
    jmp EXT_INT0                ; INT0 interrupt vector
.org INT1addr
    jmp EXT_INT1                ; INT1 interrupt vector 
.org OVF0addr
	jmp Timer0OVF               ; Timer0 overflow interrupt vector

map:    .db     1,  2,  3,  4,  5,  6,  7,  8,  9,  8,  7,  6,  5,  4,  3,  0   ; ROW 0
        .db     2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  1   ; ROW 1
        .db     3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  2   ; ROW 2
        .db     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  3   ; ROW 3
        .db     5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  4   ; ROW 4
        .db     6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  5   ; ROW 5
        .db     7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  6   ; ROW 6
        .db     8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  7   ; ROW 7
        .db     9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  8   ; ROW 8
        .db     8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  9   ; ROW 9
        .db     7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  8   ; ROW 10
        .db     6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  7   ; ROW 11
        .db     5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  6   ; ROW 12
        .db     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  5   ; ROW 13
        .db     3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  4   ; ROW 14
        .db     2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  3   ; ROW 15

opening_line:   .db     "Acci loc: "

RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

    ser r16                     ; Set up LED bar to be output pins
    out DDRC, r16

    clr AccidentX
    clr AccidentY
    clr DroneX
    clr DroneY
    clr DroneZ
    ldi r16, 1
    mov DroneZ, r16
    ldi r16, 'S'
    mov Direction, r16
    ldi r16, MIN_SPEED
    mov Spd, r16
    ldi r16, 'F'
    mov FlightState, r16

    M_KEYPAD_INIT

    M_LCD_INIT
    
    M_CLEAR_LCD
    M_DO_LCD_COMMAND 0x40 | (1<<7)      ; Set DDRAM address to 0x40 (second line) 40 ~ 67 are the second line, 00 ~ 27 are the first line, DB7 must be 1

    rcall print_opening_line
    rcall read_accident_location
    
    ; Start game, enable timer interrupt

    ; Timer0 interrupt set up and initialization
	ldi r16, 0b00000000
	out TCCR0A, r16
	ldi r16, 0b00000011
	out TCCR0B, r16          	; Prescaler value=64, counting 1024 us
	ldi r16, 1<<TOIE0
	sts TIMSK0, r16           	; T / C0 interrupt enable


    ; INT0 and INT1 interrupt set up and initialization
    ldi r16, (2<<ISC00) | (2<<ISC10) ; Falling edge triggered interrupt
    sts EICRA, r16              ; Configure INT0 and INT1 as falling edge triggered interrupt
    in r16, EIMSK
    ori r16, (1<<INT0) | (1<<INT1)
    out EIMSK, r16              ; Enable INT0 interrupt

    sei

    jmp main_loop


print_opening_line:
    push ZH
    push ZL
    push r17
    push r16

    ldi ZH, high(opening_line<<1)
    ldi ZL, low(opening_line<<1)

    clr r17
print_opening_line_loop:
    lpm r16, Z+
    M_DO_LCD_DATA r16
    inc r17
    cpi r17, 10 ; 10 characters to be printed
    brne print_opening_line_loop
    
    pop r16
    pop r17
    pop ZL
    pop ZH
    ret



read_accident_location:
    push r18

get_x_corrdinate:
    rcall scan_key_pad
    mov r18, r0
    cpi r18, 0
    breq get_x_corrdinate

    rcall sleep_200ms
    rcall sleep_200ms

    M_DO_LCD_DATA r0
    mov r18, r0
    cpi r18, '*'
    breq get_y_corrdinate
    M_MULT_TEN AccidentX
    subi r18, '0'
    add AccidentX, r18
    out PORTC, AccidentX
    rjmp get_x_corrdinate
get_y_corrdinate:
    rcall scan_key_pad
    mov r18, r0
    cpi r18, 0
    breq get_y_corrdinate

    rcall sleep_200ms
    rcall sleep_200ms
    M_DO_LCD_DATA r0
    mov r18, r0
    cpi r18, '*'
    breq end_set_up_accident_location
    M_MULT_TEN AccidentY
    subi r18, '0'
    add AccidentY, r18
    out PORTC, AccidentY
    rjmp get_y_corrdinate

end_set_up_accident_location:
    pop r18
    ret


; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Timer0 Overflow Handler ------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;
Timer0OVF:                      ; interrupt subroutine for Timer0
	push r16
    in r16, SREG
	push r16                    ; Prologue starts.
	push YH                     ; Save all conflict registers in the prologue.
	push YL
	push r25
	push r24                    ; Prologue ends.

	ldi YL, low(TempCounter)    ; Load the address of the temporary
	ldi YH, high(TempCounter)   ; counter.
	ld r24, Y+                  ; Load the value of the temporary counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the temporary counter by one

    rcall scan_key_pad
    ldi r16, 0
    cp r0, r16
    breq no_drone_command
    rcall process_drone_command
    rcall flash_three_times

no_drone_command:
    ; User hasn't input anything, drone continue to move according its inertia

	cpi r24, low(1000)          ; Check if (r25:r24)=500
	brne NotSecond
	cpi r25, high(1000)
	brne NotSecond

	; Otherwise we have reached 500ms

    rcall step_drone
   
	Clear TempCounter           ; Reset the temporary counter.
	ldi YL, low(SecondCounter)  ; Load the address of the second
	ldi YH, high(SecondCounter) ; counter.
	ld r24, Y +                 ; Load the value of the second counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the second counter by one.

    ; out PORTC, r24              ; Display the second counter on the LED bar.

	st Y, r25                   ; Store the value of the second counter.
	st - Y, r24
	rjmp endif
NotSecond:
	st Y, r25                  	; Store the value of the temporary counter.
	st - Y, r24
endif:
	pop r24                     ; Epilogue starts;
	pop r25                     ; Restore all conflict registers from the stack.
	pop YL
	pop YH
	pop r16
	out SREG, r16
	pop r16                    	; Epilogue ends.
	reti

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- INT0 Handler ------------------------------------------ ;
; --------------------------------------------------------------------------------------------------------------- ;

EXT_INT0:
    push r16
    in r16, SREG
    push r16

    mov r16, Spd
    cpi r16, MIN_SPEED      ; do not decrease speed if it is min already
    breq end_dec_speed
    dec r16
    mov Spd, r16
    
end_dec_speed:

    in r16, EIMSK
    ori r16, (0<<INT0)      ; Turn off this shit to prevent bouncing

    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- INT1 Handler ------------------------------------------ ;
; --------------------------------------------------------------------------------------------------------------- ;

EXT_INT1:
    push r16
    in r16, SREG
    push r16

    mov r16, Spd
    cpi r16, MAX_SPEED      ; do not increase speed if it is max already
    breq end_inc_speed
    inc r16
    mov Spd, r16

end_inc_speed:

    in r16, EIMSK
    ori r16, (0<<INT1)      ; Turn off this shit to prevent bouncing

    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Main Loop --------------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; Main loop has one job, which is to constant query the status of INT0 and INT1
; If one of them is not set, this means we have just pushed a button, to debounce it
; we wait for a certain period to renabled it.
; This is a quick and dirty way to do debouncing with interrupts, strictly speaking we
; should have 2 counters for each PB, but since the time we debounce is only 50 ms and it is
; unlikely for user to press these two buttons alternatively within 50ms, therefore this is
; enough, worst case scenario one button waits for 100ms before it is reenabled.
main_loop:
    push r16
    in r16, EIMSK
    sbis r16, INT0      ; if INT0 is set, do nothing, otherwise we wait for 50ms and re-enables INT0
    rjmp enable_INT0
    sbis r16, INT1      ; if INT1 is set, do nothing, otherwise we wait for 50ms and re-enables INT1
    rjmp enable_INT1
    rjmp end_main_loop
enable_INTO:
    rcall sleep_50ms    ; Otherwise we just pressed a Push Button, wait for 50 ms to reenable it
    in r16, EIMSK
    ori r16, (1<<INT0)
    rjmp end_main_loop
enable_INT1:
    rcall sleep_50ms
    in r16, EIMSK
    ori r16, (1<<INT1)
    rjmp end_main_loop
end_main_loop:
    pop r16
    rjmp main_loop


; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Subroutines ------------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; Process the drone command input by the user, which has already been left on r0 register
process_drone_command:
    push r16
    push r17
    mov r16, r0
    cpi r16, '2'
    breq north
    cpi r16, '4'
    breq west
    cpi r16, '6'
    breq east
    cpi r16, '8'
    breq south
    cpi r16, '0'
    breq down
    cpi r16, '5'
    breq up
    cpi r16, 'A'    ; A -> Toggle Between Flight and Hover
    breq toggle_flight_state
    ; Otherwise, this command is unknown and should be ignored
    rjmp end_process_drone_command
toggle_flight_state:
    mov r16, FlightState
    cpi r16, 'F'
    breq flying
    cpi r16, 'H'
    breq hovering
    rjmp end_process_drone_command
flying:
    ldi r16, 'H'
    rjmp update_flight_state
hovering:
    ldi r16, 'F'
    rjmp update_flight_state
update_flight_state:
    mov FlightState, r16
    rjmp end_process_drone_command
north:
    ldi r16, 'N'
    rjmp update_direction
south:
    ldi r16, 'S'
    rjmp update_direction
east:
    ldi r16, 'E'
    rjmp update_direction
west:
    ldi r16, 'W'
    rjmp update_direction
up:
    ldi r16, 'U'
    rjmp update_direction
down:
    ldi r16, 'D'
    rjmp update_direction
update_direction:
    mov r17, FlightState
    cpi r17, 'H'
    brne end_process_drone_command  ; Do not allow direction change if drone is not in hovering state
    mov Direction, r16
end_process_drone_command:
    pop r17
    pop r16
    ret


; Step function for the drone
; This function represents an atomic unit of time, is a single indivisible step
; that discretise time into ticks,
; Should only be called in a timer interrupt 
step_drone:
    push r16

    mov r16, FlightState
    cpi r16, 'C'
    breq has_crashed
    cpi r16, 'H'
    breq is_hovering
    cpi r16, 'R'
    breq is_returning
    cpi r16, 'F'
    breq is_flying
    rjmp end_step_drone
has_crashed:
    rjmp end_step_drone
is_returning:
    rjmp end_step_drone
is_hovering:
    rcall update_drone_in_hovering_state
    rcall update_status_if_crashed      ; Still need to check for crash on its way back
    rjmp end_step_drone
is_flying:
    rcall update_drone_position
    rcall update_status_if_crashed

    ; If drone has crashed during this step, then we dont need to check if it has found the accident location
    mov r16, FlightState
    cpi r16, 'C'
    breq end_step_drone

    ; Otherwise we proceed to check if the drone has found the accident location
    rcall update_status_if_found
    rjmp end_step_drone
end_step_drone:

    ; At the end of the step function a new Frame (screen) should be drawn
    ; on LCD, therefore the LCD has a display refresh rate of 1 / 500ms = 2Hz (Sort of :P)
    ; M_CLEAR_LCD
    ; rcall lcd_wait_busy
    rcall print_curr_path
    rcall print_status_bar

    pop r16
    ret

; Change the FlightState register to 'R' if the drone has 'seen'
; the accident location, given the visibilty (1)
; For now kogic is very simple, only when the drone is above the accident location can the drone see it
; Drone does not have a camera that can look around :(
update_status_if_found:
    push r16

    ; Check X
    cp DroneX, AccidentX
    brne end_check_found
    ; Check Y
    cp DroneY, AccidentY
    brne end_check_found
    ; Check Z
    rcall get_tile_height
    mov r16, r0
    subi r16, -VISIBILITY
    cp r16, DroneZ
    brge found  ; terran height + visibility >= drone height (given drone didnt crash)
    rjmp end_check_found
found:
    ldi r16, 'R'
    mov FlightState, r16
end_check_found:
    pop r16
    ret

; Change the FlightState register to 'C' if the drone has crashed
; Otherwise this function has no effect
; Called after update_drone_position
update_status_if_crashed:
    push r16
    ; Check X
    mov r16, DroneX
    cpi r16, 0
    brlt crashed
    cpi r16, MAP_SIZE
    brge crashed
    ; Check Y
    mov r16, DroneY
    cpi r16, 0
    brlt crashed
    cpi r16, MAP_SIZE
    brge crashed
    ; Check Z
    mov r16, DroneZ
    rcall get_tile_height
    cp r16, r0
    brlt crashed
    cpi r16, MAX_HEIGHT
    brge crashed
    rjmp end_check
crashed:
    ldi r16, 'C'
    mov FlightState, r16
end_check:
    pop r16
    ret


update_drone_in_hovering_state:
    push r16

    mov r16, Direction
    
    cpi r16, 'U'
    breq hover_up
    cpi r16, 'D'
    breq hover_down

hover_up:
    add DroneZ, Spd
    rjmp end_update_drone_in_hovering_state
hover_down:
    sub DroneZ, Spd
    rjmp end_update_drone_in_hovering_state

end_update_drone_in_hovering_state:
    pop r16
    ret



; TODO: need to check for negative speed... 
; After update drone position
update_drone_position:
    push r16
    push r17    ; Store current height of tile
    push r18    ; Store next tile's height

    rcall get_tile_height
    mov r17, r0

    mov r16, Direction
    cpi r16, 'N'
    breq north_update
    cpi r16, 'S'
    breq south_update
    cpi r16, 'E'
    breq east_update
    cpi r16, 'W'
    breq west_update
    cpi r16, 'U'            ; Should we allow UP or DOWN in flight mode? or should we allow it only in hover mode
    breq up_update
    cpi r16, 'D'
    breq down_update

    rjmp end_update_drone_position

north_update:
    sub DroneY, Spd
    rjmp update_drone_z
south_update:
    add DroneY, Spd
    rjmp update_drone_z
east_update:
    add DroneX, Spd
    rjmp update_drone_z
west_update:
    sub DroneX, Spd
    rjmp update_drone_z   ; For consistency
up_update:
    add DroneZ, Spd
    rjmp end_update_drone_position
down_update:
    sub DroneZ, Spd
    rjmp end_update_drone_position
update_drone_z:

    ; Only try to cope with mountain contour if speed is 1
    ; which means next tile this drone will be on is an adjacent tile
    mov r16, Spd
    cpi r16, 1
    brne end_update_drone_position

    rcall get_tile_height
    mov r18, r0

    ; Now we can compare prev tile height and curr (new) tile height
    ; Update Z corrdinate to try to cope with mountain contour

    cp r18, r17
    breq end_update_drone_position
    cp r18, r17
    brlt fly_lower
    cp r17, r18
    brlt fly_higher

    rjmp end_update_drone_position

fly_higher:
    inc DroneZ
    rjmp end_update_drone_position
fly_lower:
    dec DroneZ
    rjmp end_update_drone_position       ; for consistency

end_update_drone_position:
    
    pop r18
    pop r17
    pop r16
    ret


print_curr_path:
    push r16

    M_DO_LCD_COMMAND 0x00 | (1<<7)

    ldi r16, 'N'
    cp Direction, r16
    breq vertical
    ldi r16, 'S'
    cp Direction, r16
    breq vertical
    ldi r16, 'E'
    cp Direction, r16
    breq horizontal
    ldi r16, 'W'
    cp Direction, r16
    breq horizontal
    rjmp end_print_curr_path
horizontal:
    rcall print_curr_row
    rjmp end_print_curr_path
vertical:
    rcall print_curr_col
    rjmp  end_print_curr_path
end_print_curr_path:
    pop r16
    ret

print_status_bar:
    push r16

    M_DO_LCD_COMMAND 0x40 | (1<<7)

    M_DO_LCD_DATA FlightState
    ldi r16, ' '
    M_DO_LCD_DATA r16
    ldi r16, '('
    M_DO_LCD_DATA r16
    mov r16, DroneX
    rcall display_decimal
    ldi r16, ','
    M_DO_LCD_DATA r16
    mov r16, DroneY
    rcall display_decimal
    ldi r16, ','
    M_DO_LCD_DATA r16
    mov r16, DroneZ
    rcall display_decimal
    ldi r16, ')'
    M_DO_LCD_DATA r16
    mov r16, Spd
    rcall display_decimal
    ldi r16, '/'
    M_DO_LCD_DATA r16
    M_DO_LCD_DATA Direction
    pop r16
    ret


print_curr_row:
    push ZH
    push ZL
    push r16
    push r17
    push r18

    ldi r17, MAP_SIZE
    mul DroneY, r17           ; rol * MAP_SIZE gives the offset of the start of this rol in the map array, result is in r1:r0

    ldi ZH, high(map<<1)
    ldi ZL, low(map<<1)

    clr r18
    add ZL, r0                  ; ajust Z pointer to point at the first element of the current row
    adc ZH, r1                  ; only data in r0 is important, and r1 is zero, becuase map size is 16 and 16 * 16 = 256, which is just enought to fill up r0, also CURR_ROL < 16

print_row_loop:
    lpm r16, Z+
    subi r16, -'0'
    M_DO_LCD_DATA r16
    inc r18
    cpi r18, MAP_SIZE
    breq end_print_row_loop
    rjmp print_row_loop
end_print_row_loop:
    pop r18
    pop r17
    pop r16
    pop ZL
    pop ZH
    ret



print_curr_col:
    push ZH
    push ZL
    push r16
    push r17
    push r18
    push r19

    ldi ZH, high(map<<1)
    ldi ZL, low(map<<1)

    ldi r17, MAP_SIZE
    clr r19                         ; temp register just to hold a zero
    clr r18                         ; number of iterations

    add ZL, DroneX                ; add column offset to Z pointer, so Z is pointing to the correct column
    adc ZH, r18

print_col_loop:
    lpm r16, Z
    add ZL, r17                     ; manually increment Z pointer by MAP_SIZE, which is to point to the same column in the next row
    adc ZH, r19
    subi r16, -'0'
    M_DO_LCD_DATA r16
    inc r18
    cpi r18, MAP_SIZE
    breq end_print_col_loop
    rjmp print_col_loop
end_print_col_loop:

    pop r19
    pop r18
    pop r17
    pop r16
    pop ZL
    pop ZH
    ret 




; Get the hight of the current tile the drone is on / above
; leave the result at r0
get_tile_height:
    push ZH
    push ZL
   
    push r18
    push r19

    ; tile_index = Y * MAP_SIZE + X
    ; which means the tile of interest in map is the nth tile where
    ; n is calculated by Row index * MAP_SIZE + Column index
    ldi r19, 0
    ldi r18, MAP_SIZE
    mul DroneY, r18
    add r0, DroneX
    adc r1, r19
    

    ldi ZH, high(map<<1)
    ldi ZL, low(map<<1)

    ; Update Z pointer by this offset to get the address of the this tile
    add ZL, r0
    adc ZH, r1

    ; Load the height of the this tile, store it in r0
    lpm r18, Z
    mov r0, r18

    ; subi r16, -'0'
    ; M_DO_LCD_DATA r16

    pop r19
    pop r18
    pop ZL
    pop ZH
    ret

.include "bcd.asm"
.include "lcd_functions.asm"
.include "keypad_functions.asm"
.include "led_bar_functions.asm"

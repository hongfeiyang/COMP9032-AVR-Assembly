.include "m2560def.inc"

.include "lcd_defs.asm"
.include "keypad_defs.asm"

.include "lcd_macros.asm"
.include "keypad_macros.asm"

.equ MAP_SIZE       =   16
.equ MIN_SPEED      =   1
.equ MAX_SPEED      =   9
.equ VISIBILITY     =   1
.equ INIT_DRONE_X   =   0
.equ INIT_DRONE_Y   =   0
.equ INIT_DRONE_Z   =   1
.equ MAX_HEIGHT     =   100
.def DroneX         =   r4
.def DroneY         =   r5
.def DroneZ         =   r6
.def Direction      =   r7    ; N: North, S: South, E: East, W: West, U: Up, D: Down
.def Spd            =   r8
.def FlightState    =   r9    ; F: Flight, H: Hover, R: Return, C: Crash
.def AccidentX      =   r10
.def AccidentY      =   r11


.cseg

.org 0x0000
	jmp RESET                   ; Reset interrupt vector
.org INT0addr
    jmp EXT_INT0                ; INT0 interrupt vector
.org INT1addr
    jmp EXT_INT1                ; INT1 interrupt vector 
.org OC1Aaddr
    jmp TIMER_1_COMPA_VECT               
.org OC0Aaddr
	jmp TIMER_0_COMPA_VECT               

;               0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
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
    
    ldi r16, INIT_DRONE_X
    mov DroneX, r16
    ldi r16, INIT_DRONE_Y
    mov DroneY, r16
    ldi r16, INIT_DRONE_Z
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
    M_LCD_SET_CURSOR_TO_SECOND_LINE_START

    rcall print_opening_line
    rcall read_accident_location
    
    rcall flash_three_times

    ; Start game, enable timer interrupt

    ; Timer 0 CTC A interrupt set up and initialization

	ldi r16, (1<<WGM01)
	out TCCR0A, r16                 ; Set Timer0 to CTC mode
	ldi r16, (1<<CS02) | (1<<CS00)  ; Set the prescaler to 1024, now the new clock frequency is 16MHz/1024 = 15.625kHz
	out TCCR0B, r16
    ; one tick now is 1/15.625kHz = 64us
    ; To get 16 ms, we need to have 16ms/64us = 250 ticks
    ldi r16, 250                    
    out OCR0A, r16                  ; Poll keypad every 16ms, instead of 1ms to reduce CPU stress

	ldi r16, (1<<OCIE0A)
	sts TIMSK0, r16           	    ; Enable Timer0 Compare A interrupt


    ; Timer1 CTC A set up and initialization
    
    ; Set Timer 1 (16 bits) to CTC mode
    ; Set the prescaler to 256, now the new clock frequency is 16MHz/256 = 62.5kHz
    ; and each tick is 1/62.5kHz = 16us
    ldi r16, (0<<WGM11) | (0<<WGM10)
    sts TCCR1A, r16
    ldi r16, (0<<WGM13) | (1<<WGM12) | (1<<CS12)
    sts TCCR1B, r16

    ; To get 500ms, we need to have 500/16us = 31250 ticks
    ; Load OCR1AH and OCR1AL with 31250
    ldi r16, high(31250<<1)
    sts OCR1AH, r16
    ldi r16, low(31250<<1)
    sts OCR1AL, r16

    ; Clear the timer counter
    clr r16
    sts TCNT1H, r16
    sts TCNT1L, r16
    
    ldi r16, 1<<OCIE1A
	sts TIMSK1, r16             ; Enable Timer 1 CTC Output Compare A interrupt


    ; INT0 and INT1 interrupt set up and initialization
    ldi r16, (2<<ISC00) | (2<<ISC10) ; Falling edge triggered interrupt
    sts EICRA, r16              ; Configure INT0 and INT1 as falling edge triggered interrupt
    in r16, EIMSK
    ori r16, (1<<INT0) | (1<<INT1)
    out EIMSK, r16              ; Enable INT0 interrupt

    sei

    jmp main_loop


; --------------------------------------------------------------------------------------------------------------- ;
; ----------------------------------- Timer0 Compare A Interrupt Handler ---------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; TODO: Do deboucing for keyboard also, need around 400ms delay between each key press
TIMER_0_COMPA_VECT:
    push r16
    in r16, SREG
    push r16

    rcall scan_key_pad
    ldi r16, 0
    cp r0, r16
    breq no_drone_command           ; User hasn't inputted anything
    rcall process_drone_command
    rcall flash_three_times
no_drone_command:
    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ----------------------------------- Timer1 Compare A Interrupt Handler ---------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

TIMER_1_COMPA_VECT:
    push r16
    in r16, SREG
    push r16
    
    rcall step_drone

    pop r16
    out SREG, r16
    pop r16
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

    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Main Loop --------------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;


main_loop:
    rjmp main_loop


; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Subroutines ------------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; Print the "Acci Loc: " line at the start of the game
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
    cpi r17, 10         ; 10 characters to be printed
    brne print_opening_line_loop
    
    pop r16
    pop r17
    pop ZL
    pop ZH
    ret


; Read the accident location from the user input, at the start of the game, input is in the format of X*Y* where X and Y are any valid two digit number, decimal
; Leave the result at AccidentX and AccidentY
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
    ; I was told that when drone is in hover mode, it displays a speed,
    ; but it does not move anymore, not even up or down, which is good!
    rcall update_status_if_crashed      
    
    ; If drone has crashed during this step, even if it has found the accident,
    ; it does not live to tell the story :(, so no need to check if it has found the accident location
    mov r16, FlightState
    cpi r16, 'C'
    breq end_step_drone

    rcall update_status_if_found        
    rjmp end_step_drone
is_flying:
    rcall update_status_if_crashed

    ; If drone has crashed during this step, then we dont need to check if it has found the accident location
    mov r16, FlightState
    cpi r16, 'C'
    breq end_step_drone

    ; Otherwise we proceed to check if the drone has found the accident location
    rcall update_status_if_found

    ; If drone has found the accident location during this step, then we dont need to update its position
    mov r16, FlightState
    cpi r16, 'R'
    breq end_step_drone

    rcall update_drone_position

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
; For now logic is very simple, only when the drone is above the accident location can the drone see it
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
    rcall flash_three_times ; Spec says we need to flash LED when accident is found
end_check_found:
    pop r16
    ret

; Change the FlightState register to 'C' if the drone has crashed
; Otherwise this function has no effect
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


; Move drone forward by one step in the current direction
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
    rjmp update_drone_z  
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

; Print the current path of the drone on the LCD, first line
; current path is determined by the current direction of the drone
; if drone is flying E-W, then print the current row
; if drone is flying N-S, then print the current column
print_curr_path:
    push r16

    M_LCD_SET_CURSOR_TO_FIRST_LINE_START
    
    ldi r16, 'R'
    cp FlightState,r16
    breq clear_path         ; no path printed if returning
    ldi r16, 'C'
    cp FlightState,r16
    breq clear_path         ; no path printed if crashed
    ldi r16, 'N'
    cp Direction, r16
    breq north_south
    ldi r16, 'S'
    cp Direction, r16
    breq north_south
    ldi r16, 'E'
    cp Direction, r16
    breq east_west
    ldi r16, 'W'
    cp Direction, r16
    breq east_west
    rjmp end_print_curr_path
east_west:
    rcall print_curr_row
    M_LCD_SET_CURSOR_OFFSET DroneX      ; Move cursor to the current X
    rcall sleep_200ms                   ; Sleep 200ms to make sure cursor can be seen on LCD
    rjmp end_print_curr_path
north_south:
    rcall print_curr_col
    M_LCD_SET_CURSOR_OFFSET DroneY      ; Move cursor to the current Y
    rcall sleep_200ms                   ; Sleep 200ms to make sure cursor can be seen on LCD
    rjmp end_print_curr_path
clear_path:
    M_CLEAR_LCD
end_print_curr_path:
    pop r16
    ret

; Print the status bar on the LCD, second line
; Status bar is in the format of:
; FlightState (DroneX,DroneY,DroneZ)Speed/Direction
; e.g. F (0,0,1)1/N
print_status_bar:
    push r16

    M_LCD_SET_CURSOR_TO_SECOND_LINE_START

print_flight_state:
    M_DO_LCD_DATA FlightState
print_drone_coords:
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
    ldi r16, 'R'
    cp FlightState,r16
    breq print_accident_height      ; show accident location rather than drone location on accident found 
    ldi r16, 'C'
    cp FlightState,r16
    breq print_crash_height
print_drone_height:
    mov r16, DroneZ
    rcall display_decimal
    ldi r16, ')'
    M_DO_LCD_DATA r16
print_speed_dir:
    mov r16, Spd
    rcall display_decimal
    ldi r16, '/'
    M_DO_LCD_DATA r16
    M_DO_LCD_DATA Direction
    rjmp finish_print_status_bar
print_accident_height:
    rcall get_tile_height
    mov r16,r0
    rcall display_decimal
    ldi r16, ')'
    M_DO_LCD_DATA r16
    rjmp finish_print_status_bar
print_crash_height:
    ldi r16, '-'
    M_DO_LCD_DATA r16
    M_DO_LCD_DATA r16
    ldi r16, ')'
    M_DO_LCD_DATA r16
finish_print_status_bar:
    pop r16
    ret

; Prints the E-W row that the drone is currently on
print_curr_row:
    push ZH
    push ZL
    push r16
    push r17
    push r18

    ldi r17, MAP_SIZE
    mul DroneY, r17             ; rol * MAP_SIZE gives the offset of the start of this rol in the map array, result is in r1:r0

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


; Prints the N-S column that the drone is currently on
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

    add ZL, DroneX                  ; add column offset to Z pointer, so Z is pointing to the correct column
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

.include "sleep_functions.asm"
.include "bcd.asm"
.include "lcd_functions.asm"
.include "keypad_functions.asm"
.include "led_bar_functions.asm"

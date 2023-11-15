.include "m2560def.inc"

; Macros added at top
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
.equ MAX_HEIGHT     =   99
.def DroneX         =   r4      ; Drone coordinates X: col     
.def DroneY         =   r5      ; Drone coordinates Y: row
.def DroneZ         =   r6      ; Drone coordinates Z: height
.def Direction      =   r7      ; N: North, S: South, E: East, W: West, U: Up, D: Down
.def Spd            =   r8
.def FlightState    =   r9      ; F: Flight, H: Hover, R: Return, C: Crash
.def AccidentX      =   r10     ; Accident coordinates
.def AccidentY      =   r11


.cseg

.org 0x0000
	jmp RESET                   ; Reset interrupt vector
.org INT0addr
    jmp EXT_INT0                ; INT0 interrupt vector
.org INT1addr
    jmp EXT_INT1                ; INT1 interrupt vector 
.org OC1Aaddr
    jmp TIMER_1_COMPA_VECT      ; Timer 1 for movement       
.org OC0Aaddr
	jmp TIMER_0_COMPA_VECT      ; Timer 0 for inputs   
.org OC3Aaddr                   
    jmp TIMER_3_COMPA_VECT      ; Timer 3 for speed up
.org OC4Aaddr                   
    jmp TIMER_4_COMPA_VECT      ; Timer 4 for speed down


;               0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
map:    .db     0,  0,  1,  2,  3,  4,  5,  6,  7,  6,  5,  4,  3,  2,  1,  0   ; ROW 0
        .db     0,  1,  2,  2,  2,  3,  4,  5,  6,  5,  4,  3,  2,  2,  2,  1   ; ROW 1
        .db     1,  1,  2,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  0   ; ROW 2
        .db     2,  1,  2,  6,  5,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  0   ; ROW 3
        .db     3,  5,  6,  7,  6,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  0   ; ROW 4
        .db     4,  6,  7,  8,  7,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  0   ; ROW 5
        .db     5,  7,  7,  7,  7,  6,  6,  6,  6,  7,  6,  6,  6,  6,  7,  0   ; ROW 6
        .db     5,  4,  5,  6,  7,  8,  7,  6,  7,  6,  5,  4,  3,  2,  1,  0   ; ROW 7
        .db     5,  5,  6,  6,  7,  7,  7,  2,  3,  4,  3,  4,  3,  2,  1,  0   ; ROW 8
        .db     5,  6,  7,  8,  8,  9,  8,  8,  4,  3,  2,  1,  2,  2,  3,  0   ; ROW 9
        .db     5,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  0   ; ROW 10
        .db     5,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  7,  6,  6,  1   ; ROW 11
        .db     5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  6,  7,  6,  5,  2   ; ROW 12
        .db     5,  4,  4,  4,  4,  4,  4,  4,  4,  3,  2,  2,  2,  2,  2,  3   ; ROW 13
        .db     5,  3,  3,  3,  3,  3,  3,  3,  3,  3,  2,  1,  1,  1,  2,  2   ; ROW 14
        .db     5,  1,  2,  2,  2,  2,  2,  2,  2,  2,  2,  1,  0,  1,  1,  1   ; ROW 15

opening_line:   .db     "Acci loc: "
invalid_accident_loc_line:      .db     "Invalid loc"

RESET:
	ldi r16, low(RAMEND)        ; Set stack pointer to RAMEND
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

    ser r16                     ; Set up LED bar to be output pins
    out DDRC, r16

    clr AccidentX
    clr AccidentY
    
    ldi r16, INIT_DRONE_X       ; Initialise all drone values 
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
    rcall set_accident

    ; Start game, enable timer interrupt
    ; ------Timer 0 (8-bits) CTC A interrupt set up and initialization---------------------------------------------

	ldi r16, (1<<WGM01)
	out TCCR0A, r16                 ; Set Timer0 to CTC mode in control register A
	ldi r16, (1<<CS02) | (1<<CS00)  ; Set the prescaler to 1024 in control register B
	out TCCR0B, r16                 ; Now the new clock frequency is 16MHz/1024 = 15.625kHz
    ; one tick now is 1/15.625kHz = 64us
    ; To get 16 ms, we need to have 16ms/64us = 250 ticks
    ldi r16, 250                    
    out OCR0A, r16                  ; Poll keypad every 16ms, instead of 1ms to reduce CPU stress

	ldi r16, (1<<OCIE0A)
	sts TIMSK0, r16           	    ; Enable Timer0 Compare A interrupt in mask register


    ; ------Timer1 (16-bits) CTC A set up and initialization--------------------------------------------------------
    
    ldi r16, (0<<WGM11) | (0<<WGM10)                ; Set Timer 1 to CTC mode in control register A
    sts TCCR1A, r16
    ldi r16, (0<<WGM13) | (1<<WGM12) | (1<<CS12)    ; Set the prescaler to 256 in control register B
    sts TCCR1B, r16                                 ; Now the new clock frequency is 16MHz/256 = 62.5kHz
    ; one tick is 1/62.5kHz = 16us
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
	sts TIMSK1, r16             ; Enable Timer 1 CTC Output Compare A interrupt in mask register

    ;
    ; ------ Timer3 (16-bits) CTC A set up and initialization -----------------------------------------------------------------
    ; Set Timer 3 to CTC mode (OCR3A is used for comparison)
    ldi r16, (0<<WGM31) | (0<<WGM30)                ; Configure Timer 3 for CTC mode in control register A
    sts TCCR3A, r16
    ldi r16, (0<<WGM33) | (1<<WGM32) | (1<<CS32)    ; Set the prescaler to 256 in control register B
    sts TCCR3B, r16

    ; Load OCR3AH and OCR3AL with 18750 for 300ms delay
    ldi r16, high(18750)                            ; High byte of 18750
    sts OCR3AH, r16
    ldi r16, low(18750)                             ; Low byte of 18750
    sts OCR3AL, r16

    ; Clear the timer counter
    clr r16
    sts TCNT3H, r16
    sts TCNT3L, r16

    ; Enable Timer 3 CTC interrupt
    ldi r16, 1<<OCIE3A
    sts TIMSK3, r16  


    ;
    ; ------ Timer4 (16-bits) CTC A set up and initialization -----------------------------------------------------------------
    ; Set Timer 4 to CTC mode (OCR3A is used for comparison)
    ldi r16, (0<<WGM41) | (0<<WGM40)                ; Configure Timer 4 for CTC mode in control register A
    sts TCCR4A, r16
    ldi r16, (0<<WGM43) | (1<<WGM42) | (1<<CS42)    ; Set the prescaler to 256 in control register B
    sts TCCR4B, r16

    ; Load OCR4AH and OCR4AL with 18750 for 300ms delay
    ldi r16, high(18750)                            ; High byte of 18750
    sts OCR4AH, r16
    ldi r16, low(18750)                             ; Low byte of 18750
    sts OCR4AL, r16

    ; Clear the timer counter
    clr r16
    sts TCNT4H, r16
    sts TCNT4L, r16

    ; Enable Timer 4 CTC interrupt
    ldi r16, 1<<OCIE4A
    sts TIMSK4, r16 


    ; ------ INT0 (speed down) and INT1 (speed up) interrupt set up and initialization------------------------------
    ldi r16, (2<<ISC00) | (2<<ISC10)    ; Falling edge triggered interrupt
    sts EICRA, r16                      ; Configure INT0 and INT1 as falling edge triggered interrupt
    in r16, EIMSK
    ori r16, (1<<INT0) | (1<<INT1)
    out EIMSK, r16                      ; Enable INT0 interrupt

    sei

    jmp main_loop


; --------------------------------------------------------------------------------------------------------------- ;
; ----------------------------------- Timer0 Compare A Interrupt Handler ---------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; On every interrupt, Timer 0 listens for user input on keypad and processes input if detected
; TODO: Do deboucing for keyboard also, need around 400ms delay between each key press
TIMER_0_COMPA_VECT:
    push r16
    in r16, SREG
    push r16

    rcall scan_key_pad              ; Listen for user input on keypad
    ldi r16, 0                      ; If user hasn't inputted anything, keypad outputs 0 and nothing happens
    cp r0, r16
    breq no_drone_command           
    rcall process_drone_command     ; If input detected, process input
    rcall flash_three_times         ; and flash LED to signify input received 
no_drone_command:
    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ----------------------------------- Timer1 Compare A Interrupt Handler ---------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; On every interrupt, Timer 1 moves the drone 
TIMER_1_COMPA_VECT:
    push r16
    in r16, SREG
    push r16
    
    ; Load the 'speed' and excute the movement function
    ; 'speed' amount of times to mimic the speed of the drone
    clr r16                 ; r16 is temp counter variable starting from 0 and incrementing until same value as spd 
start_drone_step:
    rcall step_drone        ; Drone movement function
    inc r16
    cp r16, Spd
    brne start_drone_step
    
    ; Refresh LCD once all movement is complete           
    rcall print_curr_path
    rcall print_status_bar

    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ----------------------------------- Timer3 Compare A Interrupt Handler ---------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;
;
TIMER_3_COMPA_VECT:
    push r16
    in r16, SREG
    push r16
    
    mov r16, Spd
    cpi r16, MAX_SPEED      ; do not increase speed if it is max already
    breq end_speed_up
    inc r16
    mov Spd, r16

end_speed_up:
    lds r16, TCCR3B
    andi r16, (0<<CS32)     ; Stop the timer (disable Clock Source)
    sts TCCR3B, r16      

    clr r16
    sts TCNT3H, r16
    sts TCNT3L, r16         ; Clear remaining value in the timer counter
 
    in r16, EIMSK
    ori r16, (1<<INT0)      ; Re-enable INT0 interrupt
    out EIMSK, r16

	pop r16
	out SREG, r16
	pop r16                    
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ----------------------------------- Timer4 Compare A Interrupt Handler ---------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;
;
TIMER_4_COMPA_VECT:
    push r16
    in r16, SREG
    push r16

    mov r16, Spd
    cpi r16, MIN_SPEED      ; do not increase speed if it is max already
    breq end_speed_down
    dec r16
    mov Spd, r16

end_speed_down:
    lds r16, TCCR3B
    andi r16, (0<<CS42)     ; Stop the timer (disable Clock Source)
    sts TCCR4B, r16      

    clr r16
    sts TCNT4H, r16
    sts TCNT4L, r16         ; Clear remaining value in the timer counter

    in r16, EIMSK
    ori r16, (1<<INT1)      ; Re-enable INT0 interrupt
    out EIMSK, r16

	pop r16
	out SREG, r16
	pop r16                    
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- INT0 Handler ------------------------------------------ ;
; --------------------------------------------------------------------------------------------------------------- ;

; Speed up button
EXT_INT0:
    push r16
    in r16, SREG
    push r16

    in r16, EIMSK
    ori r16, (0<<INT0)      ; Disable INT0 interrupt
    out EIMSK, r16              

    lds r16, TCCR3B
    ori r16, (1<<CS32)     ; Start the timer
    sts TCCR3B, r16 

    pop r16
    out SREG, r16
    pop r16
    reti

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- INT1 Handler ------------------------------------------ ;
; --------------------------------------------------------------------------------------------------------------- ;

; Speed down button
EXT_INT1:
    push r16
    in r16, SREG
    push r16

    in r16, EIMSK
    ori r16, (0<<INT1)      ; Disable INT0 interrupt
    out EIMSK, r16              

    lds r16, TCCR4B
    ori r16, (1<<CS42)     ; Start the timer
    sts TCCR4B, r16 

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


set_accident: 
    push r17
set_accident_start:
    M_CLEAR_LCD
    M_LCD_SET_CURSOR_TO_SECOND_LINE_START   ; Set cursor to second line to display "Acci loc" prompt
    rcall print_opening_line                ; Print acci loc prompt
    rcall read_accident_location            ; Take user input for accident location
    rcall flash_three_times
check_valid_accident:                       ; If either coordinate is greater than 16, invalid location 
    ldi r17, 17
    cp AccidentX, r17
    brsh invalid_accident_loc
    cp AccidentY, r17
    brsh invalid_accident_loc
    rjmp valid_accident_loc
invalid_accident_loc:                       ; If invalid location, print invalid location line and loop back to start 
    M_CLEAR_LCD
    M_LCD_SET_CURSOR_TO_SECOND_LINE_START
    rcall print_invalid_line
    rcall sleep_200ms
    rcall sleep_200ms
    rcall sleep_200ms
    rcall sleep_200ms
    rjmp set_accident_start
valid_accident_loc:
    pop r17
    ret

; Print the "Acci Loc: " line at the start of the game
print_opening_line:
        push ZH
        push ZL
        push r17
        push r16

        ldi ZH, high(opening_line<<1)
        ldi ZL, low(opening_line<<1)

        clr r17
    ; Loop to print "acci loc:" character by character 
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

; Print the "Invalid loc " line if accident location invalid
print_invalid_line:
        push ZH
        push ZL
        push r17
        push r16

        ldi ZH, high(invalid_accident_loc_line<<1)
        ldi ZL, low(invalid_accident_loc_line<<1)

        clr r17
    ; Loop to print "Invalid loc" character by character 
    print_invalid_line_loop:
        lpm r16, Z+
        M_DO_LCD_DATA r16
        inc r17
        cpi r17, 11         ; 11 characters to be printed
        brne print_invalid_line_loop
        
        pop r16
        pop r17
        pop ZL
        pop ZH
        ret

; Read the accident location from the user input, at the start of the game, input is in the format of X*Y* where X and Y are any valid two digit number, decimal
; Leave the result at AccidentX and AccidentY
read_accident_location:
    push r18
    clr AccidentX
    clr AccidentY
; Read X (col) coord input and adds to AccidentX register until * detected
get_x_coordinate:
    rcall scan_key_pad
    mov r18, r0
    cpi r18, 0
    breq get_x_coordinate
    rcall sleep_200ms
    rcall sleep_200ms

    cpi r18, '*'
    breq X_asterisk
    cpi r18, '0'
    brlo get_x_coordinate
    cpi r18, ':'
    brsh get_x_coordinate
    M_DO_LCD_DATA r18
    M_MULT_TEN AccidentX
    subi r18, '0'
    add AccidentX, r18
    out PORTC, AccidentX
    rjmp get_x_coordinate
; Read Y (row) coord input and adds to AccidentX register until * detected
X_asterisk:
    M_DO_LCD_DATA r18
get_y_coordinate:
    rcall scan_key_pad
    mov r18, r0
    cpi r18, 0
    breq get_y_coordinate
    rcall sleep_200ms
    rcall sleep_200ms

    cpi r18, '*'
    breq Y_asterisk
    cpi r18, '0'
    brlo get_y_coordinate
    cpi r18, ':'
    brsh get_y_coordinate
    M_DO_LCD_DATA r18
    M_MULT_TEN AccidentY
    subi r18, '0'
    add AccidentY, r18
    out PORTC, AccidentY
    rjmp get_y_coordinate
Y_asterisk:
    M_DO_LCD_DATA r18
end_set_up_accident_location:
    pop r18
    ret


; Process the drone command input by the user, which has already been left on r0 register
process_drone_command:
        push r16
        push r17
        mov r16, r0
        cpi r16, '2'    ; 2: North
        breq north
        cpi r16, '4'    ; 4: West
        breq west
        cpi r16, '6'    ; 6: East
        breq east
        cpi r16, '8'    ; 8: South
        breq south
        cpi r16, '0'    ; 0: Down
        breq down
        cpi r16, '5'    ; 5: Up
        breq up
        cpi r16, 'A'    ; A: Toggle Between Flight and Hover
        breq toggle_flight_state
        ; Otherwise, this command is unknown and should be ignored
        rjmp end_process_drone_command
    ; Checks current flight state and changes to opposite 
    toggle_flight_state:
        mov r16, FlightState
        cpi r16, 'F'
        breq flying
        cpi r16, 'H'
        breq hovering
        rjmp end_process_drone_command
    ; If flying state detected, change to hover
    flying:
        ldi r16, 'H'
        rjmp update_flight_state
    ; If hovering state detected, change to flying
    hovering:
        ldi r16, 'F'
        rjmp update_flight_state
    ; Update flight state register
    update_flight_state:
        mov FlightState, r16
        rjmp end_process_drone_command
    ; For directions, load corresponding direction to temp register
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
    ; Update direction register accordingly. 
    ; Drone can only change direction in hover state so only update if hover state detected
    update_direction:
        mov r17, FlightState
        cpi r17, 'H'
        brne end_process_drone_command 
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
        ; Check current drone state
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
    ; If crashed, skip movement step
    has_crashed:
        rjmp end_step_drone
    ; If returning, skip movement step
    is_returning:
        rjmp end_step_drone
    is_hovering:
        ; I was told that when drone is in hover mode, it displays a speed,
        ; but it does not move anymore, not even up or down, which is good!
        rcall update_status_if_crashed      ; Check if drone crashed
        mov r16, FlightState                ; If drone crashed, skip accident checking and skip to end
        cpi r16, 'C'
        breq end_step_drone

        rcall update_status_if_found        ; If not crashed, check if accident found
        rjmp end_step_drone                 ; End movement
    is_flying:
        rcall update_status_if_crashed      ; Check if drone crashed
        mov r16, FlightState                ; If drone crashed, skip accident checking and skip to end
        cpi r16, 'C'
        breq end_step_drone

        rcall update_status_if_found        ; If not crashed, check if accident found

        ; If drone has found the accident location during this step, then we dont need to update its position
        mov r16, FlightState
        cpi r16, 'R'
        breq end_step_drone

        rcall update_drone_position         ; Update drone position on DroneX, DroneY, DroneZ registers

        rjmp end_step_drone

    end_step_drone:
        ; At the end of the step function a new Frame (screen) should be drawn
        ; on LCD, therefore the LCD has a display refresh rate of 1 / 500ms = 2Hz (Sort of :P)
        ; M_CLEAR_LCD
        ; rcall lcd_wait_busy
        pop r16
        ret

; Change the FlightState register to 'R' if the drone has 'seen'
; the accident location, given the visibilty (1)
; Drone detects the accident if it is on the same (X,Y) coordinates and within visibility for height
update_status_if_found:
    push r16

    ; Check DroneX = AccidentX
    cp DroneX, AccidentX
    brne end_check_found
    ; Check DroneY = AccidentY
    cp DroneY, AccidentY
    brne end_check_found
    ; Check Z within visibility
    rcall get_tile_height   ; Retrieve current tile height
    mov r16, r0
    subi r16, -VISIBILITY   ; Add visibility value to current tile height 
    cp r16, DroneZ
    brge found  ; terran height + visibility >= drone height (given drone didnt crash)
    rjmp end_check_found
; If accident found, update drone state 
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
    ; Check if drone is outside X coord boundary
    mov r16, DroneX
    cpi r16, 0
    brlt crashed
    cpi r16, MAP_SIZE
    brge crashed
    ; Check if drone is outside Y coord boundary
    mov r16, DroneY
    cpi r16, 0
    brlt crashed
    cpi r16, MAP_SIZE
    brge crashed
    ; Check if current tile height is more than drone height
    ; or if drone is flying heigher than max height 
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
        push r18    ; Store next tile's height

        ; Update drone position according to direction
        mov r16, Direction
        cpi r16, 'N'
        breq north_update
        cpi r16, 'S'
        breq south_update
        cpi r16, 'E'
        breq east_update
        cpi r16, 'W'
        breq west_update
        cpi r16, 'U'          
        breq up_update
        cpi r16, 'D'
        breq down_update

        rjmp end_update_drone_position

    ; Increments/deccrements corresponding drone position register
    north_update:
        dec DroneY
        rjmp update_drone_z
    south_update:
        inc DroneY
        rjmp update_drone_z
    east_update:
        inc DroneX
        rjmp update_drone_z
    west_update:
        dec DroneX
        rjmp update_drone_z  
    up_update:
        inc DroneZ
        rjmp end_update_drone_position
    down_update:
        dec DroneZ
        rjmp end_update_drone_position
    ; For automatic change in height with change in terrain elevation
    update_drone_z:
        rcall get_tile_height           ; Retrieve current tile height 
        mov r18, r0


        cp r18, DroneZ                      ; If drone height same as tile height, dont do anything
        breq end_update_drone_position
        cp r18, DroneZ                      ; If drone height greater than tile height, drop height by 1
        brlt fly_lower
        cp DroneZ, r18                      ; If drone height less than tile height, increase height by 1 
        brlt fly_higher                     ; (if still less, update_status_if_crashed will handle)

        rjmp end_update_drone_position

    ; Increment height
    fly_higher:
        inc DroneZ
        rjmp end_update_drone_position
    ; Decrement height
    fly_lower:
        dec DroneZ
        rjmp end_update_drone_position       ; for consistency

    end_update_drone_position:
        
        pop r18
        pop r16
        ret

; Print the current path of the drone on the LCD, first line
; current path is determined by the current direction of the drone
; if drone is flying E-W, then print the current row
; if drone is flying N-S, then print the current column
print_curr_path:
        push r16

        M_LCD_SET_CURSOR_TO_FIRST_LINE_START    ; Set cursor to start of first line
        
        ; no path printed if returning
        ldi r16, 'R'            
        cp FlightState,r16
        breq clear_path         
        ; no path printed if crashed
        ldi r16, 'C'
        cp FlightState,r16
        breq clear_path      
        ; For N or S, display a col   
        ldi r16, 'N'
        cp Direction, r16
        breq north_south
        ldi r16, 'S'
        cp Direction, r16
        breq north_south
        ; For E or W, display a row 
        ldi r16, 'E'
        cp Direction, r16
        breq east_west
        ldi r16, 'W'
        cp Direction, r16
        breq east_west
        rjmp end_print_curr_path
    east_west:
        rcall print_curr_row                ; Function to print current row on first line of LCD
        M_LCD_SET_CURSOR_OFFSET DroneX      ; Move cursor to the current X
        rcall sleep_200ms                   ; Sleep 200ms to make sure cursor can be seen on LCD
        rjmp end_print_curr_path
    north_south:
        rcall print_curr_col                ; Function to print current col on first line of LCD
        M_LCD_SET_CURSOR_OFFSET DroneY      ; Move cursor to the current Y
        rcall sleep_200ms                   ; Sleep 200ms to make sure cursor can be seen on LCD
        rjmp end_print_curr_path
    ; On crash or return state, clear the first line of the LCD
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

        M_LCD_SET_CURSOR_TO_SECOND_LINE_START   ; Set cursor to start of second line 

    ; Print drone state
    print_flight_state:
        M_DO_LCD_DATA FlightState   
    ; Print X and Y coords            
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
        ldi r16, 'R'                    ; After printing X and Y coords, check if return or crash state
        cp FlightState,r16
        breq print_accident_height      ; Show accident location rather than drone location on accident found 
        ldi r16, 'C'
        cp FlightState,r16
        breq print_crash_height         ; Show '--' rather than drone height on crash
    ; Print drone height if hover or flight state 
    print_drone_height:
        mov r16, DroneZ
        rcall display_decimal
        ldi r16, ')'
        M_DO_LCD_DATA r16
    ; Print drone speed and direction if hover or flight state
    print_speed_dir:
        mov r16, Spd
        rcall display_decimal
        ldi r16, '/'
        M_DO_LCD_DATA r16
        M_DO_LCD_DATA Direction
        rjmp finish_print_status_bar
    ; Print height of current tile instead of drone height on accident found
    print_accident_height:
        rcall get_tile_height
        mov r16,r0
        rcall display_decimal
        ldi r16, ')'
        M_DO_LCD_DATA r16
        rjmp finish_print_status_bar
    ; Print -- for the height coord on crash 
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

        ldi r17, MAP_SIZE           ; MAP_SIZE = 16
        mul DroneY, r17             ; rol * MAP_SIZE gives the offset of the start of this rol in the map array, result is in r1:r0

        ldi ZH, high(map<<1)
        ldi ZL, low(map<<1)

        clr r18
        add ZL, r0                  ; ajust Z pointer to point at the first element of the current row
        adc ZH, r1                  ; only data in r0 is important, and r1 is zero, becuase map size is 16 and 16 * 16 = 256, which is just enought to fill up r0, also CURR_ROL < 16

    ; Keep printing next value in the row 16 times
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

        ldi r17, MAP_SIZE               ; MAP_SIZE = 16
        clr r19                         ; temp register just to hold a zero
        clr r18                         ; number of iterations

        add ZL, DroneX                  ; add column offset to Z pointer, so Z is pointing to the correct column
        adc ZH, r18

    ; Keep printing the same index in each consecutive row 16 times
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
    mul DroneY, r18     ; Find start of the row first
    add r0, DroneX      ; Then add on col number
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

; Functions added at bottom
.include "sleep_functions.asm"
.include "bcd.asm"
.include "lcd_functions.asm"
.include "keypad_functions.asm"
.include "led_bar_functions.asm"

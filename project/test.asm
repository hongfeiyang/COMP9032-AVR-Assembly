

.include "m2560def.inc"

.cseg
.org 0x0000
    jmp RESET
.org INT0addr
    jmp EXT_INT0
.org INT1addr
    reti
.org OC1Aaddr               ; <--- This is Output Compare Match A, **NOT** overflow
    jmp TIMER1_COMPA_VECT

RESET:

    clr r20
    ser r16
    out DDRC, r16               ; Set all PORTC pins as output
    out PORTC, r16              

    ; Timer1 CTC set up and initialization
    
    ; Set Timer 1 (16 bits) to CTC mode
    ; Set the prescaler to 256, now the new clock frequency is 16MHz/256 = 62.5kHz
    ; and each tick is 1/62.5kHz = 16us
    ldi r16, (0<<WGM11) | (0<<WGM10)
    sts TCCR1A, r16
    ldi r16, (0<<WGM13) | (1<<WGM12) | (1<<CS12)
    sts TCCR1B, r16

    ; To get 500ms, we need to have 500/16us = 31250 ticks
    ; Load OCR1AH and OCR1AL with 31250
    ldi r16, high(31250)
    sts OCR1AH, r16
    ldi r16, low(31250)
    sts OCR1AL, r16

    ; Clear the timer counter
    clr r16
    sts TCNT1H, r16
    sts TCNT1L, r16
    
    ldi r16, 1<<OCIE1A
	sts TIMSK1, r16             ; Enable Timer 1 CTC Channel A interrupt

    ; INT0 and INT1 interrupt set up and initialization
    ldi r16, (2<<ISC00) | (2<<ISC10) ; Falling edge triggered interrupt
    sts EICRA, r16              ; Configure INT0 and INT1 as falling edge triggered interrupt
    in r16, EIMSK
    ori r16, (1<<INT0) | (1<<INT1)
    out EIMSK, r16              ; Enable INT0 interrupt

    sei

    jmp main

TIMER1_COMPA_VECT:
    push r16
    in r16, SREG
    push r16

    inc r20
    out PORTC, r20

    lds r16, TCCR1B
    andi r16, (0<<CS12)     ; Stop the timer (disable Clock Source)
    sts TCCR1B, r16      

    clr r16
    sts TCNT1H, r16
    sts TCNT1L, r16         ; Clear remaining value in the timer counter

    in r16, EIMSK
    ori r16, (1<<INT0)      ; Re-enable INT0 interrupt
    out EIMSK, r16  

	pop r16
	out SREG, r16
	pop r16                    
    reti

EXT_INT0:
    push r16
    in r16, SREG
    push r16

    ; inc r20
    ; out PORTC, r20

    ; ldi r16, 1<<OCIE1A
	; sts TIMSK1, r16

    in r16, EIMSK
    ori r16, (0<<INT0)      ; Disable INT0 interrupt
    out EIMSK, r16              

    lds r16, TCCR1B
    ori r16, (1<<CS12)     ; Start the timer
    sts TCCR1B, r16    

    pop r16
    out SREG, r16
    pop r16
    reti


main:
    rjmp main

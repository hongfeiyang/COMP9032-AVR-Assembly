;
; lab03.asm
;
; Created: 19 / 10 / 2023 2:17:18 AM
; Author : Hongfei
;

.include "m2560def.inc"


ldi r16, 0xFF
rcall convert_to_hex_and_display
rjmp end

; Function Name: convert_to_hex_and_display
; Symposis:
; 	Converts an 8 - bit signed binary number located in the r16 register to its ASCII hexadecimal representation and displays it on an LCD.
; 	The displayed output will be in the format of either a two - character hexadecimal or - 0xXX for negative numbers.

; Inputs:
; 	r16: Contains the 8 - bit signed binary number that you want to convert.
; Outputs:
; 	LCD Display: The LCD will display the ASCII hexadecimal representation of the input number. Negative numbers will be prefixed with - 0x.
; Registers Used:
; 	r16: Holds the input number and is used as a temporary register during the conversion process.
; 	r17: Acts as a counter to keep track of the number of hex digits that have been converted.
; 	YL and YH: Serve as the frame pointer for local stack operations.
convert_to_hex_and_display:
	
	push YL
	push YH
	push r16
	push r17
	in YL, SPL
	in YH, SPH
	sbiw Y, 6
	out SPH, YH
	out SPL, YL
	
	; assume binary is in R16
	
	; check sign
	ldi r17, 0                   ; r17 stores how many hex digit we have converted
	sbrs r16, 7                  ; check MSB for negative number
	rjmp display_0x
neg_number:
	neg r16                      ; convert to positive to print
	
	std Y + 1, r16               ; store r16 now so later we can load it again at the start of another loop
	
	;TODO: print minus symbol to LCD

display_0x:
	; TODO: print 0x on LCD
	
	ldi r16, '0'
	; TODO: print r16 on LCD
	ldi r16, 'x'
	; TODO: print r16 on LCD
	ldd r16, Y + 1               ; restore r16 to the original number we first stored to do hex conversion
	
convert_to_ascii_loop:
	swap r16                     ; Convert the highest 4 bit first, swap them to the lower 4 bit for convinence
	andi r16, 0b00001111         ; Keep the 4 bit we are interested in only
	cpi r16, 10                  ; if this digit is larger than 10, we need to represent it with a letter
	brlt convert_to_ascii_number
	subi r16, - ('A' - 10)       ; convert r16 to a ASCII letter, first minus R16 by 10 to get how much it exceeds 10, then displace it by the ASCII value of 'A'
	rjmp display_to_lcd
convert_to_ascii_number:
	subi r16, - ('0')            ; convert r16 to a ASCII number, displace it by the ASCII value of '0'
display_to_lcd:
	; TODO: print r16 on LCD
	inc r17                      ; we now have converted one digit, we then prepare the lower 4 bit for conversion
	ldd r16, Y + 1               ; restore r16
	swap r16                     ; swap now so that the lower 4 bit will be correctly placed at the lower 4 bit later when convert_to_ascii_loop is jumped to again
	cpi r17, 2
	brne convert_to_ascii_loop
	
	
	adiw Y, 6
	out SPH, YH
	out SPL, YL
	pop r17
	pop r16
	pop YH
	pop YL
	ret
	
	
end:
	rjmp end

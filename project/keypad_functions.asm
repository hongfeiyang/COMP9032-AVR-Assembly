

; Symposis:
;   Wait for a key to be pressed on the keypad.
;   If a key is pressed, the function terminates and left the ASCII value of the key pressed on the r0 register.
; Registers changed by the function:
;   r0
wait_for_key_input:
        push r15
        push r16
        push cmask
        push rmask
        push col
        push row        

	key_start:
		ldi cmask, INITCOLMASK		; initial column mask
		clr	col						; initial column
	colloop:
		cpi col, 4
		breq key_start
		sts	PORTL, cmask			; set column to mask value (one column off)
		ldi r16, 0xFF               
	delay:                          ; delay 512 cycles, on a 16Mhz board this is 32ms
		dec r16
		brne delay

		lds	r16, PINL				; read PORTL
		andi r16, ROWMASK
		cpi r16, 0xF				; check if any rows are on
		breq nextcol
                                    ; if yes, find which row is on
		ldi rmask, INITROWMASK		; initialise row check
		clr	row						; initial row
	rowloop:
		cpi row, 4
		breq nextcol
		mov r15, r16
		and r15, rmask			    ; check masked bit
		breq convert 				; if bit is clear, convert the bitcode
		inc row						; else move to the next row
		lsl rmask					; shift the mask to the next bit
		jmp rowloop

	nextcol:
		lsl cmask					; else get new mask by shifting and 
		inc col						; increment column value
		jmp colloop					; and check the next column

	convert:
		cpi col, 3					; if column is 3 we have a letter
		breq letters				
		cpi row, 3					; if row is 3 we have a symbol or 0
		breq symbols

		mov r16, row				; otherwise we have a number in 1-9
		lsl r16
		add r16, row				; r16 = row * 3
		add r16, col				; add the column address to get the value
		subi r16, -'1'			    ; add the value of character '0'
		jmp convert_end

	letters:
		ldi r16, 'A'
		add r16, row				; increment the character 'A' by the row value
		jmp convert_end

	symbols:
		cpi col, 0					; check if we have a star
		breq star
		cpi col, 1					; or if we have zero
		breq zero					
		ldi r16, '#'				; if not we have hash
		jmp convert_end
	star:
		ldi r16, '*'				; set to star
		jmp convert_end
	zero:
		ldi r16, '0'				; set to zero
	convert_end:

        mov r0, r16                 ; left result on the r0 register

        pop row
        pop col
        pop rmask
        pop cmask
        pop r16
        pop r15
        ret

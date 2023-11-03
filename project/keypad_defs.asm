.equ PORTLDIR       =   0xF0			; use PortL for input/output from keypad: PL7-4, output, PL3-0, input
.equ INITCOLMASK    =   0xEF		    ; scan from the leftmost column, the value to mask output
.equ INITROWMASK    =   0x01		    ; scan from the bottom row
.equ ROWMASK        =   0x0F			; low four bits are output from the keypad. This value mask the high 4 bits.
.def row            =   r17		        ; current row number
.def col            =   r18             ; current column number
.def rmask          =   r19		        ; mask for current row
.def cmask          =   r20		        ; mask for current column

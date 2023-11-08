
.equ LCD_RS         =   7       ;   Register Select
                                ;   0: Instruction register (Write)
                                ;   :   Busy flag (DB7); Address counter (Read)
                                ;   1: Data register (Write, Read)
.equ LCD_E          =   6       ;   Enable - Operation start signal for data read/write
.equ LCD_RW         =   5       ;   Signal to select Read or Write
                                ;   0: Write
                                ;   1: Read
.equ LCD_BF         =   7       ;   Busy Flag (DB7)

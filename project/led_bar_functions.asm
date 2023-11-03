flash_three_times:
    push r16

	ser r16
	out PORTC,r16
	rcall sleep_50ms
	clr r16
	out PORTC,r16
	rcall sleep_50ms
	ser r16
	out PORTC,r16
	rcall sleep_50ms
	clr r16
	out PORTC,r16
	rcall sleep_50ms
	ser r16
	out PORTC,r16
	rcall sleep_50ms
	clr r16
	out PORTC,r16
    
	pop r16
	ret


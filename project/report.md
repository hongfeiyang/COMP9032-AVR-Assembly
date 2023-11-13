# Instructions (to remove)

The report is about six pages long in font size 11. It should provide:

- (5 marks) the general description about the project development,
  management, and the contribution of each group member, (5 marks)
- (20 marks) the overview of the project design, which includes:
  - hardware components used and related interfacing design (5 marks)
  - software code structure and execution flow (5 marks), and
  - how software and hardware interact with each other (10 marks).
- (5 marks) concluding remarks about the project

# Project development

## Overview

Our group was tasked with developing a simulation system for the Atmel
ATmega2560 microprocessor board, emulating the control of a drone to
search an accident scene in a mountainous area.

This project had many complexities including: handling the hardware and
related interfacing; designing software to interact with the hardware;
and working collaboratively across different locations, different
operating systems, and with a limited number of microprocessors.

The timeline of our project was as follows:

- Week 7 Wed (25/10): Used lab time to discuss the assignment
  specification with lab tutors
- Week 7 Fri (27/10): Had a group call with the team to brainstorm
  assignment approach
- Week 8 (30/10 - 05/11): Work on assigned tasks
- Week 9 (06/11 - 12/11): Work on assigned tasks
- Week 9 Thu (09/11): Group call to align on completed work and
  communicate how code works
- Week 9 Fri (10/11): Commence writing report

Communication strategy:

- Used weekly labs to confirm scope and specifications
- Communication with lab tutors to ensure that our team was following
  the right path forward
- Communication with team members over discord to ensure that work was
  being completed correctly, on time, and without any double-ups

Collaboration strategy:

- Git version control (branching, PRs, PR reviews)
- Separated tasks into functions/macros such that each member could work
  on tasks without conflict/double ups

Difficulties:

- Team was split between macOS and Windows
  - Split between visual studio code and atmel microchip studio
  - Knowledge share on how to develop in MacOS
- Two boards shared amongst the team
  - Two of the more technical members kept the boards so that they could
    test their code in real time
  - Used lab time to demonstrate board functioning

Additional tools:

- Makefiles to reduce friction for uploading code to boards

## Contributions

Hongfei

- Git setup
- Software expert

Luke

- Project management
- Hardware expert

Tina

- Code reviewer
- Software and hardware support

Alan

- Communication
- Report

# Project design

## Hardware components and interfacing design

AVR ATmega2560 Microprocessor.

| Hardware Component | Direction | AVR Port (Pins)  |
| ------------------ | --------- | ---------------- |
| Keypad             | Input     | Port L (PL0-PL7) |
| PB0 button         | Input     | Port D (RDX3)    |
| PB1 button         | Input     | Port D (RDX4)    |
| RESET button       | Input     | N/A              |
| LCD                | Output    | Port F (PF0-PF7) |
| LED                | Output    | Port C (PC0-PC7) |

Insert picture?

## Software code structure and execution flow

General design choices:

- Code modularised into multiple files that are loaded in the `main.asm`
  file
  - Separate files for definition of macros, functions, and variables
  - Split by I/O device
- Macros capitalised, prefixed with `M_`, and written in snake case
  as per convention

File structure:

- `bcd.asm`:
  - Defines the `display_decimal` function which uses the double dabble
    algorithm to convert a binary number to decimal and displays it on
    the LCD
- `keypad_defs.asm`:
  - Defines variables and values required for operating the keypad
- `keypad_functions.asm`:
  - Defines the `scan_key_pad` function which scans the keypad for input
    and saves the result to a data register
- `keypad_macros.asm`:
  - Defines the `M_KEYPAD_INIT` macro for setting up the keypad to
    receive input
- `lcd_defs.asm`:
  - Defines variables and values required for operating the LCD
- `lcd_functions.asm`:
  - Defines the `lcd_command` function which accepts commands to be sent
    to the LCD
  - Defines the `lcd_data` function which accepts data to be displayed
    on the LCD
  - Defines a number of delay functions to ensure the LCD operates
    properly
- `lcd_macros.asm`:
  - Defines the `M_DO_LCD_COMMAND` macro which uses the `lcd_command`
    function to send a command to the LCD
  - Defines the `M_DO_LCD_DATA` macro which uses the `lcd_data` function
    to display data on the LCD
  - Defines the `M_CLEAR_LCD` macro which clears the LCD
  - Defines the `M_LCD_INIT` macro which initialises the LCD
- `led_bar_functions.asm`
  - Defines the `flash_three_times` function which causes the lights on
    the LED bar to flash three times successively
- `main.asm`
  - Uses all of the aforementioned files to execute the main body of
    code to satisfy the assessment criteria

Interrupts:

- `RESET`
  - Triggered by RESET button
  - Reset all pins and I/O devices and re-initialise starting values
    (e.g. drone position)
- `EXT_INT0`
  - Triggered by P0 button
  - Decreases drone speed
- `EXT_INT1`
  - Triggered by P1 button
  - Increases drone speed
- `Timer0OVF`
  - Constantly triggered
  - Moves the game forward by "one step" by checking if any key has been
    pressed and responding accordingly (e.g. change direction, flight
    status)

## Software and hardware interaction

# Concluding remarks

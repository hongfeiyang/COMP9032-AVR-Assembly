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

## Project timeline

The timeline of our project was as follows:

- (25/10): Discussed the assignment specification and confirmed scope
  with lab tutors
- (27/10): Had a group call with the team to brainstorm assignment
  approach and ideas
- (30/10 - 12/11): Developed code
  - (31/10): Added LCD helper functions and code to display map rows and
    columns, drone attributes (speed, state, position)
  - (03/11): Added timer interrupt for drone movement
  - (03/11): Performed major code refactoring to split codebase across
    multiple files
  - (05/11): Added push button interrupts, speed handling, and crash
    detection
  - (06/11): Added visibility and accident detection, and hover logic
  - (08/11): Performed bug fixes and edge case handling
- (09/11): Had a group call to align on completed work and communicate
  how the code works
- (10/11): Commenced writing report

## Communication strategy

A major challenge of group projects, especially software development
projects, is communication. Our group maintained clear communication
by:

- Using early weekly labs to confirm specifications and scope with lab
  tutors
- Using weekly labs to check in with lab tutors to ensure that our work
  remained aligned with the project goal
- Using Discord messaging to communicate with group members to ensure
  that work was being completed correctly and on time, and to provide a
  platform for group members to collaborate with each other (e.g. ask for
  help/advice)
- Using Discord calls to check in with group member work progress, and
  have knowledge share sessions to ensure that all group members
  understand the entire code
- Using Git version control (branching, PRs, PR reviews) to facilitate
  software development collaboration
- Separating project tasks into functions and macros such that each
  member can work on tasks without conflicts or double ups

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

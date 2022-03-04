$NOLIST
$MODLP51
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
New_TIMER0_RELOAD  EQU ((65536-(CLK/TIMER0_RATE-2000)))
DEBOUNCE_DELAY     EQU 50




org 0000H
   ljmp MyProgram

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

BUTTON_BOOT   equ P4.5      ;start the game
BUTTON_1      equ P1.1     ;selecting player 
BUTTON_2      equ P2.0      ;move ^ 
BUTTON_3      equ P0.0      ;RANDOM 
BUTTON_4      equ P0.4
SOUND_OUT     equ P2.4


BSEG
mf: dbit 1
HLbit: dbit 1

$NOLIST
$include(LCD_4bit.inc)
$include(math32.inc) ; A library of LCD related functions and utility macros
$LIST

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Timer2_overflow: ds 1 ; 8-bit overflow to measure the frequency of fast signals (over 65535Hz)
player1_score: ds 2
player2_score: ds 2
cursor_pos   : ds 3
mode         : ds 3
current_frequency: ds 8
p1_capacitance:  ds 8
p2_capacitance:  ds 8
number        :  ds 3
high_low      :  ds 8
x:   ds 4
y:   ds 4
bcd: ds 5
T2ov: ds 2 ; 16-bit timer 2 overflow (to measure the period of very slow signals)
Seed: ds 4
tone1:ds 2


cseg
;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db '   GAME TIMR!   ', 0
player_numbers:   db '        2   3   ', 0
number1:          db '        ^       ', 0
number2:          db '            ^   ', 0
game_mode1:       db 'P1:       P2:   ', 0
game_mode1_2_1:   db 'Fighting!       ', 0
game_mode1_2_2:   db 'play3:0         ', 0
game_mode2:       db 'winner:         ', 0
player1_win:      db 'Winner: player1 ', 0
player2_win:      db 'Winner: player2 ', 0
; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)


;Pseudo random number generator
Random: 
	;Seed=214013*Seed+2531011
	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(214013)
	lcall mul32
	Load_y(2531011)
	lcall add32
	mov Seed+0, x+0
	mov Seed+1, x+1
	mov Seed+2, x+2
	mov Seed+3, x+3
	ret
	
Wait_Random:

	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret

Initial_Seed:
	setb TR2 ;Enable Timer2	
	mov Seed+0,TH2
	mov Seed+1,#0x01
	mov Seed+2,#0x87
	mov Seed+3,TL2
	;clr TF2?
	clr TR2
	ret 
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
    
      clr TR0
	clr ET0
	
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)	
	mov current_frequency,#low(TIMER0_RELOAD)
	
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
    lcall Timer0_ISR

	

New_Timer0_Init:

	clr TR0
	clr ET0
	
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(New_TIMER0_RELOAD)
	mov TL0, #low(New_TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(New_TIMER0_RELOAD)
	mov RL0, #low(New_TIMER0_RELOAD)
	mov current_frequency,#low(New_TIMER0_RELOAD)
	
	; Enable the timer and interrupts
      setb ET0  ; Enable timer 0 interrupt
      setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti


Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
    ret

;Initializes timer/counter 2 as a 16-bit counter
InitTimer2:
	mov T2CON, #0b_0000_0010 ; Stop timer/counter.  Set as counter (clock input is pin T2).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
    setb P1.0 ; P1.0 is connected to T2.  Make sure it can be used as input.
    setb ET2
    ret

;timer1 not used here
;InitTimer1:
;	mov T2CON, #0b_0000_0010 ; Stop timer/counter.  Set as counter (clock input is pin T2).
;   Set the reload value on overflow to zero (just in case is not zero)
;	mov TH1, #0
;	mov TH2, #0
;   setb P1.1 ; P1.1 is connected to T2.  Make sure it can be used as input.
;   setb ET1
;   ret


Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	inc Timer2_overflow
	reti


; Dumps the 8-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 8th digit:
    mov a, R3
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 6th digit:
    mov a, R3
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 6th digit:
    mov a, R2
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    ;lcall InitTimer1
    lcall InitTimer2
    ;lcall Timer0_Init
    lcall LCD_4BIT ; Initialize LCD
    mov player1_score,#0x00
    mov player2_score,#0x00

    
    ;set mode
    mov mode,#0x00
    setb EA ; Enable interrrupts
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Timer0_ISR
    lcall Initialize_All
	lcall Initial_Seed
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)

loop:
;determine mode
;mode 0 waiting for game to start
;mode 1 game start selection
;mode 2 two people mode
;mode 3 three people mode

    mov  a,mode
    jz   mode0        ;a=0 go to mode0
    subb a,#0x01    ;a=a-1
    jnz  loop_notmode1
    ljmp mode1

loop_notmode1:   
   
    mov  a,mode
    subb a,#0x02
    jnz  loop_notmode2
    ljmp mode2      ;if mode==2
    
loop_notmode2:
    
    mov a,mode
    subb a,#0x03
    jnz loop_notmode3
    ljmp mode3      ;if mode==3

loop_notmode3:
    ;reset mode back to 0
    mov a,#0x00
    mov mode,a
    ljmp mode0_d

mode0:
    jb BUTTON_BOOT, mode0_a  ; if the 'BOOT' button is not pressed skip
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb     	BUTTON_BOOT, mode0_a
    jnb    	BUTTON_BOOT, $	
;wait for the to release The '$' means: jump to same instruction.
;goes into game mode1,shows the number of players choosing screen
    clr a
    mov cursor_pos,a
    ;setup screen
    Set_Cursor(1,1)
    Send_Constant_String(#game_mode1)
    Set_Cursor(2,1)
    Send_Constant_String(#game_mode1_2_1)
    ;change mode
    mov a,#0x02
    mov mode,a
    clr a
    ljmp mode0_d

mode0_a:
    
    ljmp loop
mode0_d:
    
    ljmp loop
;==[mode1]==  
mode1:


    
    ;choose the number of players to play
    ;SETB TR2
    jb      BUTTON_1,       mode1_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,       mode1_a
    jnb     BUTTON_1,       $
    ; valid button 1: game start
	clr a
    mov a,#0x02
    mov mode,a
    clr a
    ljmp mode1_d

mode1_a:
   

    jb      BUTTON_2,       mode1_c
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode1_c
    jnb     BUTTON_2,       $
    ; valid button 2: change position
    clr a
    mov a, #3
    mov number,a
    Set_Cursor(2, 1)
    Send_Constant_String(#number2)
    ljmp mode1_b

mode1_c:
	clr a
    mov a,#2 
    mov number, a
    Set_Cursor(2, 1)
    Send_Constant_String(#number1)
    mov a,#0x01
    mov mode,a
	ljmp mode1

mode1_b:

    jb      BUTTON_2,       mode1_e
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode1_e
    jnb     BUTTON_2,       $
    ; valid button 2: change position
    
    ljmp mode1_c

mode1_d:
    ljmp loop   
mode1_e:
    mov a,#0x01
    mov mode,a
	ljmp mode1_b    
    ; mov     a,  cursor_pos
   ; cjne    a,  #0x02,  mode1_a_inc
    ;mov     cursor_pos,  #0x00
    ;ljmp    mode1_d
    
;mode1_a_inc:
    ;inc     cursor_pos
    ;ljmp    mode1_d
    
    
    
;==[mode2]==
mode2:

    ;clr		c
    ;mov 	  a, number
    ;subb      a, #0x02
    ;jnz		loop_not2players	
    ; if number == 2
    ljmp	mode2_2


loop_not2players:
    clr c
    mov a, number
    subb a, #0x03
    jnz  loop_not3players
    ljmp    mode2_3


loop_not3players:
    mov a,#0x00
    mov  number,#0
    ljmp mode0_d  

    ;defualt 

;==[2 Players]==
mode2_2:
    lcall two_modeinitial
    lcall display_score
    lcall initial_Seed
 
    lcall forever
    lcall check1_5
    lcall check2_5
   
check1_5:
	clr a
	mov a, player1_score
	cjne a,#5, check2_5
	mov player1_score,a 
	ljmp player1_win
	
check2_5:
	clr a
	mov a, player2_score
	cjne a,#5, go_forever
	mov player2_score,a 
	ljmp player2_win

go_forever:
	ljmp forever	
	
two_modeinitial:
	Set_Cursor(1, 1)
    Send_Constant_String(#game_mode1)
    Set_Cursor(2, 1)
    Send_Constant_String(#game_mode1_2_1)
    
display_score:
	Set_Cursor(1,4)
	Display_BCD(player1_score)
	Set_Cursor(1,15)
	Display_BCD(player2_score)
	


mode2_low_tone:	
	lcall New_Timer0_Init	
	Wait_Milli_Seconds(#200)
	clr TR0
	lcall Random
	lcall Wait_Random
    mov tone1,#1
    clr TR0
	ljmp loop_c

	

;==[player1]==
forever:
 
    lcall Random 
    mov a,Seed+1;
    mov c,acc.3
    mov HLbit,c
    jB HLbit, mode2_low_tone

 ;wait random time to make speaker work
 ;lcall Wait_Random
 ;lcall NEW_Timer0_Init
 ;lcall Timer0_Init

loop_b:	
	;lcall Random    
	;load_x(Seed+0)
    ;load_y(8)
    ;lcall x_gteq_y
    ;mov a,mf
    ;clr TR0 
    

mode2_high_tone:
	lcall Timer0_Init	
	Wait_Milli_Seconds(#200)
	clr TR0
	lcall Random
	lcall Wait_Random
	
    mov tone1,#0
    
	ljmp loop_c
  
   
loop_c:   
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2
synch1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal ; If the count is larger than 0x01ffffffff*45ns=1.16s, we assume there is no signal
    jb P1.1, synch1
synch2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P1.1, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal 
    jb P1.1, measure1
measure2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P1.1, measure2
    clr TR2 ; Stop timer 2, [T2ov+1, T2ov+0, TH2, TL2] * 45.21123ns is the period

	sjmp skip_this
no_signal:	
	;Set_Cursor(2, 1)
    ;Send_Constant_String(#No_Signal_Str)
    ljmp forever ; Repeat! 
skip_this:

	; Make sure [T2ov+1, T2ov+2, TH2, TL2]!=0
	mov a, TL2
	orl a, TH2
	orl a, T2ov+0
	orl a, T2ov+1
	jz no_signal
	; Using integer math, convert the period to frequency:
	mov x+0, TL2
	mov x+1, TH2
	mov x+2, T2ov+0
	mov x+3, T2ov+1
	Load_y(45) ; One clock pulse is 1/22.1184MHz=45.21123ns
	lcall mul32

	; Convert the result to BCD and display on LCD
	; 1.44T = (RA+2Rb)*c
	Load_y(3)        ;/(RA+2RB)  pass down to have whole number
	lcall div32
	Load_y(693)   
	lcall div32
	Load_y(1000000)
	lcall mul32 

	;Set_Cursor(1, 7)
	;lcall hex2bcd
	;lcall Display_10_digit_BCD
	clr a
    mov p1_capacitance,x
    mov a,x
    clr TR2
    cjne a,#15,NOTEQUAL1
	
	
NOTEQUAL1:
    JC GREATER1
	ljmp forever1
GREATER1:
    ljmp player1_touch_folio

;==[player2]==
forever1:    
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2
synch3:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal1 ; If the count is larger than 0x01ffffffff*45ns=1.16s, we assume there is no signal
    jb P1.1, synch3
synch4:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal1
    jnb P1.0, synch4
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2 ; Start timer 2
measure3:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal1
    jb P1.0, measure3
measure4:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal1
    jnb P1.2, measure4
    clr TR2 ; Stop timer 2, [T2ov+1, T2ov+0, TH2, TL2] * 45.21123ns is the period

	sjmp skip_this1
no_signal1:	
	;Set_Cursor(2, 1)
    ;Send_Constant_String(#No_Signal_Str)
    ljmp forever1 ; Repeat! 
skip_this1:

	; Make sure [T2ov+1, T2ov+2, TH2, TL2]!=0
	mov a, TL2
	orl a, TH2
	orl a, T2ov+0
	orl a, T2ov+1
	jz no_signal1
	; Using integer math, convert the period to frequency:
	mov x+0, TL2
	mov x+1, TH2
	mov x+2, T2ov+0
	mov x+3, T2ov+1
	Load_y(45) ; One clock pulse is 1/22.1184MHz=45.21123ns
	lcall mul32

	; Convert the result to BCD and display on LCD
	; 1.44T = (RA+2Rb)*c
	Load_y(9)        ;/(RA+2RB)  pass down to have whole number
	lcall div32
	Load_y(693)   
	lcall div32
	Load_y(1000)
	lcall mul32 

	;Set_Cursor(2, 7)
	;lcall hex2bcd
    ;lcall Display_10_digit_BCD
    clr a
	mov p2_capacitance,x
	mov a,x
	clr TR2
	CJNE a,#15,NOTEQUAL2
	

	

jump_forever:
    ljmp forever
clr TR2

NOTEQUAL2:
    JC GREATER2
	ljmp forever
GREATER2:
    ljmp player2_touch_folio




player2_touch_folio:
    clr a
    
    load_x(current_frequency)
    load_y(100)
    lcall div32
    mov a,x
    
    cjne  a,#22, player2_lose_mark
    clr a
    mov a, player2_score
    add a,#1
    mov player2_score,a
    clr a
	ljmp check2_5
	
player1_touch_folio:
    clr a
    
    load_x(current_frequency)
    load_y(100)
    lcall div32
    mov a,x
    
    cjne  a,#22, player1_lose_mark
    clr a
    mov a, player1_score
    add a,#1
    mov player1_score,a
    clr a
	ljmp check1_5

player1_lose_mark:
    clr a
    mov a, player1_score
    subb a,#0x01 
	mov player1_score,a
	clr a
	ljmp forever1
	
player2_lose_mark:
    clr a
    mov a, player2_score
    subb a,#0x01 
    mov player2_score,a
	clr a
	ljmp forever

	
player1_winn:
	Set_Cursor(1,1)
	Send_Constant_String(#player1_win)
	ljmp MyProgram

player2_winn:
      Set_Cursor(1,1)
	Send_Constant_String(#player2_win)
	ljmp MyProgram


;==[3 Players]==
	mode2_3:
    ljmp loop



    ; Measure the frequency applied to pin T2
    ;clr TR2 ; Stop counter 2
    ;clr a
    ;mov TL2, a
    ;mov TH2, a
    ;mov Timer2_overflow, a
    ;clr TF2
    ;setb TR2 ; Start counter 2
    ;lcall Wait1s ; Wait one second
    ;clr TR2 ; Stop counter 2, TH2-TL2 has the frequency
mode3:
	mov mode,#0
	ljmp loop



	
;update the score
;display
end
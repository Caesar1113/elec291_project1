$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram

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

BUTTON_BOOT   equ P4.5
BUTTON_1      equ         ;move ^
BUTTON_2      equ         ;selecting player 
BUTTON_3      equ


$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Timer2_overflow: ds 1 ; 8-bit overflow to measure the frequency of fast signals (over 65535Hz)
player1_socre: ds 1
player2_socre: ds 1
cursor_pos   : ds 1
mode         : ds 1


cseg
;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db '   Game time!  ', 0
player_numbers:   db '     2   3     ', 0
number1:          db '     ^         ', 0
number2:          db '         ^     ', 0
game_mode1:       db 'play1: ,play2: ', 0
game_mode1_2_1:   db 'fighting!      ', 0
game_mode1_2_2:   db 'play3:         ', 0
game_mode2:       db 'winner:        ', 0
; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)




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

InitTimer1:
	mov T2CON, #0b_0000_0010 ; Stop timer/counter.  Set as counter (clock input is pin T2).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov TH1, #0
	mov TH2, #0
    setb P1.1 ; P1.1 is connected to T2.  Make sure it can be used as input.
    setb ET1
    ret


Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	inc Timer2_overflow
	reti

;Converts the hex number in Timer2_overflow-TH2-TL2 to BCD in R3-R2-R1-R0
hex2bcd:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #0
    mov R4, #24 ;Loop counter.

hex2bcd_loop:
    mov a, TL2 ;Shift TH0-TL0 left through carry
    rlc a
    mov TL2, a
    
    mov a, TH2
    rlc a
    mov TH2, a

    mov a, Timer2_overflow
    rlc a
    mov Timer2_overflow, a
      
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	mov a, R3
	addc a, R3
	da a
	mov R3, a
	
	djnz R4, hex2bcd_loop
	ret

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
    lcall InitTimer1
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
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
    lcall Initialize_All

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)

forever:
;determine mode
;mode 0 waiting for game to start
;mode 1 game start
;mode 2 two people mode
;mode 3 three people mode

    clr  c
    mov  a,mode
    jz   mode0        ;a=0 go to mode0
    subb a,#0x01    ;a=a-1
    jnz  loop_notmode1
    ljmp mode1

loop_mode1:   
    clr  c
    mov  a,mode
    subb a,#0x02
    jnz  loop_notmode2
    ljmp mode2      ;if mode==2
    
loop_notmode2:
    clr c
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
   ;如果boot被按了，那么会进入mode1，如果不被按就会走mode0_a
    clr a
    mov cursor_pos,a
    ;setup screen
    Set_Cursor(1,1)
    Send_Constant_String(#player_numbers)
    Set_Cursor(2,1)
    Send_Constant_String(#number1)
    ;change mode
    mov a,#0x01
    mov mode,a
    ljmp mode0_d

mode0_a:
    ;mode0_a要做什么，什么都不做，跳回去判断处在什么mode
    ljmp forever
mode0_d:
    ；同mode0_a
    ljmp forever
mode1:

    ;一旦进入了mode1，说明游戏开始了，要开始选择游戏人数
    ;choose the number of players to play
    ;SETB TR2
    jb      BUTTON_1,       mode1_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,       mode1_a
    jnb     BUTTON_1,       $
    ; valid button 1: game start！
    ；按钮1可以正式进入游戏
    ；如果没有按下按钮1，那么就会继续等待，在等待过程中去选择玩家人数
    ；（进入游戏）
    mov a,#0x02
    mov mode,a
    ljmp mode1_d

mode1_a:
    ;选择人数
    jb      BUTTON_2,       mode1_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode1_b
    jnb     BUTTON_2,       $
    ; valid button 2: change position
    mov     a,  cursor_pos
    cjne    a,  #0x02,  mode1_a_inc
    mov     cursor_pos,  #0x00
    ljmp    mode1_d

mode1_d:
    ljmp forever

mode1_a:
    jb      BUTTON_2,       mode1_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode1_b
    jnb     BUTTON_2,       $
    ; valid button 2: change position
    mov     a,  cursor_pos
    cjne    a,  #0x02,  mode1_a_inc
    mov     cursor_pos,  #0x00
    ljmp    mode1_d
    
mode1_a_inc:
    inc     cursor_pos
    ljmp    mode1_d

mode1_b:




    jb   BUTTON_1, mode1_3
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,   mode1_3
    jnb    BUTTON_1,   $
    
    


    ;button 2 pressed so we go to mode1_2_1    two players mode
    jnb    TR0, mode1_2
    clr    TR0
    sjmp  mode0_d

mode1_3:

    Set_Cursor(2,1)
    Send_Constant_String(#number2)

    jb   BUTTON_1, mode0_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,   mode0_b
    jnb    BUTTON_1,   $

    jb   BUTTON_2, mode1_3
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,   mode1_3
    jnb    BUTTON_2,   $


mode1_2_1:

mode0_a:
    SETB TR2
    jb   BUTTON_1, mode0_b




    ; Measure the frequency applied to pin T2
    clr TR2 ; Stop counter 2
    clr a
    mov TL2, a
    mov TH2, a
    mov Timer2_overflow, a
    clr TF2
    setb TR2 ; Start counter 2
    lcall Wait1s ; Wait one second
    clr TR2 ; Stop counter 2, TH2-TL2 has the frequency
	

mode2:    
	cjne TR2,#200000,NOTEQUAL
; equal code goes here, then branch out
    NOTEQUAL:
    JC GREATER
; less than code goes here, then branch out
    ljmp mode2
    GREATER:
    ; greater code goes here
    sjmp player2_touch_folio
//.........................................................player1

    cjne TR1,#200000,NOTEQUAL
; equal code goes here, then branch out
    NOTEQUAL:
    JC GREATER
; less than code goes here, then branch out
    ljmp mode2
    GREATER:
    ; greater code goes here
    sjmp player1_touch_folio

player2_touch_folio:
    clr a
    mov a, player2_socre
    
    cjne #2200, #sound_frequency, player2_lose_mark
    add player2_socre,#1

player1_touch_folio:
    clr a
    mov a, player2_socre
    
    cjne #2200, #sound_frequency, player2_lose_mark
    add player2_socre,#1

player2_lose_mark:
    clr a
    mov a, player2_socre
    add player2_socre,#0x59

player2_lose_mark:
    clr a
    mov a, player1_socre
    add player1_socre,#0x59


end

$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram
   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
T2ov: ds 2 ; 16-bit timer 2 overflow (to measure the period of very slow signals)

BSEG
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

BUTTON equ P4.5

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message1:  db 'freq1:', 0
Initial_Message2:  db 'freq2:', 0
No_Signal_Str:    db 'No signal      ', 0

; Sends 10-digit BCD number in bcd to the LCD

WaitHalfSec: 
    mov R2, #40 
a3: mov R1, #250 
a2: mov R0, #166 
a1: djnz R0, a1 ; 3 cycles->3*45.21123ns*166=22.51519us 
    djnz R1, a2 ; 22.51519us*250=5.629ms 
    djnz R2, a3 ; 5.629ms*89=0.5s (approximately) 
    ret 

Display_10_digit_BCD:
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_char(#'.')
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret

Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	push acc
	inc T2ov+0
	mov a, T2ov+0
	jnz Timer2_ISR_done
	inc T2ov+1
Timer2_ISR_done:
	pop acc
	reti

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
    setb EA
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    setb P1.1 ; Pin is used as input
	setb P1.0; Pin is used as input
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message1)
   	Set_Cursor(2, 1)
    Send_Constant_String(#Initial_Message2)
forever:
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
	Set_Cursor(2, 1)
    Send_Constant_String(#No_Signal_Str)
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
	Load_y(1000)
	lcall mul32 

	Set_Cursor(1, 7)
	lcall hex2bcd
	lcall Display_10_digit_BCD

clr TR2


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
	Set_Cursor(2, 1)
    Send_Constant_String(#No_Signal_Str)
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

	Set_Cursor(2, 7)
	lcall hex2bcd
	lcall Display_10_digit_BCD

lcall WaitHalfSec
	

jump_forever:
    ljmp forever
    ljmp forever1 ; Repeat! 
clr TR2
end

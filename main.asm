#include <P16F877.INC>
;******************************************************************
; En este programa se varia el duty cycle del PWM en funcion del dato que entra del puerto serie
;*******************************************************************

BIN		EQU	0x24
BCDH	EQU	0x25
BCDM	EQU	0x26
BCDL	EQU	0x27
ENTER	EQU 0x28
reg1	EQU	0x29
reg2	EQU	0X30




 	ORG 0X0000
	goto inicio

	ORG 0x0004
	goto isr		; salto a la rutina de atencion a la interrupcion
	
	ORG 0x0005
inicio
 	call 	inicializacion	; llamamos a la subrutina de inicializacion
 	;goto 	$			; quedamos a la espera de una interrupcion sin realizar ninguna acción
loop
 	bsf		ADCON0,GO	; empieza la conversion
esp_conversion
 	btfsc	ADCON0,GO	; espero que termine la conversion
 	goto	esp_conversion
 	movf	ADRESH,w
 	movwf	BIN
 	call	convert_dato
 	call	env_dato
 	;call 	delay
 	goto 	loop
 
 
inicializacion


 	; INICIALIZACION DE PUERTO SERIE
 	bsf		STATUS,RP0
 	bcf		TRISC,6
 	bsf		TRISC,7
 	movlw	b'10100110'	; 8-bit transm., transmision habilitada, high speed
 	movwf	TXSTA
 	movlw	d'25'		
 	movwf	SPBRG	; 9600 baudios en high speed con 4MHz
 	bcf		STATUS,RP0
 	movlw	b'10010000'	; sp enable 8-bit recep, continues receive.
 	movwf	RCSTA
 
 	
 	;INICIALIZACION DE ADC
 	bsf		STATUS,RP0
	; porque carajo usa el trisc, no sera el trisa?
 	clrf	TRISA
 	comf	TRISA
	bcf		TRISC,6  ;anda sin esto; no se porque...
 	movlw	0x00
 	movwf	ADCON1
 	bcf		STATUS,RP0
 	movlw	0x41
 	movwf	ADCON0
	
 	
 	
 	;INICIALIZACION DE INTERRUPCIONES
 	bsf		STATUS, RP0
 	bsf		PIE1, RCIE	; habilito int de recepcion, la int de transmision no hace falta ya que tomamos accion solo al recibir un dato.
 	bcf		STATUS, RP0
 	bsf		INTCON, PEIE	; habilito int de perifericos
 	bsf		INTCON, GIE		; habilito int global	
 	return

 	
 	
isr
 	bcf		INTCON,GIE
 	btfss	PIR1,RCIF	; si fue una interrupcion de recepcion  saltamos la sig instruccion
 	goto	fin_isr
 	bcf		PIR1,RCIF	; si se recibio un dato limpio la bandera de la int

	goto    fin_isr

fin_isr
 	bsf		INTCON,GIE 	
 	retfie	
 
 
convert_dato
        clrf    BCDH
        clrf    BCDM
        clrf	BCDL
BCD_HIGH
        movlw   d'100'
        subwf   BIN,f
        btfss   STATUS,C	; si esta seteado no hubo BORROW
        goto    SUMA_100	; si hubo BORROW entonces el numero que quedaba era menor a 100
        incf    BCDH,f
        goto    BCD_HIGH
SUMA_100
        movlw   d'100'
        addwf   BIN,f
		goto 	BCD_LOW 

BCD_LOW 
		movlw   d'10'
        subwf   BIN,f
        btfss   STATUS,C   ; si esta seteado no hubo BORROW
        goto    SUMA_10
        incf    BCDM
        goto    BCD_LOW

SUMA_10 
		movlw   d'10'
        addwf   BIN,f
        movf    BIN,w
        movwf	BCDL
        return 
 
env_dato
		movlw	d'8'
		call	transmitir
		call	transmitir
		call	transmitir
		movlw	BCDH
		movwf	FSR
continuar 
 		movf	INDF,w
 		addlw	0x30
 		call	transmitir
 		incf	FSR,f
		btfss	FSR,3
		goto	continuar	
		return

transmitir
		movwf	TXREG
esp_envio
 		btfss	PIR1, TXIF
 		goto 	esp_envio
 		bcf		PIR1, TXIF
 		return
 		
 		
delay
	clrf	reg1
	clrf	reg2
cont_delay	
	incfsz	reg1
	goto 	cont_delay
	incfsz	reg2
	goto	cont_delay
	return	
 	end
 	
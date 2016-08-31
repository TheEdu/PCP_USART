;edu tp pcp-usart (KAIZEN)
#include <P16F877.INC>

contTA  EQU 0X23 ; contador de tiempo de adquisicion para empezar a recibir datos del ADC
BIN 	EQU 0X24 ; resultado de la conversion del ADC (convertion result)
BCDH	EQU	0x25
BCDM	EQU	0x26
BCDL	EQU	0x27
reg1	EQU	0x28
reg2	EQU	0X29

ORG 0X0000
goto inicio
ORG 0x0004
call isr

ORG 0x0005
inicio
 	call init
	call main


;PROGRAMA PRINCIPAL
main
	NOP
	CLRWDT ; por las dudas :D
	
	;BANKSEL PIR1
	;WaitRX
	;	btfss PIR1,RCIF
	;goto WaitRX


;Fin main
goto main

TABLA
		addwf	PCL, 1
		retlw	d'63'  ;0
		retlw	d'6'   ;1
		retlw	d'91'  ;2
		retlw	d'79'  ;3
		retlw	d'102' ;4
		retlw	d'109' ;5
		retlw	d'125' ;6
		retlw	d'7'   ;7
		retlw	d'127' ;8
		retlw	d'103' ;9

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
	goto BCD_HIGH
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
;FIN convert_dato
return

 		
delay
	clrf reg1
	clrf reg2
	cont_delay	
		incfsz reg1
		goto cont_delay
		incfsz reg2
		goto cont_delay
return	 

isr
	;Pagina 00 (BANK 0)
	bcf STATUS,RP0
	bcf STATUS,RP1

	bcf	INTCON,GIE
	btfsc PIR1,RCIF
	goto recibiAlgo ; si RCIF esta en 1
	btfsc PIR1,TXIF
	goto transmitiAlgo ; si TXIF esta en 1
	goto fin_isr

recibiAlgo
	
	BANKSEL RCREG
	movf RCREG,W
	BANKSEL BIN
	movwf BIN
	call convert_dato; genero BCDL, BCDM y BCDH
	BCF PORTD,RD0
	MOVFW BCDL 
	call TABLA
	MOVWF PORTB
	BSF PORTD,RD0
	call delay;delay
	BCF PORTD,RD1
	MOVFW BCDM 
	call TABLA
	MOVWF PORTB
	BSF PORTD,RD1
	call delay;delay
	BCF PORTD,RD2
	MOVFW BCDH 
	call TABLA
	MOVWF PORTB
	BSF PORTD,RD2
	call delay;delay
	BCF PORTD,RD3
	MOVLW 0x00 
	call TABLA
	MOVWF PORTB
	BSF PORTD,RD3
 	call delay;delay
	bcf PIR1,RCIF
	goto fin_isr

transmitiAlgo
	bcf PIR1,TXIF
	goto fin_isr

fin_isr
 	bsf		INTCON,GIE 	
 	retfie		
	


init

;INICIALIZACION PUERTO DISPLAY
	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
	CLRF PORTB ; PORTB Numero que voy a mostrar en el Display
	; PORTC Muestra el Display si su bit correspondiente esta en 0,
 	; ej: RD0 = 0 --> Display0 muestra un numero
	CLRF PORTD
	COMF PORTD
	;Pagina 01 (BANK 1)
 	bsf	STATUS,RP0
 	bcf	STATUS,RP1
	clrf TRISB
	clrf TRISD	
		
;FIN INICIALIZACION PUERTO DISPLAY 

;INICIALIZACION PUERTO SERIE (USART)

	;Pagina 01 (BANK 1)
 	bsf	STATUS,RP0
 	bcf	STATUS,RP1
	;TX y RX
	bcf	TRISC,6 ;TX como salida  (OUTPUT)
 	bsf	TRISC,7 ;RX como entrada (INPUT)
	;The rate at which data is transmitted or received must be always be set using the
	;baud rate generator unless the USART is being used in synchronous slave mode.
	;Configuro la velocidad de transmision/recepcion (baudios = bit/segundo (?))
	movlw	d'25'
 	movwf	SPBRG	; 9600 baudios en high speed con 4MHz
	;Configuro el TXSTA
    clrf TXSTA
	bsf TXSTA,TRMT  ;TRMT: Transmit Shift Register Status bit, 1 = TSR empty
	bsf TXSTA,BRGH  ;High speed
	bsf TXSTA,TXEN  ;Transmision habilitada
	
	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
	;Configuro el RCSTA
	clrf RCSTA
	bsf RCSTA,SPEN ; Serial Port Enable
	bsf RCSTA,CREN ; Continuous receive enable

;FIN INICIALIZACION PUERTO SERIE (USART)


; INICIALIZACION DE INTERRUPCIONES

	;Pagina 01 (BANK 1)
 	bsf	STATUS,RP0
 	bcf	STATUS,RP1
	;Habilito int de recepcion, la int de transmision no hace falta ya que tomamos accion solo al recibir un dato. 
 	bsf	PIE1,RCIE 	;Habilito int de recepcion
	;bsf PIE1,TXIE	;Habilito int de transmision (preguntar)
 
	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
 	bsf	INTCON, PEIE	; habilito int de perifericos
 	bsf	INTCON, GIE		; habilito int global	

; FIN INICIALIZACION DE INTERRUPCIONES

;FIN INIT
return
end
	

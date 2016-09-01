;edu tp pcp-usart (KAIZEN)
#include <P16F877.INC>

dato 	EQU	0x22
BIN		EQU	0x24
BCDH	EQU	0x25
BCDM	EQU	0x26
BCDL	EQU	0x27
ENTER	EQU 0x28
reg1	EQU	0x29
reg2	EQU	0X30
reg3	EQU 0x31

ORG 0X0000
goto inicio
ORG 0x0004
goto isr

ORG 0x0005
inicio
 	call init
;PROGRAMA PRINCIPAL
main
	NOP
	CLRWDT ; por las dudas :D
;Fin main
goto main


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

 		

isr
	bcf	INTCON,GIE
	BTFSC INTCON,T0IF ;SALTA SI NO ES LA INTERRUPCION DEL TIMER
	GOTO INTERRUPCION_TIMER
	btfsc PIR1,RCIF
	goto recibiAlgo ; si RCIF esta en 1
	goto fin_isr

INTERRUPCION_TIMER
	;REESTABLECER TIMER (PARA QUE VUELVA A INTERRUMPIR DESPUES DE 2 MSEG)
	BCF INTCON,T0IF ;PONGO EN 0 EL BIT T0IF (DEL TMR0)
	MOVLW 0X86 ;LE PASO EL VALOR 134 (DECIMAL) AL TMR0 
	MOVWF TMR0 ;PARA QUE EMPIECE A CONTAR EL TMR0 DESDE ESE VALOR.

	BSF STATUS,C
	RLF PORTD
	BTFSC PORTD, 3	;SALTA UNA INSTRUCCION SI EL BIT 6 DE PORTC ES 0, OSEA QUE TIENE QUE VOLVER A PONER EN 0 EL BIT 0 PARA MOSTRAR SEGUNODS_UNIDAD
	GOTO DISPLAY1
	MOVLW b'11111110'
	MOVWF PORTD 

	DISPLAY1 ;REFRESCA EL VALOR DE DISPLAY1 (EL BCDL) (SI LO TIENE QUE HACER)
		BTFSC PORTD,0 ;SALTA SI TIENE QUE MOSTRAR BCDL
		GOTO DISPLAY2
		MOVF BCDL,W
		CALL TABLA
		MOVWF PORTB
		GOTO fin_isr

	DISPLAY2 ;REFRESCA EL VALOR DE DISPLAY2 (EL BCDM) (SI LO TIENE QUE HACER)
		BTFSC PORTD,1 ;SALTA SI TIENE QUE MOSTRAR BCDM
		GOTO DISPLAY3
		MOVF BCDM,W
		CALL TABLA
		MOVWF PORTB
		GOTO fin_isr

	DISPLAY3 ;REFRESCA EL VALOR DE DISPLAY3 (EL BCDH) (SI LO TIENE QUE HACER)
		BTFSC PORTD,2 ;SALTA SI TIENE QUE MOSTRAR BCDH
		GOTO fin_isr
		MOVF BCDH,W
		CALL TABLA
		MOVWF PORTB
		GOTO fin_isr


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
	

recibiAlgo
	bcf PIR1,RCIF
	movf RCREG,W
	movwf BIN
	call convert_dato; genero BCDL, BCDM y BCDH
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
	;Configuro el TXSTA
    clrf TXSTA
	bsf TXSTA,TRMT  ;TRMT: Transmit Shift Register Status bit, 1 = TSR empty
	bsf TXSTA,BRGH  ;High speed
	bsf TXSTA,TXEN  ;Transmision habilitada
	;The rate at which data is transmitted or received must be always be set using the
	;baud rate generator unless the USART is being used in synchronous slave mode.
	;Configuro la velocidad de transmision/recepcion (baudios = bit/segundo (?))
	movlw	d'25'
 	movwf	SPBRG	; 9600 baudios en high speed con 4MHz
	
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
 

	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
	bsf INTCON,T0IE	;HABILITA EL TMR0
 	bsf	INTCON, PEIE	; habilito int de perifericos
 	bsf	INTCON, GIE		; habilito int global	

; FIN INICIALIZACION DE INTERRUPCIONES

;CONFIGURACION TIMER
BSF STATUS,RP0		;BANCO 1 
BCF OPTION_REG,T0CS ;USA EL OSCILADOR INTERNO (Fosc/4)
BCF OPTION_REG,PSA	;HABILITA EL PRESCALER

;VALOR DEL PRESCALER 001
BCF OPTION_REG,PS2 ;BIT 2 DEL PRESCALER EN 0
BCF OPTION_REG,PS1 ;BIT 1 DEL PRESCALER EN 0
BSF OPTION_REG,PS0 ;BIT 0 DEL PRESCALER EN 1


	
;INICIALIZACION DEL TMR0
BCF STATUS,RP0	;BANCO 0
BCF INTCON,T0IF ;PONGO EN 0 EL BIT T0IF (DEL TMR0)
MOVLW 0X86 ;LE PASO EL VALOR 134 (DECIMAL) AL TMR0 
MOVWF TMR0 ;PARA QUE EMPIECE A CONTAR DESDE ESE VALOR.	

	;INICIALIZACION DE VARIABLES
	clrf BCDH
	clrf BCDM
	clrf BCDL
	MOVLW b'11111101'
	MOVWF PORTD
 	return
;FIN INIT
return
end
	

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
goto isr

ORG 0x0005
inicio
 	call init
	call main


;PROGRAMA PRINCIPAL
main

	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
		
	;Esperando el Tiempo de Adquisicion para iniciar la conversion
	;20us delay loop with 4MHz oscillator frequency
	movlw 0x06
	movwf contTA ;initialize count
	loop
		decfsz contTA,F ;dec count, store in count
	goto loop ;not finished

	;Empezando la conversion
	bsf	ADCON0,GO ;GO/DONE: A/D Conversion Status bit, 1 = A/D conversion in progress
				  ;(Setting this bit starts the A/D conversion. This bit is automatically cleared
				  ;by hardware when the A/D conversion is complete), 0 = A/D conversion not in progress

	;Esperando a que el ADC termine la conversion del valor analogico preveniente del potenciometro
	WaitingConvertion
		btfsc ADCON0,GO ;conversion done?
	goto WaitingConvertion ;not finished

	;Once the analog-to-digital conversion has completed, the result can be read. The
	;result of the conversion is automatically placed in the ADRES register upon
	;completion.
	movf ADRESH,w
	movwf BIN ; Guardo el resultado de la conversion en BIN (para su posterior procesamiento)
	
	call convert_dato
 	call env_dato
 	call delay

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

env_dato
		movlw	d'8'
		call	transmitir
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
		movwf TXREG
	esp_envio
 		btfss PIR1, TXIF
 	goto esp_envio
 		bcf	PIR1, TXIF
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
 	bcf		INTCON,GIE
 	btfss	PIR1,RCIF	; si fue una interrupcion de recepcion  saltamos la sig instruccion
 	goto	fin_isr
 	bcf		PIR1,RCIF	; si se recibio un dato limpio la bandera de la int
	goto    fin_isr

fin_isr
 	bsf		INTCON,GIE 	
 	retfie	



init

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
	bsf TXSTA,CSRC  ;El manual dice que no importa (en modo asincronico) pero jose lo puso en 1 no se porque
	
	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
	;Configuro el RCSTA
	clrf RCSTA
	bsf RCSTA,SPEN ; Serial Port Enable
	bsf RCSTA,CREN ; Continuous receive enable

;FIN INICIALIZACION PUERTO SERIE (USART)


;INICIALIZACION DE ADC

	;Pagina 01 (BANK 1)
 	bsf	STATUS,RP0
 	bcf	STATUS,RP1
	;TRISA d'11111111' --> INPUT
	clrf	TRISA
 	comf	TRISA
	;All pins used for analog-to-digital conversion should also be configured as analog
	;pins. The value in the ADCON1 register determines if pins are configured as
	;analog or digital, and the source of the analog-to-digital converter voltage
	;references.
	;Configuro todos como entradas analogicas (A,A,A,A,A,A,A,A)
	movlw	0x00
 	movwf	ADCON1

	;The input channel and the analog-to-digital converter clock are selected, and the
	;converter is enabled, by the options selected in the ADCON0 register. 
	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
	;Configuro el ADCON0 en b'01000001'
	;bit 7:6 ADCS1:ADCS0: A/D Conversion Clock Select bits: 00 = FOSC/2, 01 = FOSC/8, 10 = FOSC/32, 11 = FRC (clock derived from the internal A/D RC oscillator)
	;The analog-to-digital converter clock is selected as the main
	;oscillator frequency divided by eight, the input channel selected is channel zero, and
	;the converter is being enabled. 
	movlw b'01000001'
	movwf ADCON0

;FIN INICIALIZACION ADC

; INICIALIZACION DE INTERRUPCIONES

	;Pagina 01 (BANK 1)
 	bsf	STATUS,RP0
 	bcf	STATUS,RP1
	;Habilito int de recepcion, la int de transmision no hace falta ya que tomamos accion solo al recibir un dato. 
 	bsf		PIE1, RCIE 	;Habilito int de recepcion
 
	;Pagina 00 (BANK 0)
 	bcf	STATUS,RP0
 	bcf	STATUS,RP1
 	bsf		INTCON, PEIE	; habilito int de perifericos
 	bsf		INTCON, GIE		; habilito int global	

; FIN INICIALIZACION DE INTERRUPCIONES
;FIN INIT
return
end
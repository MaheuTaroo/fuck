; Ficheiro:  AC_ProjFinal_LEIC23D_G12.S
; Descricao: Projeto final
; Autor:     João Martins (a50055@alunos.isel.pt)
;            Gonçalo Antunes (a49219@alunos.isel.pt)
; Data:      05-06-2024

; Definicao dos valores dos simbolos utilizados no programa
;
	.equ	CPSR_BIT_I, 0b010000          ; Mascara para o bit I do registo CPSR

	.equ	STACK_SIZE, 64                ; Dimensao do stack - 64 B

	; Definicoes do porto de entrada
	.equ	INPORT_ADDRESS, 0xFF80        ; Endereco do porto de entrada

	; Definicoes do porto de saida
	.equ	OUTPORT_ADDRESS, 0xFFC0       ; Endereco do porto de saida

	; Definicoes do circuito pTC
	.equ	PTC_ADDRESS,  0xFF40          ; Endereco do circuito pTC

	.equ	PTC_TCR, 0                    ; Deslocamento do registo TCR do pTC
	.equ	PTC_TMR, 2                    ; Deslocamento do registo TMR do pTC
	.equ	PTC_TC,  4                    ; Deslocamento do registo TC do pTC
	.equ	PTC_TIR, 6                    ; Deslocamento do registo TIR do pTC

	.equ	PTC_CMD_START, 0              ; Comando para iniciar a contagem no pTC
	.equ	PTC_CMD_STOP, 1               ; Comando para parar a contagem no pTC

	.equ	SYSCLK_FREQ, 0x63             ; Intervalo de contagem do circuito pTC
                                          ; que suporta a implementação do sysclk
										  
	; Outras definicoes
	.equ	PEDESTRIAN_BUTTON, 0x1
	.equ	CONFIG, 0x10
	.equ	TRAFFIC_OUTPUT, 0b100111
	.equ	TRAFFIC_BLINK, 0b11
	.equ	PED_OUTPUT, 0b101001
	.equ	CONFIG_OUTPUT, 0b111011
	.equ	CONFIG_BLINK, 0b1011
	
	.equ	TIME_IDX_MAX, 0x4

	.equ	BLINK_TIME, 5


; Seccao:    startup
; Descricao: Guarda o código de arranque do sistema
;
	.section startup
	b	_start
	ldr	pc, isr_addr
_start:
	ldr	sp, stack_top_addr
    mov r0, pc
    add lr, r0, #4
	ldr	pc, main_addr
    b   .

stack_top_addr:
	.word	stack_top
main_addr:
	.word	main
isr_addr:
	.word	isr

; Seccao:    text
; Descricao: Guarda o código do programa
;
	.text

; Rotina:    main
; Descricao: *** Para completar ***
; Entradas:  -
; Saidas:    -
; Efeitos:   *** Para completar ***
main:
	bl sysclk_init
	mov r0, #0
	bl set_state
	bl sysclk_get_ticks
	bl set_ref
	mov r0, #TRAFFIC_OUTPUT
	bl outport_init
	mrs	r0, cpsr
	mov	r1, #CPSR_BIT_I
	orr	r0, r0, r1
	msr	cpsr, r0
	mov r4, #BLINK_TIME
main_loop:
	bl check_config
	bl check_ped_press
	and r0, r0, r0
	bzs if_state
	b ped_state
if_state:
	bl get_state
	and r0, r0, r0
	bzs wait_state
ped_state:
	mov r0, #PED_OUTPUT
	bl outport_init
	mov r0, #1
	bl set_state
ped_reset:
	bl sysclk_get_ticks
	bl set_ref
ped_cross:
	bl check_config
	bl get_state
	and r0, r0, r0
	bzs ped_end
	bl detect_ped_rise
	mov r1, #1
	cmp r0, r1
	beq ped_reset
	bl get_sleep_val
	mov r5, r0
	bl get_ref
	mov r6, r0
	bl sysclk_get_ticks
	sub r0, r0, r6
	cmp r0, r5
	blo ped_cross
	mov r0, #0
	bl set_state
ped_end:
	mov r0, #TRAFFIC_OUTPUT
	bl outport_init
	b main_loop
wait_state:
	bl get_ref
	mov r1, r0
	bl sysclk_get_ticks
	sub r2, r0, r1
	cmp r2, r4
	blo main_loop
	bl set_ref
	mov r0, #TRAFFIC_BLINK
	bl outport_toggle_bits
	b main_loop

; Rotina:    isr
; Descricao: Incrementa o valor da variável global sysclk.
; Entradas:  -
; Saidas:    -
; Efeitos:   R0 - endereço da variável sysclk
;			 R1 - valor novo da variável sysclk
isr:
	push r0
	push r1
	ldr r0, PTC_ADDR1
	strb r1, [r0, #PTC_TIR]
	ldr r1, sysclk_addr
	ldr r0, [r1]
	add r0, r0, #1
	str r0, [r1]
	pop r1
	pop r0
	movs pc, lr
	
PTC_ADDR1:
	.word PTC_ADDRESS

; Rotina:    sysclk_init
; Descricao: Inicia com o valor zero a variavel global sysclk.
;            Interface exemplo: void sysclk_init( uint8_t interval );
; Entradas:  R0 - Valor do novo intervalo de contagem, em ticks.
; Saidas:    -
; Efeitos:   Inicia com o valor zero a variavel global sysclk
sysclk_init:
	push lr
	ldr r1, sysclk_addr
	mov r2, #0
	str r2, [r1]
	mov r0, #SYSCLK_FREQ
	bl ptc_init
	pop pc

; Rotina:    sysclk_get_ticks
; Descricao: Devolve o valor corrente da variável global sysclk.
;            Interface exemplo: uint16_t sysclk_get_ticks ( );
; Entradas:  -
; Saidas:    R0 - valor da variável sysclk
; Efeitos:   -
sysclk_get_ticks:
	ldr r0, sysclk_addr
	ldr r0, [r0]
	mov pc, lr

sysclk_addr:
	.word sysclk

get_sleep_val:
	ldr r0, sleep_val_addr
	ldr r0, [r0]
	mov pc, lr

; Rotina:    fetch_sleep_duration
; Descricao: Devolve o tempo de espera entre estados
;            Interface exemplo: uint16_t fetch_sleep_duration();
; Entradas:  -
; Saidas:    R0 - tempo de espera
; Efeitos:   R1 - máscara/limite de endereçamento do array de tempos
set_sleep_duration:
    push lr
    bl inport_read          	; lê índice do array de tempos
    lsr r0, r0, #5              ; filtra o índice do resto dos bits
    mov r1, #TIME_IDX_MAX
    cmp r0, r1  				; previne ultrapassagem do limite máximo (4) do índice,
    bhs ssd_fetchtime   		; comparando o índice lido com o limite
    mov r1, r0              	; utiliza o valor lido se não ultrapassar
ssd_fetchtime:
	lsl r1, r1, #1
    ldr r0, times_addr
    ldr r0, [r0, r1]        	; obtém o tempo de espera entre estados
	ldr r1, sleep_val_addr
	str r0, [r1]               ; salva o tempo de espera obtido
    pop pc

times_addr:
	.word sleep_values

sleep_val_addr:
	.word sleep_val

; Rotina:    check_config
; Descricao: Verifica se o bit de configuração foi ativado; caso
;            esteja ativado, permanece em modo de configuração
;            Interface exemplo: void check_config();
; Entradas:  -
; Saidas:    -
; Efeitos:   R0 - leitura do bit de configuração
check_config:
	push lr
	push r4
	bl inport_read
	mov r4, #CONFIG
	and r0, r0, r4
	bzs noconfig        ; verificar se o bit de config está ativo; senão, sair da rotina
	push r5
	push r6
	push r7       
	bl sysclk_get_ticks
	mov r5, r0
	mov r0, #CONFIG_OUTPUT
	bl outport_init
	mov r6, #BLINK_TIME
	mov r7, #CONFIG_BLINK
config:
	bl detect_ped_rise
	bl inport_read
	and r0, r0, r4
	bzs config_end        ; verificar se o bit de config ainda está ativo; senão, sair da rotina
	bl set_sleep_duration ; obter novo tempo de espera para peões
	bl sysclk_get_ticks
	sub r1, r0, r5
	cmp r1, r6
	blo config
	mov r5, r0
	mov r0, r7
	bl outport_toggle_bits
	b config
config_end:
	mov r0, #TRAFFIC_OUTPUT
	bl outport_init
	pop r7
	pop r6
	pop r5
	mov r0, #0
	bl set_state
noconfig:
	pop r4
	pop pc

; Rotina:    get_state
; Descricao: Retorna o identificador do estado atual
;            Interface exemplo: uint8_t get_state();
; Entradas:  -
; Saidas:    R0 - estado atual
; Efeitos:   -
get_state:
	ldr r0, state_addr
	ldrb r0, [r0]
	mov pc, lr

; Rotina:    set_state
; Descricao: Retorna o identificador do estado atual
;            Interface exemplo: void set_state(uint8_t state);
; Entradas:  R0 - estado a definir
; Saidas:    -
; Efeitos:   -
set_state:
	ldr r1, state_addr
	strb r0, [r1]
	mov pc, lr

state_addr:
	.word state_val

; Rotina:    check_ped_press
; Descricao: Transita de estado se houver alguma transição
;            ascendente do botão de pedestre
;            Interface exemplo: void check_ped_press();
; Entradas:  -
; Saidas:    -
; Efeitos:   -
check_ped_press:
	push lr
	bl detect_ped_rise
	mov r1, #1
	cmp r0, r1
	bne no_press
	bl set_state
	bl sysclk_get_ticks
	bl set_ref
no_press:
	pop pc

; Rotina:    detect_ped_rise
; Descricao: Indica se houve alguma transição ascendente do
;            botão do pedestre
;            Interface exemplo: uint_8 detect_ped_rise();
; Entradas:  -
; Saidas:    R0 - um valor que indica se houve transição ascendente
; Efeitos:   -
detect_ped_rise:
	push lr
	bl      inport_read
	mov		r1, #PEDESTRIAN_BUTTON				
	and		r1, r0, r1                  ; R1 = inport_val & PEDESTRIAN_BUTTON
	mov		r0, #0                      ; rising_edge = FALSE
	ldr		r2, edge_status_addr
	bzs		detect_rise_l0              ; edge_now == 0
	ldrb	r3, [r2]                    ; R3 = edge_last
	and		r3, r3, r3
	bzc		detect_rise_l0              ; edge_last != 0
	mov		r0, #1                      ; rising_edge = TRUE
detect_rise_l0:
	strb	r1, [r2]					; edge_last = edge_now
	pop 	pc					; return rising_edge

edge_status_addr:
	.word	edge_status

	; Rotina:    get_ref
; Descricao: Obtém a referência temporal atual, em número de ticks
;            Interface exemplo: uint16_t get_ref();
; Entradas:  -
; Saidas:    R0 - a referência temporal
; Efeitos:   -
get_ref:
	ldr r0, ref_addr
	ldr r0, [r0]
	mov pc, lr

; Rotina:    get_ref
; Descricao: Armazena uma nova referência temporal atual, em número
;            de ticks
;            Interface exemplo: void set_ref(uint16_t new_ref);
; Entradas:  R0 - a referência temporal
; Saidas:    -
; Efeitos:   -
set_ref:
	ldr r1, ref_addr
	str r0, [r1]
	mov pc, lr

ref_addr:
	.word ref_ticks

; Gestor de periférico para o porto de entrada
;

; Rotina:    inport_read
; Descricao: Adquire e devolve o valor corrente do porto de entrada.
;            Interface exemplo: uint8_t inport_read( );
; Entradas:  -
; Saidas:    R0 - valor adquirido do porto de entrada
; Efeitos:   -
inport_read:
	ldr	r1, inport_addr
	ldrb	r0, [r1, #0]
	mov	pc, lr

inport_addr:
	.word	INPORT_ADDRESS

; Gestor de periférico para o porto de saída
;

; Rotina:    outport_toggle_bits
; Descricao: Transita entre valores lógicos nos bits do porto de saida
;            identificados em R0. O valor dos outros bits nao e alterado.
;            Interface exemplo: void outport_toggle_bits( uint8_t bit_mask );
; Entradas:  R0 - Mascara com os bits a alterar.
; Saidas:    -
; Efeitos:   Altera o valor da variavel global outport_img.
outport_toggle_bits:
	push	lr
	ldr	r1, outport_img_addr
	ldrb	r2, [r1, #0]
	eor	r0, r2, r0
	strb	r0, [r1, #0]
	bl	outport_write
	pop	pc

; Rotina:    outport_init
; Descricao: Faz a iniciacao do porto de saida, nele estabelecendo o valor
;            recebido em R0.
;            Interface exemplo: void outport_init( uint8_t value );
; Entradas:  R0 - Valor a atribuir ao porto de saida.
; Saidas:    -
; Efeitos:   Altera o valor da variavel global outport_img.
outport_init:
	push	lr
	ldr	r1, outport_img_addr
	strb	r0, [r1]
	bl	outport_write
	pop	pc

outport_img_addr:
	.word	outport_img

; Rotina:    outport_write
; Descricao: Escreve no porto de saida o valor recebido em R0.
;            Interface exemplo: void outport_write( uint8_t value );
; Entradas:  R0 - valor a atribuir ao porto de saida.
; Saidas:    -
; Efeitos:   -
outport_write:
	ldr	r1, outport_addr
	strb	r0, [r1, #0]
	mov	pc, lr

outport_addr:
	.word	OUTPORT_ADDRESS

; Gestor de periférico para o Pico Timer/Counter (pTC)
;

; Rotina:    ptc_init
; Descricao: Faz a iniciacao do periférico pTC, habilitando o seu funcionamento
;            em modo continuo e com o intervalo de contagem recebido em R0, em
;            ticks.
;            Interface exemplo: void ptc_init( uint8_t interval );
; Entradas:  R0 - Valor do novo intervalo de contagem, em ticks.
; Saidas:    -
; Efeitos:   Inicia a contagem no periferico a partir do valor zero, limpando
;            o pedido de interrupcao eventualmente pendente.
ptc_init:
    push    lr
	ldr	r1, PTC_ADDR
	mov	r2, #PTC_CMD_STOP
	strb	r2, [r1, #PTC_TCR]
	strb	r0, [r1, #PTC_TMR]
    bl  ptc_clr_irq
	mov	r2, #PTC_CMD_START
	strb	r2, [r1, #PTC_TCR]
	pop pc

; Rotina:    ptc_start
; Descricao: Habilita a contagem no periferico pTC.
;            Interface exemplo: void ptc_start( );
; Entradas:  -
; Saidas:    -
; Efeitos:   -
ptc_start:
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_START
	strb	r1, [r0, #PTC_TCR]
	mov	pc, lr

; Rotina:    ptc_stop
; Descricao: Para a contagem no periferico pTC.
;            Interface exemplo: void ptc_stop( );
; Entradas:  -
; Saidas:    -
; Efeitos:   O valor do registo TC do periferico e colocado a zero.
ptc_stop:
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_STOP
	strb	r1, [r0, #PTC_TCR]
	mov	pc, lr

; Rotina:    ptc_get_value
; Descricao: Devolve o valor corrente da contagem do periferico pTC.
;            Interface exemplo: uint8_t ptc_get_value( );
; Entradas:  -
; Saidas:    R0 - O valor corrente do registo TC do periferico.
; Efeitos:   -
ptc_get_value:
	ldr	r1, PTC_ADDR
	ldrb	r0, [r1, #PTC_TC]
	mov	pc, lr

; Rotina:    ptc_clr_irq
; Descricao: Sinaliza o periferico pTC que foi atendido um pedido de
;            interrupção.
;            Interface exemplo: void ptc_clr_irq( );
; Entradas:  -
; Saidas:    -
; Efeitos:   -
ptc_clr_irq:
	ldr	r0, PTC_ADDR
	strb	r1, [r0, #PTC_TIR]
	mov	pc, lr

PTC_ADDR:
	.word	PTC_ADDRESS

; Seccao:    data
; Descricao: Guarda as variáveis globais
;
	.data
sleep_values:
	.word   100, 200, 300, 400, 500

ref_ticks:
	.word   0
	
sysclk:
	.space	2

sleep_val:
	.word  100

edge_status:
	.byte   1

state_val:
	.byte   0

outport_img:
	.space	1

	.align

; Seccao:    stack
; Descricao: Implementa a pilha com o tamanho definido pelo simbolo STACK_SIZE
;
	.stack
	.space	STACK_SIZE
stack_top:

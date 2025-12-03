    .text
    .global main

    .set LED_BASE,   0x41210000
    .set SSD_BASE,   0x43C10000
    .set MATRIX_N,   4

main:
    BL      init_LED
    BL      disable_7seg
    BL      init_var
    BL      LED_0001
    BL      init_matrix
    BL      matrix_mul
    B       inf



@ ============================================================
@ ===============  MATRIX MULTIPLICATION ====================
@ ============================================================

matrix_mul:
    PUSH    {R4-R11,LR}

    @ Setup: calculate base addresses and constants
    MOV     R9, R12            @ n (matrix size)
    MUL     R10, R9, R9        @ n*n
    LSL     R10, R10, #2       @ n*n*4 (bytes per matrix)

    MOV     R4, #36            @ base_B = SP + 36 (offset after pushed registers)
    ADD     R5, R4, R10        @ base_A = SP + 36 + (n*n*4)

    @ Outer loop: i from 0 to n-1
    MOV     R11, #0            @ i = 0
i_loop:
    @ Pre-compute i*n once per i-loop iteration
    MUL     R0, R11, R9        @ i*n (reused in j-loop and k-loop)

    @ Middle loop: j from 0 to n-1
    MOV     R8, #0             @ j = 0
j_loop:
    MOV     R7, #0             @ sum = 0

    @ Inner loop: k from 0 to n-1
    MOV     R6, #0             @ k = 0
    @ Pre-compute base address for A[i][*] row (i*n*4)
    MOV     R1, R0             @ i*n
    LSL     R1, R1, #2         @ i*n*4 (byte offset for row i of A)
    ADD     R1, R1, R5         @ base address for A[i][*] row

k_loop:
    @ Load A[i][k]
    @ Address: A[i][k] = base_A + (i*n + k)*4 = base_A + i*n*4 + k*4
    MOV     R2, R6             @ k
    LSL     R2, R2, #2         @ k*4
    ADD     R2, R1, R2         @ offset = base_A + i*n*4 + k*4
    LDR     R2, [SP, R2]       @ A[i][k] = [SP + offset]

    @ Load B[k][j]
    @ Address: B[k][j] = base_B + (k*n + j)*4
    MUL     R3, R6, R9         @ k*n
    ADD     R3, R3, R8         @ k*n + j
    LSL     R3, R3, #2         @ (k*n + j)*4
    ADD     R3, R3, R4         @ base_B + (k*n + j)*4
    LDR     R3, [SP, R3]       @ B[k][j]

    @ Multiply and accumulate: sum += A[i][k] * B[k][j]
    MLA     R7, R2, R3, R7     @ sum = sum + A[i][k] * B[k][j]

    ADD     R6, R6, #1         @ k++
    CMP     R6, R9
    BLT     k_loop

    @ Store Y[i][j] = sum at base_B location (overwrites B)
    @ Address: Y[i][j] = base_B + (i*n + j)*4
    ADD     R2, R0, R8         @ i*n + j
    LSL     R2, R2, #2         @ (i*n + j)*4
    ADD     R2, R2, R4         @ base_B + (i*n + j)*4
    STR     R7, [SP, R2]       @ Y[i][j] = sum

    ADD     R8, R8, #1         @ j++
    CMP     R8, R9
    BLT     j_loop

    ADD     R11, R11, #1       @ i++
    CMP     R11, R9
    BLT     i_loop

    @ Check result and set LEDs accordingly
    BL      check_answer

    POP     {R4-R11,LR}
    BX      LR



@ ============================================================
@ ============== LONG DELAY (~1 second) ======================
@ ============================================================

long_delay:
    MOV  R0, #0
    MOVT R0, #0xFFFF          @ R0 ≈ 0xFFFF0000 → long wait
delay_loop:
    SUBS R0, R0, #1
    BNE  delay_loop
    BX   LR


@ ============================================================
@ =================== LED / INIT ROUTINES ===================
@ ============================================================

init_LED:       LDR R0,=LED_BASE; MOV R1,#0; STR R1,[R0]; BX LR
LED_0001:       LDR R0,=LED_BASE; MOV R1,#1; STR R1,[R0]; BX LR
LED_1001:       LDR R0,=LED_BASE; MOV R1,#9; STR R1,[R0]; BX LR
LED_1111:       LDR R0,=LED_BASE; MOV R1,#15; STR R1,[R0]; BX LR
init_var:       LDR R12,=MATRIX_N; BX LR
disable_7seg:   LDR R0,=SSD_BASE; MOV R1,#0; STR R1,[R0]; BX LR


@ ============================================================
@ ====================== INITIAL MATRICES ====================
@ ============================================================

init_matrix:
    @ B
    MOV R0,#3; MOV R1,#6; MOV R2,#3; MOV R3,#7; PUSH {R0-R3}
    MOV R0,#5; MOV R1,#6; MOV R2,#7; MOV R3,#3; PUSH {R0-R3}
    MOV R0,#2; MOV R1,#2; MOV R2,#4; MOV R3,#5; PUSH {R0-R3}
    MOV R0,#7; MOV R1,#3; MOV R2,#1; MOV R3,#2; PUSH {R0-R3}
    @ A
    MOV R0,#2; MOV R1,#3; MOV R2,#4; MOV R3,#5; PUSH {R0-R3}
    MOV R0,#1; MOV R1,#3; MOV R2,#2; MOV R3,#4; PUSH {R0-R3}
    MOV R0,#3; MOV R1,#6; MOV R2,#2; MOV R3,#1; PUSH {R0-R3}
    MOV R0,#2; MOV R1,#7; MOV R2,#3; MOV R3,#2; PUSH {R0-R3}
    BX LR


@ ============================================================
@ ======================== CHECKER ===========================
@ ============================================================

check_answer:
    LDR R0,[SP,#36+60]; CMP R0,#64; BNE wrong
    LDR R0,[SP,#36+56]; CMP R0,#53; BNE wrong
    LDR R0,[SP,#36+52]; CMP R0,#48; BNE wrong
    LDR R0,[SP,#36+48]; CMP R0,#53; BNE wrong
    LDR R0,[SP,#36+44]; CMP R0,#50; BNE wrong
    LDR R0,[SP,#36+40]; CMP R0,#40; BNE wrong
    LDR R0,[SP,#36+36]; CMP R0,#36; BNE wrong
    LDR R0,[SP,#36+32]; CMP R0,#34; BNE wrong
    LDR R0,[SP,#36+28]; CMP R0,#50; BNE wrong
    LDR R0,[SP,#36+24]; CMP R0,#61; BNE wrong
    LDR R0,[SP,#36+20]; CMP R0,#60; BNE wrong
    LDR R0,[SP,#36+16]; CMP R0,#51; BNE wrong
    LDR R0,[SP,#36+12]; CMP R0,#61; BNE wrong
    LDR R0,[SP,#36+8];  CMP R0,#66; BNE wrong
    LDR R0,[SP,#36+4];  CMP R0,#69; BNE wrong
    LDR R0,[SP,#36];    CMP R0,#54; BNE wrong

    BL LED_1111
    BX LR

wrong:
    BL LED_1001
    BX LR


inf:
    B inf

    .end

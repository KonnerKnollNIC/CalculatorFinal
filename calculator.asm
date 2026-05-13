;*****************************************************************************
; Author: Konner Knoll
; Date: 05/12/2026
; Revision: 1.0
;
; Description:
;   A calculator supporting +, -, *, /, ^ on values with one decimal digit (fixed-point).
;
; Notes:
;  - Input in format: num1[.frac1] op num2[.frac2]
;  - Handles a single digit plus one decimal digit per input number
;  - Will overflow for large exponents
;
; Register Usage:
;   R0  I/O / result
;   R1  Operand A
;   R2  Operand B
;   R3  Operator
;   R4  Loop counter
;   R5  Remainder
;   R6  Stack pointer
;   R7  Return address
;*****************************************************************************

        .ORIG x3000

; Strings near the top so LEA can reach them
MSG_PROMPT  .STRINGZ "\nCalculate: "
MSG_EQ      .STRINGZ " = "
MSG_ERR     .STRINGZ "Unknown operator\n"
MSG_DIVZ    .STRINGZ "Error: divide by zero\n"

        LD R6, STACK_INIT

MAIN
        LEA R0, MSG_PROMPT
        TRAP x22 ; PUTS

        ; Read operand A -> R1
        JSR READ_FIXED
        ST R1, OPERAND_A

        ; Read operator
        LD R3, SAVED_OP
        ; If SAVED_OP is 0, operator not yet read (no decimal point in A)
        ADD R3, R3, #0
        BRnp GOT_OP
        TRAP x20
        TRAP x21
        ST R0, SAVED_OP
        LD R3, SAVED_OP
GOT_OP
        ST R3, TEMP_OP

        JSR READ_FIXED
        ST R1, OPERAND_B

        LD R0, CHAR_NL
        TRAP x21

        LD R3, TEMP_OP

        LD R4, CHAR_PLUS
        NOT R4, R4
        ADD R4, R4, #1
        ADD R4, R3, R4
        BRz DO_ADD

        LD R4, CHAR_MINUS
        NOT R4, R4
        ADD R4, R4, #1
        ADD R4, R3, R4
        BRz DO_SUB

        LD R4, CHAR_STAR
        NOT R4, R4
        ADD R4, R4, #1
        ADD R4, R3, R4
        BRz DO_MUL

        LD R4, CHAR_SLASH
        NOT R4, R4
        ADD R4, R4, #1
        ADD R4, R3, R4
        BRz DO_DIV

        LD R4, CHAR_CARET
        NOT R4, R4
        ADD R4, R4, #1
        ADD R4, R3, R4
        BRz DO_EXP

        LEA R0, MSG_ERR
        TRAP x22
        BR MAIN

; Add: result = A + B (both scaled x10)
DO_ADD
        LD R1, OPERAND_A
        LD R2, OPERAND_B
        ADD R0, R1, R2
        BR PRINT_RESULT

; Subtract: result = A - B
DO_SUB
        LD R1, OPERAND_A
        LD R2, OPERAND_B
        NOT R2, R2
        ADD R2, R2, #1
        ADD R0, R1, R2
        BR PRINT_RESULT

; Multiply: (A * B) / 10
DO_MUL
        LD R1, OPERAND_A
        LD R2, OPERAND_B
        JSR UMUL ; R0 = |A| * |B|
        JSR DIV10 ; R0 = R0 / 10, remainder in R5
        BR PRINT_RESULT

; Divide: (A * 10) / B  (keeps one decimal digit)
DO_DIV
        LD R2, OPERAND_B
        ADD R4, R2, #0
        BRz DIV_ZERO
        LD R1, OPERAND_A
        ; Scale A up by 10
        AND R0, R0, #0
        AND R4, R4, #0
        ADD R4, R4, #10
DIV_SCALE
        ADD R0, R0, R1
        ADD R4, R4, #-1
        BRp DIV_SCALE ; R0 = A * 10
        ST R2, DIV_DSOR
        JSR UDIV ; R0 = R0 / R2
        BR PRINT_RESULT
DIV_ZERO
        LEA R0, MSG_DIVZ
        TRAP x22
        BR MAIN

; Exponent: A ^ floor(B/10)
DO_EXP
        LD R1, OPERAND_B
        ADD R0, R1, #0
        JSR DIV10
        ST R0, EXP_N
        LD R0, FIXED_ONE ; accumulator = 1.0 (= 10 in fixed)
        LD R4, EXP_N
        ADD R4, R4, #0
        BRz EXP_DONE
EXP_LOOP
        ADD R1, R0, #0
        LD R2, OPERAND_A
        ST R4, EXP_CTR ; save counter
        JSR UMUL
        JSR DIV10
        LD R4, EXP_CTR ; restore
        ADD R4, R4, #-1
        BRp EXP_LOOP
EXP_DONE
        BR PRINT_RESULT

; PRINT_RESULT - print R0 as fixed-point decimal "INT.FRAC"
PRINT_RESULT
        ST R0, SAVED_RES
        LEA R0, MSG_EQ
        TRAP x22

        LD R0, SAVED_RES
        ADD R4, R0, #0
        BRzp PR_POS
        LD R0, CHAR_MINUS
        TRAP x21
        LD R0, SAVED_RES
        NOT R0, R0
        ADD R0, R0, #1
PR_POS
        JSR DIV10 ; R0 = integer part, R5 = frac digit

        ; Print integer part
        ADD R6, R6, #-1
        STR R7, R6, #0
        ADD R6, R6, #-1
        STR R5, R6, #0 ; save frac digit across PRINT_NUM
        JSR PRINT_NUM
        LDR R5, R6, #0
        ADD R6, R6, #1
        LDR R7, R6, #0
        ADD R6, R6, #1

        LD R0, CHAR_DOT
        TRAP x21
        ADD R0, R5, #0
        LD R1, ASCII0
        ADD R0, R0, R1
        TRAP x21
        LD R0, CHAR_NL
        TRAP x21

        AND R0, R0, #0
        ST R0, SAVED_OP ; clear saved op for next iteration
        BR MAIN

; READ_FIXED - reads "<d>[.<d>]" into R1.
;   After an integer digit, reads one more char:
;   - if '.', reads fractional digit -> returns via RET
;   - otherwise saves that char in SAVED_OP
READ_FIXED
        ADD R6, R6, #-1
        STR R7, R6, #0

        AND R0, R0, #0
        ST R0, SAVED_OP ; clear

        TRAP x20
        TRAP x21
        LD R1, NEG_ASCII0
        ADD R1, R0, R1 ; R1 = digit value

        ; Multiply R1 by 10
        AND R4, R4, #0
        AND R5, R5, #0
        ADD R4, R4, #10
RF_MUL
        ADD R5, R5, R1
        ADD R4, R4, #-1
        BRp RF_MUL
        ADD R1, R5, #0 ; R1 = digit * 10

        TRAP x20
        TRAP x21

        LD R4, CHAR_DOT
        NOT R4, R4
        ADD R4, R4, #1
        ADD R4, R0, R4
        BRnp RF_SAVE_OP ; not a dot -> operator

        ; read fractional digit
        TRAP x20
        TRAP x21
        LD R4, NEG_ASCII0
        ADD R4, R0, R4
        ADD R1, R1, R4 ; R1 = int*10 + frac
        LDR R7, R6, #0
        ADD R6, R6, #1
        RET

RF_SAVE_OP
        ST R0, SAVED_OP ; save operator char for MAIN
        LDR R7, R6, #0
        ADD R6, R6, #1
        RET

; UMUL - unsigned multiply R1 * R2 -> R0
UMUL
        AND R0, R0, #0
        ADD R4, R1, #0
UMUL_LOOP
        BRz UMUL_DONE
        ADD R0, R0, R2
        ADD R4, R4, #-1
        BR UMUL_LOOP
UMUL_DONE
        RET

; DIV10 - R0 / 10: quotient -> R0, remainder -> R5
DIV10
        AND R5, R5, #0
        ADD R5, R0, #0
        AND R0, R0, #0
D10_L
        LD R4, NEG_TEN
        ADD R5, R5, R4
        BRn D10_DONE
        ADD R0, R0, #1
        BR D10_L
D10_DONE
        LD R4, POS_TEN
        ADD R5, R5, R4
        RET

; UDIV - R0 / DIV_DSOR -> R0 (unsigned)
UDIV
        AND R4, R4, #0
        LD R5, DIV_DSOR
        NOT R5, R5
        ADD R5, R5, #1
UDIV_L
        ADD R0, R0, R5
        BRn UDIV_DONE
        ADD R4, R4, #1
        BR UDIV_L
UDIV_DONE
        ADD R0, R4, #0
        RET

; PRINT_NUM - print non-negative integer R0 as decimal
PRINT_NUM
        ADD R6, R6, #-1
        STR R7, R6, #0
        ADD R6, R6, #-1
        STR R5, R6, #0
        ADD R6, R6, #-1
        STR R4, R6, #0
        ADD R6, R6, #-1
        STR R3, R6, #0
        ADD R6, R6, #-1
        STR R2, R6, #0
        ADD R6, R6, #-1
        STR R1, R6, #0
        ADD R6, R6, #-1
        STR R0, R6, #0
        AND R5, R5, #0
PN_LOOP
        AND R2, R2, #0
        ADD R1, R0, #0
        LD R3, NEG_TEN
PN_DIV
        ADD R1, R1, R3
        BRn PN_REM
        ADD R2, R2, #1
        BR PN_DIV
PN_REM
        LD R4, POS_TEN
        ADD R1, R1, R4
        LD R4, ASCII0
        ADD R1, R1, R4
        ADD R6, R6, #-1
        STR R1, R6, #0
        ADD R5, R5, #1
        ADD R0, R2, #0
        BRnp PN_LOOP
PN_PRINT
        ADD R5, R5, #0
        BRz PN_DONE
        LDR R0, R6, #0
        ADD R6, R6, #1
        TRAP x21
        ADD R5, R5, #-1
        BR PN_PRINT
PN_DONE
        LDR R0, R6, #0
        ADD R6, R6, #1
        LDR R1, R6, #0
        ADD R6, R6, #1
        LDR R2, R6, #0
        ADD R6, R6, #1
        LDR R3, R6, #0
        ADD R6, R6, #1
        LDR R4, R6, #0
        ADD R6, R6, #1
        LDR R5, R6, #0
        ADD R6, R6, #1
        LDR R7, R6, #0
        ADD R6, R6, #1
        RET

; Data
STACK_INIT  .FILL xFE00
NEG_ASCII0  .FILL xFFD0 ; -0x30: convert ASCII digit to integer
ASCII0      .FILL x0030
NEG_TEN     .FILL xFFF6
POS_TEN     .FILL x000A
CHAR_NL     .FILL x000A
CHAR_DOT    .FILL x002E ; '.'
CHAR_PLUS   .FILL x002B ; '+'
CHAR_MINUS  .FILL x002D ; '-'
CHAR_STAR   .FILL x002A ; '*'
CHAR_SLASH  .FILL x002F ; '/'
CHAR_CARET  .FILL x005E ; '^'
FIXED_ONE   .FILL x000A ; 10 = 1.0 in fixed-point x10

SAVED_OP    .BLKW 1
SAVED_RES   .BLKW 1
OPERAND_A   .BLKW 1
OPERAND_B   .BLKW 1
DIV_DSOR    .BLKW 1
EXP_N       .BLKW 1
TEMP_OP     .BLKW 1
EXP_CTR     .BLKW 1

        .END
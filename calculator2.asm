; ==============================================================================
; Pure 64-bit x86_64 Linux Assembly Calculator (No External C/C++ Libraries)
; Assemble: nasm -f elf64 calculator2.asm -o calculator2.o
; Link:     ld calculator2.o -o calculator2
; Run:      ./calculator2
; ==============================================================================

section .data
    prompt      db "Enter expression (e.g., 15 + 7): ", 0
    prompt_len  equ $ - prompt

    res_msg     db "Result: ", 0
    res_len     equ $ - res_msg

    err_op      db "Error: Invalid operator. Use +, -, *, or /", 10, 0
    err_op_len  equ $ - err_op

    err_div     db "Error: Division by zero", 10, 0
    err_div_len equ $ - err_div

    err_fmt     db "Error: Invalid input format", 10, 0
    err_fmt_len equ $ - err_fmt

    newline     db 10

section .bss
    in_buf      resb 64
    out_buf     resb 32
    num1        resq 1
    num2        resq 1
    operator    resb 1

section .text
    global _start

_start:
    ; 1. Print Prompt Window
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [rel prompt]
    mov rdx, prompt_len
    syscall

    ; 2. Read User Text Input Buffer
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [rel in_buf]
    mov rdx, 63
    syscall
    
    cmp rax, 0
    jle .fmt_error
    
    lea rsi, [rel in_buf]

    ; 3. Parse First Number (ASCII to Integer)
    call _skip_spaces
    call _parse_int
    cmp rcx, 0          ; If no digits parsed, trigger format error
    je .fmt_error
    mov [rel num1], rax

    ; 4. Parse Operator
    call _skip_spaces
    mov al, [rsi]
    cmp al, 10          ; Missing operator check
    je .fmt_error
    mov [rel operator], al
    inc rsi             ; Advance past operator

    ; 5. Parse Second Number (ASCII to Integer)
    call _skip_spaces
    call _parse_int
    cmp rcx, 0
    je .fmt_error
    mov [rel num2], rax

    ; 6. Route Execution Based on Operator Character
    mov r8, [rel num1]
    mov r9, [rel num2]
    movzx rax, byte [rel operator]

    cmp rax, '+'
    je .do_add
    cmp rax, '-'
    je .do_sub
    cmp rax, '*'
    je .do_mul
    cmp rax, '/'
    je .do_div
    jmp .op_error

.do_add:
    add r8, r9
    mov rax, r8
    jmp .print_result

.do_sub:
    sub r8, r9
    mov rax, r8
    jmp .print_result

.do_mul:
    mov rax, r8
    imul r9
    jmp .print_result

.do_div:
    cmp r9, 0
    je .div_zero_error
    mov rax, r8
    cqo                 ; Sign-extend RAX into RDX:RAX for idiv
    idiv r9
    jmp .print_result

; --- Output Handlers ---

.print_result:
    push rax            ; Save calculation outcome
    
    ; Print "Result: "
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel res_msg]
    mov rdx, res_len
    syscall

    pop rax             ; Restore outcome value
    lea rdi, [rel out_buf + 30] ; Start string construction at the tail of the buffer
    call _int_to_ascii

    ; Output converted number string
    mov rdx, rsi        ; Character length calculated inside conversion routing
    mov rsi, rdi        ; String pointer destination
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall

    ; Print Newline
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel newline]
    mov rdx, 1
    syscall
    jmp .exit

.op_error:
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel err_op]
    mov rdx, err_op_len
    syscall
    mov rdi, 1
    jmp .exit

.div_zero_error:
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel err_div]
    mov rdx, err_div_len
    syscall
    mov rdi, 2
    jmp .exit

.fmt_error:
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel err_fmt]
    mov rdx, err_fmt_len
    syscall
    mov rdi, 3
    jmp .exit

.exit:
    mov rax, 60         ; sys_exit
    syscall

; ==============================================================================
; UTILITY SUBROUTINES
; ==============================================================================

; Skips space characters (ASCII 32) at pointer [rsi]
_skip_spaces:
.loop:
    mov al, [rsi]
    cmp al, ' '
    jne .done
    inc rsi
    jmp .loop
.done:
    ret

; Parses base-10 integer string to 64-bit signed integer value
; Inputs:  RSI = Pointer to ASCII string
; Outputs: RAX = Parsed numeric integer, RCX = Count of characters processed
_parse_int:
    xor rax, rax
    xor rcx, rcx
    xor r10, r10        ; Sign tracking register (0 = positive, 1 = negative)

    mov bl, [rsi]
    cmp bl, '-'
    jne .parse_loop
    mov r10, 1          ; Track negative flag state
    inc rsi
    inc rcx

.parse_loop:
    movzx rbx, byte [rsi]
    cmp rbx, '0'
    jl .finished
    cmp rbx, '9'
    jg .finished

    sub rbx, '0'        ; Translate character code to true integer values
    imul rax, 10
    add rax, rbx
    inc rsi
    inc rcx
    jmp .parse_loop

.finished:
    cmp r10, 1
    jne .exit_sub
    neg rax             ; Negate if minus prefix was tracked
.exit_sub:
    ret

; Converts 64-bit signed integer value to ASCII text backwards
; Inputs:  RAX = Value to convert, RDI = Tail address reference pointer
; Outputs: RDI = Updated pointer facing head of string, RDX = Calculated string size
_int_to_ascii:
    xor rcx, rcx        ; Count loop tracking length
    xor r10, r10        ; Sign track configuration

    cmp rax, 0
    jge .convert_loop
    mov r10, 1          ; Number is negative
    neg rax

.convert_loop:
    xor rdx, rdx
    mov rbx, 10
    div rbx             ; Divide RDX:RAX by 10. RAX = Quotient, RDX = Remainder
    add dl, '0'         ; Offset integer to ASCII character
    dec rdi             ; Move text building buffer index backward
    mov [rdi], dl
    inc rcx
    cmp rax, 0
    jne .convert_loop

    cmp r10, 1
    jne .done_ascii
    dec rdi
    mov byte [rdi], '-' ; Prepend negative symbol
    inc rcx

.done_ascii:
    mov rsi, rcx        ; Copy tracked length out to RSI system output storage
    ret

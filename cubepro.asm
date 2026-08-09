section .data
    term_init        db 27, "[2J", 27, "[?25l", 27, "[H"
    term_init_len    equ $ - term_init

    term_reset       db 27, "[?25h", 10
    term_reset_len   equ $ - term_reset

    SCREEN_W         equ 80
    SCREEN_H         equ 24
    FRAME_SIZE       equ (SCREEN_W + 1) * SCREEN_H

    delay_tv         dq 0, 16666666  

    vertices:
        dw -25, -25, -25
        dw  25, -25, -25
        dw  25,  25, -25
        dw -25,  25, -25
        dw -25, -25,  25
        dw  25, -25,  25
        dw  25,  25,  25
        dw -25,  25,  25

    edges:
        db 0, 1    
        db 1, 2    
        db 2, 3    
        db 3, 0    
        db 4, 5    
        db 5, 6    
        db 6, 7    
        db 7, 4    
        db 0, 4    
        db 1, 5    
        db 2, 6    
        db 3, 7    

    sin_table:
        dw 0, 33, 66, 97, 128, 156, 181, 203
        dw 221, 235, 244, 250, 252, 250, 244, 235
        dw 221, 203, 181, 156, 128, 97, 66, 33

    sigaction_struct:
        dq _cleanup_handler          
        dq 0x04000000                
        dq _signal_restorer          
        dq 0                         

section .bss
    frame_buf        resb FRAME_SIZE
    projected_x      resw 8
    projected_y      resw 8
    
    angle_x          resb 1
    angle_y          resb 1
    angle_z          resb 1

section .text
    global _start

_start:
    mov rax, 134                    
    mov rdi, 2                      
    lea rsi, [rel sigaction_struct] 
    mov rdx, 0                      
    mov r10, 8                      
    syscall

    mov byte [rel angle_x], 0
    mov byte [rel angle_y], 4
    mov byte [rel angle_z], 8

    mov rax, 1                      
    mov rdi, 1                      
    lea rsi, [rel term_init]
    mov rdx, term_init_len
    syscall

.engine_loop:
    lea rdi, [rel frame_buf]
    mov rcx, SCREEN_H
.clear_rows:
    push rcx
    mov rcx, SCREEN_W
    mov al, ' '                     
    rep stosb
    mov al, 10                      
    stosb
    pop rcx
    loop .clear_rows

    movzx rax, byte [rel angle_x]
    lea rbx, [rel sin_table]
    movsx r8, word [rbx + rax * 2]   
    add rax, 6
    cmp rax, 24
    jl .skip_wrap_x
    sub rax, 24
.skip_wrap_x:
    movsx r9, word [rbx + rax * 2]   

    movzx rax, byte [rel angle_y]
    movsx r10, word [rbx + rax * 2]  
    add rax, 6
    cmp rax, 24
    jl .skip_wrap_y
    sub rax, 24
.skip_wrap_y:
    movsx r11, word [rbx + rax * 2]  

    xor rbp, rbp                     
.transform_vertex_loop:
    lea rcx, [rel vertices]
    mov rdi, rbp
    imul rdi, 6                      
    movsx rbx, word [rcx + rdi + 0]  
    movsx rsi, word [rcx + rdi + 2]  
    movsx rdx, word [rcx + rdi + 4]  

    mov rax, rsi
    imul r9
    mov r12, rax                     
    mov rax, rdx
    imul r8
    sub r12, rax
    sar r12, 8                       

    mov rax, rsi
    imul r8
    mov r13, rax                     
    mov rax, rdx
    imul r9
    add r13, rax
    sar r13, 8                       

    mov rax, rbx
    imul r11
    mov r14, rax                     
    mov rax, r13
    imul r10
    add r14, rax
    sar r14, 8                       

    mov rax, rbx
    imul r10
    neg rax
    mov r15, rax                     
    mov rax, r13
    imul r11
    add r15, rax
    sar r15, 8                       

    add r15, 90                      
    
    mov rax, r14
    mov rdi, 55                      
    imul rdi
    cqo
    idiv r15
    add rax, 40                      
    lea rdi, [rel projected_x]
    mov [rdi + rbp * 2], ax

    mov rax, r12
    mov rdi, 28                      
    imul rdi
    cqo
    idiv r15
    add rax, 12                      
    lea rdi, [rel projected_y]
    mov [rdi + rbp * 2], ax

    inc rbp
    cmp rbp, 8
    jl .transform_vertex_loop

    xor rbp, rbp                     
.render_edge_vectors_loop:
    lea rbx, [rel edges]
    mov rdi, rbp
    shl rdi, 1                       
    movzx r12, byte [rbx + rdi + 0]  
    movzx r13, byte [rbx + rdi + 1]  

    lea rbx, [rel projected_x]
    movsx r8, word [rbx + r12 * 2]   
    movsx r10, word [rbx + r13 * 2]  

    lea rbx, [rel projected_y]
    movsx r9, word [rbx + r12 * 2]   
    movsx r11, word [rbx + r13 * 2]  

    call _draw_bresenham_line

    inc rbp
    cmp rbp, 12                      
    jl .render_edge_vectors_loop

    mov rax, 1                      
    mov rdi, 1                      
    lea rsi, [rel frame_buf]
    mov rdx, FRAME_SIZE
    syscall

    mov rax, 35                     
    lea rdi, [rel delay_tv]
    xor rsi, rsi
    syscall

    inc byte [rel angle_x]
    cmp byte [rel angle_x], 24
    jne .skip_reset_anx
    mov byte [rel angle_x], 0
.skip_reset_anx:

    inc byte [rel angle_y]
    cmp byte [rel angle_y], 24
    jne .skip_reset_any
    mov byte [rel angle_y], 0
.skip_reset_any:

    jmp .engine_loop

_draw_bresenham_line:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov r12, r10
    sub r12, r8                      
    mov r14, 1                       
    cmp r12, 0
    jge .calc_dy
    neg r12                          
    mov r14, -1                      

.calc_dy:
    mov r13, r11
    sub r13, r9                      
    mov r15, 1                       
    cmp r13, 0
    jge .evaluate_octant
    neg r13                          
    mov r15, -1                      

.evaluate_octant:
    cmp r12, r13
    jge .dx_driven_axis

.dy_driven_axis:
    mov rax, r12
    shl rax, 1                       
    sub rax, r13                     
    
    mov rbx, r13                     
    inc rbx
.dy_loop:
    push rbx
    call _plot_pixel_safely
    
    cmp rax, 0
    jl .dy_error_negative
    add r8, r14                      
    mov rdx, r13
    shl rdx, 1
    sub rax, rdx                     
.dy_error_negative:
    mov rdx, r12
    shl rdx, 1
    add rax, rdx                     
    
    add r9, r15                      
    pop rbx
    dec rbx
    jnz .dy_loop
    jmp .line_complete

.dx_driven_axis:
    mov rax, r13
    shl rax, 1                       
    sub rax, r12                     
    
    mov rbx, r12                     
    inc rbx
.dx_loop:
    push rbx
    call _plot_pixel_safely
    
    cmp rax, 0
    jl .dx_error_negative
    add r9, r15                      
    mov rdx, r12
    shl rdx, 1
    sub rax, rdx                     
.dx_error_negative:
    mov rdx, r13
    shl rdx, 1
    add rax, rdx                     
    
    add r8, r14                      
    pop rbx
    dec rbx
    jnz .dx_loop

.line_complete:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

_plot_pixel_safely:
    cmp r8, 0
    jl .plot_abort
    cmp r8, SCREEN_W
    jge .plot_abort

    cmp r9, 0
    jl .plot_abort
    cmp r9, SCREEN_H
    jge .plot_abort

    push rax
    push rbx
    mov rax, r9
    mov rbx, SCREEN_W
    inc rbx                          
    imul rbx
    add rax, r8                      
    
    lea rbx, [rel frame_buf]
    add rbx, rax
    mov byte [rbx], '*'              
    pop rbx
    pop rax
.plot_abort:
    ret

_cleanup_handler:
    mov rax, 1                      
    mov rdi, 1                      
    lea rsi, [rel term_reset]
    mov rdx, term_reset_len
    syscall

    mov rax, 60                     
    mov rdi, 0                      
    syscall

_signal_restorer:
    mov rax, 15                     
    syscall

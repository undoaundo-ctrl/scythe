; ==============================================================================
; 3D Rotating Cube in Terminal (Linux x86_64) - Fixed 64-bit RIP Addressing
; Assemble: nasm -f elf64 cubeasm.asm -o cube.o
; Link:     ld cube.o -o cube
; Run:      ./cube  (Press Ctrl+C to exit)
; 

section .data
    ; ANSI Escape Codes to clear screen, hide cursor, and reset cursor position
    cls_seq      db 27, "[2J", 27, "[?25l", 27, "[H"
    cls_len      equ $ - cls_seq
    
    ; Grid Setup: 80 columns x 22 rows + 1 newline per row = 1782 bytes
    SCREEN_W     equ 80
    SCREEN_H     equ 22
    FRAME_SIZE   equ (SCREEN_W + 1) * SCREEN_H

    ; Timing delay (approx 30,000 microseconds)
    delay_tv     dq 0, 30000000

    ; 3D Cube Vertices (Scaled up by 100 for fixed-point math: X, Y, Z)
    vertices     dw -20, -20, -20
                 dw  20, -20, -20
                 dw  20,  20, -20
                 dw -20,  20, -20
                 dw -20, -20,  20
                 dw  20, -20,  20
                 dw  20,  20,  20
                 dw -20,  20,  20

    ; Cube Edges (Pairs of vertex indices to connect)
    edges        db 0,1, 1,2, 2,3, 3,0  ; Back Face
                 db 4,5, 5,6, 6,7, 7,4  ; Front Face
                 db 0,4, 1,5, 2,6, 3,7  ; Connecting edges

    ; Fixed-point Sine Table (0 to 70 degrees in steps of 10, scaled up by 256)
    sin_table    dw 0, 44, 87, 128, 164, 196, 221, 240

section .bss
    frame_buf    resb FRAME_SIZE
    rot_vertices resw 8 * 2  ; Transformed 2D screen points (X, Y) per vertex
    angle_idx    resb 1

section .text
    global _start

_start:
    mov byte [rel angle_idx], 0

.main_loop:
    ; 1. Clear screen and home cursor
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel cls_seq]
    mov rdx, cls_len
    syscall

    ; 2. Initialize Frame Buffer with blank spaces and newlines
    lea rdi, [rel frame_buf]
    mov rcx, SCREEN_H
.init_rows:
    push rcx
    mov rcx, SCREEN_W
    mov al, ' '
    rep stosb
    mov al, 10          ; '\n'
    stosb
    pop rcx
    loop .init_rows

    ; 3. Calculate Rotation Sine & Cosine Values
    movzx rbx, byte [rel angle_idx]
    lea rcx, [rel sin_table]         
    movzx rbx, word [rcx + rbx*2]    
    
    movzx rdx, byte [rel angle_idx]
    add rdx, 2
    and rdx, 7
    lea rcx, [rel sin_table]         
    movzx rdx, word [rcx + rdx*2]    

    ; 4. Project and Rotate 8 Vertices
    xor rsi, rsi        ; Vertex index counter (0 to 7)
.rotate_vertices_loop:
    ; Fetch raw X, Y, Z coordinates using safe 64-bit base offsets
    lea rcx, [rel vertices]
    mov rdi, rsi
    imul rdi, 6
    movsx r8, word [rcx + rdi + 0]
    movsx r9, word [rcx + rdi + 2]
    movsx r10, word [rcx + rdi + 4]

    ; Apply Y-axis Rotation Matrix:
    ; X' = X * cos - Z * sin
    ; Z' = X * sin + Z * cos
    mov rax, r8
    imul rdx
    mov r11, rax        ; r11 = X * cos
    mov rax, r10
    imul rbx
    sub r11, rax        ; r11 -= Z * sin
    sar r11, 8          ; Re-scale fixed point (/256)

    mov rax, r8
    imul rbx
    mov r12, rax        ; r12 = X * sin
    mov rax, r10
    imul rdx
    add r12, rax        ; r12 += Z * cos
    sar r12, 8          ; Re-scale fixed point (/256)

    ; Perspective projection & centering onto 2D text screen grid
    add r12, 60         
    
    ; Screen X = CenterX + (X' * Distance) / Z'
    mov rax, r11
    imul word 40
    cqo
    idiv r12
    add rax, 40         ; Center X
    
    lea rcx, [rel rot_vertices]
    mov rdi, rsi
    shl rdi, 2          ; Index * 4
    mov [rcx + rdi + 0], ax

    ; Screen Y = CenterY + (Y' * Distance) / Z'
    mov rax, r9
    imul word 20
    cqo
    idiv r12
    add rax, 11         ; Center Y
    
    lea rcx, [rel rot_vertices]
    mov rdi, rsi
    shl rdi, 2          ; Index * 4
    mov [rcx + rdi + 2], ax

    inc rsi
    cmp rsi, 8
    jl .rotate_vertices_loop

    ; 5. Draw the 12 Edges connecting vertices
    xor rsi, rsi        ; Edge counter (0 to 11)
.draw_edges_loop:
    lea rcx, [rel edges]
    mov rdi, rsi
    shl rdi, 1          ; Index * 2
    movzx rax, byte [rcx + rdi + 0] ; Vertex A index
    movzx rbx, byte [rcx + rdi + 1] ; Vertex B index

    ; Get screen positions of points A and B safely
    lea rcx, [rel rot_vertices]
    shl rax, 2          ; Vertex A offset
    shl rbx, 2          ; Vertex B offset
    movsx r8, word [rcx + rax + 0]  ; X1
    movsx r9, word [rcx + rax + 2]  ; Y1
    movsx r10, word [rcx + rbx + 0] ; X2
    movsx r11, word [rcx + rbx + 2] ; Y2

    ; Line interpolation loop (Draws 8 sequential points per line)
    mov rcx, 8
.draw_line_points:
    ; X interpolation: X1 + ((X2 - X1) * rcx) / 8
    mov rax, r10
    sub rax, r8
    imul rcx
    sar rax, 3
    add rax, r8

    ; Y interpolation: Y1 + ((Y2 - Y1) * rcx) / 8
    mov rdi, r11
    sub rdi, r9
    imul rdi, rcx
    sar rdi, 3
    add rdi, r9

    ; Bounds validation safety check
    cmp rax, 0
    jl .skip_pixel
    cmp rax, SCREEN_W - 1
    jge .skip_pixel
    cmp rdi, 0
    jl .skip_pixel
    cmp rdi, SCREEN_H - 1
    jge .skip_pixel

    ; Offset math: buffer_ptr = frame_buf + (Y * (SCREEN_W + 1)) + X
    imul rdi, (SCREEN_W + 1)
    lea rdx, [rel frame_buf]
    add rdi, rdx
    add rdi, rax
    mov byte [rdi], '*'  ; Draw line character

.skip_pixel:
    loop .draw_line_points

    inc rsi
    cmp rsi, 12
    jl .draw_edges_loop

    ; 6. Render Frame Buffer onto screen
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel frame_buf]
    mov rdx, FRAME_SIZE
    syscall

    ; 7. Frame Rate Limiter (Sleep Delay)
    mov rax, 35         
    lea rdi, [rel delay_tv]
    xor rsi, rsi
    syscall

    ; 8. Increment angle table index to rotate frame
    inc byte [rel angle_idx]
    and byte [rel angle_idx], 7

    jmp .main_loop

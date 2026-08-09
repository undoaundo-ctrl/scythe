; ==============================================================================
; 3D Rotating Cube in Terminal (Linux x86_64)
; Assemble: nasm -f elf64 cube.asm -o cube.o
; Link:     ld cube.o -o cube
; Run:      ./cube  (Press Ctrl+C to exit)
; ==============================================================================

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
    ; Approximates continuous incremental rotation
    sin_table    dw 0, 44, 87, 128, 164, 196, 221, 240

section .bss
    frame_buf    resb FRAME_SIZE
    rot_vertices resw 8 * 2  ; Transformed 2D screen points (X, Y) per vertex
    angle_idx    resb 1

section .text
    global _start

_start:
.main_loop:
    ; 1. Clear screen and home cursor
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [rel cls_seq]  ; FIX: Added 'rel' for 64-bit compatibility
    mov rdx, cls_len
    syscall

    ; 2. Initialize Frame Buffer with blank spaces and newlines
    lea rdi, [rel frame_buf] ; FIX: Added 'rel' for 64-bit compatibility
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
    lea rcx, [rel sin_table]         ; FIX: Load base address into 64-bit register
    movzx rbx, word [rcx + rbx*2]    ; FIX: Explicit word pointer array index lookup
    
    movzx rdx, byte [rel angle_idx]
    add rdx, 2
    and rdx, 7
    lea rcx, [rel sin_table]         ; FIX: Load base address into 64-bit register
    movzx rdx, word [rcx + rdx*2]    ; FIX: Explicit word pointer array index lookup


    

    ; 2. Initialize Frame Buffer with blank spaces and newlines
    mov rdi, frame_buf
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
    movzx rbx, byte [angle_idx]
    mov rbx, [sin_table + rbx*2]  ; Get Sin value
    ; Simple Cosine approximation from shifted Sine array index
    movzx rdx, byte [angle_idx]
    add rdx, 2
    and rdx, 7
    mov rdx, [sin_table + rdx*2]  ; Get Cos value

    ; 4. Project and Rotate 8 Vertices
    xor rsi, rsi        ; Vertex index counter (0 to 7)
.rotate_vertices_loop:
    ; Fetch raw X, Y, Z coordinates
    movsx r8, word [vertices + rsi*6 + 0]
    movsx r9, word [vertices + rsi*6 + 2]
    movsx r10, word [vertices + rsi*6 + 4]

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
    ; Z offset = 60 to prevent division by zero
    add r12, 60         
    
    ; Screen X = CenterX + (X' * Distance) / Z'
    mov rax, r11
    imul word 40
    cqo
    idiv r12
    add rax, 40         ; Center X
    mov [rot_vertices + rsi*4 + 0], ax

    ; Screen Y = CenterY + (Y' * Distance) / Z'
    mov rax, r9
    imul word 20
    cqo
    idiv r12
    add rax, 11         ; Center Y
    mov [rot_vertices + rsi*4 + 2], ax

    inc rsi
    cmp rsi, 8
    jl .rotate_vertices_loop

    ; 5. Draw the 12 Edges connecting vertices (Bresenham-like sampling)
    xor rsi, rsi        ; Edge counter (0 to 11)
.draw_edges_loop:
    movzx rax, byte [edges + rsi*2 + 0] ; Vertex A index
    movzx rbx, byte [edges + rsi*2 + 1] ; Vertex B index

    ; Get screen positions of points A and B
    movsx r8, word [rot_vertices + rax*4 + 0]  ; X1
    movsx r9, word [rot_vertices + rax*4 + 2]  ; Y1
    movsx r10, word [rot_vertices + rbx*4 + 0] ; X2
    movsx r11, word [rot_vertices + rbx*4 + 2] ; Y2

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
    add rdi, frame_buf
    add rdi, rax
    mov byte [rdi], '*'  ; Draw line character

.skip_pixel:
    loop .draw_line_points

    inc rsi
    cmp rsi, 12
    jl .draw_edges_loop

    ; 6. Render Frame Buffer onto screen
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, frame_buf
    mov rdx, FRAME_SIZE
    syscall

    ; 7. Frame Rate Limiter (Sleep Delay)
    mov rax, 35         ; sys_nanosleep
    mov rdi, delay_tv
    xor rsi, rsi
    syscall

    ; 8. Increment angle table index to rotate frame
    inc byte [angle_idx]
    and byte [angle_idx], 7

    jmp .main_loop

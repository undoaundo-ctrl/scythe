; ==============================================================================
; Real-Time Digital Clock in Terminal (Linux x86_64, UTC/Local Epoch Time)
; Assemble: nasm -f elf64 clock2.asm -o clock2.o
; Link:     ld clock2.o -o clock2
; Run:      ./clock2  (Press Ctrl+C to exit)
; ==============================================================================

section .data
    ; ANSI Escape Codes to clear screen, hide cursor, and reset cursor position
    cls_seq      db 27, "[2J", 27, "[?25l", 27, "[H"
    cls_len      equ $ - cls_seq

    ; Reset sequence to show the text cursor when the program is killed
    reset_seq    db 27, "[?25h", 10
    reset_seq_len equ $ - reset_seq

    ; Static UI components
    border       db "=========================", 10
    border_len   equ $ - border
    label_text   db "  TIME (UTC): "
    label_len    equ $ - label_text

    ; System poll delay struct (1 second sleep intervals)
    delay_tv     dq 1, 0

section .bss
    time_struct  resq 2   ; Buffer for sys_gettimeofday (Seconds, Microseconds)
    out_buf      resb 8   ; Render buffer for "HH:MM:SS" string

section .text
    global _start

_start:
    ; Configure termination signal processing to keep terminal safe
    ; Pressing Ctrl+C exits cleanly. Use 'echo -e "\e[?25h"' if cursor stays hidden.

.main_loop:
    ; 1. Wipe the terminal clean and position cursor at top left
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [rel cls_seq]
    mov rdx, cls_len
    syscall

    ; 2. Print Top UI Line
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel border]
    mov rdx, border_len
    syscall

    ; 3. Print Time Header Title
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel label_text]
    mov rdx, label_len
    syscall

    ; 4. Fetch the absolute system epoch time via kernel space
    mov rax, 96         ; sys_gettimeofday [1]
    lea rdi, [rel time_struct]
    xor rsi, rsi        ; timezone struct null pointer
    syscall

    ; Extract total seconds component
    mov rax, [rel time_struct]

    ; NOTE OPTION: To shift this to your local timezone, add or subtract 
    ; the raw timezone offset seconds here before division math.
    ; Example for GMT+8: add rax, 28800

    ; 5. Convert Epoch seconds to current structural time values
    xor rdx, rdx
    mov rbx, 86400      ; 86400 seconds in a full calendar day
    div rbx             ; RDX = total accumulated seconds inside the current day

    mov rax, rdx        ; Move remaining seconds of the day to RAX
    xor rdx, rdx
    mov rbx, 3600       ; 3600 seconds per hour
    div rbx             ; RAX = Current Hour (0-23)
    push rdx            ; Save remaining seconds for minutes processing

    ; Format and write Hours to Output Buffer string
    lea rdi, [rel out_buf]
    call _format_two_digits
    mov byte [rdi], ':'
    inc rdi

    ; Parse Minutes component
    pop rax
    xor rdx, rdx
    mov rbx, 60         ; 60 seconds per minute
    div rbx             ; RAX = Current Minute (0-59)
    push rdx            ; Save remaining seconds for absolute seconds count

    ; Format and write Minutes to Output Buffer string
    call _format_two_digits
    mov byte [rdi], ':'
    inc rdi

    ; Parse Seconds component
    pop rax             ; RAX = Current Second (0-59)
    call _format_two_digits

    ; 6. Print the formatted "HH:MM:SS" time string
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [rel out_buf]
    mov rdx, 8          ; Exactly 8 characters long
    syscall

    ; Print closing layout elements
    mov rax, 1          
    mov rdi, 1          
    lea rsi, [rel border] ; Re-use line wrap format for bottom buffer border
    mov rdx, border_len
    syscall

    ; 7. Sleep for 1 exact second to stabilize processor load cycles
    mov rax, 35         ; sys_nanosleep
    lea rdi, [rel delay_tv]
    xor rsi, rsi
    syscall

    jmp .main_loop

; ==============================================================================
; HELPER FUNCTIONS
; ==============================================================================

; Formats a number between 0-59 into 2 ASCII characters with a leading zero padding.
; Inputs:  RAX = Integer value to parse, RDI = Destination pointer address
; Outputs: RDI = Incremented past the two generated character positions
_format_two_digits:
    push rbx
    push rdx
    xor rdx, rdx
    mov rbx, 10
    div rbx             ; RAX = Quotient (tens digit), RDX = Remainder (ones digit)

    add al, '0'         ; Offset to base ASCII character value
    mov [rdi], al
    inc rdi

    add dl, '0'         ; Offset to base ASCII character value
    mov [rdi], dl
    inc rdi

    pop rdx
    pop rbx
    ret

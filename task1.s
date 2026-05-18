section .bss
    char_buf resb 1          ; 1-byte buffer for sys_read/sys_write

section .data
    newline db 10            ; Newline character
    
    ; Encoder variables
    default_key db 'A', 0    ; Default key (shift by 0)
    key_ptr dd default_key   ; Pointer to the active key string
    key_idx dd 0             ; Current index in the key
    is_add  db 1             ; Boolean flag: 1 for addition (+V), 0 for subtraction (-V)

section .text
    global main
    extern strlen

main:
    ; ----------------------------------------------------
    ; 1. Set up Stack Frame
    ; ----------------------------------------------------
    push    ebp
    mov     ebp, esp
    sub     esp, 4           ; Local variable i = [ebp-4]
    mov     dword [ebp-4], 0 

.parse_args_loop:
    ; ----------------------------------------------------
    ; 2. Parse argv for +V and -V keys (and print them)
    ; ----------------------------------------------------
    mov     eax, [ebp-4]     ; i
    cmp     eax, [ebp+8]     ; compare i with argc
    jge     .encoder_loop    ; If done with args, start encoding

    ; Get argv[i]
    mov     edx, [ebp+12]    
    mov     ecx, [edx + eax*4] ; ecx = pointer to argv[i]
    
    ; Check for +V or -V
    mov     bl, [ecx]        ; First char of argv[i]
    cmp     bl, '+'
    je      .check_V
    cmp     bl, '-'
    je      .check_V
    jmp     .print_arg       ; Not + or -, just print it

.check_V:
    mov     bh, [ecx+1]      ; Second char
    cmp     bh, 'V'
    jne     .print_arg       ; If not 'V', just print it
    
    ; We found a Vigenere key!
    cmp     bl, '+'
    je      .set_add
    ; It's -V
    mov     byte [is_add], 0
    jmp     .set_key_ptr
.set_add:
    mov     byte [is_add], 1
    
.set_key_ptr:
    add     ecx, 2           ; Skip the "+V" or "-V" (argv[i] + 2)
    mov     [key_ptr], ecx   ; Save pointer to the key

.print_arg:
    ; Call strlen on argv[i]
    mov     edx, [ebp+12]
    mov     eax, [ebp-4]
    mov     ecx, [edx + eax*4]
    push    ecx
    call    strlen
    add     esp, 4
    
    ; sys_write argv[i]
    mov     edx, eax         ; Length
    mov     eax, [ebp-4]
    mov     ebx, [ebp+12]
    mov     ecx, [ebx + eax*4]
    mov     eax, 4
    mov     ebx, 1
    int     0x80

    ; sys_write newline
    mov     eax, 4
    mov     ebx, 1
    mov     ecx, newline
    mov     edx, 1
    int     0x80

    inc     dword [ebp-4]    ; i++
    jmp     .parse_args_loop

.encoder_loop:
    ; ----------------------------------------------------
    ; 3. Read char from stdin
    ; ----------------------------------------------------
    mov     eax, 3           ; sys_read
    mov     ebx, 0           ; stdin
    mov     ecx, char_buf    
    mov     edx, 1           
    int     0x80
    
    cmp     eax, 0           ; Check for EOF
    jle     .exit_prog
    
    ; ----------------------------------------------------
    ; 4. Vigenere Encoding Logic
    ; ----------------------------------------------------
    mov     al, [char_buf]   ; Load the read character into al
    
    ; Check bounds: is it a letter?
    cmp     al, 'A'
    jl      .print_char      ; Less than 'A', don't encode
    cmp     al, 'Z'
    jle     .is_upper        ; Between 'A' and 'Z'
    
    cmp     al, 'a'
    jl      .print_char      ; Between 'Z' and 'a', don't encode
    cmp     al, 'z'
    jle     .is_lower        ; Between 'a' and 'z'
    jmp     .print_char      ; Greater than 'z', don't encode

.is_upper:
    mov     bl, 'A'          ; Base = 'A'
    jmp     .do_encode

.is_lower:
    mov     bl, 'a'          ; Base = 'a'

.do_encode:
    ; Get shift from key: shift = key[key_idx] - 'A'
    mov     esi, [key_ptr]
    mov     edi, [key_idx]
    mov     cl, [esi + edi]  ; cl = key character
    sub     cl, 'A'          ; cl = shift amount (0 to 25)
    
    ; Check if addition or subtraction
    cmp     byte [is_add], 1
    je      .apply_shift
    neg     cl               ; If subtraction, shift = -shift

.apply_shift:
    sub     al, bl           ; c = c - base (0 to 25)
    add     al, cl           ; c = c + shift
    
    ; Modulo 26 logic in assembly (Wrap around)
.fix_underflow:
    cmp     al, 0
    jge     .fix_overflow
    add     al, 26           ; If negative, add 26
    jmp     .fix_underflow

.fix_overflow:
    cmp     al, 26
    jl      .finish_encode
    sub     al, 26           ; If >= 26, subtract 26
    jmp     .fix_overflow

.finish_encode:
    add     al, bl           ; c = c + base
    mov     [char_buf], al   ; Put encoded char back in buffer
    
    ; Advance key_idx
    inc     edi
    cmp     byte [esi + edi], 0 ; Check for null terminator '\0'
    jne     .save_idx
    mov     edi, 0           ; Reset to 0 if end of key
.save_idx:
    mov     [key_idx], edi

.print_char:
    ; ----------------------------------------------------
    ; 5. Write char to stdout
    ; ----------------------------------------------------
    mov     eax, 4           ; sys_write
    mov     ebx, 1           ; stdout
    mov     ecx, char_buf
    mov     edx, 1
    int     0x80
    
    jmp     .encoder_loop    ; Read next character

.exit_prog:
    ; ----------------------------------------------------
    ; 6. Exit
    ; ----------------------------------------------------
    mov     eax, 1           ; sys_exit
    mov     ebx, 0           
    int     0x80
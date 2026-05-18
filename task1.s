section .bss
    char_buf resb 1          ; 1-byte buffer for sys_read/sys_write

section .data
    newline db 10            ; Newline character
    
    infile_fd  dd 0          ; File descriptor for input (Default: 0 for stdin)
    outfile_fd dd 1          ; File descriptor for output (Default: 1 for stdout)
    
    default_key db 'A', 0    ; Default key (shift by 0)
    key_ptr dd default_key   ; Pointer to the active key string
    key_idx dd 0             ; Current index in the key

section .text
    global main
    extern strlen

main:
    ; ====================================================
    ; SECTION 1: Set up Stack Frame
    ; ====================================================
    push    ebp
    mov     ebp, esp
    sub     esp, 4           ; Local variable i = [ebp-4]
    mov     dword [ebp-4], 0 

.parse_args_loop:
    ; ====================================================
    ; SECTION 2: Parse argv for +V, -i, and -o
    ; ====================================================
    mov     eax, [ebp-4]     ; load i
    cmp     eax, [ebp+8]     ; compare i with argc
    jge     .encoder_loop    ; If done with args, jump to encoder loop

    ; Get pointer to argv[i]
    mov     edx, [ebp+12]    
    mov     ecx, [edx + eax*4] ; ecx = pointer to argv[i]
    
    mov     bl, [ecx]        ; First char of argv[i]
    mov     bh, [ecx+1]      ; Second char of argv[i]
    
    cmp     bl, '+'
    je      .check_V
    cmp     bl, '-'
    je      .check_io
    jmp     .print_arg       ; Not + or -, just print it

.check_V:
    cmp     bh, 'V'
    jne     .print_arg       ; If not '+V', print it
    add     ecx, 2           ; Skip "+V"
    mov     [key_ptr], ecx   ; Save pointer to the key
    jmp     .print_arg

.check_io:
    cmp     bh, 'i'
    je      .setup_infile
    cmp     bh, 'o'
    je      .setup_outfile
    jmp     .print_arg       ; If not -i or -o, print it

.setup_infile:
    ; ====================================================
    ; SECTION 3A: Open Input File
    ; ====================================================
    add     ecx, 2           ; Skip "-i" to get the filename pointer
    mov     eax, 5           ; sys_open (syscall 5)
    mov     ebx, ecx         ; Arg 1: pointer to filename
    mov     ecx, 0           ; Arg 2: flags (0 = O_RDONLY)
    mov     edx, 0           ; Arg 3: mode (not needed for read)
    int     0x80
    mov     [infile_fd], eax ; Save the returned file descriptor
    jmp     .print_arg

.setup_outfile:
    ; ====================================================
    ; SECTION 3B: Open Output File
    ; ====================================================
    add     ecx, 2           ; Skip "-o" to get the filename pointer
    mov     eax, 5           ; sys_open (syscall 5)
    mov     ebx, ecx         ; Arg 1: pointer to filename
    mov     ecx, 577         ; Arg 2: flags (577 = O_WRONLY | O_CREAT | O_TRUNC)
    mov     edx, 420         ; Arg 3: mode (420 dec = 0644 octal permissions)
    int     0x80
    mov     [outfile_fd], eax; Save the returned file descriptor

.print_arg:
    ; ====================================================
    ; SECTION 4: Print the current argument to stdout
    ; ====================================================
    mov     edx, [ebp+12]
    mov     eax, [ebp-4]
    mov     ecx, [edx + eax*4]
    push    ecx
    call    strlen
    add     esp, 4
    
    mov     edx, eax         ; Length
    mov     eax, [ebp-4]
    mov     ebx, [ebp+12]
    mov     ecx, [ebx + eax*4]
    mov     eax, 4           ; sys_write
    mov     ebx, 1           ; Always print args to stdout (1)
    int     0x80

    mov     eax, 4
    mov     ebx, 1
    mov     ecx, newline
    mov     edx, 1
    int     0x80

    inc     dword [ebp-4]    ; i++
    jmp     .parse_args_loop

.encoder_loop:
    ; ====================================================
    ; SECTION 5: Read from Input File (or stdin)
    ; ====================================================
    mov     eax, 3           ; sys_read (syscall 3)
    mov     ebx, [infile_fd] ; Read from our dynamic input FD
    mov     ecx, char_buf    
    mov     edx, 1           
    int     0x80
    
    cmp     eax, 0           ; Check for EOF or Error
    jle     .cleanup_and_exit
    
    ; ====================================================
    ; SECTION 6: Vigenere Encoding (Addition Only)
    ; ====================================================
    mov     al, [char_buf]   ; Load character
    
    ; Bounds checking
    cmp     al, 'A'
    jl      .write_char      
    cmp     al, 'Z'
    jle     .is_upper        
    cmp     al, 'a'
    jl      .write_char      
    cmp     al, 'z'
    jle     .is_lower        
    jmp     .write_char      

.is_upper:
    mov     bl, 'A'          ; Base for uppercase
    jmp     .do_encode

.is_lower:
    mov     bl, 'a'          ; Base for lowercase

.do_encode:
    ; Get shift from key
    mov     esi, [key_ptr]
    mov     edi, [key_idx]
    mov     cl, [esi + edi]  
    sub     cl, 'A'          ; Shift amount (0-25)
    
    sub     al, bl           ; c = c - base
    add     al, cl           ; c = c + shift
    
    ; Modulo 26 for addition
.fix_overflow:
    cmp     al, 26
    jl      .finish_encode
    sub     al, 26           ; If >= 26, subtract 26
    jmp     .fix_overflow

.finish_encode:
    add     al, bl           ; c = c + base
    mov     [char_buf], al   ; Put back in buffer
    
    ; Advance key index
    inc     edi
    cmp     byte [esi + edi], 0 
    jne     .save_idx
    mov     edi, 0           ; Reset if end of key
.save_idx:
    mov     [key_idx], edi

.write_char:
    ; ====================================================
    ; SECTION 7: Write to Output File (or stdout)
    ; ====================================================
    mov     eax, 4           ; sys_write
    mov     ebx, [outfile_fd]; Write to our dynamic output FD
    mov     ecx, char_buf
    mov     edx, 1
    int     0x80
    
    jmp     .encoder_loop    ; Loop to next character

.cleanup_and_exit:
    ; ====================================================
    ; SECTION 8: Cleanup and Exit
    ; ====================================================
    ; Close infile if it's not stdin
    mov     ebx, [infile_fd]
    cmp     ebx, 0
    je      .close_outfile
    mov     eax, 6           ; sys_close (syscall 6)
    int     0x80

.close_outfile:
    ; Close outfile if it's not stdout
    mov     ebx, [outfile_fd]
    cmp     ebx, 1
    je      .exit_prog
    mov     eax, 6           ; sys_close
    int     0x80

.exit_prog:
    mov     eax, 1           ; sys_exit
    mov     ebx, 0           
    int     0x80
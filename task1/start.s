section .bss
    char_buf resb 1          ; 1-byte buffer used to read/write a single character

section .data
    newline db 10            ; ASCII code for a newline character ('\n')
    
    infile_fd  dd 0          ; File descriptor for input (Default: 0 for stdin)
    outfile_fd dd 1          ; File descriptor for output (Default: 1 for stdout)
    
    default_key db 'A', 0    ; Default key (shift by 0, 'A'-'A' = 0)
    key_ptr dd default_key   ; Pointer to the active key string
    key_idx dd 0             ; Current index in the key string

section .text
    global _start
    global system_call
    extern strlen            ; We need strlen from util.c to print arguments

; ------------------------------------------------------------------------------
; LAB PROVIDED GLUE CODE
; _start sets up the stack frame with argc and argv, then calls main.
; ------------------------------------------------------------------------------
_start:
    pop     dword ecx        ; Get argc from the stack
    mov     esi, esp         ; Get pointer to argv array
    push    esi              ; Push argv as second argument to main
    push    ecx              ; Push argc as first argument to main
    call    main             ; call our internal main function
    
    mov     ebx, eax         ; Move main's return value into exit status
    mov     eax, 1           ; sys_exit
    int     0x80
    nop

; ------------------------------------------------------------------------------
; LAB PROVIDED GLUE CODE
; system_call wrapper to easily execute interrupts from C (if needed)
; ------------------------------------------------------------------------------
system_call:
    push    ebp              
    mov     ebp, esp
    sub     esp, 4           
    pushad                   
    mov     eax, [ebp+8]     
    mov     ebx, [ebp+12]    
    mov     ecx, [ebp+16]    
    mov     edx, [ebp+20]    
    int     0x80             
    mov     [ebp-4], eax     
    popad                    
    mov     eax, [ebp-4]     
    add     esp, 4           
    pop     ebp              
    ret                      

; ------------------------------------------------------------------------------
; TASK 1.C: MAIN FUNCTION (Vigenere Encoder)
; ------------------------------------------------------------------------------
main:
    push    ebp
    mov     ebp, esp
    sub     esp, 4           ; Allocate local variable 'i' = [ebp-4]
    mov     dword [ebp-4], 0 

.parse_args_loop:
    mov     eax, [ebp-4]     
    cmp     eax, [ebp+8]     
    jge     .encoder_loop    ; If done parsing args, jump to encoder loop

    mov     edx, [ebp+12]    
    mov     ecx, [edx + eax*4] ; Get argv[i] pointer
    
    mov     bl, [ecx]        ; First char
    mov     bh, [ecx+1]      ; Second char
    
    cmp     bl, '+'
    je      .check_V
    cmp     bl, '-'
    je      .check_io
    jmp     .print_arg       ; Not a flag, just print it

.check_V:
    cmp     bh, 'V'
    jne     .print_arg       
    add     ecx, 2           ; Skip "+V"
    mov     [key_ptr], ecx   ; Save the remaining string as our key
    jmp     .print_arg

.check_io:
    cmp     bh, 'i'
    je      .setup_infile
    cmp     bh, 'o'
    je      .setup_outfile
    jmp     .print_arg

.setup_infile:
    add     ecx, 2           ; Skip "-i"
    mov     eax, 5           ; sys_open
    mov     ebx, ecx         
    mov     ecx, 0           ; O_RDONLY
    mov     edx, 0           
    int     0x80
    mov     [infile_fd], eax ; Save new input FD
    jmp     .print_arg

.setup_outfile:
    add     ecx, 2           ; Skip "-o"
    mov     eax, 5           ; sys_open
    mov     ebx, ecx         
    mov     ecx, 577         ; O_WRONLY | O_CREAT | O_TRUNC
    mov     edx, 0644o       
    int     0x80
    mov     [outfile_fd], eax; Save new output FD

.print_arg:
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
    mov     ebx, 1           ; Always print args to stdout
    int     0x80

    mov     eax, 4
    mov     ebx, 1
    mov     ecx, newline
    mov     edx, 1
    int     0x80

    inc     dword [ebp-4]    
    jmp     .parse_args_loop

.encoder_loop:
    mov     eax, 3           ; sys_read
    mov     ebx, [infile_fd] 
    mov     ecx, char_buf    
    mov     edx, 1           
    int     0x80
    
    cmp     eax, 0           ; Check for EOF or Error
    jle     .cleanup_and_exit
    
    mov     al, [char_buf]   
    
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
    mov     bl, 'A'
    jmp     .do_encode
.is_lower:
    mov     bl, 'a'

.do_encode:
    mov     esi, [key_ptr]
    mov     edi, [key_idx]
    mov     cl, [esi + edi]  
    sub     cl, 'A'          ; Shift amount (0 to 25)
    
    sub     al, bl           ; Subtract Base
    add     al, cl           ; Apply Shift
    
.fix_overflow:
    cmp     al, 26
    jl      .finish_encode
    sub     al, 26           ; Wrap around
    jmp     .fix_overflow

.finish_encode:
    add     al, bl           ; Add Base back
    mov     [char_buf], al   
    
    inc     edi
    cmp     byte [esi + edi], 0 
    jne     .save_idx
    mov     edi, 0           ; Reset key loop
.save_idx:
    mov     [key_idx], edi

.write_char:
    mov     eax, 4           ; sys_write
    mov     ebx, [outfile_fd]
    mov     ecx, char_buf
    mov     edx, 1
    int     0x80
    
    jmp     .encoder_loop

.cleanup_and_exit:
    mov     ebx, [infile_fd]
    cmp     ebx, 0
    je      .close_outfile
    mov     eax, 6           ; sys_close
    int     0x80

.close_outfile:
    mov     ebx, [outfile_fd]
    cmp     ebx, 1
    je      .exit_main
    mov     eax, 6           ; sys_close
    int     0x80

.exit_main:
    mov     eax, 0
    mov     esp, ebp
    pop     ebp
    ret
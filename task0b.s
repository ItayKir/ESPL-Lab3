section .data
    ; Define the string we want to print. '10' is the ASCII code for a newline character ('\n')
    msg db 'RELIC IS KING', 10  
    
    ; Calculate the length of the string automatically
    ; '$' means current memory location, so $ - msg gives the total bytes.
    len equ $ - msg           

section .text
    global _start             ; Declare _start as global so the linker (ld) can find it

; The entry point of the program
_start:
    ; ----------------------------------------------------
    ; 1. Perform sys_write (System Call Number 4)
    ; ----------------------------------------------------
    mov eax, 4      ; eax holds the system call number. 4 = sys_write
    mov ebx, 1      ; ebx holds the first argument. 1 = standard output (stdout)
    mov ecx, msg    ; ecx holds the second argument. Pointer to the start of our string
    mov edx, len    ; edx holds the third argument. The length of the string to print
    int 0x80        ; Software interrupt: Hand over control to the Linux kernel to execute

    ; ----------------------------------------------------
    ; 2. Perform sys_exit (System Call Number 1)
    ; ----------------------------------------------------
    mov eax, 1      ; eax holds the system call number. 1 = sys_exit
    mov ebx, 0      ; ebx holds the first argument. 0 = exit status (success)
    int 0x80        ; Software interrupt: Hand over control to the kernel to terminate the program
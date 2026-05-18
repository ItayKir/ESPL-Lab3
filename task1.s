section .data
    newline db 10            ; ASCII code for a newline character ('\n')

section .text
    global main              ; Make main visible to the linker (called by start.s)
    extern strlen            ; Tell NASM that strlen exists externally (in util.c)

main:
    ; ----------------------------------------------------
    ; 1. Set up the Stack Frame (CDECL Convention)
    ; ----------------------------------------------------
    push    ebp              ; Save the caller's base pointer
    mov     ebp, esp         ; Set the base pointer for this function
    sub     esp, 4           ; Allocate 4 bytes on the stack for a local variable (i)
    
    mov     dword [ebp-4], 0 ; Initialize loop counter (i = 0)

.print_loop:
    ; ----------------------------------------------------
    ; 2. Loop Condition: if (i >= argc) break;
    ; ----------------------------------------------------
    mov     eax, [ebp-4]     ; Load i into eax
    cmp     eax, [ebp+8]     ; Compare i with argc (located at ebp+8)
    jge     .exit_prog       ; If i >= argc, jump to exit

    ; ----------------------------------------------------
    ; 3. Get the pointer to argv[i]
    ; ----------------------------------------------------
    mov     edx, [ebp+12]    ; Load the base address of the argv array into edx
    mov     ecx, [edx + eax*4] ; Load the string pointer at argv[i] into ecx (eax*4 because pointers are 4 bytes)

    ; ----------------------------------------------------
    ; 4. Call strlen(argv[i])
    ; ----------------------------------------------------
    push    ecx              ; Push the string pointer as the argument for strlen
    call    strlen           ; Call the C function from util.c
    add     esp, 4           ; Clean up the stack (remove the argument we pushed)
    ; The length of the string is now in the eax register

    ; ----------------------------------------------------
    ; 5. System Call: sys_write(stdout, argv[i], length)
    ; ----------------------------------------------------
    mov     edx, eax         ; Move the string length into edx (Arg 3)
    
    ; Re-fetch the string pointer into ecx (Arg 2) because calling strlen might have modified ecx
    mov     eax, [ebp-4]     ; Load i
    mov     ebx, [ebp+12]    ; Load argv base address
    mov     ecx, [ebx + eax*4] ; ecx = pointer to argv[i]
    
    mov     eax, 4           ; System call number 4 = sys_write
    mov     ebx, 1           ; File descriptor 1 = stdout (Arg 1)
    int     0x80             ; Execute the system call

    ; ----------------------------------------------------
    ; 6. System Call: sys_write(stdout, "\n", 1)
    ; ----------------------------------------------------
    mov     eax, 4           ; System call number 4 = sys_write
    mov     ebx, 1           ; File descriptor 1 = stdout
    mov     ecx, newline     ; Pointer to the newline character
    mov     edx, 1           ; Length = 1 byte
    int     0x80             ; Execute the system call

    ; ----------------------------------------------------
    ; 7. Increment counter and repeat
    ; ----------------------------------------------------
    inc     dword [ebp-4]    ; i++
    jmp     .print_loop      ; Jump back to the start of the loop

.exit_prog:
    ; ----------------------------------------------------
    ; 8. System Call: sys_exit(0)
    ; ----------------------------------------------------
    mov     eax, 1           ; System call number 1 = sys_exit
    mov     ebx, 0           ; Exit status code = 0 (Success)
    int     0x80             ; Execute the system call
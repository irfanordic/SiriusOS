[org 0x7c00]  ;

cli

lgdt [gdt_descriptor]

mov eax, cr0
or  eax, 0x1
mov cr0, eax

jmp 0x08:gdt_init


gdt_start:
    dq 0x0

gdt_code:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0

gdt_data:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b    ; Flags: Present, Privilege (Ring 0), Data, Read/Write
    db 11001111b
    db 0x0


gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[bits 32]    

gdt_init:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ebp, 0x90000
    mov esp, ebp

    

mov ebx , hello_msg  ;
mov edx, 0xB8000   ;
mov ah, 0x0f


print_loop:
    mov al, [ebx]
    cmp al, 0   ;
    je halt     ;

    mov [edx], ax

    add ebx, 1
    add edx, 2    

    jmp print_loop ;

halt:

    cli         ;
    hlt         ;


hello_msg:
    db 'hello wendy , thsi is siriusOS!', 0 ;
    

    


times 510-($-$$) db 0
dw 0xaa55    



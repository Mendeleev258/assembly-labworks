.model small
.stack 100h

.data
    array dw 100 dup(?)     ; numbers array
    array_length dw ?       ; array length
    
    ; output messages
    msg_yes db 'YES: Signs alternate$'
    msg_no db 'NO: Signs do not alternate$'
    newline db 13, 10, '$'
    msg_enter_length db 'Enter array length: $'
    msg_enter_element db 'Enter element: $'
    msg_array db 'Array: $'
    msg_space db ' $'

.code
main proc
    mov ax, @data
    mov ds, ax
    
    call input_array_length
    call input_array
    call print_array
    
    push array_length         
    lea ax, array
    push ax                   
    call check_sign_alternation
    add sp, 4 ; stack clean (2+2=4 bytes)
    
    mov ah, 4Ch
    int 21h
main endp

; Input array length
input_array_length proc
    mov ah, 09h
    lea dx, msg_enter_length
    int 21h
    
    call input_number
    mov array_length, ax
    
    mov ah, 09h
    lea dx, newline
    int 21h
    ret
input_array_length endp

; Input array elements
input_array proc
    mov cx, array_length
    mov si, 0
    
input_loop:
    mov ah, 09h
    lea dx, msg_enter_element
    int 21h
    
    call input_number
    mov array[si], ax
    
    add si, 2
    loop input_loop
    
    mov ah, 09h
    lea dx, newline
    int 21h
    ret
input_array endp

; Print array
print_array proc
    mov ah, 09h
    lea dx, msg_array
    int 21h
    
    mov cx, array_length
    mov si, 0
    
print_loop:
    mov ax, array[si]
    call print_number
    
    mov ah, 09h
    lea dx, msg_space
    int 21h
    
    add si, 2
    loop print_loop
    
    mov ah, 09h
    lea dx, newline
    int 21h
    ret
print_array endp

; Input number (signed)
input_number proc
    push bx
    push cx
    push dx
    
    xor bx, bx ; reset number
    xor cx, cx ; sign flag (0 - positive)
    
    mov ah, 01h ; input char
    int 21h
    
    cmp al, '-' ; check for negative
    jne process_digit
    mov cx, 1 ; set negative flag
    jmp next_char

next_char:
    mov ah, 01h ; input next char
    int 21h

process_digit:
    cmp al, 13  ; Enter - end of input
    je end_input
    
    cmp al, '0'
    jb end_input
    cmp al, '9'
    ja end_input
    
    sub al, '0' ; convert into a digit
    mov ah, 0
    
    ; bx = bx * 10 + ax
    push ax ; save new digit
    mov ax, bx
    mov dx, 10 
    mul dx
    mov bx, ax
    pop ax
    add bx, ax
    
    mov ah, 01h ; input next char
    int 21h
    jmp process_digit

end_input:
    mov ax, bx
    
    cmp cx, 0     ; check sign
    je positive_num
    neg ax
    
positive_num:
    pop dx
    pop cx
    pop bx
    ret
input_number endp

; Print number (signed)
print_number proc
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10 ; number system base
    xor cx, cx ; digit counter
    
    test ax, ax ; check sign
    jns positive_print
    neg ax ; absolute value
    push ax
    
    mov ah, 02h
    mov dl, '-'
    int 21h
    
    pop ax

positive_print:
    xor dx, dx
    div bx ; ax = ax/10, dx = remainder
    push dx ; save digit
    inc cx
    
    test ax, ax
    jnz positive_print
    
print_digits:
    pop dx
    add dl, '0' ; convert into a symbol
    mov ah, 02h
    int 21h
    loop print_digits
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_number endp

; Check if signs alternate in array
check_sign_alternation proc
    push bp
    mov bp, sp
    
    ; parameters:
    ; [bp+4] = array address
    ; [bp+6] = array length
    
    mov cx, [bp+6] ; array length
    cmp cx, 1
    jle yes_result ; array with 0 or 1 element always alternates
    
    mov si, [bp+4] ; array address
    
    ; Get sign of first element
    mov ax, [si]
    call get_sign
    mov bl, al ; previous sign in BL
    
    add si, 2 ; move to next element
    dec cx ; we'll check n-1 pairs
    
check_loop:
    mov ax, [si] ; load current element
    call get_sign
    mov bh, al ; current sign in BH
    
    ; Compare signs
    cmp bh, bl
    je no_result ; if signs are equal - not alternating
    
    ; Update previous sign
    mov bl, bh
    
    add si, 2 ; move to next element
    loop check_loop
    
yes_result:
    mov ah, 09h
    lea dx, msg_yes
    int 21h
    jmp finish

no_result:
    mov ah, 09h
    lea dx, msg_no
    int 21h

finish:
    mov ah, 09h
    lea dx, newline
    int 21h
    
    pop bp
    ret
check_sign_alternation endp

; Get sign of number
; Input: AX = number
; Output: AL = 0 if negative, 1 if positive or zero
get_sign proc
    push bx
    test ax, ax
    jl negative
    mov al, 1 ; positive or zero
    jmp sign_end
negative:
    mov al, 0 ; negative
sign_end:
    pop bx
    ret
get_sign endp

end main
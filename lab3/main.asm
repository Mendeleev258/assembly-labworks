.model small
.stack 100h

.data
    buffer_size equ 200
    text_buffer db buffer_size, 0, buffer_size + 2 dup('$')
    input_msg db 'Enter text: $'
    result_msg db 0Dh, 0Ah, 'Modified text: $'
    new_line db 0Dh, 0Ah, '$'
    empty_msg db 'No text entered!$'
    press_any_key db 0Dh, 0Ah, 'Press any key to exit...$'
    max_spaces dw 0
    modified_text db buffer_size + 2 dup('$')

.code

; Процедура вывода новой строки
print_new_line proc
    push ax
    push dx
    mov ah, 09h
    lea dx, new_line
    int 21h
    pop dx
    pop ax
    ret
print_new_line endp

; Процедура ввода текста
input_text_buffered proc
    push ax
    push dx
    
    mov ah, 09h
    mov dx, offset input_msg
    int 21h
    
    mov ah, 0Ah
    mov dx, offset text_buffer
    int 21h
    
    mov al, text_buffer[1]
    cmp al, 0
    je empty_input
    jmp input_done
    
empty_input:
    mov ah, 09h
    mov dx, offset empty_msg
    int 21h
    call print_new_line
    mov ax, 4C00h
    int 21h
    
input_done:
    pop dx
    pop ax
    ret
input_text_buffered endp

; Процедура поиска максимального количества пробелов между словами
find_max_spaces proc
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si
    push di
    
    mov si, [bp+4]      ; адрес текста
    mov di, [bp+6]      ; адрес max_spaces
    mov word ptr [di], 0
    
    mov cl, text_buffer[1]
    mov ch, 0
    jcxz find_done
    
    mov bx, 0              ; счетчик текущих пробелов
    
scan_loop:
    mov al, [si]
    inc si
    dec cx
    
    cmp al, '.'             ; конец текста
    je check_final
    
    cmp al, ' '
    jne not_space
    inc bx                  ; пробел - увеличиваем счетчик
    jmp next_char
    
not_space:
    ; Не пробел - проверяем последовательность пробелов
    cmp bx, 0
    je no_spaces
    
    ; Обновляем максимум если нужно
    cmp bx, [di]
    jle reset_count
    mov [di], bx
    
reset_count:
    mov bx, 0
    
no_spaces:
next_char:
    jcxz check_final
    jmp scan_loop
    
check_final:
    ; Проверяем пробелы перед точкой
    cmp bx, [di]
    jle find_done
    mov [di], bx
    
find_done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
find_max_spaces endp

; Процедура уменьшения максимального количества пробелов
reduce_max_spaces proc
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov si, [bp+4]      ; исходный текст
    mov di, [bp+6]      ; модифицированный текст
    mov dx, [bp+8]      ; максимальное количество пробелов
    
    ; Если максимум <= 1, просто копируем текст
    cmp dx, 1
    jle copy_all
    
    mov cl, text_buffer[1]
    mov ch, 0
    jcxz reduce_done
    
    mov bx, 0              ; счетчик текущих пробелов
    
process_text_loop:
    mov al, [si]
    inc si
    dec cx
    
    cmp al, '.'             ; конец текста
    je end_of_text
    
    cmp al, ' '
    jne not_space_char
    
    ; Это пробел
    inc bx
    jmp next_char_process
    
not_space_char:
    ; Не пробел - обрабатываем предыдущие пробелы
    cmp bx, 0
    je write_current_char  ; если пробелов не было, просто пишем символ
    
    ; Проверяем, нужно ли уменьшать пробелы
    cmp bx, dx
    jne write_spaces_normal
    
    ; Уменьшаем максимальную последовательность на 1
    push ax                 ; СОХРАНЯЕМ текущий символ!
    mov al, ' '
    push cx
    mov cx, bx
    dec cx                  ; уменьшаем на 1
    jz after_reduce         ; если стало 0, не пишем пробелы
    
write_reduced:
    stosb                   ; записываем пробел
    loop write_reduced
    
after_reduce:
    pop cx
    pop ax                  ; ВОССТАНАВЛИВАЕМ текущий символ!
    jmp write_current_char
    
write_spaces_normal:
    ; Пишем пробелы без изменений
    push ax                 ; СОХРАНЯЕМ текущий символ!
    mov al, ' '
    push cx
    mov cx, bx
write_spaces:
    stosb                   ; записываем пробел
    loop write_spaces
    pop cx
    pop ax                  ; ВОССТАНАВЛИВАЕМ текущий символ!
    
write_current_char:
    ; Пишем текущий символ (букву)
    stosb                   ; записываем символ слова
    mov bx, 0              ; сбрасываем счетчик пробелов
    
next_char_process:
    jcxz end_of_text
    jmp process_text_loop
    
end_of_text:
    ; Обработка пробелов перед точкой
    cmp bx, 0
    je add_final_dot
    
    cmp bx, dx
    jne write_final_spaces_normal
    
    ; Уменьшаем конечные пробелы
    mov al, ' '
    mov cx, bx
    dec cx
    jz add_final_dot
    
write_final_reduced:
    stosb
    loop write_final_reduced
    jmp add_final_dot
    
write_final_spaces_normal:
    mov al, ' '
    mov cx, bx
write_final_spaces:
    stosb
    loop write_final_spaces
    
add_final_dot:
    mov al, '.'
    stosb
    jmp reduce_done
    
copy_all:
    ; Просто копируем весь текст
    mov si, [bp+4]
    mov di, [bp+6]
    mov cl, text_buffer[1]
    mov ch, 0
    rep movsb
    
reduce_done:
    ; Добавляем терминатор строки
    mov al, '$'
    mov [di], al
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6
reduce_max_spaces endp

; Основная процедура обработки текста
process_text_main proc
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Находим максимальное количество пробелов
    push offset max_spaces
    push [bp+4]
    call find_max_spaces
    
    ; Уменьшаем максимальное количество пробелов
    push max_spaces
    push [bp+6]
    push [bp+4]
    call reduce_max_spaces
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
process_text_main endp

; Главная процедура программы
main:
    mov ax, @data
    mov ds, ax
    mov es, ax

    ; Ввод текста
    call input_text_buffered
    call print_new_line

    ; Вывод исходного текста
    mov ah, 09h
    mov dx, offset text_buffer + 2
    int 21h

    ; Обработка текста
    push offset modified_text
    push offset text_buffer + 2
    call process_text_main

    call print_new_line

    ; Вывод модифицированного текста
    mov ah, 09h
    mov dx, offset result_msg
    int 21h
    
    mov ah, 09h
    mov dx, offset modified_text
    int 21h

    call print_new_line

    ; Ожидание нажатия любой клавиши
    mov ah, 09h
    mov dx, offset press_any_key
    int 21h
    
    mov ah, 01h
    int 21h

    mov ax, 4C00h
    int 21h

end main
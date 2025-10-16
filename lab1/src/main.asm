.model small
.stack 100h

.data
    ; Исходный массив чисел
    array dw 5, -3, 8, -2, 6, -4, 7, -1, 9, -5
    array_length dw 10
    
    ; Сообщения
    msg_alternating db 'YES$'    ; Знаки чередуются
    msg_not_alternating db 'NO$' ; Знаки не чередуются

.code
main proc
    ; Инициализация сегментных регистров
    mov ax, @data
    mov ds, ax
    
    ; Проверка чередования знаков
    call check_sign_alternation
    
    ; Завершение программы
    mov ah, 4Ch
    mov al, 0
    int 21h
main endp

; Процедура проверки чередования знаков
check_sign_alternation proc
    mov cx, [array_length]
    dec cx                  ; Проверяем n-1 пар
    jz alternating          ; Если массив из одного элемента - считаем чередующимся
    
    mov si, offset array
    
    ; Определяем знак первого элемента
    mov ax, [si]
    call get_sign
    mov bl, al              ; BL = предыдущий знак
    
    add si, 2               ; Переходим ко второму элементу
    
check_loop:
    ; Получаем знак текущего элемента
    mov ax, [si]
    call get_sign
    mov bh, al              ; BH = текущий знак
    
    ; Сравниваем с предыдущим знаком
    cmp bh, bl
    je not_alternating      ; Если знаки одинаковые - не чередуются
    
    ; Сохраняем текущий знак как предыдущий для следующей итерации
    mov bl, bh
    
    ; Следующий элемент
    add si, 2
    loop check_loop
    
alternating:
    ; Вывод "YES"
    mov ah, 09h
    mov dx, offset msg_alternating
    int 21h
    jmp check_end

not_alternating:
    ; Вывод "NO"
    mov ah, 09h
    mov dx, offset msg_not_alternating
    int 21h

check_end:
    ret
check_sign_alternation endp

; Процедура определения знака числа
; Возвращает: AL = 0 если число отрицательное, AL = 1 если положительное
get_sign proc
    cmp ax, 0
    jl negative
    mov al, 1              ; Положительное число
    jmp sign_end
negative:
    mov al, 0              ; Отрицательное число
sign_end:
    ret
get_sign endp

end main
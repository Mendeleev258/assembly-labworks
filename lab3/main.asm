.model small
.stack 100h

.data
    buffer_size equ 200                    ; Константа размера буфера
    text_buffer db buffer_size, 0, buffer_size + 2 dup('$')   ; Буфер для ввода текста
    ; Структура буфера DOS: 
    ; [0] - максимальная длина
    ; [1] - фактическая длина (заполняется DOS)
    ; [2...] - сам текст
    input_msg db 'Enter text: $'           ; Приглашение для ввода
    result_msg db 0Dh, 0Ah, 'Modified text: $' ; Сообщение результата
    new_line db 0Dh, 0Ah, '$'              ; Перевод строки (CR+LF)
    empty_msg db 'No text entered!$'       ; Сообщение об ошибке
    press_any_key db 0Dh, 0Ah, 'Press any key to exit...$' ; Сообщение ожидания
    max_spaces dw 0                        ; Переменная для хранения максимального количества пробелов
    modified_text db buffer_size + 2 dup('$') ; Буфер для модифицированного текста

.code

; Процедура вывода новой строки
; Не принимает параметров, не возвращает значений
print_new_line proc
    push ax                    ; Сохраняем AX (используется как временный)
    push dx                    ; Сохраняем DX (будет содержать адрес строки)
    mov ah, 09h                ; Функция DOS 09h - вывод строки
    lea dx, new_line           ; DX = адрес строки с переводом строки
    int 21h                    ; Вызов прерывания DOS
    pop dx                     ; Восстанавливаем DX
    pop ax                     ; Восстанавливаем AX
    ret                        ; Возврат из процедуры
print_new_line endp

; Процедура ввода текста с клавиатуры
; Использует буферизованный ввод DOS
input_text_buffered proc
    push ax
    push dx
    
    ; Вывод приглашения для ввода
    mov ah, 09h                ; Функция вывода строки
    mov dx, offset input_msg   ; DX = адрес строки "Enter text: "
    int 21h
    
    ; Буферизованный ввод текста
    mov ah, 0Ah                ; Функция 0Ah - буферизованный ввод
    mov dx, offset text_buffer ; DX = адрес буфера для ввода
    int 21h
    
    ; Проверка на пустой ввод
    mov al, text_buffer[1]     ; AL = фактическая длина введенного текста
    cmp al, 0                  ; Сравниваем с 0
    je empty_input             ; Если длина = 0, переходим к обработке пустого ввода
    jmp input_done             ; Иначе завершаем процедуру
    
empty_input:
    mov ah, 09h
    mov dx, offset empty_msg   ; Вывод сообщения "No text entered!"
    int 21h
    call print_new_line
    mov ax, 4C00h              ; Завершение программы с кодом 0
    int 21h
    
input_done:
    pop dx
    pop ax
    ret
input_text_buffered endp

; Процедура поиска максимального количества пробелов между словами
; Параметры через стек:
;   [bp+4] - адрес текста (исходный текст)
;   [bp+6] - адрес переменной max_spaces (для результата)
find_max_spaces proc
    push bp                    ; Сохраняем базовый указатель
    mov bp, sp                 ; BP = SP для доступа к параметрам через стек
    push ax                    ; Сохраняем регистры, которые будем использовать
    push bx                    ; BX - счетчик текущих пробелов
    push cx                    ; CX - счетчик оставшихся символов
    push si                    ; SI - указатель на текущий символ в тексте
    push di                    ; DI - адрес переменной max_spaces
    
    ; Получаем параметры из стека
    mov si, [bp+4]             ; SI = адрес начала текста
    mov di, [bp+6]             ; DI = адрес переменной max_spaces
    mov word ptr [di], 0       ; Инициализируем max_spaces = 0
    
    ; Получаем длину текста
    mov cl, text_buffer[1]     ; CL = длина текста (из буфера DOS)
    mov ch, 0                  ; CH = 0 (теперь CX = длина текста)
    jcxz find_done             ; Если длина = 0, завершаем
    
    mov bx, 0                  ; BX = 0 (счетчик текущих пробелов)
    
scan_loop:
    mov al, [si]               ; AL = текущий символ из текста
    inc si                     ; SI++ (переходим к следующему символу)
    dec cx                     ; CX-- (уменьшаем счетчик оставшихся символов)
    
    cmp al, '.'                ; Проверяем конец текста (точка)
    je check_final             ; Если точка, переходим к проверке конечных пробелов
    
    cmp al, ' '                ; Проверяем пробел
    jne not_space              ; Если не пробел, переходим к обработке не-пробела
    inc bx                     ; Увеличиваем счетчик пробелов
    jmp next_char              ; Переходим к следующему символу
    
not_space:
    ; Обработка не-пробельного символа
    cmp bx, 0                  ; Проверяем, были ли перед этим пробелы
    je no_spaces               ; Если не было, пропускаем проверку максимума
    
    ; Сравниваем текущее количество пробелов с максимумом
    cmp bx, [di]               ; Сравниваем BX (текущие пробелы) с [DI] (max_spaces)
    jle reset_count            ; Если BX <= max_spaces, переходим к сбросу счетчика
    mov [di], bx               ; Обновляем max_spaces = BX (новый максимум)
    
reset_count:
    mov bx, 0                  ; Сбрасываем счетчик пробелов после слова
    
no_spaces:
next_char:
    jcxz check_final           ; Если CX = 0 (текст закончился), переходим к финальной проверке
    jmp scan_loop              ; Иначе продолжаем цикл
    
check_final:
    ; Проверяем пробелы перед точкой (в конце текста)
    cmp bx, [di]               ; Сравниваем конечные пробелы с максимумом
    jle find_done              ; Если <=, завершаем
    mov [di], bx               ; Обновляем максимум если конечные пробелы больше
    
find_done:
    ; Восстанавливаем регистры в обратном порядке
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4                      ; Возврат с очисткой 4 байт параметров (2 параметра × 2 байта)
find_max_spaces endp

; Процедура уменьшения максимального количества пробелов на 1
; Параметры через стек:
;   [bp+4] - адрес исходного текста
;   [bp+6] - адрес модифицированного текста (результат)
;   [bp+8] - максимальное количество пробелов
reduce_max_spaces proc
    push bp
    mov bp, sp
    push ax                    ; AX - текущий символ
    push bx                    ; BX - счетчик текущих пробелов
    push cx                    ; CX - счетчик оставшихся символов
    push dx                    ; DX - максимальное количество пробелов
    push si                    ; SI - указатель исходного текста
    push di                    ; DI - указатель модифицированного текста
    
    ; Получаем параметры
    mov si, [bp+4]             ; SI = исходный текст
    mov di, [bp+6]             ; DI = модифицированный текст
    mov dx, [bp+8]             ; DX = max_spaces
    
    ; Проверяем, нужно ли вообще что-то менять
    cmp dx, 1                  ; Если максимум <= 1
    jle copy_all               ; Просто копируем текст без изменений
    
    ; Получаем длину текста
    mov cl, text_buffer[1]
    mov ch, 0
    jcxz reduce_done           ; Если текст пустой, завершаем
    
    mov bx, 0                  ; BX = 0 (счетчик текущих пробелов)
    
process_text_loop:
    ; Читаем символ из исходного текста
    mov al, [si]               ; AL = текущий символ
    inc si                     ; Переходим к следующему символу
    dec cx                     ; Уменьшаем счетчик
    
    cmp al, '.'                ; Проверяем конец текста
    je end_of_text
    
    cmp al, ' '                ; Проверяем пробел
    jne not_space_char
    
    ; Обработка пробела
    inc bx                     ; Увеличиваем счетчик пробелов
    jmp next_char_process
    
not_space_char:
    ; Обработка не-пробельного символа (начало слова)
    cmp bx, 0                  ; Проверяем, были ли пробелы перед этим
    je write_current_char      ; Если не было, просто пишем символ
    
    ; Обрабатываем накопленные пробелы
    cmp bx, dx                 ; Сравниваем с максимумом
    jne write_spaces_normal    ; Если не равны максимуму, пишем без изменений
    
    ; Уменьшаем максимальную последовательность на 1
    push ax                    ; СОХРАНЯЕМ текущий символ (букву)!
    mov al, ' '                ; AL = пробел для записи
    push cx                    ; Сохраняем CX (счетчик оставшихся символов)
    mov cx, bx                 ; CX = количество пробелов
    dec cx                     ; Уменьшаем на 1 (CX = BX - 1)
    jz after_reduce            ; Если стало 0, пропускаем запись пробелов
    
write_reduced:
    stosb                      ; Записываем пробел в модифицированный текст (DI++)
    loop write_reduced         ; Повторяем CX раз
    
after_reduce:
    pop cx                     ; Восстанавливаем CX
    pop ax                     ; ВОССТАНАВЛИВАЕМ текущий символ!
    jmp write_current_char
    
write_spaces_normal:
    ; Записываем пробелы без изменений
    push ax                    ; СОХРАНЯЕМ текущий символ!
    mov al, ' '
    push cx
    mov cx, bx                 ; CX = количество пробелов
write_spaces:
    stosb                      ; Записываем пробел
    loop write_spaces          ; Повторяем CX раз
    pop cx
    pop ax                     ; ВОССТАНАВЛИВАЕМ текущий символ!
    
write_current_char:
    ; Записываем текущий символ (букву слова)
    stosb                      ; AL -> [DI], DI++
    mov bx, 0                  ; Сбрасываем счетчик пробелов
    
next_char_process:
    jcxz end_of_text           ; Если текст закончился
    jmp process_text_loop      ; Продолжаем цикл
    
end_of_text:
    ; Обработка пробелов перед точкой (в конце текста)
    cmp bx, 0                  ; Проверяем, есть ли пробелы перед точкой
    je add_final_dot
    
    cmp bx, dx                 ; Сравниваем с максимумом
    jne write_final_spaces_normal
    
    ; Уменьшаем конечные пробелы
    mov al, ' '
    mov cx, bx
    dec cx                     ; Уменьшаем на 1
    jz add_final_dot           ; Если стало 0, переходим к точке
    
write_final_reduced:
    stosb                      ; Записываем пробел
    loop write_final_reduced
    jmp add_final_dot
    
write_final_spaces_normal:
    ; Записываем конечные пробелы без изменений
    mov al, ' '
    mov cx, bx
write_final_spaces:
    stosb
    loop write_final_spaces
    
add_final_dot:
    mov al, '.'                ; Добавляем точку в конец
    stosb
    jmp reduce_done
    
copy_all:
    ; Просто копируем исходный текст без изменений
    mov si, [bp+4]             ; Источник
    mov di, [bp+6]             ; Приемник
    mov cl, text_buffer[1]     ; Длина
    mov ch, 0
    rep movsb                  ; Копируем CX байт из SI в DI
    
reduce_done:
    ; Добавляем терминатор строки для корректного вывода
    mov al, '$'
    mov [di], al
    
    ; Восстанавливаем регистры
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6                      ; Возврат с очисткой 6 байт (3 параметра × 2 байта)
reduce_max_spaces endp

; Основная процедура обработки текста
; Параметры через стек:
;   [bp+4] - адрес исходного текста
;   [bp+6] - адрес модифицированного текста
process_text_main proc
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Шаг 1: Находим максимальное количество пробелов
    push offset max_spaces      ; Параметр 2 - адрес для результата
    push [bp+4]                 ; Параметр 1 - адрес текста
    call find_max_spaces
    
    ; Шаг 2: Уменьшаем максимальное количество пробелов
    push max_spaces             ; Параметр 3 - максимальное количество пробелов
    push [bp+6]                 ; Параметр 2 - адрес модифицированного текста
    push [bp+4]                 ; Параметр 1 - адрес исходного текста
    call reduce_max_spaces
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4                       ; Возврат с очисткой 4 байт (2 параметра)
process_text_main endp

; Главная процедура программы
main:
    ; Инициализация сегментных регистров
    mov ax, @data               ; AX = адрес сегмента данных
    mov ds, ax                  ; DS = сегмент данных
    mov es, ax                  ; ES = дополнительный сегмент (для строковых операций)
    
    ; Ввод текста с клавиатуры
    call input_text_buffered
    call print_new_line
    
    ; Вывод исходного текста
    mov ah, 09h                 ; Функция вывода строки
    mov dx, offset text_buffer + 2 ; DX = адрес текста (пропускаем 2 байта заголовка буфера)
    int 21h
    
    ; Обработка текста
    push offset modified_text    ; Параметр 2 - адрес для модифицированного текста
    push offset text_buffer + 2  ; Параметр 1 - адрес исходного текста
    call process_text_main
    
    call print_new_line
    
    ; Вывод результата
    mov ah, 09h
    mov dx, offset result_msg   ; "Modified text: "
    int 21h
    
    mov ah, 09h
    mov dx, offset modified_text ; Вывод модифицированного текста
    int 21h
    
    call print_new_line
    
    ; Ожидание нажатия любой клавиши
    mov ah, 09h
    mov dx, offset press_any_key
    int 21h
    
    mov ah, 01h                 ; Функция ввода символа без эха
    int 21h
    
    ; Завершение программы
    mov ax, 4C00h               ; Функция завершения программы
    int 21h

end main
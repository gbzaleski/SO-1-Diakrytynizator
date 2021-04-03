; Grzegorz B. Zaleski (418494)

SYS_EXIT equ 60 ; Index komendy exit dla syscall.
EXIT_CODE equ 0 ; Kod udanego wyjscia.
EXIT_FAIL equ 1 ; Kod wyjścia z sygnalizacją błędu.
SYS_WRITE equ 1
SYS_READ equ 0
STD_OUT equ 1
STD_IN equ 0
MOD equ 0x10FF80 ; Stała modulo dla wielomianu.
BUFFER_LEN equ 4096 ; Rozmiar bufora danych.
BUFFER_THRESHOLD equ 4024 ; Próg wypisywania.

global _start

section .bss
buffer_input resb BUFFER_LEN ; Buffor na wczytanie znaki.
range resq 1 ; Długośc wczytanego inputu.
buffer_output resb BUFFER_LEN ; Buffor na wypisywane znaki.
ans resq 1 ; Pomocnicza zmienna na obróbkę danych.

section .text
; Funkcja przerabia stringa z rdi na liczbe w rax (uzywa rsi jako iteratora).
atoi_convertRDI:
   movzx rsi, byte[rdi] ; Pobranie cyfry.
   test rsi, rsi ; Sprawdza czy to koniec.
   je finished

   ; Sprawdzenie czy argument jest poprawną cyfrą
   cmp rsi, '0'
   jb  exit_fail
   cmp rsi, '9'
   ja exit_fail

   ; Konwersja na ASCII i dodanie do wyniku.
   sub rsi, '0'
   imul rax, 10  
   add rax, rsi

   ; Modulowanie przez MOD wspołczynnika.
   mov r8, MOD
   xor rdx, rdx
   div r8
   mov rax, rdx

   inc rdi 
   jmp atoi_convertRDI ; Następna iteracja

finished:
   ret

_start:
    ; Sprawdzenie czy wielomian ma jakieś wspołczynniki.
    cmp [rsp], byte 2 ; Jeśli nie ma żadnych dodatkowych argumentów = error
    jb exit_fail

    mov r10, rsp ; Pomocniczy wskaznik stosu.
    add r10, 16 ; Ustawienie na początek wielomianu.
    xor r13, r13 ; Licznik stopni pierwiastka.
    xor r15, r15 ; Iterator wypisywania.
    xor rbp, rbp ; Iterator wczytywania.

; Przetwarzanie argumentów na liczby
iter:
    mov rdi, [r10] ; rdi = *r10

    xor rax, rax ; Wyczyszczenie wartosci gdzie bedzie współczynnik.
    call atoi_convertRDI ; Przerobienie stringa na liczbe (z rdi na rax).

    push rax ; Wrzucenie na stos.
    inc r13 ; Zwiekszenie liczby współczynników (stopnia wielomianu).

    add r10, 8 ; Przesuwamy pointer na kolejny argument.

    ; Jeśli są kolejne argumenty to kolejna iteracja.
    cmp qword [r10], 0 
    jne iter

after_polynomial:
    mov r10, rsp ; Poczatek stosu.
    mov r14, r13 ; Zapamietanie liczby argumentów.

; Wczytania znak do przerobienia.
read_argument: 
    ; Wczytanie znaku
    call getchar ; Zapisze w [ans] bajta a w rax długosc.
    ; Jesli to koniec inputu to exit.
    cmp rax, 0 
    je exit_succ

    xor rax, rax ; Tu bedziemy zapisywac bajta zeby go dodac do r12.
    ; Analiza bajta zeby zobaczyć jakie to UTF
    mov al, [ans]

    ; Sprawdzamy czy byte ma postac 0xxxxxxx - wtedy od razu go wypisujemy.
    test al, 0x80
    jz single_byte_UTF

    xor r12, r12 ; r12 = 0, tu bedziemy zapisywać wartość znaku z UTF-8.
    ; Zatem bajt jest 1xxxxxxx - analiza dalej.
    test al, 0x40

    jz exit_fail ; Postać 10xxxxxx - błedna wzgl. UTF-8 - nalezy wyrzucić error.
                 ; Zatem jest postać 11xxxxxx.

    test al, 0x20 ; Analiza dalej.
    jz double_byte_UTF ; Postać 110xxxxx.

    test al, 0x10 ; Analiza dalej.
    jz triple_byte_UTF ; Postac 1110xxxx.

    test al, 0x8 ; Analiza dalej.
    jz quad_byte_UTF; Postać 11110xxx.

    jmp exit_fail ; Postać 11111xxx jest błędna dla UTF-8 - nalezy wyrzucić error.

; Wczytanie kolejnego bajta do [ans] i ustawienie rax na długosc bufora.
getchar:
    cmp rbp, [range]
    jne after_read

    ; Wczytanie danych do bufora.
    mov rax, SYS_READ
    mov rdi, STD_IN
    mov rdx, BUFFER_LEN
    mov rsi, buffer_input
    syscall

    ; Jeśli rax = 0 tj. koniec pliku.
    cmp rax, 0
    jne not_EOF

    ret 

not_EOF:
    mov [range], rax
    xor rbp, rbp ; Ustawienie iteratora na 0.

after_read:
    mov al, byte[buffer_input + rbp]
    mov [ans], al
    inc rbp
    mov rax, [range]
    ret

; Funkcja przetwarza kolejny bajt liczby.
append_byte:
    call getchar

    ; Jesli to koniec inputu to exit failure.
    cmp rax, 0 
    je exit_fail

    ; Zapisujemy bajt.
    xor rax, rax 
    mov al, [ans]

    ; Sprawdzenie czy bajt zaczyna się od 10 - jeśli nie to wyrzucamy error.
    xor al, 10000000b
    test al, 11000000b
    jnz exit_fail

    and al, 00111111b ; Uciecie prefixa kontrolnego.

    shl r12, 6
    add r12, rax
    ret

; Funkcja wypisująca dane z bufora.
print_output:
    mov rax, SYS_WRITE
    mov rdi, STD_OUT
    mov rsi, buffer_output
    mov rdx, r15
    syscall
    xor r15, r15
    ret

single_byte_UTF:
    ; Poprostu wypisujemy ten znak.
    mov [buffer_output + r15], al
    inc r15

    ; Sprawdzenie czy bufor jest już pełny.
    cmp r15, BUFFER_THRESHOLD
    jbe read_argument
    call print_output

    jmp read_argument

double_byte_UTF:
    and al, 00011111b ; Uciecie prefixa kontrolnego.
    add r12, rax

    call append_byte ; Drugi bajt liczby.

    ; Sprawdzenie czy jest optymalny kod UTF8.
    cmp r12, 0x80
    jb exit_fail
    cmp r12, 0x7FF
    ja exit_fail

    jmp prepolynomial

triple_byte_UTF:
    and al, 00001111b ; Uciecie prefixa kontrolnego.
    add r12, rax

    call append_byte ; Drugi bajt liczby.

    call append_byte ; Trzeci bajt liczby.

    ; Sprawdzenie czy jest optymalny kod UTF8.
    cmp r12, 0x800
    jb exit_fail
    cmp r12, 0xFFFF
    ja exit_fail

    jmp prepolynomial

quad_byte_UTF:
    and al, 00000111b ; Uciecie prefixa kontrolnego.
    add r12, rax

    call append_byte ; Drugi bajt liczby.

    call append_byte ; Trzeci bajt liczby.

    call append_byte ; Czwarty bajt liczby.

    ; Sprawdzenie czy jest optymalny kod UTF8
    cmp r12, 0x10000
    jb exit_fail
    cmp r12, 0x10FFFF
    ja exit_fail

    ; Skok do prepolynomial następuje naturalnie.

; Przygotowanie do obliczenia wielomianu.
prepolynomial:
    sub r12, 0x80 ; Liczymy wartośc dla (x - 0x80).
    xor rax, rax 
    
; Po wykonaniu xxxx_byte_UTF:
; r12 = wartosc znaku w UTF8.
; rax = 0 -> bedziemy liczyć wartośc wielomianu.
proceed_polynomial: ; Przerabiamy wartosc przez wielomina
    mov r8, [r10] ; Wsadzenie do r8 współczynnika.
    add r10, 8 ; Pointer na kolejny wspolcznik.
     
    mul r12     ; *= x
    add rax, r8 ; + a_i
    
    ; modulo MOD
    mov r8, MOD
    xor rdx, rdx
    div r8
    mov rax, rdx

    dec r13 ; Licznik iteracji -= 1.

     ; Jesli to nie koniec to wykonujemy kolejna iteracje.
    cmp r13, 0
    jne proceed_polynomial

    mov r10, rsp ; Przeniesieni pointer na poczatek wielomianu.
    mov r13, r14 ; Przywrócenie wartosci licznika współczynnika.
    
    add rax, 0x80 ; Dodanie 0x80 do wartości.

    mov r12, rax ; Zapisany wynik r12 to UTF8 znaku.

    ; Sprawdzamy czy liczba jest dwubajtowa
    cmp r12, 0x7FF
    jbe print_double_byte_UTF

    ; Sprawdzamy czy liczba jest trzybajtowa
    cmp r12, 0xFFFF
    jbe print_triple_byte_UTF

    ; Sprawdzamy czy liczba jest trzybajtowa
    cmp r12, 0x10FFFF
    jbe print_quad_byte_UTF 
    
    jmp exit_fail; Jak nie to error

; Funkcja parsujuca liczbe na ostatni bajt tj. r12 /= 2^6, rax (al) = r12 mod 2^6.
press_byte_al:
    xor rdx, rdx;
    mov rax, r12
    mov r8, 64
    div r8
    mov r12, rax
    xor rax, rax
    mov rax, rdx
    or al, 10000000b ; Dodanie prefixu kontrolnego 10.
    ret

print_double_byte_UTF:
    call press_byte_al
    mov [buffer_output + r15 + 1], al

    call press_byte_al
    or al, 11000000b ; Prefix pierwszego bajtu jest inny.
    mov [buffer_output + r15], al

    add r15, 2

    ; Sprawdzenie czy bufor jest już pełny.
    cmp r15, BUFFER_THRESHOLD
    jbe read_argument
    call print_output

    jmp read_argument

print_triple_byte_UTF:
    call press_byte_al
    mov [buffer_output + r15 + 2], al

    call press_byte_al
    mov [buffer_output + r15 + 1], al

    call press_byte_al
    or al, 11100000b; Prefix pierwszego bajtu jest inny.
    mov [buffer_output + r15], al

    add r15, 3

    ; Sprawdzenie czy bufor jest już pełny.
    cmp r15, BUFFER_THRESHOLD
    jbe read_argument
    call print_output

    jmp read_argument

print_quad_byte_UTF:
    call press_byte_al
    mov [buffer_output + r15 + 3], al

    call press_byte_al
    mov [buffer_output + r15 + 2], al

    call press_byte_al
    mov [buffer_output + r15 + 1], al

    call press_byte_al
    or al, 11110000b ; Prefix pierwszego bajtu jest inny.
    mov [buffer_output + r15], al

    add r15, 4

    ; Sprawdzenie czy bufor jest już pełny.
    cmp r15, BUFFER_THRESHOLD
    jbe read_argument
    call print_output

    jmp read_argument

exit_succ:
    ; Zakończenie programu kodem 0 (poprawny) i wypisanie zaległych bajtów.
    call print_output
    mov     rax, SYS_EXIT
    mov     rdi, EXIT_CODE
    syscall 

exit_fail:
    ; Zakończenie programu kodem błędu i wypisanie zaległych bajtów.
    call print_output
    mov     rax, SYS_EXIT
    mov     rdi, EXIT_FAIL
    syscall 
    

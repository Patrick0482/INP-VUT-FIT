; Autor reseni: Patrik Früštök xfrust00

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64
; xfrust00-r12-r13-r7-r8-r0-r4

; DATA SEGMENT
                .data
login:          .asciiz "xfrust00"  ; sem doplnte vas login
cipher:         .space  17  ; misto pro zapis sifrovaneho loginu

char_f:           .word 6 
char_r:           .word 18 
char_abc:           .word 26
char_z:           .word 122 
char_a:         .word 96

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize "funkce" print_string)

; CODE SEGMENT
                .text

                ; ZDE NAHRADTE KOD VASIM RESENIM
main:
    load_char:
                lb r12, login(r8) ; nacitanie znaku z loginu
                lb r13, char_f(r0) ; nacitanie znaku f
                sltiu r7, r12, 96 ; kontrola, ci je znak mensi nez a
                bne r7, r0, print_vernam ; ak ano, vypis sifru
                j check_char ; ak ne, pokracuj

    load_char_2:
                lb r12, login(r8) 
                lb r13, char_r(r0)   
                sltiu r7, r12, 96 ; kontrola, ci je znak mensi nez a
                bne r7, r0, print_vernam ; ak ano, vypis sifru
                j check_char_2 ; ak ne, pokracuj

    check_char:
                
                add r12, r12, r13 ; scitanie znaku z loginu a f
                add r13, r12, r0 ; ulozenie vysledku do r13
                lb r7, char_z(r0) ; nacitanie znaku z
                sub r13, r7, r13 ; odobraniu znaku z od vysledku
                bgez r13, next_char ; ak je vysledok vacsi alebo rovny nule, pokracuj
                lb r7, char_abc(r0) ; nacitanie znaku 26
                sub r12, r12, r7 ; odebranie znaku 26 od vysledku

    next_char: 
                sb r12, cipher(r8) ; ulozenie vysledku do cipher
                daddi r8, r8, 1 ; inkrementacia r8
                j load_char_2 ; pokracuj
                
    check_char_2:  
                
                sub r12, r12, r13 ; odobranie znaku r od znaku z loginu
                add r13, r12, r0 ; ulozenia vysledku do r13
                lb r7, char_a(r0) ; nacitanie znaku a
                sub r13, r13, r7 ;odebranie znaku a od vysledku
                bgez r13, next_char_2 ; pokial je vysledek vacsi nebo rovny nule, pokracuj
                lb r7, char_abc(r0) ; nacitanie znaku 26
                add r12, r12, r7    ; scitanie znaku 26 s vysledkom

    next_char_2: 
                sb r12, cipher(r8) ; ulozenie vysledku do cipher
                daddi r8, r8, 1 ; inkrementacia r8
                j load_char 

    print_vernam:
                daddi   r4, r0, cipher   ; vzorovy vypis: adresa login: do r4
                jal     print_string    ; vypis pomoci print_string - viz nize
                syscall 0   ; halt
                
print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address
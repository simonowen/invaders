; Space Invaders 'emulator' for the SAM Coupe (v0.5)
;
; WWW: http://simonowen.com/sam/invaders/
;
; ToDo:
;  - rotate display to correct orientation
;  - sound support, using SAA

base:          equ  &8000

line:          equ  &f9
status:        equ  &f9
lmpr:          equ  &fa
hmpr:          equ  &fb
vmpr:          equ  &fc
border:        equ  &fe
keyboard:      equ  &fe

scrhi:         equ  &c0             ; SAM display at &c000
scrdiff:       equ  scrhi-&24-2     ; offset from Invaders to SAM display
rom_page:      equ  4               ; Invaders 8K ROM in PAGE 4 (at &0000)
rom0_off:      equ  %00100000       ; LMPR bit to disable ROM0

jp_op:         equ  &c3             ; JP opcode
rst8_op:       equ  &cf             ; RST 8 opcode
in_a_op:       equ  &db             ; IN A,(n) opcode
out_a_op:      equ  &d3             ; OUT (n),a opcode


               org  base
               dump $
               autoexec

start:         di

               ; Page Invaders ROM at &0000
               ld   a,rom_page+rom0_off
               out  (lmpr),a

               call patch_rom
               call init_tables
               call init_display
               call init_im2

               ; Start game!
               ld   sp,&ff00
               jp   0


               ; Generate bit-reverse table
init_tables:   ld   hl,reverse_tab
rev_lp1:       ld   c,l
               ld   b,8
rev_lp2:       rr   c
               rla
               djnz rev_lp2
               ld   (hl),a
               inc  l
               jr   nz,rev_lp1
               ret


               ; Fill all attributes with white on black
init_display:  ld   hl,&e000
               ld   de,&e001
               ld   bc,&17ff
               ld   (hl),7
               ldir

               ; Colour lives area in green
               ld   hl,&e000+&0100
               ld   de,&20-1
               ld   bc,&6844
attr_loop1:    ld   (hl),c
               inc  l
               ld   (hl),c
               add  hl,de
               djnz attr_loop1

               ; Colour bases in green
               ld   hl,&e000+&02
               ld   de,&20-6
               ld   bc,&c044
attr_loop2:    ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               add  hl,de
               djnz attr_loop2

               ; Colour special ufo at top in red
               ld   hl,&e000+&18
               ld   de,&20-3
               ld   bc,&c042
attr_loop3:    ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               inc  l
               ld   (hl),c
               add  hl,de
               djnz attr_loop3

               ld   a,2+%00100000
               out  (vmpr),a
               ret


               ; Prepare IM2 vector table
init_im2:      ld   hl,&fe00
               ld   a,&fd
im2_lp:        ld   (hl),a
               inc  l
               jr   nz,im2_lp
               inc  h
               ld   (hl),a

               ; Set IM2 jump to handler
               ld   a,jp_op
               ld   (&fdfd),a
               ld   hl,int_handler
               ld   (&fdfe),hl

               ; IM2, though don't enable interrupts yet
               ld   a,&fe
               ld   i,a
               im   2

               ; Set line interrupt for our choice of invaders int position
               xor  a
               out  (line),a
               ret


               ; IM2 interrupt handler
int_handler:   push af
               push bc              ; these 4 pushes must be the only change to the
               push de              ; stack and be in the same order, as they're
               push hl              ; popped by the original Invaders interrupt code

               in   a,(status)
               rra
               jr   nc,frame_int

               ; Update input on true frame interrupt
               call update_input

               ; Call the original RST 8 handler, +4 skips the push instructions we've done above
               jp   &0008+4

               ; Perform invaders interrupt handler at line interrupt position
frame_int:     jp   &0010+4

               ; RST 8 hander for I/O hooks
io_handler:    ex   (sp),hl         ; swap to get return address in hl
               push af              ; save AF
               ld   a,(hl)          ; fetch port
               inc  hl              ; advance to new return address
               push hl              ; keep for later
               srl  a               ; check in/out bit, with 0 to bit 7
               jr   c,io_read       ; jump if read instruction

               dec  a
               dec  a
               jr   z,write_2
               dec  a
               jr   z,write_3
               dec  a
               jr   z,write_4
               dec  a
               jr   z,write_5

out_exit:      pop  hl
               pop  af
               ex   (sp),hl
               ret

io_read:       dec  a
               jr   z,read_1
               dec  a
               jr   z,read_2
               dec  a
               jr   z,read_3
               xor  a               ; unhandled ports return zero

in_exit:       pop  hl
               inc  sp
               inc  sp
               ex   (sp),hl
               ret

               ; coins, start and p1 controls
read_1:        ld   hl,port1
               ld   a,(hl)
               res  0,(hl)          ; coin bit cleared once read
               jr   in_exit

               ; flags, including P2 controls
read_2:        ld   a,(port1)
               and  %01110000       ; keep p1 controls
               ld   l,a
               ld   a,(port2i)
               or   l               ; combine with p2 controls
               jr   in_exit

               ; read shifter result
read_3:        ld   a,(port4l)
               ld   l,a
               ld   a,(port4h)
               ld   h,a
               ld   a,(port2o)
               and  %00000111       ; bottom 3 bits only
               jr   z,r3_noshift
r3_lp:         add  hl,hl
               dec  a
               jr   nz,r3_lp
r3_noshift:    ld   a,h             ; return the high byte of the result
               jr   in_exit

               ; write shifter count
write_2:       pop  hl
               pop  af
               ld   (port2o),a
               ex   (sp),hl
               ret

               ; sound ports (not implemented yet)
write_3:
write_5:       pop  hl
               pop  af
               ex   (sp),hl
               ret

               ; write shifter data (2 bytes)
write_4:       ld   a,(port4h)      ; latched high value
               ld   (port4l),a      ; move into low value
               pop  hl
               pop  af
               ld   (port4h),a      ; move into high value
               ex   (sp),hl
               ret

port1:         defb 0               ; b7=X, b6=right1, b5=left1, b4=fire1, b3=X, b2=start1, b1=start2, b0=coin
port2i:        defb 0               ; b7=coinshow, b6=right2, b5=left2, b4=fire2, b3=X, b2=easy, b1-0=ships
port2o:        defb 0               ; shift count
;port_3:       defb 0               ; sound (unsupported)
port4h:        defb 0               ; value to shift (high byte)
port4l:        defb 0               ; value to shift (low byte, latched)
;port_5:       defb 0               ; sound (unsupported)

update_input:  ld   l,0             ; port 1 built from scratch
               ld   a,(port2i)
               and  %10000111       ; keep only DIP switches in port 2
               ld   h,a

               ld   a,&f7
               in   a,(keyboard)
               rra
               jr   c,not_1
               set  2,l             ; 1 = start 1
not_1:         rra
               jr   c,not_2
               set  1,l             ; 2 = start 2
not_2:         rra
               jr   c,not_3
               set  0,l             ; 3 = coin 1
               jr   do_arrows
not_3:         rra
               rra
               jr   c,do_arrows
               set  0,l             ; 5 = coin 1

do_arrows:     ld   a,&ff
               in   a,(keyboard)
               bit  3,a
               jr   nz,not_left
               set  5,l             ; p1 left
not_left:      bit  4,a
               jr   nz,not_right
               set  6,l             ; p1 right
not_right:     ld   a,&7f
               in   a,(keyboard)
               rra
               jr   c,not_space
               set  4,l             ; p1 fire
not_space:     ld   (port1),hl      ; write port 1+2 settings
               ret


patch_rom:     ld   a,scrhi
               ld   (&09d8),a       ; cls start high-byte
               ld   (&1a5e),a
               ld   a,scrdiff+&40
               ld   (&09ea),a       ; cls end high-byte
               ld   (&1a64),a

;              ld   a,jp_op
;              ld   (&1401),a
;              ld   hl,hook_1401
;              ld   (&1402),hl

               ld   a,jp_op

               ld   hl,hook_1405
               ld   (&1405),a
               ld   (&1406),hl

               ld   hl,hook_1424
               ld   (&1424),a
               ld   (&1425),hl

               ld   hl,hook_1439
               ld   (&1439),a
               ld   (&143a),hl

               ld   hl,hook_1452
               ld   (&1452),a
               ld   (&1453),hl

               ld   hl,hook_147c
               ld   (&147c),a
               ld   (&147d),hl

               ld   hl,hook_1491
               ld   (&1491),a
               ld   (&1492),hl

               ld   hl,hook_14cc
               ld   (&14cc),a
               ld   (&14cd),hl

               ld   hl,hook_15c5
               ld   (&15c5),a
               ld   (&15c6),hl

               ld   hl,hook_15d6
               ld   (&15d6),a
               ld   (&15d7),hl

               ld   hl,hook_1a69
               ld   (&1a69),a
               ld   (&1a6a),hl

               ; Patch relevant I/O instructions with RST hooks
               ld   hl,0            ; start of ROM
io_lp:         ld   a,(hl)
               cp   in_a_op         ; in a,(n) ?
               scf
               jr   z,found_io
               cp   out_a_op        ; out (n),a ?
               jp   nz,next_io
found_io:      ex   af ,af'         ; save carry (set=IN, clear=OUT)
               inc  hl
               ld   a,(hl)
               dec  a
               cp   6
               jr   nc,next_io2     ; accept ports 1-6 only
               dec  hl              ; step back to IN/OUT opcode
               ld   (hl),rst8_op    ; replace with rst 8
               inc  hl              ; advance to port number
               ex   af,af'          ; restore carry
               rl   (hl)            ; bit 0 of port now holds IN/OUT flag
next_io:       inc  hl              ; advance past port number
next_io2:      bit  5,h
               jp   z,io_lp         ; loop until end of ROM at &2000

               ; RST 8 handler for I/O emulation
               ; This replaces 3 push instructions, which are provided by our own handler
               ld   a,jp_op
               ld   hl,io_handler
               ld   (&0008),a
               ld   (&0009),hl
               ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

               ; draw character from DE to HL
               ; used to draw font characters
hook_1439:     ld   a,h
               add  a,scrdiff
               ld   h,a
lp_1439:       push bc
               ld   a,(de)
               ld   b,reverse_tab/256
               ld   c,a
               ld   a,(bc)
               ld   (hl),a
               inc  de
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_1439
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

;hook_15d3:     call &1474
;               push hl
;               ld   a,h
;               add  a,scrdiff
;               ld   h,a
;               jp   &15d3+3

               ; draw sprite from DE to HL
               ; used to draw invader replacing inverted Y
hook_15d6:     push hl
               ld   a,h
               add  a,scrdiff
               ld   h,a
               ld   ixh,reverse_tab/256
lp_15d6:       push bc
               push hl
               ld   a,(de)
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               ld   (hl),a
               inc  hl
               inc  de
               xor  a
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               ld   (hl),a
               pop  hl
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_15d6
               pop  hl
               ret

               ; fill B lines of A to HL
hook_14cc:     ex   af,af'
               ld   a,h
               add  a,scrdiff
               ld   h,a
               ex   af,af'
loop_14cc:     push bc
               ld   (hl),a
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz loop_14cc
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

;hook_1401:     call &1474
;               ld   a,h
;               add  a,scrdiff
;               ld   h,a
;               call &1405
;               ld   a,h
;               sub  scrdiff
;               ld   h,a
;               ret

               ; OR to draw sprite
hook_1405:     ld   a,h
               add  a,scrdiff
               ld   h,a
               ld   ixh,reverse_tab/256
lp_1405:       push bc
               push hl
               ld   a,(de)
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               or   (hl)
               ld   (hl),a
               inc  hl
               inc  de
               xor  a
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               or   (hl)
               ld   (hl),a
               pop  hl
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_1405
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

hook_1424:     call &1474
               ld   a,h
               add  a,scrdiff
               ld   h,a
               call &1424+3
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

               ; AND to erase sprite
               ; used to erase bullets
hook_1452:     call &1474
               ld   a,h
               add  a,scrdiff
               ld   h,a
lp_1452:       push bc
               push hl
               ld   a,(de)
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               cpl
               and  (hl)
               ld   (hl),a
               inc  hl
               inc  de
               xor  a
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               cpl
               and  (hl)
               ld   (hl),a
               pop  hl
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_1452
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

               ; Copy CxB block from screen HL to DE
hook_147c:     ld   a,h
               add  a,scrdiff
               ld   h,a
lp_147c:       push bc
               push hl
lp2_147c:      ld   a,(hl)
               ld   (de),a
               inc  de
               inc  hl
               dec  c
               jp   nz,lp2_147c
               pop  hl
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_147c
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

               ; OR to draw sprite, plus collision detection
               ; used to draw bullets
hook_1491:     call &1474
               ld   a,h
               add  a,scrdiff
               ld   h,a
               ld   ixh,reverse_tab/256

               xor  a
               ld   (&2061),a
lp_1491:       push bc
               push hl
               ld   a,(de)
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               push af
               and  (hl)
               jp   z,lp2_1491
               ld   a,1
               ld   (&2061),a
lp2_1491:      pop  af
               or   (hl)
               ld   (hl),a
               inc  hl
               inc  de
               xor  a
               rst  8
               defb 4*2
               rst  8
               defb 3*2+1
               ld   ixl,a
               ld   a,(ix)
               push af
               and  (hl)
               jp   z,lp3_1491
               ld   a,1
               ld   (&2061),a
lp3_1491:      pop  af
               or   (hl)
               ld   (hl),a
               pop  hl
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_1491
exit_1491:     ld   a,h
               sub  scrdiff
               ld   h,a
               ret

               ; check for invaders turn-around point
               ; 3ea4 or 2524 as starting address
hook_15c5:     ld   a,h
               add  a,scrdiff
               ld   h,a
               ld   b,&17
lp_15c5:       ld   a,(hl)
               and  a
               jr   nz,scf_15c5
               inc  hl
               djnz lp_15c5
               jr   exit_15c5
scf_15c5:      scf
exit_15c5:     push af
               ld   a,h
               sub  scrdiff
               ld   h,a
               pop  af
               ret

hook_1a69:     ld   a,h
               add  a,scrdiff
               ld   h,a
               ld   ixh,reverse_tab/256
lp_1a69:       push bc
               push hl
lp2_1a69:      ld   a,(de)
               ld   ixl,a
               ld   a,(ix)
               or   (hl)
               ld   (hl),a
               inc  de
               inc  hl
               dec  c
               jr   nz,lp2_1a69
               pop  hl
               ld   bc,32
               add  hl,bc
               pop  bc
               djnz lp_1a69
               ld   a,h
               sub  scrdiff
               ld   h,a
               ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
length:        equ $ - start        ; code length

               defs -$\256
reverse_tab:   defs 256

               dump rom_page,0
mdat "invaders.h"
mdat "invaders.g"
mdat "invaders.f"
mdat "invaders.e"

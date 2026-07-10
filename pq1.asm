org 100h


start:
    ; Save original interrupt vectors FIRST
    mov ax, 0
    mov es, ax
    
    ; Save original INT 9 (keyboard) vector
    mov ax, [es:9*4]
    mov [oldKbdOff], ax
    mov ax, [es:9*4+2]
    mov [oldKbdSeg], ax
    
    ; Save original INT 1Ch (timer) vector
    mov ax, [es:1Ch*4]
    mov [oldTimerOff], ax
    mov ax, [es:1Ch*4+2]
    mov [oldTimerSeg], ax
    
    ; Show introduction screen (uses normal BIOS keyboard)
    call ShowIntroScreen
    
    ; Initialize graphics mode
    mov ax, 13h
    int 10h
    
    ; Draw static scene FIRST
    call DrawLandscape
    call DrawRoad
    call DrawLanesSolid
    call DrawLeftTrees
    call DrawRightTrees
    call DrawCar
    
    ; Reset timer counter
    mov word [timerCounter], 0
    
    ; NOW install custom keyboard ISR
    cli
    mov ax, 0
    mov es, ax
    mov word [es:9*4], NewKbdISR
    mov [es:9*4+2], cs
    
    ; Install custom timer ISR
    mov word [es:1Ch*4], NewTimerISR
    mov [es:1Ch*4+2], cs
    sti
    
    ; Enable game (allows timer to scroll)
    mov byte [gameStarted], 1
    
    ; Jump to animation loop
    jmp Animation

Animation:
    ; Disable interrupts during drawing to prevent flickering
    cli
    
    ; Clear top area for score
    push ax
    push bx
    push cx
    push dx
    mov dx, 0
ClearScoreRow:
    mov cx, 0
ClearScoreCol:
    mov bh, 0
    mov ah, 0Ch
    mov al, 0
    int 10h
    inc cx
    cmp cx, 100
    jl ClearScoreCol
    inc dx
    cmp dx, 8
    jl ClearScoreRow
    pop dx
    pop cx
    pop bx
    pop ax
    
    ; Draw score
    call DrawScoreHUD
    
    ; Re-enable interrupts temporarily for input
    sti
    
    ; Handle input
    call HandleInput
    
    ; Disable interrupts for drawing operations
    cli
   
    ; Erase car at old position
    call EraseCarAtPosition
    
    ; Move to new position
    call MoveCarSmooth
    
    ; Redraw lanes
    call DrawLanesSolid
    
    ; Update and draw objects
    call UpdateObject
    
    ; Draw player car
    call DrawCar
    
    ; Re-enable interrupts
    sti
    
    ; Check for game over
    mov al, [gameOver]
    cmp al, 1
    je GameOverSequence
    
    ; Check for ESC confirmation
    mov al, [escPressed]
    cmp al, 1
    je ShowExitConfirm
    
    ; Delay
    mov cx, 2000
DelayLoop:
    loop DelayLoop
    
    jmp Animation

ShowExitConfirm:
    ; Disable game flag to stop scrolling
    mov byte [gameStarted], 0
    
    ; Save current state and show confirmation
    call ShowExitScreen
    
    ; Check response
    mov al, [exitConfirmed]
    cmp al, 1
    je ExitGame
    
    ; Resume game - enable scrolling again
    mov byte [gameStarted], 1
    mov byte [escPressed], 0
    jmp Animation

GameOverSequence:
    ; Disable scrolling
    mov byte [gameStarted], 0
    call ShowEndScreen
    jmp ExitGame

ExitGame:
    ; Restore original interrupt vectors
    cli
    mov ax, 0
    mov es, ax
    mov ax, [oldKbdOff]
    mov [es:9*4], ax
    mov ax, [oldKbdSeg]
    mov [es:9*4+2], ax
    
    mov ax, [oldTimerOff]
    mov [es:1Ch*4], ax
    mov ax, [oldTimerSeg]
    mov [es:1Ch*4+2], ax
    sti
    
    ; Return to text mode
    mov ax, 0003h
    int 10h
    
    ; Exit to DOS
    mov ax, 4C00h
    int 21h

; ============================================================
; PART II: Introduction Screen
; ============================================================
ShowIntroScreen:
    push ax
    push bx
    push cx
    push dx
    
    mov ax, 0003h
    int 10h
    
    ; Title
    mov ah, 02h
    mov bh, 0
    mov dh, 5
    mov dl, 15
    int 10h
    mov si, gameTitle
    call PrintString
    
    ; Roll numbers
    mov ah, 02h
    mov dh, 10
    mov dl, 10
    int 10h
    mov si, rollMsg
    call PrintString
    
    ; Names
    mov ah, 02h
    mov dh, 12
    mov dl, 10
    int 10h
    mov si, namesMsg
    call PrintString
    
    ; Semester
    mov ah, 02h
    mov dh, 14
    mov dl, 15
    int 10h
    mov si, semesterMsg
    call PrintString
    
    ; Instructions
    mov ah, 02h
    mov dh, 18
    mov dl, 8
    int 10h
    mov si, instructMsg
    call PrintString
    
    ; Wait for Enter key
WaitIntro:
    mov ah, 00h
    int 16h
    cmp al, 0Dh
    jne WaitIntro
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; PART II: Exit Confirmation Screen
; ============================================================
ShowExitScreen:
    push ax
    push bx
    push cx
    push dx
    push es
    
    ; Switch to text mode
    mov ax, 0003h
    int 10h
    
    ; Temporarily restore original keyboard handler
    cli
    mov ax, 0
    mov es, ax
    mov ax, [oldKbdOff]
    mov [es:9*4], ax
    mov ax, [oldKbdSeg]
    mov [es:9*4+2], ax
    sti
    
    ; Show message
    mov ah, 02h
    mov bh, 0
    mov dh, 10
    mov dl, 15
    int 10h
    mov si, exitMsg
    call PrintString
    
    ; Get response
WaitExit:
    mov ah, 00h
    int 16h
    
    cmp al, 'Y'
    je ConfirmYes
    cmp al, 'y'
    je ConfirmYes
    cmp al, 'N'
    je ConfirmNo
    cmp al, 'n'
    je ConfirmNo
    
    jmp WaitExit

ConfirmYes:
    mov byte [exitConfirmed], 1
    jmp ExitScreen_Done

ConfirmNo:
    mov byte [exitConfirmed], 0
    mov byte [escPressed], 0
    
    ; Switch back to graphics mode
    mov ax, 13h
    int 10h
    
    ; Reinstall custom keyboard handler
    cli
    mov ax, 0
    mov es, ax
    mov word [es:9*4], NewKbdISR
    mov [es:9*4+2], cs
    sti
    
    ; Redraw everything
    call DrawLandscape
    call DrawRoad
    call DrawLanesSolid
    call DrawLeftTrees
    call DrawRightTrees
    call DrawCar

ExitScreen_Done:
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; PART II: End Screen (Game Over)
; ============================================================
ShowEndScreen:
    push ax
    push bx
    push cx
    push dx
    push es
    
    ; Switch to text mode
    mov ax, 0003h
    int 10h
    
    ; Temporarily restore original keyboard handler
    cli
    mov ax, 0
    mov es, ax
    mov ax, [oldKbdOff]
    mov [es:9*4], ax
    mov ax, [oldKbdSeg]
    mov [es:9*4+2], ax
    sti
    
    ; Game Over message
    mov ah, 02h
    mov bh, 0
    mov dh, 10
    mov dl, 20
    int 10h
    mov si, gameOverMsg
    call PrintString
    
    ; Final score
    mov ah, 02h
    mov dh, 12
    mov dl, 20
    int 10h
    mov si, finalScoreMsg
    call PrintString
    
    mov ax, [score]
    call PrintDecAX
    
    ; Wait message
    mov ah, 02h
    mov dh, 16
    mov dl, 15
    int 10h
    mov si, pressKeyMsg
    call PrintString
    
    ; Wait for any key
    mov ah, 00h
    int 16h
    
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

PrintString:
    push ax
    push bx
PS_Loop:
    lodsb
    cmp al, 0
    je PS_Done
    mov ah, 0Eh
    mov bh, 0
    mov bl, 0Fh
    int 10h
    jmp PS_Loop
PS_Done:
    pop bx
    pop ax
    ret

; ============================================================
; PART I & II: Custom Keyboard ISR (INT 9)
; ============================================================
NewKbdISR:
    push ax
    push bx
    push ds
    
    mov ax, cs
    mov ds, ax
    
    in al, 60h
    
    cmp al, 01h
    je KbdESC
    cmp al, 4Bh
    je KbdLeft
    cmp al, 4Dh
    je KbdRight
    
    jmp KbdDone

KbdESC:
    mov byte [escPressed], 1
    jmp KbdDone

KbdLeft:
    mov ax, [carX]
    cmp ax, 145
    je SetLeft_ISR
    cmp ax, 180
    je SetCenter_ISR
    jmp KbdDone

SetLeft_ISR:
    mov word [targetCarX], 110
    jmp KbdDone

SetCenter_ISR:
    mov word [targetCarX], 145
    jmp KbdDone

KbdRight:
    mov ax, [carX]
    cmp ax, 110
    je SetCenterR_ISR
    cmp ax, 145
    je SetRight_ISR
    jmp KbdDone

SetCenterR_ISR:
    mov word [targetCarX], 145
    jmp KbdDone

SetRight_ISR:
    mov word [targetCarX], 180

KbdDone:
    mov al, 20h
    out 20h, al
    
    pop ds
    pop bx
    pop ax
    iret

; ============================================================
; PART III: Timer ISR (INT 1Ch)
; ============================================================
NewTimerISR:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    ; Check if game has started
    mov al, [gameStarted]
    cmp al, 1
    jne TimerDone
    
    inc word [timerCounter]
    
   
    cmp word [timerCounter], 4
    jl TimerDone
    
    mov word [timerCounter], 0
    call MoveScreen
    
TimerDone:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret
; ============================================================
; Drawing Primitives
; ============================================================

DrawLandscape:
    mov cx, 0
LG_X:
    mov dx, 0
LG_Y:
    mov bh, 0
    mov ah, 0Ch
    mov al, 2
    int 10h
    inc dx
    cmp dx, 200
    jl LG_Y
    inc cx
    cmp cx, 100
    jl LG_X

    mov cx, 220
RG_X:
    mov dx, 0
RG_Y:
    mov bh, 0
    mov ah, 0Ch
    mov al, 2
    int 10h
    inc dx
    cmp dx, 200
    jl RG_Y
    inc cx
    cmp cx, 320
    jl RG_X
    ret

DrawRoad:
    mov cx, 100
RD_X:
    mov dx, 0
RD_Y:
    mov bh, 0
    mov ah, 0Ch
    mov al, 8
    int 10h
    inc dx
    cmp dx, 200
    jl RD_Y
    inc cx
    cmp cx, 220
    jl RD_X
    ret

DrawLanesSolid:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, 140
    mov dx, 10      ; Start below score area
LN1_Y:
    mov bh, 0
    mov ah, 0Ch
    mov al, 15
    int 10h
    inc dx
    cmp dx, 200
    jl LN1_Y

    mov cx, 180
    mov dx, 10      ; Start below score area
LN2_Y:
    mov bh, 0
    mov ah, 0Ch
    mov al, 15
    int 10h
    inc dx
    cmp dx, 200
    jl LN2_Y
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret


DrawCar:
    push ax
    push bx
    push cx
    push dx
    push bp

    mov si, [carX]
    mov di, [carY]

    ; Main body
    mov cx, si
    mov bx, cx
    add bx, 30
DC_BodyX:
    mov dx, di
    add dx, 2
    mov bp, dx
    add bp, 16
DC_BodyY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 4
    int 10h
    inc dx
    cmp dx, bp
    jl DC_BodyY
    inc cx
    cmp cx, bx
    jl DC_BodyX

    ; Windshield
    mov cx, si
    add cx, 5
    mov bx, cx
    add bx, 20
DC_WindX:
    mov dx, di
    add dx, 4
    mov bp, dx
    add bp, 4
DC_WindY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 9
    int 10h
    inc dx
    cmp dx, bp
    jl DC_WindY
    inc cx
    cmp cx, bx
    jl DC_WindX

    ; Roof
    mov cx, si
    add cx, 3
    mov bx, cx
    add bx, 24
DC_RoofX:
    mov dx, di
    mov bp, dx
    add bp, 2
DC_RoofY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 4
    int 10h
    inc dx
    cmp dx, bp
    jl DC_RoofY
    inc cx
    cmp cx, bx
    jl DC_RoofX

    ; Left wheel
    mov cx, si
    add cx, 4
    mov bx, cx
    add bx, 6
DC_LWheelX:
    mov dx, di
    add dx, 16
    mov bp, dx
    add bp, 4
DC_LWheelY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 8
    int 10h
    inc dx
    cmp dx, bp
    jl DC_LWheelY
    inc cx
    cmp cx, bx
    jl DC_LWheelX

    ; Right wheel
    mov cx, si
    add cx, 20
    mov bx, cx
    add bx, 6
DC_RWheelX:
    mov dx, di
    add dx, 16
    mov bp, dx
    add bp, 4
DC_RWheelY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 8
    int 10h
    inc dx
    cmp dx, bp
    jl DC_RWheelY
    inc cx
    cmp cx, bx
    jl DC_RWheelX

    ; Left headlight
    mov cx, si
    add cx, 2
    mov bx, cx
    add bx, 4
DC_LHeadX:
    mov dx, di
    add dx, 18
    mov bp, dx
    add bp, 2
DC_LHeadY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 14
    int 10h
    inc dx
    cmp dx, bp
    jl DC_LHeadY
    inc cx
    cmp cx, bx
    jl DC_LHeadX

    ; Right headlight
    mov cx, si
    add cx, 24
    mov bx, cx
    add bx, 4
DC_RHeadX:
    mov dx, di
    add dx, 18
    mov bp, dx
    add bp, 2
DC_RHeadY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 14
    int 10h
    inc dx
    cmp dx, bp
    jl DC_RHeadY
    inc cx
    cmp cx, bx
    jl DC_RHeadX

    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret

EraseCarAtPosition:
    push ax
    push bx
    push cx
    push dx
    push bp
    push si
    push di

    mov si, [carX]
    mov di, [carY]
    mov bp, si
    add bp, 30
ECP_X:
    mov cx, si
    mov dx, di
    mov bx, dx
    add bx, 20
ECP_Y:
    cmp cx, 140
    je ECP_Skip
    cmp cx, 180
    je ECP_Skip
    
    mov bh, 0
    mov ah, 0Ch
    mov al, 8
    int 10h

ECP_Skip:
    inc dx
    cmp dx, bx
    jl ECP_Y
    inc si
    cmp si, bp
    jl ECP_X

    pop di
    pop si
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret

HandleInput:
    ret

MoveCarSmooth:
    mov ax, [targetCarX]
    mov [carX], ax
    ret
DrawLeftTrees:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov si, 30
    mov di, 30
DLT_Loop:
    mov cx, si
    mov dx, di
DLT_TrunkY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 6
    int 10h
    inc dx
    mov bp, di
    add bp, 10
    cmp dx, bp
    jl DLT_TrunkY

    mov cx, si
    sub cx, 5
DLT_CanX:
    mov dx, di
    sub dx, 10
DLT_CanY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 10
    int 10h
    inc dx
    mov bp, di
    sub bp, 5
    cmp dx, bp
    jl DLT_CanY
    inc cx
    mov bx, si
    add bx, 5
    cmp cx, bx
    jl DLT_CanX

    add di, 30
    cmp di, 180
    jl DLT_Loop

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DrawRightTrees:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov si, 270
    mov di, 30
DRT_Loop:
    mov cx, si
    mov dx, di
DRT_TrunkY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 6
    int 10h
    inc dx
    mov bp, di
    add bp, 10
    cmp dx, bp
    jl DRT_TrunkY

    mov cx, si
    sub cx, 5
DRT_CanX:
    mov dx, di
    sub dx, 10
DRT_CanY:
    mov bh, 0
    mov ah, 0Ch
    mov al, 10
    int 10h
    inc dx
    mov bp, di
    sub bp, 5
    cmp dx, bp
    jl DRT_CanY
    inc cx
    mov bx, si
    add bx, 5
    cmp cx, bx
    jl DRT_CanX

    add di, 30
    cmp di, 180
    jl DRT_Loop

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

MoveScreen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov dx, 199
MS_Row:
    mov cx, 0
MS_Col:
    push ax
    push bx
    
    mov ax, [carY]
    mov bx, ax
    add bx, 20
    cmp dx, ax
    jl MS_CheckAbove
    cmp dx, bx
    jge MS_CheckAbove
    mov ax, [carX]
    mov bx, ax
    add bx, 30
    cmp cx, ax
    jl MS_CheckAbove
    cmp cx, bx
    jge MS_CheckAbove
    pop bx
    pop ax
    jmp MS_NextCol

MS_CheckAbove:
    cmp dx, 10
    jle MS_FillNew
    mov ax, [carY]
    mov bx, ax
    add bx, 20
    push dx
    dec dx
    cmp dx, ax
    pop dx
    jl MS_DoScroll
    push dx
    dec dx
    cmp dx, bx
    pop dx
    jge MS_DoScroll
    mov ax, [carX]
    mov bx, ax
    add bx, 30
    cmp cx, ax
    jl MS_DoScroll
    cmp cx, bx
    jge MS_DoScroll
    pop bx
    pop ax
    jmp MS_NextCol

MS_DoScroll:
    pop bx
    pop ax
    
    push cx
    push dx
    dec dx
    mov bh, 0
    mov ah, 0Dh
    int 10h
    mov bl, al
    pop dx
    pop cx
    
    push cx
    push dx
    mov bh, 0
    mov ah, 0Ch
    mov al, bl
    int 10h
    pop dx
    pop cx
    jmp MS_NextCol

MS_FillNew:
    pop bx
    pop ax
    push cx
    push dx
    
    ; Simply fill with appropriate background color
    cmp cx, 100
    jl MS_NewGrass
    cmp cx, 220
    jl MS_NewRoad
    
MS_NewGrass:
    mov al, 2           ; Green grass
    jmp MS_WriteNew
    
MS_NewRoad:
    mov al, 8           ; Gray road
    
MS_WriteNew:
    mov bh, 0
    mov ah, 0Ch
    int 10h
    pop dx
    pop cx
    jmp MS_NextCol
MS_NextCol:
    inc cx
    cmp cx, 320
    jl MS_Col
    
    dec dx
    cmp dx, 10
    jge MS_Row

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; Object System
; ============================================================

UpdateObject:
    call EraseObject
    call MoveObject
    call CheckCollision
    call DrawObject
    ret

MoveObject:
    add word [objY], 3
    cmp word [objY], 180
    jl MO_SkipReset
    call RandomizeObject
MO_SkipReset:
    ret

EraseObject:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov si, [objX]
    mov di, [objY]
    mov bx, si
    add bx, 30
EO_X:
    mov cx, si
    mov dx, di
    mov bp, dx
    add bp, 20
EO_Y:
    mov ax, [carX]
    cmp cx, ax
    jl EO_Safe
    add ax, 30
    cmp cx, ax
    jg EO_Safe
    mov ax, [carY]
    cmp dx, ax
    jl EO_Safe
    add ax, 20
    cmp dx, ax
    jg EO_Safe
    jmp EO_Skip

EO_Safe:
    cmp cx, 140
    je EO_Skip
    cmp cx, 180
    je EO_Skip
    mov bh, 0
    mov ah, 0Ch
    mov al, 8
    int 10h

EO_Skip:
    inc dx
    cmp dx, bp
    jl EO_Y
    inc si
    cmp si, bx
    jl EO_X

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DrawObject:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov si, [objX]
    mov di, [objY]
    
    mov al, [objType]
    cmp al, 1
    jne DO_DrawEnemy
    jmp DO_DrawBonus

DO_DrawEnemy:
    ; Enemy car body
    mov cx, si
    mov bx, cx
    add bx, 30
DOE_BodyX:
    mov dx, di
    add dx, 3
    mov bp, dx
    add bp, 14
DOE_BodyY:
    push ax
    mov ax, [carX]
    cmp cx, ax
    jl DOE_BSafe
    add ax, 30
    cmp cx, ax
    jg DOE_BSafe
    mov ax, [carY]
    cmp dx, ax
    jl DOE_BSafe
    add ax, 20
    cmp dx, ax
    pop ax
    jg DOE_BSafe
    pop ax
    jmp DOE_BSkip
DOE_BSafe:
    pop ax
    cmp cx, 140
    je DOE_BSkip
    cmp cx, 180
    je DOE_BSkip
    mov bh, 0
    mov ah, 0Ch
    mov al, [objColor]
    int 10h
DOE_BSkip:
    inc dx
    cmp dx, bp
    jl DOE_BodyY
    inc cx
    cmp cx, bx
    jl DOE_BodyX
    
    ; Window
    mov cx, si
    add cx, 5
    mov bx, cx
    add bx, 20
DOE_WinX:
    mov dx, di
    add dx, 6
    mov bp, dx
    add bp, 3
DOE_WinY:
    push ax
    mov ax, [carX]
    cmp cx, ax
    jl DOE_WSafe
    add ax, 30
    cmp cx, ax
    jg DOE_WSafe
    mov ax, [carY]
    cmp dx, ax
    jl DOE_WSafe
    add ax, 20
    cmp dx, ax
    pop ax
    jg DOE_WSafe
    pop ax
    jmp DOE_WSkip
DOE_WSafe:
    pop ax
    cmp cx, 140
    je DOE_WSkip
    cmp cx, 180
    je DOE_WSkip
    mov bh, 0
    mov ah, 0Ch
    mov al, 11
    int 10h
DOE_WSkip:
    inc dx
    cmp dx, bp
    jl DOE_WinY
    inc cx
    cmp cx, bx
    jl DOE_WinX
    
    ; Roof
    mov cx, si
    add cx, 3
    mov bx, cx
    add bx, 24
DOE_RoofX:
    mov dx, di
    mov bp, dx
    add bp, 3
DOE_RoofY:
    push ax
    mov ax, [carX]
    cmp cx, ax
    jl DOE_RSafe
    add ax, 30
    cmp cx, ax
    jg DOE_RSafe
    mov ax, [carY]
    cmp dx, ax
    jl DOE_RSafe
    add ax, 20
    cmp dx, ax
    pop ax
    jg DOE_RSafe
    pop ax
    jmp DOE_RSkip
DOE_RSafe:
    pop ax
    cmp cx, 140
    je DOE_RSkip
    cmp cx, 180
    je DOE_RSkip
    mov bh, 0
    mov ah, 0Ch
    mov al, [objColor]
    int 10h
DOE_RSkip:
    inc dx
    cmp dx, bp
    jl DOE_RoofY
    inc cx
    cmp cx, bx
    jl DOE_RoofX
    
    jmp DO_Done

DO_DrawBonus:
    ; Outer yellow border
    mov cx, si
    add cx, 3
    mov bx, cx
    add bx, 24
DOB_OuterX:
    mov dx, di
    add dx, 1
    mov bp, dx
    add bp, 18
DOB_OuterY:
    push ax
    mov ax, [carX]
    cmp cx, ax
    jl DOB_OSafe
    add ax, 30
    cmp cx, ax
    jg DOB_OSafe
    mov ax, [carY]
    cmp dx, ax
    jl DOB_OSafe
    add ax, 20
    cmp dx, ax
    pop ax
    jg DOB_OSafe
    pop ax
    jmp DOB_OSkip
DOB_OSafe:
    pop ax
    cmp cx, 140
    je DOB_OSkip
    cmp cx, 180
    je DOB_OSkip
    mov bh, 0
    mov ah, 0Ch
    mov al, 14         ; Bright yellow
    int 10h
DOB_OSkip:
    inc dx
    cmp dx, bp
    jl DOB_OuterY
    inc cx
    cmp cx, bx
    jl DOB_OuterX
    
    ; Inner orange/red core (16x12)
    mov cx, si
    add cx, 7
    mov bx, cx
    add bx, 16
DOB_InnerX:
    mov dx, di
    add dx, 4
    mov bp, dx
    add bp, 12
DOB_InnerY:
    push ax
    mov ax, [carX]
    cmp cx, ax
    jl DOB_ISafe
    add ax, 30
    cmp cx, ax
    jg DOB_ISafe
    mov ax, [carY]
    cmp dx, ax
    jl DOB_ISafe
    add ax, 20
    cmp dx, ax
    pop ax
    jg DOB_ISafe
    pop ax
    jmp DOB_ISkip
DOB_ISafe:
    pop ax
    cmp cx, 140
    je DOB_ISkip
    cmp cx, 180
    je DOB_ISkip
    mov bh, 0
    mov ah, 0Ch
    mov al, 12         ; Light red/orange center
    int 10h
DOB_ISkip:
    inc dx
    cmp dx, bp
    jl DOB_InnerY
    inc cx
    cmp cx, bx
    jl DOB_InnerX
    
    ; Small white highlight (6x4)
    mov cx, si
    add cx, 10
    mov bx, cx
    add bx, 6
DOB_HighX:
    mov dx, di
    add dx, 6
    mov bp, dx
    add bp, 4
DOB_HighY:
    push ax
    mov ax, [carX]
    cmp cx, ax
    jl DOB_HSafe
    add ax, 30
    cmp cx, ax
    jg DOB_HSafe
    mov ax, [carY]
    cmp dx, ax
    jl DOB_HSafe
    add ax, 20
    cmp dx, ax
    pop ax
    jg DOB_HSafe
    pop ax
    jmp DOB_HSkip
DOB_HSafe:
    pop ax
    cmp cx, 140
    je DOB_HSkip
    cmp cx, 180
    je DOB_HSkip
    mov bh, 0
    mov ah, 0Ch
    mov al, 15         ; White highlight
    int 10h
DOB_HSkip:
    inc dx
    cmp dx, bp
    jl DOB_HighY
    inc cx
    cmp cx, bx
    jl DOB_HighX

DO_Done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

RandomizeObject:
    ; Use BIOS ticks for pseudo-random
    mov ah, 00h
    int 1Ah            ; CX:DX = ticks
    mov ax, dx
    and ax, 0003h
    cmp ax, 0
    je RO_Left
    cmp ax, 1
    je RO_Center
    jmp RO_Right
RO_Left:
    mov word [objX], 110
    jmp RO_SetType
RO_Center:
    mov word [objX], 145
    jmp RO_SetType
RO_Right:
    mov word [objX], 180
RO_SetType:
    mov ax, dx
    and ax, 0001h
    mov [objType], al

    cmp al, 1
    je RO_BonusColor

    ; Enemy: use solid darker colors
    mov ax, dx
    shr ax, 4
    and ax, 0003h
    cmp ax, 0
    je RO_Blue
    cmp ax, 1
    je RO_Red
    cmp ax, 2
    je RO_Magenta
    mov byte [objColor], 3  ; cyan
    jmp RO_SetY
RO_Blue:
    mov byte [objColor], 1  ; blue
    jmp RO_SetY
RO_Red:
    mov byte [objColor], 4  ; red
    jmp RO_SetY
RO_Magenta:
    mov byte [objColor], 5  ; magenta
    jmp RO_SetY

RO_BonusColor:
    mov byte [objColor], 14     ; bright yellow for bonus

RO_SetY:
    mov word [objY], 0
    ret

CheckCollision:
    push ax
    push bx
    push cx
    push dx

    ; Check vertical overlap
    mov ax, [objY]
    add ax, 20         ; objY + obj height
    mov bx, [carY]
    cmp ax, bx
    jl CC_No           ; obj bottom < car top
    
    mov ax, [objY]
    mov bx, [carY]
    add bx, 20         ; carY + car height
    cmp ax, bx
    jg CC_No           ; obj top > car bottom

    ; Check horizontal overlap
    mov ax, [objX]
    add ax, 30         ; objX + obj width
    mov bx, [carX]
    cmp ax, bx
    jl CC_No           ; obj right < car left
    
    mov ax, [objX]
    mov bx, [carX]
    add bx, 30         ; carX + car width
    cmp ax, bx
    jg CC_No           ; obj left > car right

    ; COLLISION DETECTED!
    mov al, [objType]
    cmp al, 1
    je CC_Bonus

    ; Enemy collision - GAME OVER
    mov byte [gameOver], 1
    jmp CC_Exit

CC_Bonus:
    inc word [score]
    call RandomizeObject

CC_Exit:
CC_No:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; HUD: Draw score at top-left
; ============================================================
DrawScoreHUD:
    push ax
    push bx
    push cx
    push dx

    ; Cursor to row 0, col 0
    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 10h

    ; Print "Score: "
    mov ah, 0Eh
    mov bh, 0
    mov bl, 0Fh
    mov al, 'S'
    int 10h
    mov al, 'c'
    int 10h
    mov al, 'o'
    int 10h
    mov al, 'r'
    int 10h
    mov al, 'e'
    int 10h
    mov al, ':'
    int 10h
    mov al, ' '
    int 10h

    mov ax, [score]
    call PrintDecAX

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Print AX as unsigned decimal
PrintDecAX:
    push ax
    push bx
    push cx
    push dx

    mov bx, 10
    xor cx, cx
    cmp ax, 0
    jne PD_Conv
    mov ah, 0Eh
    mov bh, 0
    mov bl, 0Fh
    mov al, '0'
    int 10h
    jmp PD_Done

PD_Conv:
PD_Div:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne PD_Div

PD_Print:
    pop dx
    add dl, '0'
    mov ah, 0Eh
    mov bh, 0
    mov bl, 0Fh
    mov al, dl
    int 10h
    loop PD_Print

PD_Done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; Data Section
; ============================================================
objX         dw 145
objY         dw 0
objType      db 1
objColor     db 1
score        dw 0
carY         dw 170
carX         dw 145
targetCarX   dw 145

; Interrupt-related variables
oldKbdOff    dw 0
oldKbdSeg    dw 0
oldTimerOff  dw 0
oldTimerSeg  dw 0
timerCounter dw 0
escPressed   db 0
exitConfirmed db 0
gameOver     db 0
gameStarted  db 0

; String messages
gameTitle      db '--------------------------------------', 0Dh, 0Ah
               db '                         ROAD RACER                     ', 0Dh, 0Ah
               db '                ---------------------------------------', 0
rollMsg        db '         Roll Numbers: 24l-0523, 24l-0833        ', 0
namesMsg       db '         Names: Ayesha Muzammil, Fatima Tahir    ', 0
semesterMsg    db '         Semester: Fall 2025                     ', 0
instructMsg    db '         Press ENTER to start the game!          ', 0Dh, 0Ah
               db '                 Use LEFT/RIGHT arrows to change lanes   ', 0
exitMsg        db '         Are you sure you want to exit? (Y/N)     ', 0
gameOverMsg    db '         GAME OVER - You Crashed!                 ', 0
finalScoreMsg  db '         Your Final Score:                        ', 0
pressKeyMsg    db '         Press any key to exit...                 ', 0
escExitMsg     db '         Press ESC to exit to DOS'                , 0
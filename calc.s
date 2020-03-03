section	.rodata								; we define (global) read-only variables in .rodata section
        calcMsg: db "calc: ", 0						;so we can print calc msg
	printInt: db "%02X", 0
	printInt1: db "%01X", 0
	printLine: db 10, 0
	printOverFlow: db "Error: Operand Stack Overflow", 0
	printEmpty: db "Error: Insufficient Number of Arguments on Stack", 0
	printYErr: db "wrong Y value", 0

section .bss
	bufferInput: resb 82
	bufferInputLength equ $ - bufferInput
	bufferOffset: resb 4
	numberStack: resb 20
	numPointer: resb 4
	prevPointer: resb 4
	firstPointer: resb 4
	firstPointer1: resb 4
	firstPointer2: resb 4
	curr: resb 4
	temp: resb 1
	flagOdd: resb 1
	stackCount: resb 1
	prev1: resb 4
	prev2: resb 4
	stayFlag: resb 1
	errorFlag: resb 1
	currPointer: resb 4
	oddF: resb 1
	actionsNum: resb 4
	tempOdd: resb 1
	oneLink: resb 1
	peekPointer: resb 4
	debugFlag: resb 1
	currByte: resb 4
	tempChar: resb 4

section .text                    					;we write code in .text section
	global main
	extern printf
	extern fprintf
	extern fflush
	extern malloc
	extern calloc
	extern free
	extern fgets
	extern stdin
	extern stderr
	extern stdout	
 
main:	
	mov [debugFlag], byte 0						; check for debugger
	cmp dword [esp+4],2
	jne _debugOff
	mov [debugFlag], byte 1

	_debugOff:

		mov [actionsNum], byte 0				;reset counter of actions
		call myCalc						;call the calculator loop
		
		pushad
		movzx eax, byte [actionsNum]
		push eax
		push printInt1					
		call printf						;print to stdout the actual number
		add esp,8
		popad
		
		pushad
		push printLine
		call printf						;print to stdout new line
		add esp,4
		popad

		pushad
		push dword [stdout]				
		call fflush						;call fflush to show stdout
		add esp,4
		popad
		
		mov eax, 1						;set sys_exit
		mov ebx, 0						;set return arg
		int 0x80						;call sys_exit

myCalc:
	push ebp
	mov ebp, esp
	pushad

	mov eax, numberStack
	mov [numPointer], eax
	mov byte [flagOdd], 0
	mov byte [stackCount], 0
	mov byte [stayFlag], 0
	mov byte [errorFlag], 0

	_loop:	
		pushad
		push dword calcMsg					;set msg text to print
		call printf						;print msg for the user to enter an input
		add esp,4						;update stack index
		popad

		pushad						
		push dword [stdin]					;set arg - read from stdin
		push bufferInputLength					;set arg - size of buffer to read
		push bufferInput					;set arg - write to bufferInput
		call fgets						;call fgets - get the input 
		add esp, 12						;update stack index
		popad

		call cleanZeros						;check for unwanted zeros and clean them

		mov eax, [bufferOffset]					;set input to register

		cmp [eax], byte 'q'					;case 'q' - exit program
		je _end
	
		cmp [eax], byte '+' 					;case '+' - add two number
		je _plus	
	
		cmp [eax], byte 'p'					;case 'p' - print answer
		je _popPrint

		cmp [eax], byte 'd'					;case 'd' - duplicate value 
		je _duplicate

		cmp [eax], byte '^'					;case '^' - calc power
		je _power

		cmp [eax], byte 'v'					;case 'v' - calc negative power
		je _negPower

		cmp [eax], byte 'n'					;case 'n' - calc number of '1-s' in binary representation
		je _oneBitsCount

		cmp [eax], dword 'sr'					;case 'sr' - calc square root
		je _squareRoot

		jmp _number						;default case - a number was entered


		_power:
			call power					;call power func	

			mov esi, [actionsNum]				;inc actions counter
			inc esi
			mov [actionsNum], esi

			cmp [debugFlag], byte 0				;check debug mode
			je _loop
			call debugPrint					;print debug info
			jmp _loop					;go back to main loop
			
		_plus:
			call plus					;call function plus
			mov esi, [actionsNum]						;inc counter of actions
			inc esi
			mov [actionsNum], esi

					
			cmp [debugFlag], byte 0				;check debug mode
			je _loop
			call debugPrint					;print debug info
			jmp _loop					;go back to main loop


		_popPrint:
		
			mov esi, [actionsNum]				
			inc esi
			mov [actionsNum], esi

			cmp byte [stackCount], 0			;check if there are items in the stack to print
			je _errorPrint					;if not, error

			dec byte [stackCount]				;decrease the num of items in the stack 
			mov eax, [numPointer]				
			sub eax, 4					
			mov [numPointer], eax				;decrease the pointer to the stack to the right place
			mov edx, [eax]					;edx now contain the pointer to the first node in stack
			mov eax, [flagOdd]
			mov [tempOdd], eax				;put the value in tempOdd to check if the number is odd
			mov byte [oneLink], 0				;varaible that helps to check if we have one link
				
			
			_startPrint:
				cmp dword [edx +1], 0			;check if we are at the end of x
				je _finishPrint				;if we are at the end of the number jump to the end

				mov byte [oneLink],1			;if the next link exists, we have more than one link
				cmp byte [stayFlag], 1			;check if we have a stay
				je _stayPrint

				movzx eax, byte [edx]			;put in eax the data of the link

				pushad
				push dword eax
				cmp byte [tempOdd], 1			;if the number is odd we need to print with 01X the first node
				je _oddPrint

				push printInt
				call printf

				jmp _evenPrint				; if even print regular
				
				_oddPrint:	
					push printInt1			; print in case the number is odd
					call printf
					mov byte [tempOdd], 0
	
				_evenPrint:
					add esp, 8
					popad

					mov eax, [edx + 1]		; put in eax the next node
					mov edx, eax			; put in edx the next node		
					jmp _startPrint
			
			_finishPrint:
				movzx eax, byte [edx]			;put in eax the byte of the final link

				cmp byte [oneLink], 0			;if we didn't raise oneByte, print 01X
				je _oneByte
				
				pushad				
				push dword eax
				push printInt 				;if not, print regular
				call printf
				add esp, 8
				popad

				jmp _moreThanOneByte			;jump after oneByte

				_oneByte:
					pushad				
					push dword eax
					push printInt1 			;print 01X
					call printf
					add esp, 8
					popad
				
				_moreThanOneByte:
					pushad
					push printLine
					call printf			;print next line
					add esp, 4
					popad

					jmp _loop

			_errorPrint:					;in case of error
				pushad
				push dword printEmpty			;print the error massage
				call printf
				add esp,4
				popad

				pushad
				push dword printLine			;print next line
				call printf
				add esp,4
				popad
		
				jmp _loop

			_stayPrint:
				mov byte [tempOdd], 0
				movzx eax, byte [edx]

				pushad
				push dword eax
				push printInt1
				call printf
				add esp, 8
				popad

				mov eax, [edx + 1]		; put in eax the next node
				mov edx, eax			; put in edx the next node		
				mov byte [stayFlag], 0
				jmp _startPrint


		_duplicate:
			call duplicate					;call duplicate function

			mov esi, [actionsNum]
			inc esi
			mov [actionsNum], esi

			cmp [debugFlag], byte 0				;check debug mode
			je _loop
			call debugPrint					;print debug info
			jmp _loop					;go back to main loop


		_negPower:
			mov esi, [actionsNum]
			inc esi
			mov [actionsNum], esi
			call popItem					;get x from the stack
			cmp byte [errorFlag], 1				;check if there is an error 
			mov byte [errorFlag], 0
			je _loop
			mov edx, [firstPointer]				;edx contains the pointer to x 
			call popItem					;get y from the stack
			cmp byte [errorFlag], 0	
			je ok1
			call pushFirstToStack				;bring the stack to the previus status
			mov byte [errorFlag], 0
			jmp _loop
			ok1:
			mov ecx, [firstPointer]				;ecx contains the pointer to y
			mov [firstPointer], edx				;[firstPointer] contains the first link of x
			
			mov eax, [ecx]					;eax contains y
			cmp byte [ecx + 1], 0
        		jne YError                			;y must be lower than one node
			movzx esi, al
			cmp esi, 201					;y must be lower than 201
    		        jge YError

			mov [firstPointer], edx				;[firstPointer] contains the first link of x
			call size					;check the link size of x
			push eax
			call oppList					;oposite x that the first node is the lowst
			pop eax   
	
			_addingLoop2:

				mov edx, [firstPointer]			;edx contains the first link of x

				cmp esi, 0				;do this loop until y is zero
				je finishNegPow
				cmp esi, 8				;check if esi is grater than 8
    		       		jge GT8
				mov edi, 8
				sub edi, esi				;if not, put in edi the rest esi need to be 8
				mov esi, 8
				
				pushad					;create new link for the counter
				mov eax, 5				
				push eax							
				call malloc
				add esp,4

				mov dword [eax], edi			;put the rest value in the link we have as data
				
				mov [firstPointer], eax			;set link to rest value				
				popad
				call pushFirstToStack			;push the counter link to the stack

				mov [firstPointer], edx
				call size
				push eax
				call oppList				;oposite again x, to put him in the stack
				pop eax  
				call pushFirstToStack			;push x to stack


				call power				;power x with the rest
				call popItem				;get the new x from the stack
				call size
				push eax
				call oppList				;oposite x again to keep working on the lowest node
				pop eax
				mov edx, [firstPointer]			
				GT8:					;in case esi grater than 8
				mov ebx , edx				
				inc ebx
				mov eax, [ebx]				;put in eax the next node
    				cmp dword eax, 0			;check if next node exists
				jne nextNot0
				
				mov byte [edx], 0			;in case not, our value is 0, put it in the data
				jmp finishNegPow
				nextNot0:				;in case we have another node
				
				mov ebx , edx				
				inc ebx
				mov eax, [ebx]				;put in eax the next node
				mov [firstPointer], eax			;put in firstPointer the next node
				mov edx, [firstPointer]			;update edx to the next node
				sub esi, 8				;we removed one node, so we need to decrease the pow by 8
				jmp _addingLoop2			;back to loop
			YError:						;in case of error
				pushad
				push dword printYErr			;print the error massage
				call printf
				add esp,4
				popad

				pushad
				push dword printLine			;print next line	
				call printf
				add esp,4
				popad
				mov [firstPointer], ecx			;put back in stack y
				call pushFirstToStack
				mov [firstPointer], edx			;put bacl in stack x
				call pushFirstToStack
				jmp _loop

			finishNegPow:
				call size
				push eax
				call oppList				;opposite again the number to put in stack
				pop eax  
				call pushFirstToStack			;put in stack the final number
				cmp [debugFlag], byte 0				;check debug mode
				je _loop
				call debugPrint					;print debug info
				jmp _loop					;go back to main loop

		_oneBitsCount:
			mov esi, [actionsNum]				;increase counter of actions
			inc esi
			mov [actionsNum], esi

			call popItem					;get x from the stack
			cmp byte [errorFlag], 1				;check if there is an error 
			mov byte [errorFlag], 0
			je _loop

			mov edx, [firstPointer]				;edx contains the first link


			pushad						;create a new link
			mov eax, 5
			push eax							
			call malloc
			add esp,4
			popad

			mov byte [eax], 0				;put 0 as the data of the link
			mov dword [eax + 1], 0 		
			mov [firstPointer], eax				
			

			call pushFirstToStack				;push the link to the stack

			_initializeCounter:
				movzx eax,byte [edx]				;get curr link's value
				mov ebx, 0     					;reset counter of 1's - ebx
				
			_count:
				cmp eax, 0				;if done dividing the number
				je _finishCount				;jmp to _finishCount
				shr eax, 1				;else - devide by 2
				mov ecx, 0
				setc cl					;cl contains the carry flag
				
				cmp cl, byte 0				;if carry is 0
				je _count				;and go back to _count loop
				inc ebx 				;else (carry is 1) - inc counter
				jmp _count				;go back _count loop

			_finishCount:	
				pushad					;create new link for the counter
				mov eax, 5				
				push eax							
				call malloc
				add esp,4

				mov byte [eax], bl			;put the counter value in the link we have as data
				mov dword [eax + 1], 0
				mov dword [firstPointer], eax			;set link to counter value				
				popad
				call pushFirstToStack			;push the counter link to the stack
					
				call plus				;add the new 'amount' with prev sum	 															
				inc edx					;inc index
				mov edx ,dword [edx]			;get next byte
				
				cmp edx, 0				;check if we are done going over the links				
				jne _initializeCounter			;if no - go to back to _count loop
				
				cmp [debugFlag], byte 0			;else - check debug mode
				je _loop
				call debugPrint				;print debug info
				jmp _loop				;go back to main loop

	

		_squareRoot:
			mov esi, [actionsNum]  				;inc actions counter
			inc esi
			mov [actionsNum], esi
			jmp _loop					;do nothing and go back to main loop
	
		_number:
			cmp byte [stackCount], 5			;if the stack is full, error
			je _overF 

			call makeList					;make the input number a list
			call pushFirstToStack				;push the number to stack
			
			cmp [debugFlag], byte 0
			je _loop
			call debugPrint
			jmp _loop

			_overF:
				pushad
				push dword printOverFlow		;print the error
				call printf
				add esp,4
				popad
	
				pushad
				push dword printLine			;print next line
				call printf
				add esp,4
				popad	

				jmp _loop
				
	_end:
		popad
		mov esp, ebp	
		pop ebp
		ret
	
size:									;return the number of links in number
	push ebp
	mov ebp, esp
	sub esp, 4
	pushad

	mov ebx, 0
	mov edx, [firstPointer]						;put in edx the pointer to the first link 
	_startLoopSize:
		cmp dword edx, 0					;check if we got to the end of the list
		je _finishSize		
		inc ebx							;increase the counter
		mov dword eax, [edx + 1]				
		mov edx, eax						;put in edx the next node
		jmp _startLoopSize					;jump back to the loop

	_finishSize:
		mov dword [ebp - 4], ebx				;save the return value int the local arg
		popad
		mov eax, [ebp - 4]					;put the return value in eax

		mov esp, ebp	
		pop ebp
		ret

pushFirstToStack:							;pushs the firstPointer to the stack
	push ebp
	mov ebp, esp
	pushad

	inc byte [stackCount]						;increase the number of args in the stack
	mov eax, [numPointer]
	mov edx, [firstPointer]						;put in edx the pointer to the number we want to add
	mov [eax], edx
	mov eax, [numPointer]
	add eax, 4
	mov [numPointer], eax						;increase the numPointer to the next empty cell in the stack

	popad
	mov esp, ebp	
	pop ebp
	ret


popItem:								;pops an Item from the stack
	push ebp
	mov ebp, esp
	pushad
	
	cmp byte [stackCount], 0					;if we don't have Items in the stack, error	
	je _error1
	dec byte [stackCount]						;decrease the number of Items in stack
	mov eax, [numPointer]
	sub eax, 4
	mov [numPointer], eax						;decrease the pointer to the stack one cell
	mov edx, [eax]							;put in edx the pointer to Item we pop
		
	mov eax, 5							;create new link 
	pushad
	push eax
	call malloc
	add esp,4
	mov [curr], eax							;save the new link in curr
	popad

	mov ecx, [curr]							;put the new link in ecx
	mov [firstPointer], ecx						;put the first link in firstPointer
	mov [prevPointer], ecx						;the first link is prev to the next one
	movzx eax, byte [edx]						
	mov [ecx], al							;put in the link the right value
	mov eax, [edx + 1]
	mov edx, eax							;increase edx to the next node

	_getNum:
		cmp dword edx, 0					;check if we are in the end of the number
		je _finishPop1
		mov eax, 5

		pushad							;creat new link
		push eax
		call malloc
		add esp,4
		mov [curr], eax
		popad

		mov ecx, [curr]						;put the new link in ecx
		mov eax, [prevPointer]
		inc eax
		mov dword [eax], ecx					;put ibt the next link pointer, pointer to the prev
		mov [prevPointer], ecx					;update the new link to be the prev
		movzx eax,byte [edx]
		mov [ecx], al						;put in the new link data the right data
		mov eax, [edx + 1]
		mov edx, eax						;increase edx to the next node
		jmp _getNum

	_error1:							;in case of error
		pushad
		push dword printEmpty					;print the error massage	
		call printf
		add esp,4
		popad
		pushad
		push dword printLine					;print next line
		call printf
		add esp,4
		popad	
		mov byte [errorFlag], 1					;indicate that there is an error
		
	_finishPop1:
		popad
		mov esp, ebp	
		pop ebp
		ret


makeList:								;put the input number in a list
	push ebp
	mov ebp, esp
	pushad	
	
	mov [temp], byte 0						;var that helps to check if we are in the first node
	call oddEven							;check if the number is odd or even
	mov byte [oddF], al						;put the return value in the flag
	mov eax, [oddF]	
	mov ebx, [bufferOffset]						;ebx is a pointer to input

	_convert:
		movzx edx, byte [ebx]					;get the curr data		
		cmp edx, 10						;check if we are in the end of the input
		je _finishNum	
			
		mov eax, 5						;create new link
		pushad
		push eax
		call malloc
		add esp,4
		mov [curr], eax						;save new link address in [curr]
		popad

		mov ecx, [curr]						;ecx points to new link
		cmp [temp], byte 0					;check if we are in the first node
		je _first

		mov eax, [prevPointer]					
		inc eax
		mov dword [eax], ecx					;if not, put in the value of prev link pointer, pointer to the new link
		mov [prevPointer], ecx					;update the new link to be the previous one
		jmp _convertHexToDec

		_first:
			mov [firstPointer], ecx				;if its the first node, update the firstPointer to him
			mov [prevPointer], ecx				;update the new link to be the previous one
			inc byte [temp]					;increase the flag
		
		_convertHexToDec:
			cmp edx, byte 'F'
			jg _isNum
			cmp edx, byte 'A'
			jl _isNum
			sub edx, byte 55				;if it is num sub 55 to make it the number
			jmp _convert1

		_isNum:
			sub edx, byte 48				;if it is num sub 48 to make it a number

		_convert1:			
			cmp [oddF],byte 1				;if the number is odd, add only the first letter to the first link
			je _odd
	
			inc ebx						;else make the next letter a number also
			mov [tempChar], edx				
			movzx edx, byte [ebx]				;get the curr data		
					
			cmp edx, byte 'F'
			jg _isNum2
			cmp edx, byte 'A'
			jl _isNum2

			sub edx, byte 55				;if its not num sub 55 to make it the number
			jmp _convert2

		_isNum2:
			sub edx, byte 48				;if it is num sub 48 ti make it a number

		_convert2:

			movzx eax, byte [tempChar]
			mov [tempChar], edx
			mov esi, 16
			mul esi						;mul the left number with 16
			
			movzx edx, byte [tempChar]

			add eax, edx					;add the two numbers to one byte
			mov [ecx], eax					;put the value in the new link data
			inc ebx						;inc ebx to the next two letters
			jmp _convert

		_finishNum:
			popad
			mov esp, ebp	
			pop ebp
			ret

		_odd:							;in case of odd			
			mov [ecx], edx					;put the value in the new link data 
			mov byte [flagOdd], 1				;indicate that the number is odd
			mov byte [oddF], 0				;update the flag
			inc ebx						;inc index of input
			jmp _convert



addLink:								;adds two links
	push ebp
	mov ebp, esp
	sub esp, 8
	pushad

	mov eax, dword [ebp+8]						;put the first argument in eax
	mov ebx, dword [ebp+12]						;put the second argument in ebx
	mov ecx, dword [ebp+16] 					;put the third argument in ecx
	movzx edx, al	
	mov eax, edx							;update eax to the first byte of the argument
	movzx edx, bl
	mov ebx, edx							;update ebx to the first byte of the argument
	movzx edx, cl
	mov ecx, edx							;update ecx to the first byte of the argument
	add eax, ebx							;add the two first argument
	add eax, ecx							;add the three argument
	movzx edx, al							;edx contains the sum
	mov [ebp -4], edx
	movzx edx, ah							;edx contains the rest
	mov [ebp -8], edx						
	popad
	mov ebx, [ebp-4]						;ebx contains the sum
	mov ecx, [ebp-8]						;edx contains the sum
	
	mov esp, ebp	
	pop ebp
	ret

oppList:								;opposite a list
	push ebp
	mov ebp, esp
	pushad

	mov edx, dword [ebp+8]						;edx contains the num of links
	mov ebx, edx							;ebx contains the num of links
	mov eax, [firstPointer]						;eax contains the first link
	mov [prevPointer], eax						;prevPointer contains the first link
	inc eax
	mov ecx, [eax]
	mov [currPointer], ecx						;currPointer is the next node
	mov dword [eax], 0						;make the first, last
	dec ebx
	_sLoop:
		cmp ebx, 0						;check if we are in the end of the list
		je _finishSLoop
		mov ecx, [currPointer]					;ecx is the current link
		inc ecx
		mov eax,[ecx]						
		mov [currPointer], eax					;currPointer is the new current link	
		mov eax, [prevPointer]
		mov [ecx], eax 						;put the pointer to the prevPointer in the current link
		dec ecx
		mov [prevPointer], ecx					;update the prevPointer
		dec ebx
		jmp _sLoop

	_finishSLoop:
		mov ecx, [prevPointer]					
		mov [firstPointer], ecx					;put in firstPointer the new pointer to the first link

		popad
		mov esp, ebp	
		pop ebp
		ret

		
oddEven:								;checks if the input is odd or even
	push ebp
	mov ebp, esp
	sub esp, 4 
	pushad

	mov edx, 0							;edx is a odd/even flag
 	mov ebx, [bufferOffset]						;ebx is a pointer to the input
	
	_startOELoop:
		movzx eax, byte [ebx]
		cmp eax, 10						;check if we are at the end of the input
		je _finishOE
	
		cmp edx, 0						
		je _mov1
		mov edx, 0						;change the odd/even flag
		jmp _mov0
		_mov1:
			mov edx, 1					;change the odd/even flag
		_mov0:
			inc ebx						;inc ebx to the next letter
			jmp _startOELoop

	_finishOE:
		mov [ebp - 4], edx

		popad
		mov eax, [ebp - 4]					;eax contains the odd/even flag
		mov esp, ebp	
		pop ebp
		ret

plus:
	push ebp
	mov ebp, esp
	pushad

	
	call popItem							;get x from the stack
	cmp byte [errorFlag], 1						;check if there is an error 
	mov byte [errorFlag], 0
	je _endPlus

	call size							;get the size of x
	mov edi, eax							;edi contains the size of x
	
	push edi
	call oppList							;opoosite the list of x
	pop edi

	mov eax, [firstPointer]		
	mov [firstPointer1], eax					;firstPointer1 points to x
	mov [prev1], eax		
	call popItem							;get y from the stack
	cmp byte [errorFlag], 0						;check if there is an error 
	je _s
	inc byte [stackCount]						;in case of error, bring the stack to the perevius status
	mov eax, [numPointer]
	add eax, 4
	mov [numPointer], eax
	mov byte [errorFlag], 0
	jmp _endPlus
	_s:
		call size
		mov esi, eax						;esi contains the size of y

		push esi
		call oppList						;opoosite the list of x				
		pop esi

		mov eax, [firstPointer]
		mov [firstPointer2], eax				;firstPointer2 points to y
		mov [prev2], eax
		mov eax, [firstPointer1]

		push dword [eax]
		mov ebx, [firstPointer2]
		push dword [ebx]
		push 0
		call addLink						;adds the two first links
		add esp, 12
		
		mov eax, 5

		pushad
		push eax
		call malloc						;create new link
		add esp,4	
		mov [curr], eax
		popad

		mov edx, [curr]						;edx contians the new link
		mov [firstPointer], edx
		mov [prevPointer], edx
		mov [edx], bl						;put in the new link the sum of the links
		dec esi
		dec edi

		_addLoop:
			cmp esi, 0					;check if we finish with y
			je _es0
			cmp edi, 0					;check if we finish with y
			je _ed0
			mov edx, [prev1]
			inc edx
			mov eax, [edx]					;eax contains the data of next link of edx
			mov [prev1], eax

			push dword [eax]				;push first link data
			push  dword ecx					;push the stay from the last add
			mov edx, [prev2]
			inc edx
			mov eax, [edx]
			mov [prev2], eax
			push dword [eax]				;push second link data
			call addLink					;add the links with the stay
			add esp, 12

			mov eax, 5
			
			pushad
			push eax
			call malloc					;creat new link
			add esp,4
			mov [curr], eax
			popad

			mov edx, [curr]					;edx contains the new link
			mov eax, [prevPointer]
			inc eax
			mov dword [eax], edx
			mov [prevPointer], edx
			mov [edx], bl					;put the sum in the new link
			dec esi
			dec edi
			jmp _addLoop

			_ed0:
				mov edx, [prev2]
				inc edx
				mov eax, [edx]
				mov [prev2], eax
				
				push dword [eax]			;push the data of edx
				push ecx				;push the stay
				push 0					
				call addLink				;add the links
				add esp, 12

				mov eax, 5

				pushad
				push eax
				call malloc				;creat new link
				add esp,4
				mov [curr], eax
				popad

				mov edx, [curr]				;edx contains the new link
				mov eax, [prevPointer]
				inc eax
				mov dword [eax], edx
				mov [prevPointer], edx
				mov [edx], bl				;put the sum in the new link
				dec esi
				jmp _addLoop
			
			_es0:	
				cmp edi, 0
				je _both0
				mov edx, [prev1]
				inc edx
				mov eax, [edx]
				mov [prev1], eax
				
				push dword [eax]			;push the data of edx
				push ecx				;push the stay
				push 0
				call addLink
				add esp, 12

				mov eax, 5

				pushad
				push eax
				call malloc				;creat new link
				add esp,4
				mov [curr], eax
				popad

				mov edx, [curr]				;edx contains the new link
				mov eax, [prevPointer]
				inc eax
				mov dword [eax], edx
				mov [prevPointer], edx
				mov [edx], bl				;put the sum in the new link
				dec edi
				jmp _addLoop

			_both0:
				call size
				mov edi, eax

				push edi
				call oppList				;opposite the list again
				pop edi

				cmp ecx, 0				;if there is no stay, jump to end
				je _addNums
				mov byte [stayFlag], 1			;increase the flag
				mov eax, 5

				pushad
				push eax
				call malloc				;create new link
				add esp,4
				mov [curr], eax
				popad

				mov edx, [curr]				;edx contains the new link
				mov [edx], ecx	
				inc edx
				mov eax, [firstPointer]
				mov [edx], eax				;put the stay in the new link
				dec edx
				mov [firstPointer], edx			;put the new link as firstPointer
		
			_addNums:	
				call pushFirstToStack			;push the add number to the stack		

	_endPlus:
		popad
		mov esp, ebp
		pop ebp
		ret


power:
	push ebp
	mov ebp, esp
	pushad
				

	call popItem							;get x from the stack
	cmp byte [errorFlag], 1						;check if there is an error 
	mov byte [errorFlag], 0
	je _endPower
	mov edx, [firstPointer]						;edx contains the pointer to x
	
	call popItem							;get y from the stack
	mov ecx, [firstPointer]						;ecx contains the pointer to y
	mov eax, [ecx]							;eax contains y
	cmp byte [ecx + 1], 0
	jne _errorY                					;y must be lower than one node
	movzx esi, al
	cmp esi, 201							;y must be lower than 201
        jge _errorY
	
	cmp byte [errorFlag], 0							
	je _ok2

	call pushFirstToStack						;bring the stack to the previous status
	mov byte [errorFlag], 0
	jmp _loop
	
	_ok2:
		mov [firstPointer], edx					;[firstPointer] contains the first link of x
		call pushFirstToStack					;push x to stack
	
	mov eax, [ecx]							;eax contains y

	_addingLoop:
		cmp eax, 0						;do this loop y-times
		je _endPower
		dec eax
		call duplicate						;math calculations
		call plus
		jmp _addingLoop
	
	_errorY:
		pushad
		push dword printYErr					;print the error massage
		call printf
		add esp,4
		popad

		pushad
		push dword printLine					;print next line	
		call printf
		add esp,4
		popad

		mov [firstPointer], ecx
		call pushFirstToStack

		mov [firstPointer], edx					;[firstPointer] contains the first link of x
		call pushFirstToStack	

	_endPower:
		popad
		mov esp, ebp
		pop ebp
		ret


duplicate:
	push ebp
	mov ebp, esp
	pushad

	
	cmp byte [stackCount], 5					;check if there is place left in the stack 
	je _overFl							;if not, error
	call popItem							;take x from the stack
	cmp byte [errorFlag], 1						;check if there is an error
	je _err1
	inc byte [stackCount]						;increase the num of items in the stack because we poped x
	mov eax, [numPointer]
	add eax, 4
	mov [numPointer], eax						;update the numPointer to the next empty cell in the stack

	_finishD:
	        call pushFirstToStack					;push the dup to the stack
		jmp _endDuplicate					;jump to end

		_overFl:
			pushad
			push dword printOverFlow			;print the over flow massage
			call printf
			add esp,4
			popad

			pushad
			push dword printLine				;print next line
			call printf
			add esp,4
			popad	

			jmp _endDuplicate				;jump to end

		_lowFl:
			pushad
			push dword printEmpty				;print the empty massage
			call printf
			add esp,4
			popad

			pushad
			push dword printLine				;print next line
			call printf
			add esp,4
			popad	

			jmp _endDuplicate

		_err1:
			mov byte [errorFlag], 0				;update the error flag
		
		_endDuplicate:
			popad
			mov esp, ebp
			pop ebp
			ret


peek:
	push ebp
	mov ebp, esp
	pushad
	
	call popItem							;pop head of stack
	mov edx, [firstPointer]						;save pointer of value
	mov eax, [edx]							;get value from pointer
	mov [peekPointer], eax						;save value to peekPointer
	call pushFirstToStack						;push back to stack

	popad
	mov esp, ebp
	pop ebp
	ret


debugPrint:

	push ebp
	mov ebp, esp
	pushad

	call peek							;call peek get the value to show
	pushad	
	movzx eax, byte [peekPointer]					;get value from pointer
	push eax							;push value to args of printf
	push printInt					
	call printf							;call printf to print value to stdout
	add esp, 8
	popad
	

	pushad
	push printLine							;print 'new line'
	call printf
	add esp,4
	popad

	popad
	mov esp, ebp
	pop ebp
	ret

cleanZeros:
	push ebp
	mov ebp, esp
	pushad
	
	mov ecx, bufferInput						;set [bufferOffset] to point to start of input
	mov dword [bufferOffset], ecx		
	
	movzx eax, byte [ecx]						;get the curr data
	cmp eax, '0'							;check if the byte is 0
	jne _finishDelete						;if no - go to deleteZeros	

	_countZeros:	
		inc ecx							;inc index and delete the 0
		inc dword [bufferOffset]

		movzx eax, byte [ecx]					;get the curr data
		cmp eax, '0'						;check if the char is 0
		je _countZeros						;go back to loop
	
		cmp eax, 10						;check if the char is 'enter'
		jne _finishDelete					;no - not all input are zeros - finished
	
		dec dword [bufferOffset]				;yes - leave 1 zero in input

	_finishDelete:
		popad
		mov esp, ebp
		pop ebp
		ret

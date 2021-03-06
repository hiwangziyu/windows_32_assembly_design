;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 控制台程序的公用子程序
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
hStdIn		dd	?		;控制台输入句柄
hStdOut		dd	?		;控制台输出句柄
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 控制台 Ctrl-C 捕获例程
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CtrlHandler	proc	_dwCtrlType

		pushad
		mov	eax,_dwCtrlType
		.if	eax ==	CTRL_C_EVENT || eax == CTRL_BREAK_EVENT
			or	dwOption,F_ABORT
		.endif
		popad
		mov	eax,TRUE
		ret

_CtrlHandler	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 控制台初始化
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ConsoleInit	proc

		invoke	GetStdHandle,STD_INPUT_HANDLE
		mov	hStdIn,eax
		invoke	GetStdHandle,STD_OUTPUT_HANDLE
		mov	hStdOut,eax
		invoke	SetConsoleCtrlHandler,addr _CtrlHandler,TRUE
		ret

_ConsoleInit	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 控制台输出子程序
; 注意: 用 WriteConsole 输出则执行时无法用 > 重定向到文件
;       用 WriteFile 则可以
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ConsolePrint	proc	_lpsz
		local	@dwCharWritten

		pushad
		invoke	lstrlen,_lpsz
		lea	ecx,@dwCharWritten
		invoke	WriteFile,hStdOut,_lpsz,eax,ecx,NULL
		popad
		ret

_ConsolePrint	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

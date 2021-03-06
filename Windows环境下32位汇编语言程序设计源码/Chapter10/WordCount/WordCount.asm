;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by 罗云彬, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; WordCount.asm
; 文件读写例子 —— 打开文本文件进行单词统计，然后创建结果文件
; 读写文件操作使用文件操作函数。
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 使用 nmake 或下列命令进行编译和链接:
; ml /c /coff WordCount.asm
; rc WordCount.rc
; Link /subsystem:windows WordCount.obj WordCount.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include 文件定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		comdlg32.inc
includelib	comdlg32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Equ 等值定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ICO_MAIN	equ		1000
DLG_MAIN	equ		100
IDC_FILE	equ		101
IDC_BROWSE	equ		102

WORD_COUNT	struct

lpLetter	dd	26 dup (?)
dwCount		dd	?
dwDepth		dd	?

WORD_COUNT	ends
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?

hInstance	dd	?
hWinMain	dd	?
szFileName	db	MAX_PATH dup (?)
szBuffer	db	4096 dup (?)
stWordCount	WORD_COUNT	<>
dwCount		dd	?

dwOption	dd	?
F_COUNTING	equ	00000001h
F_FILEEND	equ	00000002h

		.const
szFileExt	db	'全部文件',0,'*.*',0,0
szLogExt	db	'.log',0
szErrOpenFile	db	'无法打开文件!',0
szErrCreateFile	db	'无法建立记录文件!',0
szFmtWord	db	'%5d (%3d‰) %s',0dh,0ah,0
szSuccees	db	'统计成功，请查看记录文件%s',0
szSucceesCap	db	'统计成功',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

		.code

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 遍历树并输出结果
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_WalkTree	proc	_hFile,_lpWC,_lpsz
		local	@dwTemp
		local	@szWord[52]:byte

		pushad
		mov	esi,_lpWC
		assume	esi:ptr WORD_COUNT
		.if	[esi].dwDepth && [esi].dwCount
;********************************************************************
; 计算百分比并写入log文件
;********************************************************************
			mov	eax,[esi].dwCount
			mov	ecx,1000
			mul	ecx
			mov	ecx,dwCount
			.if	ecx
				div	ecx
			.else
				mov	eax,0
			.endif
			invoke	wsprintf,addr szBuffer,addr szFmtWord,[esi].dwCount,eax,_lpsz
			invoke	lstrlen,addr szBuffer
			mov	ecx,eax
			invoke	WriteFile,_hFile,addr szBuffer,ecx,addr @dwTemp,NULL
		.endif
;********************************************************************
; 如果有下层节点则递规调用
;********************************************************************
		mov	@dwTemp,0
		.while	@dwTemp < 26
			mov	ebx,@dwTemp
			mov	ebx,dword ptr [esi+ebx*4]
			.if	ebx
				invoke	lstrcpy,addr @szWord,_lpsz
				invoke	lstrlen,addr @szWord
				lea	ecx,@szWord
				add	ecx,eax
				mov	eax,@dwTemp
				add	al,'a'
				mov	word ptr [ecx],ax
				invoke	_WalkTree,_hFile,ebx,addr @szWord
			.endif
			inc	@dwTemp
		.endw
;********************************************************************
; 释放节点
;********************************************************************
		.if	[esi].dwDepth
			invoke	GlobalFree,esi
		.endif
		popad
		assume	esi:ptr WORD_COUNT
		ret

_WalkTree	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 根据数据建立树节点或增加节点计数
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CountLetter	proc	_dwLetter
		local	@dwIndex

		assume	edi:ptr WORD_COUNT
		or	al,20h				;转换成小写字母
		.if	(al >= 'a') && (al <= 'z')	;字母
;********************************************************************
; 如果是字母则按edi指针继续搜寻下一节点，找到则更新指针，
; 未找到则建立一个新的节点
;********************************************************************
			sub	al,'a'
			movzx	eax,al
			.if	dword ptr [edi+eax*4]
				mov	edi,dword ptr [edi+eax*4]
			.else
				mov	ebx,[edi].dwDepth
				.if	ebx <	50
					push	eax
					invoke	GlobalAlloc,GPTR,sizeof WORD_COUNT
					pop	ecx
					.if	eax
						mov	dword ptr [edi+ecx*4],eax
						mov	edi,eax
						inc	ebx
						mov	[edi].dwDepth,ebx
					.endif
				.endif
			.endif
		.else
;********************************************************************
; 不是字母表示一个单词已结束，增加单词计数
;********************************************************************
			inc	[edi].dwCount
			.if	[edi].dwDepth
				inc	dwCount
			.endif
			mov	edi,offset stWordCount
		.endif
		assume	edi:nothing
		ret

_CountLetter	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CountWord	proc
		local	@hFile,@dwBytesRead
		local	@szLogFile[MAX_PATH]:byte
		local	@szBuffer

		invoke	RtlZeroMemory,addr stWordCount,sizeof stWordCount
;********************************************************************
; 打开文件
;********************************************************************
		invoke	CreateFile,addr szFileName,GENERIC_READ,FILE_SHARE_READ,0,\
			OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
		.if	eax ==	INVALID_HANDLE_VALUE
			invoke	MessageBox,hWinMain,addr szErrOpenFile,NULL,MB_OK or MB_ICONEXCLAMATION
			ret
		.endif
		mov	@hFile,eax
;********************************************************************
; 循环读出文件并处理每个字节
;********************************************************************
		xor	eax,eax
		mov	@dwBytesRead,eax
		mov	dwCount,eax
		mov	edi,offset stWordCount
		.while	TRUE
			.if	@dwBytesRead
				lodsb
				dec	@dwBytesRead
				invoke	_CountLetter,eax
			.else
				mov	esi,offset szBuffer
				invoke	ReadFile,@hFile,addr szBuffer,sizeof szBuffer,addr @dwBytesRead,0
				.break	.if !@dwBytesRead
			.endif
		.endw
		invoke	_CountLetter,0
		invoke	CloseHandle,@hFile
;********************************************************************
; 输出记录文件
;********************************************************************
		invoke	lstrcpy,addr @szLogFile,addr szFileName
		invoke	lstrcat,addr @szLogFile,addr szLogExt
		invoke	CreateFile,addr @szLogFile,GENERIC_WRITE,FILE_SHARE_READ,\
			0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
		.if	eax !=	INVALID_HANDLE_VALUE
			mov	@hFile,eax
			mov	@szBuffer,0
			mov	edi,offset stWordCount
			invoke	_WalkTree,@hFile,edi,addr @szBuffer
			invoke	CloseHandle,@hFile
			invoke	wsprintf,addr szBuffer,addr szSuccees,addr @szLogFile
			invoke	MessageBox,hWinMain,addr szBuffer,addr szSucceesCap,MB_OK or MB_ICONINFORMATION
		.else
			invoke	MessageBox,hWinMain,addr szErrCreateFile,NULL,MB_OK or MB_ICONEXCLAMATION
		.endif
		ret

_CountWord	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcDlgMain	proc	uses ebx edi esi hWnd,wMsg,wParam,lParam
		local	@stOpenFileName:OPENFILENAME

		mov	eax,wMsg
		.if	eax ==	WM_CLOSE
			.if	! (dwOption & F_COUNTING)
				invoke	EndDialog,hWnd,NULL
			.endif
;********************************************************************
		.elseif	eax ==	WM_INITDIALOG
			push	hWnd
			pop	hWinMain
			invoke	LoadIcon,hInstance,ICO_MAIN
			invoke	SendMessage,hWnd,WM_SETICON,ICON_BIG,eax
			invoke	SendDlgItemMessage,hWnd,IDC_FILE,EM_SETLIMITTEXT,MAX_PATH,0
;********************************************************************
		.elseif	eax ==	WM_COMMAND
			mov	eax,wParam
			.if	ax ==	IDC_BROWSE
;********************************************************************
				invoke	RtlZeroMemory,addr @stOpenFileName,sizeof OPENFILENAME
				mov	@stOpenFileName.lStructSize,SIZEOF @stOpenFileName
				mov	@stOpenFileName.Flags,OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
				push	hWinMain
				pop	@stOpenFileName.hwndOwner
				mov	@stOpenFileName.lpstrFilter,offset szFileExt
				mov	@stOpenFileName.lpstrFile,offset szFileName
				mov	@stOpenFileName.nMaxFile,MAX_PATH
				invoke	GetOpenFileName,addr @stOpenFileName
				.if	eax
					invoke	SetDlgItemText,hWnd,IDC_FILE,addr szFileName
				.endif
;********************************************************************
			.elseif	ax ==	IDC_FILE
				invoke	GetDlgItemText,hWnd,IDC_FILE,addr szFileName,MAX_PATH
				mov	ebx,eax
				invoke	GetDlgItem,hWnd,IDOK
				invoke	EnableWindow,eax,ebx
;********************************************************************
			.elseif	ax ==	IDOK
				invoke	GetDlgItem,hWnd,IDC_FILE
				invoke	EnableWindow,eax,FALSE
				invoke	GetDlgItem,hWnd,IDC_BROWSE
				invoke	EnableWindow,eax,FALSE
				invoke	GetDlgItem,hWnd,IDOK
				invoke	EnableWindow,eax,FALSE
				or	dwOption,F_COUNTING
				call	_CountWord
				and	dwOption,not (F_COUNTING or F_FILEEND)
				invoke	GetDlgItem,hWnd,IDC_FILE
				invoke	EnableWindow,eax,TRUE
				invoke	GetDlgItem,hWnd,IDC_BROWSE
				invoke	EnableWindow,eax,TRUE
				invoke	GetDlgItem,hWnd,IDOK
				invoke	EnableWindow,eax,TRUE
			.endif
;********************************************************************
		.else
			mov	eax,FALSE
			ret
		.endif
		mov	eax,TRUE
		ret

_ProcDlgMain	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		invoke	GetModuleHandle,NULL
		mov	hInstance,eax
		invoke	DialogBoxParam,hInstance,DLG_MAIN,NULL,offset _ProcDlgMain,NULL
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start

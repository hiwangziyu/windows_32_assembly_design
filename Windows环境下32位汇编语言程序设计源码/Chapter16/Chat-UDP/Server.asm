;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming >
; by 罗云彬, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Server.asm
; 使用 UDP 协议的聊天室例子程序 —— 服务器端
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 使用 nmake 或下列命令进行编译和链接:
; ml /c /coff Server.asm
; rc Server.rc
; Link /subsystem:windows Server.obj Server.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none   ; case sensitive
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include 数据
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		wsock32.inc
includelib	wsock32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; equ 数据
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DLG_MAIN	equ	2000
IDC_INFO	equ	2001
IDC_COUNT	equ	2002
WM_SOCKET       equ	WM_USER + 100
UDP_PORT	equ	9999
MAX_SOCKET	equ	100	;聊天室最大容量
RETRY_TIMES	equ	5
;********************************************************************
CLIENT_ADDR	struct

dwClientIP	dd	?
wClientPort	dw	?
dwID		dd	?
dwRetryTimes	dd	?

CLIENT_ADDR	ends
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
hWinMain	dd	?
hSocket		dd	?
dwID		dd	?
szReadBuffer	db	32768 dup (?)
szBuffer	db	32768 dup (?)
stTable		CLIENT_ADDR MAX_SOCKET dup (<>)
		.const
szErrBind	db	'无法绑定到UDP端口9999，请检查是否有其它程序在使用!',0
szFormat	db	'【客户端#%d】- %s',0dh,0ah,0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 将有回复的客户端（表示还在聊天中）地址添加到列表中
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_AddSocket	proc	_lpSocket

;********************************************************************
; 查找地址是否存在，已存在则不必添加且重新设置应答计数器
;********************************************************************
		mov	esi,offset stTable
		mov	edi,_lpSocket
		assume	esi:ptr CLIENT_ADDR
		assume	edi:ptr sockaddr_in
		xor	ebx,ebx
		.while	ebx <	MAX_SOCKET
			mov	ax,[edi].sin_port
			mov	ecx,[edi].sin_addr
			.if	(ax == [esi].wClientPort)\
				&& (ecx == [esi].dwClientIP)
				mov	[esi].dwRetryTimes,5
				ret
			.endif
			add	esi,sizeof CLIENT_ADDR
			inc	ebx
		.endw
;********************************************************************
; 否则在客户端地址表中找一个空的表项，并添加当前地址
;********************************************************************
		mov	esi,offset stTable
		xor	ebx,ebx
		.while	ebx <	MAX_SOCKET
			.if	! [esi].dwRetryTimes
				push	esi
				inc	dwID
				push	dwID
				pop	[esi].dwID
				mov	[esi].dwRetryTimes,RETRY_TIMES
				push	[edi].sin_addr
				pop	[esi].dwClientIP
				mov	ax,[edi].sin_port
				mov	[esi].wClientPort,ax
				pop	esi
				ret
			.endif
			add	esi,sizeof CLIENT_ADDR
			inc	ebx
		.endw
		xor	esi,esi
		assume	esi:nothing
		assume	edi:nothing
		ret

_AddSocket	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 处理接收到的UDP包
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RecvData	proc	_hSocket
		local	@dwRecv,@dwStructSize
		local	@stSin:sockaddr_in
		local	@dwCount

		mov	@dwStructSize,sizeof sockaddr_in
		invoke	RtlZeroMemory,addr szReadBuffer,sizeof szReadBuffer
		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	recvfrom,_hSocket,addr szReadBuffer,sizeof szReadBuffer,\
			0,addr @stSin,addr @dwStructSize
		.if	eax !=	SOCKET_ERROR
			mov	@dwRecv,eax
;********************************************************************
; 登记客户端ID，并转换字符串格式
;********************************************************************
			invoke	_AddSocket,addr @stSin
			.if	! esi
				ret
			.endif
			assume	esi:ptr CLIENT_ADDR
			invoke	wsprintf,addr szBuffer,addr szFormat,\
				dword ptr [esi].dwID,addr szReadBuffer
;********************************************************************
; 如果不是回复字符 －1 的话，则按照客户端列表逐一发送
;********************************************************************
			.if	dword ptr szReadBuffer != -1
				invoke	GetDlgItem,hWinMain,IDC_INFO
				mov	ebx,eax
				invoke	GetWindowTextLength,ebx
				invoke	SendMessage,ebx,EM_SETSEL,eax,eax
				invoke	SendMessage,ebx,EM_REPLACESEL,FALSE,addr szBuffer
				mov	esi,offset stTable
				xor	ebx,ebx
				mov	@dwCount,ebx
				.while	ebx <	MAX_SOCKET
					.if	dword ptr [esi].dwRetryTimes
						push	[esi].dwClientIP
						pop	@stSin.sin_addr
						mov	ax,[esi].wClientPort
						mov	@stSin.sin_port,ax
						invoke	lstrlen,addr szBuffer
						mov	ecx,eax
						invoke	sendto,hSocket,addr szBuffer,ecx,\
							0,addr @stSin,sizeof sockaddr_in
						dec	dword ptr [esi].dwRetryTimes
						.if	dword ptr [esi].dwRetryTimes
							inc	@dwCount
						.else
							invoke	RtlZeroMemory,esi,sizeof CLIENT_ADDR

						.endif
					.endif
					add	esi,sizeof CLIENT_ADDR
					inc	ebx
				.endw
				invoke	SetDlgItemInt,hWinMain,IDC_COUNT,@dwCount,FALSE
			.endif
			assume	esi:nothing
		.endif
		ret

_RecvData	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 初始化 Socket，绑定到服务UDP端口并监听
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Init		proc
		local	@stWsa:WSADATA
		local	@stSin:sockaddr_in

		invoke	WSAStartup,101h,addr @stWsa
		invoke	socket,AF_INET,SOCK_DGRAM,0
		mov	hSocket,eax
		invoke	WSAAsyncSelect,hSocket,hWinMain,WM_SOCKET,FD_READ

		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	htons,UDP_PORT
		mov	@stSin.sin_port,ax
		mov	@stSin.sin_family,AF_INET
		mov	@stSin.sin_addr,INADDR_ANY
		invoke	bind,hSocket,addr @stSin,sizeof @stSin
		.if	eax ==	SOCKET_ERROR
			invoke	MessageBox,hWinMain,addr szErrBind,NULL,\
				MB_OK or MB_ICONWARNING
			invoke	SendMessage,hWinMain,WM_CLOSE,0,0
		.endif
		ret

_Init		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;	主窗口程序
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcDlgMain	proc	uses ebx edi esi hWnd,wMsg,wParam,lParam

		mov	eax,wMsg
		.if	eax ==	WM_SOCKET
			mov	eax,lParam
			.if	ax ==	FD_READ
				invoke	_RecvData,wParam
			.endif
;********************************************************************
		.elseif	eax ==	WM_CLOSE
			invoke	closesocket,hSocket
			invoke	WSACleanup
			invoke	EndDialog,hWinMain,NULL
;********************************************************************
		.elseif	eax ==	WM_INITDIALOG
			push	hWnd
			pop	hWinMain
			call	_Init
;********************************************************************
		.else
			mov	eax,FALSE
			ret
		.endif
		mov	eax,TRUE
		ret

_ProcDlgMain	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 程序开始
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		invoke	GetModuleHandle,NULL
		invoke	DialogBoxParam,eax,DLG_MAIN,NULL,offset _ProcDlgMain,0
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start

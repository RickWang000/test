;-----------------------------------------------------------------------
;�Ѿ���ɣ��ļ��½����򿪡��ı������ɾ�������桢���Ϊ���˳�
;��δʵ�֣����������������ơ�ճ����ȫѡ
;-----------------------------------------------------------------------
;���к����оֲ�������@��ͷ����������
;-----------------------------------------------------------------------
.386
.model flat, stdcall
option casemap: none
;-----------------------------------------------------------------------	
INCLUDE		  		windows.inc
INCLUDE 	  		user32.inc
INCLUDELIB	  		user32.lib
INCLUDE 	  		kernel32.inc
INCLUDELIB    		kernel32.lib
INCLUDE 			comdlg32.inc
INCLUDELIB			comdlg32.lib
INCLUDE 			comctl32.inc
INCLUDELIB			comctl32.lib
INCLUDE		  		gdi32.inc
INCLUDELIB 	  		gdi32.lib
;-----------------------------------------------------------------------
;�˵�ID & ���ټ�ID
IDM_MAIN			EQU 1000h
IDM_OPEN			EQU 1101h
IDM_SAVE			EQU 1102h
IDM_SAVEAS			EQU 1103h
IDM_EXIT			EQU 1104h
IDM_NEW				EQU	1105h
IDM_REDO			EQU 1201h
IDM_UNDO			EQU 1202h
IDM_CUT				EQU 1203h
IDM_COPY			EQU	1204h
IDM_PASTE			EQU 1205h
IDM_DELETE			EQU 1206h
IDM_ALL				EQU 1207h
IDM_FIND			EQU 1208h
IDM_REPLACE			EQU 1209h
IDA_MAIN			EQU 2000h  ;���ټ�

;��Ҫ����UNICODE�ַ���
UNICODE = 1

;-----------------------------------------------------------------------

.data?
windowInstance 	  	DWORD ?  ;����ʵ��
mainWindowHandler  	DWORD ?  ;�����ھ��
editWindowHandler	DWORD ?  ;�༭���ھ��
currentFileHandler	DWORD ?  ;��ǰ�ļ����
mainMenuHandler		DWORD ?  ;���˵����
statusBarHandler	DWORD ?  ;todo: ״̬��
findHandler			DWORD ?  ;todo: ����
replaceHandler		DWORD ?  ;todo: �滻
subMenuHandler		DWORD ?  ;todo:ʵ�ֱ༭��ع���

;�ļ���
fileName			BYTE MAX_PATH DUP(?)
fileNameTitle		BYTE MAX_PATH DUP(?)

;���ڴ�С
mainWinRect 		RECT <?>

;�и�
charFmt  			BYTE '%4u', 0
lpEditProc			DWORD ?

;RichEdit CHARFORMAT�ṹ
reCharFormat		CHARFORMAT<?>

;-----------------------------------------------------------------------

.const
winClassName		BYTE 'xNotepadClass', 0  ;��������
winDefaultTitle 	BYTE 'untitled - xNotepad', 0
savedText			BYTE 'File Saved!', 0
noticeText			BYTE 'Notice', 0

;���ļ����ƣ�����ʹ��CreateFileW, ��Ҫ��DW����
txtFilter			DW 'T', 'e', 'x', 't', 'f', 'i', 'l', 'e', '(', '*', '.', 't', 'x', 't', ')', 0, '*', '.', 't', 'x', 't', 0
					DW 'A', 'l', 'l', '(', '*', '.', '*', ')', 0, '*', '.', '*', 0, 0
defaultFormat		DW 't', 'x', 't', 0
modifiedMsg			BYTE 'File modified, do you want to save?', 0

;RichEdit
dllRiched20			BYTE 'riched20.dll', 0
editClassName		BYTE 'RichEdit20A', 0

;EDITSTREAM
errMsg				BYTE 'Could not open the file.', 0
fontType 			BYTE '����', 0

;-----------------------------------------------------------------------

.code
;-----------------------------------------------------------------------
;��ʾ�к�
;-----------------------------------------------------------------------
_ShowLineNum PROC 	
 LOCAL @stClientRect:RECT	;�ͻ�����С
 LOCAL @hDcEdit					;�豸����
 LOCAL @Char_Height			;�ַ��߶�
 LOCAL @Line_Count				;�ı�������
 LOCAL @ClientHeight			;�ͻ����߶�
 LOCAL @hdcBmp					;λͼ
 LOCAL @hdcCpb					;����Dc
 LOCAL @stBuf[10]:byte			;��ʾ�кŵĻ�����


 PUSHAD
 ;��λͼ����
 INVOKE				GetDC, editWindowHandler										;��ȡDc
 MOV				@hDcEdit, EAX
 INVOKE				CreateCompatibleDC, @hDcEdit						;�������ݵ�λͼDc
 MOV				@hdcCpb, EAX
 INVOKE				GetClientRect, editWindowHandler, ADDR @stClientRect			;���������λͼ
 MOV				EBX, @stClientRect.bottom
 SUB				EBX, @stClientRect.top
 MOV				@ClientHeight, EBX
 INVOKE				CreateCompatibleBitmap, @hDcEdit, 45, @ClientHeight;
 MOV				@hdcBmp, EAX
 INVOKE				SelectObject, @hdcCpb, @hdcBmp
				
 ;�����ɫ
 INVOKE				CreateSolidBrush, 08080ffh							
 INVOKE				FillRect, @hdcCpb, ADDR @stClientRect, EAX			
 INVOKE				SetBkMode, @hdcCpb, TRANSPARENT
				
 ;��ȡ������
 INVOKE				SendMessage, editWindowHandler, EM_GETLINECOUNT, 0, 0
 ADD				EAX, 1
 MOV 				@Line_Count, EAX
 MOV				EAX, reCharFormat.yHeight									
 CDQ
 MOV				EBX, 20
 div				EBX
 MOV				@Char_Height, EAX
 INVOKE				RtlZeroMemory, ADDR @stBuf, SIZEOF @stBuf
				
 ;������ʾ�кŵ�������ɫ
 INVOKE				SetTextColor, @hdcCpb, 0000000h
 MOV				EBX, @Char_Height
 MOV				@Char_Height, 1
				
 ;��ȡĿǰ�����׸��ɼ��к�
 INVOKE				SendMessage, editWindowHandler, EM_GETFIRSTVISIBLELINE, 0, 0
 MOV				EDI, EAX
 SUB				EDI, 1
				
 ;��λͼdc�в����к�
 .WHILE	EDI <= @Line_Count
	INVOKE			wsprintf, ADDR @stBuf, ADDR charFmt, EDI ;���ش洢���ַ���
	INVOKE			TextOut, @hdcCpb, 1, @Char_Height, ADDR @stBuf, EAX
	MOV				EDX, @Char_Height
	ADD				EDX, EBX
	ADD				EDX, 4  ;�о�
	MOV				@Char_Height, EDX
	ADD  			EDI, 1
	.BREAK  .IF EDX > @ClientHeight 
 .ENDW
				
 ;�����ƺõ�λͼ����
 INVOKE				BitBlt, @hDcEdit, 0, 0, 45, @ClientHeight, @hdcCpb, 0, 0, SRCCOPY 
 INVOKE				DeleteDC, @hdcCpb
 INVOKE				ReleaseDC, editWindowHandler, @hDcEdit
 INVOKE				DeleteObject, @hdcBmp
				
 POPAD							
				
 RET

_ShowLineNum ENDP

;-----------------------------------------------------------------------
;�����༭�������Ժ������ﶨ������༭������غ�����CALL
;-----------------------------------------------------------------------

editProc PROC hWnd, uMsg, wParam, lParam
 LOCAL @paintStruct: PAINTSTRUCT
 LOCAL @pointStruct: POINT
				
 MOV				EAX, uMsg
 .IF EAX == WM_RBUTTONDOWN
	INVOKE 			GetCursorPos, ADDR @pointStruct
	INVOKE 			TrackPopupMenu, subMenuHandler, TPM_LEFTALIGN, @pointStruct.x, @pointStruct.y, 0, editWindowHandler, NULL
 .ELSEIF EAX == WM_PAINT
	INVOKE			CallWindowProc, lpEditProc, hWnd, uMsg, wParam, lParam
	INVOKE			BeginPaint, editWindowHandler, ADDR @paintStruct
	INVOKE			_ShowLineNum
	INVOKE			EndPaint, editWindowHandler, ADDR @paintStruct
	RET
 .ELSEIF EAX == WM_COMMAND
	MOV				EAX, wParam
	;todo: CALL�༭���ܺ���
 .ENDIF
 INVOKE				CallWindowProc, lpEditProc, hWnd, uMsg, wParam, lParam
 RET

editProc ENDP

;-----------------------------------------------------------------------
;����޸ĺ���
;-----------------------------------------------------------------------

checkModified PROC

 INVOKE				SendMessage, editWindowHandler, EM_GETMODIFY, 0, 0
 .IF EAX
	INVOKE			MessageBox, mainWindowHandler, ADDR modifiedMsg, ADDR noticeText, MB_YESNOCANCEL
	.IF EAX == IDYES
		.IF !currentFileHandler ;Ŀǰ�ļ�Ϊ���ļ�
			CALL 	saveAsProc
			.IF EAX ;����ɹ�
				INVOKE 	MessageBox, mainWindowHandler, OFFSET savedText, OFFSET noticeText, MB_OK
			.ELSE
				RET
			.ENDIF
		.ELSE  ;Ŀǰ�ļ�Ϊ�Ѿ����ٱ����һ�ε��ļ�
			CALL 	saveProc
			INVOKE 	MessageBox, mainWindowHandler, OFFSET savedText, OFFSET noticeText, MB_OK
		.ENDIF
	.ELSEIF	EAX == IDCANCEL
		MOV			EAX, FALSE
		RET
	.ENDIF
 .ENDIF
 MOV 				EAX, TRUE
 RET
				
checkModified ENDP

;-----------------------------------------------------------------------
;��������
;-----------------------------------------------------------------------

procStream PROC	USES EBX EDI ESI dwCookie, lpBuffer, dwBytes, lpBytes
			
 .IF dwCookie
	INVOKE			ReadFile, currentFileHandler, lpBuffer, dwBytes, lpBytes, NULL
 .ELSE
	INVOKE			WriteFile, currentFileHandler, lpBuffer, dwBytes, lpBytes, NULL
 .ENDIF
				
 xor				EAX, EAX  ;����󷵻�
 RET
				
procStream ENDP

;-----------------------------------------------------------------------
;�򿪺���
;-----------------------------------------------------------------------

newProc	PROC

 INVOKE				CloseHandle, currentFileHandler
 MOV				currentFileHandler, 0  ;�ر�ԭ���ļ���������
 INVOKE 			DestroyWindow, editWindowHandler
 INVOKE 			GetClientRect, mainWindowHandler, ADDR mainWinRect
 MOV				EAX, mainWinRect.bottom
 sub				EAX, 0018h
 INVOKE 			CreateWindowEx, WS_EX_CLIENTEDGE, OFFSET editClassName, NULL, WS_CHILD or WS_VISIBLE or WS_VSCROLL or ES_AUTOVSCROLL \
					or ES_MULTILINE or ES_NOHIDESEL or ES_WANTRETURN or ES_LEFT, 0, 0, mainWinRect.right, EAX, mainWindowHandler,\
					NULL, windowInstance, NULL
 MOV				editWindowHandler, EAX
 INVOKE 			SendMessage, editWindowHandler, EM_SETTEXTMODE, TM_PLAINTEXT, 0
 INVOKE 			SendMessage, editWindowHandler, EM_EXLIMITTEXT, NULL, -1
 INVOKE				SendMessage, editWindowHandler, EM_SETMARGINS, EC_RIGHTMARGIN or EC_LEFTMARGIN, 00050005h+45
 INVOKE 			RtlZeroMemory, ADDR reCharFormat, sizeof reCharFormat
 MOV				reCharFormat.cbSize, sizeof CHARFORMAT
 MOV				reCharFormat.dwMask, CFM_BOLD or CFM_COLOR or CFM_FACE or CFM_ITALIC or CFM_SIZE or CFM_UNDERLINE or CFM_STRIKEOUT
 MOV				reCharFormat.yHeight, 12 * 20
 INVOKE 			lstrcpy, ADDR reCharFormat.szFaceName, ADDR fontType
 INVOKE 			SendMessage, editWindowHandler, EM_SETCHARFORMAT, SCF_ALL, ADDR reCharFormat
 INVOKE				SetWindowLong, editWindowHandler, GWL_WNDPROC, ADDR editProc
 MOV				lpEditProc, EAX
				
 ;���ñ�����
 INVOKE 			SetWindowText, mainWindowHandler, ADDR winDefaultTitle

 ;TODO: ����״̬��
				
 RET
				
newProc ENDP

;-----------------------------------------------------------------------
;�򿪺���
;-----------------------------------------------------------------------

openProc PROC	
 LOCAL @openFileNameStruct: OPENFILENAME
 LOCAL @editstreamStruct: EDITSTREAM
				
 INVOKE 			RtlZeroMemory, ADDR @openFileNameStruct, sizeof @openFileNameStruct
 PUSH				mainWindowHandler
 POP				@openFileNameStruct.hwndOwner
 MOV				@openFileNameStruct.lStructSize, sizeof OPENFILENAME
 MOV				@openFileNameStruct.lpstrFilter, OFFSET txtFilter
 MOV				@openFileNameStruct.lpstrFile, OFFSET fileName
 MOV				@openFileNameStruct.nMaxFile, MAX_PATH
 MOV				@openFileNameStruct.lpstrFileTitle, OFFSET fileNameTitle
 MOV				@openFileNameStruct.nMaxFileTitle, MAX_PATH
 MOV				@openFileNameStruct.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
 MOV				@openFileNameStruct.lpstrDefExt, OFFSET defaultFormat 
				
 INVOKE 			GetOpenFileNameW, ADDR @openFileNameStruct
 .IF EAX
	INVOKE			CreateFileW, ADDR fileName, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE,\
					NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
	.IF EAX == INVALID_HANDLE_VALUE
		INVOKE		MessageBox, mainWindowHandler, ADDR errMsg, NULL, MB_OK or MB_ICONSTOP
		RET
	.ENDIF
	PUSH 			EAX 
	.IF currentFileHandler
		INVOKE 		CloseHandle, currentFileHandler
	.ENDIF
	POP 			EAX
	MOV				currentFileHandler, EAX
	MOV				@editstreamStruct.dwCookie, TRUE
	MOV				@editstreamStruct.dwError, NULL
	MOV				@editstreamStruct.pfnCallback, OFFSET procStream
	INVOKE 			SendMessage, editWindowHandler, EM_STREAMIN, SF_TEXT, ADDR @editstreamStruct
	INVOKE			SendMessage, editWindowHandler, EM_SETMODIFY, FALSE, NULL
 .ENDIF
								
 ;���ı�����
 INVOKE 			SetWindowTextW, mainWindowHandler, @openFileNameStruct.lpstrFileTitle
				
 RET
				
openProc ENDP

;-----------------------------------------------------------------------
;���溯��
;-----------------------------------------------------------------------

saveProc PROC
 LOCAL @editstreamStruct: EDITSTREAM
 LOCAL @openFileNameStruct: OPENFILENAME
				
 .IF currentFileHandler == 0
	CALL			saveAsProc
	RET
 .ENDIF
 INVOKE 			SetFilePointer, currentFileHandler, 0, 0, FILE_BEGIN
 INVOKE 			SetEndOfFile, currentFileHandler
 MOV 				@editstreamStruct.dwCookie, FALSE
 MOV 				@editstreamStruct.pfnCallback, OFFSET procStream
 INVOKE 			SendMessage, editWindowHandler, EM_STREAMOUT, SF_TEXT, ADDR @editstreamStruct
 INVOKE 			SendMessage, editWindowHandler, EM_SETMODIFY, FALSE, 0
 INVOKE 			SetWindowTextW, mainWindowHandler, OFFSET fileNameTitle
				
 RET
				
saveProc ENDP	
;-----------------------------------------------------------------------
;���Ϊ����
;-----------------------------------------------------------------------
saveAsProc PROC
 LOCAL @openFileNameStruct: OPENFILENAME
				
 INVOKE 			RtlZeroMemory, ADDR @openFileNameStruct, sizeof @openFileNameStruct
 PUSH				mainWindowHandler
 POP				@openFileNameStruct.hwndOwner
 MOV				@openFileNameStruct.lStructSize, sizeof OPENFILENAME
 MOV				@openFileNameStruct.lpstrFilter, OFFSET txtFilter
 MOV				@openFileNameStruct.lpstrFile, OFFSET fileName
 MOV				@openFileNameStruct.nMaxFile, MAX_PATH
 MOV				@openFileNameStruct.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
 MOV				@openFileNameStruct.lpstrDefExt, OFFSET defaultFormat 
				
 INVOKE 			GetSaveFileNameW, ADDR @openFileNameStruct
 .IF EAX
	INVOKE			CreateFileW, ADDR fileName, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, \
					CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
	.IF EAX == INVALID_HANDLE_VALUE
		CALL		GetLastError
		INVOKE		MessageBox, mainWindowHandler, ADDR errMsg, NULL, MB_OK or MB_ICONSTOP
		MOV			EAX, FALSE
		RET
	.ENDIF
	PUSH 	EAX 
	.IF currentFileHandler
		INVOKE 		CloseHandle, currentFileHandler
	.ENDIF
	POP 			EAX
	MOV				currentFileHandler, EAX
	CALL 			saveProc
	MOV				EAX, TRUE  ;�ɹ����Ϊ
	RET
 .ENDIF
				
 MOV 				EAX, FALSE
 RET
				
saveAsProc ENDP
;-----------------------------------------------------------------------
quitProc PROC
				
 INVOKE 			DestroyWindow, mainWindowHandler
 INVOKE 			PostQuitMessage, NULL
				
 RET
				
quitProc ENDP
;-----------------------------------------------------------------------
;�����ڴ�����
;-----------------------------------------------------------------------	
mainWinProcProc PROC USES EBX EDI ESI, hWnd, uMsg, wParam, lParam
			  
 MOV 				EAX, uMsg  ;��ȡ��Ϣ

;-----------------------------------------------------------------------
 .IF EAX == WM_CREATE				
	;todo:ע����ҡ��滻���ڵ�
						
	;�����༭����			
	INVOKE 			CreateWindowEx, WS_EX_CLIENTEDGE, OFFSET editClassName, NULL, WS_CHILD or WS_VISIBLE or WS_VSCROLL or ES_AUTOVSCROLL or \
					ES_MULTILINE or ES_NOHIDESEL or ES_WANTRETURN or ES_LEFT, 0, 0, 0, 0, hWnd, NULL, windowInstance, NULL
	MOV				editWindowHandler, EAX
	INVOKE 			SendMessage, editWindowHandler, EM_SETTEXTMODE, TM_PLAINTEXT, 0
	INVOKE 			SendMessage, editWindowHandler, EM_EXLIMITTEXT, NULL, -1
	INVOKE 			SendMessage, editWindowHandler, EM_SETEVENTMASK, 0, ENM_MOUSEEVENTS
	INVOKE			SendMessage, editWindowHandler, EM_SETMARGINS, EC_RIGHTMARGIN or EC_LEFTMARGIN, 00050005h+45
	INVOKE 			RtlZeroMemory, ADDR reCharFormat, sizeof reCharFormat
	MOV				reCharFormat.cbSize, sizeof CHARFORMAT
	MOV				reCharFormat.dwMask, CFM_BOLD or CFM_COLOR or CFM_FACE or CFM_ITALIC or CFM_SIZE or CFM_UNDERLINE or CFM_STRIKEOUT
	MOV				reCharFormat.yHeight, 12 * 20
	INVOKE 			lstrcpy, ADDR reCharFormat.szFaceName, ADDR fontType
	INVOKE 			SendMessage, editWindowHandler, EM_SETCHARFORMAT, SCF_ALL, ADDR reCharFormat
	INVOKE			SetWindowLong, editWindowHandler, GWL_WNDPROC, ADDR editProc
	MOV				lpEditProc, EAX
						
	;����Ҽ��������Ӳ˵�
	INVOKE 			GetSubMenu, mainMenuHandler, 1
	MOV				subMenuHandler, EAX
;-----------------------------------------------------------
 .ELSEIF EAX == WM_COMMAND
	MOV				EAX, wParam
	.IF ax == IDM_OPEN
		CALL		checkModified
		.IF EAX
			CALL	openProc
		.ENDIF
	.ELSEIF ax == IDM_SAVE
		.IF !currentFileHandler
			CALL 	saveAsProc
		.ELSE
			CALL 	saveProc
		.ENDIF
		.IF EAX
			INVOKE 	MessageBox, mainWindowHandler, OFFSET savedText, OFFSET noticeText, MB_OK
		.ENDIF
	.ELSEIF ax == IDM_SAVEAS
		CALL		saveAsProc
		.IF EAX == TRUE
			INVOKE 	MessageBox, mainWindowHandler, OFFSET savedText, OFFSET noticeText, MB_OK
		.ENDIF
	.ELSEIF ax == IDM_EXIT
		CALL		checkModified
		.IF EAX
			CALL	quitProc
		.ENDIF				
	.ELSEIF ax == IDM_NEW
		CALL		checkModified
		.IF EAX
			CALL	newProc
		.ENDIF
			;todo: �˴���༭���ڷ�����Ϣ��ʹ��ͨ��editProc���ù��ܺ���
	.ENDIF
;-----------------------------------------------------------
 .ELSEIF EAX == WM_SIZE
	INVOKE 			MoveWindow, statusBarHandler, 0, 0, 0, 0, TRUE
	INVOKE 			GetClientRect, hWnd, ADDR mainWinRect
	MOV				EBX, mainWinRect.bottom
	sub				EBX, 0018h
	INVOKE 			MoveWindow, editWindowHandler, 0, 0, mainWinRect.right, EBX, TRUE
;-----------------------------------------------------------
 .ELSEIF EAX == WM_CLOSE
	CALL			checkModified
	.IF EAX
		CALL		quitProc
	.ENDIF
;-----------------------------------------------------------
 .ELSE  ;δָ������
	INVOKE 			DefWindowProc, hWnd, uMsg, wParam, lParam
	RET
 .ENDIF
;-----------------------------------------------------------
 xor		EAX, EAX ;����󷵻�									
 RET
				
mainWinProcProc ENDP
;-----------------------------------------------------------------------
winMainProc PROC
 LOCAL @winClassStruct: WNDCLASSEX
 LOCAL @msgStruct: MSG
 LOCAL @accHandler: DWORD
 LOCAL @rcedHandler: DWORD
				
;ע�ḻ�ı�����-------------------------------------------
 INVOKE 			LoadLibrary, ADDR dllRiched20  ;����richedit20dll
 MOV 				@rcedHandler, EAX
;ע�ᴰ����-----------------------------------------------
 INVOKE 			RtlZeroMemory, ADDR @winClassStruct, sizeof @winClassStruct ;��ʼ���ֲ�����
 INVOKE 			GetModuleHandle, NULL	;��ȡ��ģ��������EAX��
 MOV				windowInstance, EAX			;����ȫ�ֱ���windowInstance��									
 PUSH 				windowInstance
 POP				@winClassStruct.hInstance
 MOV 				@winClassStruct.cbSize, sizeof WNDCLASSEX
 MOV 				@winClassStruct.style, CS_HREDRAW or CS_VREDRAW
 MOV 				@winClassStruct.lpfnWndProc, OFFSET mainWinProcProc
 MOV 				@winClassStruct.hbrBackground, COLOR_WINDOW + 1  ;�ױ���ɫ
 MOV 				@winClassStruct.lpszClassName, OFFSET winClassName
 INVOKE 			RegisterClassEx, ADDR @winClassStruct
;��������--------------------------------------------------
 INVOKE 			LoadMenu, windowInstance, IDM_MAIN
 MOV				mainMenuHandler, EAX
 INVOKE 			LoadAccelerators, windowInstance, IDA_MAIN
 MOV 				@accHandler, EAX
 INVOKE 			CreateWindowEx, WS_EX_CLIENTEDGE, OFFSET winClassName, OFFSET winDefaultTitle,\
					WS_OVERLAPPEDWINDOW, 100, 100, 700, 500, NULL, mainMenuHandler, windowInstance, NULL
 MOV 				mainWindowHandler, EAX
 ;��ʾ����--------------------------------------------------
 INVOKE 			ShowWindow, mainWindowHandler, SW_SHOWNORMAL
 ;���´���--------------------------------------------------
 INVOKE 			UpdateWindow, mainWindowHandler				
 ;��Ϣѭ��--------------------------------------------------
 .while TRUE
	INVOKE 			GetMessage, ADDR @msgStruct, NULL, 0, 0			
	.break .IF EAX == 0
	INVOKE 			TranslateAccelerator, mainWindowHandler, @accHandler, ADDR @msgStruct
	.IF		EAX == 0
		INVOKE 		TranslateMessage, ADDR @msgStruct				
		INVOKE 		DispatchMessage, ADDR @msgStruct					
	.ENDIF
 .endw
				
 INVOKE 			FreeLibrary, @rcedHandler	;;�ͷſ�	
 RET
				
winMainProc ENDP
;-----------------------------------------------------------------------	
START:

 INVOKE 	InitCommonControls
 CALL 	winMainProc
 INVOKE 	ExitProcess, NULL				

end START
;-----------------------------------------------------------------------	
	
				
;-----------------------------------------------------------------------
;已经完成：文件新建、打开、文本输入和删除、保存、另存为、退出
;尚未实现：撤销、重做、复制、粘贴、全选
;-----------------------------------------------------------------------
;所有函数中局部变量用@开头，以作区分
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
;菜单ID & 加速键ID
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
IDA_MAIN			EQU 2000h  ;加速键

;需要设置UNICODE字符集
UNICODE = 1

;-----------------------------------------------------------------------

.data?
windowInstance 	  	DWORD ?  ;窗口实例
mainWindowHandler  	DWORD ?  ;主窗口句柄
editWindowHandler	DWORD ?  ;编辑窗口句柄
currentFileHandler	DWORD ?  ;当前文件句柄
mainMenuHandler		DWORD ?  ;主菜单句柄
statusBarHandler	DWORD ?  ;todo: 状态栏
findHandler			DWORD ?  ;todo: 查找
replaceHandler		DWORD ?  ;todo: 替换
subMenuHandler		DWORD ?  ;todo:实现编辑相关功能

;文件名
fileName			BYTE MAX_PATH DUP(?)
fileNameTitle		BYTE MAX_PATH DUP(?)

;窗口大小
mainWinRect 		RECT <?>

;行高
charFmt  			BYTE '%4u', 0
lpEditProc			DWORD ?

;RichEdit CHARFORMAT结构
reCharFormat		CHARFORMAT<?>

;-----------------------------------------------------------------------

.const
winClassName		BYTE 'xNotepadClass', 0  ;窗口类名
winDefaultTitle 	BYTE 'untitled - xNotepad', 0
savedText			BYTE 'File Saved!', 0
noticeText			BYTE 'Notice', 0

;打开文件名称：由于使用CreateFileW, 需要用DW定义
txtFilter			DW 'T', 'e', 'x', 't', 'f', 'i', 'l', 'e', '(', '*', '.', 't', 'x', 't', ')', 0, '*', '.', 't', 'x', 't', 0
					DW 'A', 'l', 'l', '(', '*', '.', '*', ')', 0, '*', '.', '*', 0, 0
defaultFormat		DW 't', 'x', 't', 0
modifiedMsg			BYTE 'File modified, do you want to save?', 0

;RichEdit
dllRiched20			BYTE 'riched20.dll', 0
editClassName		BYTE 'RichEdit20A', 0

;EDITSTREAM
errMsg				BYTE 'Could not open the file.', 0
fontType 			BYTE '宋体', 0

;-----------------------------------------------------------------------

.code
;-----------------------------------------------------------------------
;显示行号
;-----------------------------------------------------------------------
_ShowLineNum PROC 	
 LOCAL @stClientRect:RECT	;客户区大小
 LOCAL @hDcEdit					;设备环境
 LOCAL @Char_Height			;字符高度
 LOCAL @Line_Count				;文本总行数
 LOCAL @ClientHeight			;客户区高度
 LOCAL @hdcBmp					;位图
 LOCAL @hdcCpb					;兼容Dc
 LOCAL @stBuf[10]:byte			;显示行号的缓冲区


 PUSHAD
 ;将位图载入
 INVOKE				GetDC, editWindowHandler										;获取Dc
 MOV				@hDcEdit, EAX
 INVOKE				CreateCompatibleDC, @hDcEdit						;创建兼容的位图Dc
 MOV				@hdcCpb, EAX
 INVOKE				GetClientRect, editWindowHandler, ADDR @stClientRect			;创建与兼容位图
 MOV				EBX, @stClientRect.bottom
 SUB				EBX, @stClientRect.top
 MOV				@ClientHeight, EBX
 INVOKE				CreateCompatibleBitmap, @hDcEdit, 45, @ClientHeight;
 MOV				@hdcBmp, EAX
 INVOKE				SelectObject, @hdcCpb, @hdcBmp
				
 ;填充颜色
 INVOKE				CreateSolidBrush, 08080ffh							
 INVOKE				FillRect, @hdcCpb, ADDR @stClientRect, EAX			
 INVOKE				SetBkMode, @hdcCpb, TRANSPARENT
				
 ;获取总行数
 INVOKE				SendMessage, editWindowHandler, EM_GETLINECOUNT, 0, 0
 ADD				EAX, 1
 MOV 				@Line_Count, EAX
 MOV				EAX, reCharFormat.yHeight									
 CDQ
 MOV				EBX, 20
 div				EBX
 MOV				@Char_Height, EAX
 INVOKE				RtlZeroMemory, ADDR @stBuf, SIZEOF @stBuf
				
 ;设置显示行号的文字颜色
 INVOKE				SetTextColor, @hdcCpb, 0000000h
 MOV				EBX, @Char_Height
 MOV				@Char_Height, 1
				
 ;获取目前窗口首个可见行号
 INVOKE				SendMessage, editWindowHandler, EM_GETFIRSTVISIBLELINE, 0, 0
 MOV				EDI, EAX
 SUB				EDI, 1
				
 ;在位图dc中插入行号
 .WHILE	EDI <= @Line_Count
	INVOKE			wsprintf, ADDR @stBuf, ADDR charFmt, EDI ;返回存储的字符数
	INVOKE			TextOut, @hdcCpb, 1, @Char_Height, ADDR @stBuf, EAX
	MOV				EDX, @Char_Height
	ADD				EDX, EBX
	ADD				EDX, 4  ;行距
	MOV				@Char_Height, EDX
	ADD  			EDI, 1
	.BREAK  .IF EDX > @ClientHeight 
 .ENDW
				
 ;将绘制好的位图加入
 INVOKE				BitBlt, @hDcEdit, 0, 0, 45, @ClientHeight, @hdcCpb, 0, 0, SRCCOPY 
 INVOKE				DeleteDC, @hdcCpb
 INVOKE				ReleaseDC, editWindowHandler, @hDcEdit
 INVOKE				DeleteObject, @hdcBmp
				
 POPAD							
				
 RET

_ShowLineNum ENDP

;-----------------------------------------------------------------------
;辅助编辑函数，以后在这里定义后续编辑功能相关函数的CALL
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
	;todo: CALL编辑功能函数
 .ENDIF
 INVOKE				CallWindowProc, lpEditProc, hWnd, uMsg, wParam, lParam
 RET

editProc ENDP

;-----------------------------------------------------------------------
;检察修改函数
;-----------------------------------------------------------------------

checkModified PROC

 INVOKE				SendMessage, editWindowHandler, EM_GETMODIFY, 0, 0
 .IF EAX
	INVOKE			MessageBox, mainWindowHandler, ADDR modifiedMsg, ADDR noticeText, MB_YESNOCANCEL
	.IF EAX == IDYES
		.IF !currentFileHandler ;目前文件为新文件
			CALL 	saveAsProc
			.IF EAX ;保存成功
				INVOKE 	MessageBox, mainWindowHandler, OFFSET savedText, OFFSET noticeText, MB_OK
			.ELSE
				RET
			.ENDIF
		.ELSE  ;目前文件为已经至少保存过一次的文件
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
;流处理函数
;-----------------------------------------------------------------------

procStream PROC	USES EBX EDI ESI dwCookie, lpBuffer, dwBytes, lpBytes
			
 .IF dwCookie
	INVOKE			ReadFile, currentFileHandler, lpBuffer, dwBytes, lpBytes, NULL
 .ELSE
	INVOKE			WriteFile, currentFileHandler, lpBuffer, dwBytes, lpBytes, NULL
 .ENDIF
				
 xor				EAX, EAX  ;清零后返回
 RET
				
procStream ENDP

;-----------------------------------------------------------------------
;打开函数
;-----------------------------------------------------------------------

newProc	PROC

 INVOKE				CloseHandle, currentFileHandler
 MOV				currentFileHandler, 0  ;关闭原有文件后句柄清零
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
				
 ;设置标题栏
 INVOKE 			SetWindowText, mainWindowHandler, ADDR winDefaultTitle

 ;TODO: 设置状态栏
				
 RET
				
newProc ENDP

;-----------------------------------------------------------------------
;打开函数
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
								
 ;更改标题栏
 INVOKE 			SetWindowTextW, mainWindowHandler, @openFileNameStruct.lpstrFileTitle
				
 RET
				
openProc ENDP

;-----------------------------------------------------------------------
;保存函数
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
;另存为函数
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
	MOV				EAX, TRUE  ;成功另存为
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
;主窗口处理函数
;-----------------------------------------------------------------------	
mainWinProcProc PROC USES EBX EDI ESI, hWnd, uMsg, wParam, lParam
			  
 MOV 				EAX, uMsg  ;获取消息

;-----------------------------------------------------------------------
 .IF EAX == WM_CREATE				
	;todo:注册查找、替换窗口等
						
	;创建编辑窗口			
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
						
	;点击右键弹出的子菜单
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
			;todo: 此处向编辑窗口发送消息，使其通过editProc调用功能函数
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
 .ELSE  ;未指定命令
	INVOKE 			DefWindowProc, hWnd, uMsg, wParam, lParam
	RET
 .ENDIF
;-----------------------------------------------------------
 xor		EAX, EAX ;清零后返回									
 RET
				
mainWinProcProc ENDP
;-----------------------------------------------------------------------
winMainProc PROC
 LOCAL @winClassStruct: WNDCLASSEX
 LOCAL @msgStruct: MSG
 LOCAL @accHandler: DWORD
 LOCAL @rcedHandler: DWORD
				
;注册富文本窗口-------------------------------------------
 INVOKE 			LoadLibrary, ADDR dllRiched20  ;加载richedit20dll
 MOV 				@rcedHandler, EAX
;注册窗口类-----------------------------------------------
 INVOKE 			RtlZeroMemory, ADDR @winClassStruct, sizeof @winClassStruct ;初始化局部变量
 INVOKE 			GetModuleHandle, NULL	;获取本模块句柄存入EAX中
 MOV				windowInstance, EAX			;存入全局变量windowInstance中									
 PUSH 				windowInstance
 POP				@winClassStruct.hInstance
 MOV 				@winClassStruct.cbSize, sizeof WNDCLASSEX
 MOV 				@winClassStruct.style, CS_HREDRAW or CS_VREDRAW
 MOV 				@winClassStruct.lpfnWndProc, OFFSET mainWinProcProc
 MOV 				@winClassStruct.hbrBackground, COLOR_WINDOW + 1  ;白背景色
 MOV 				@winClassStruct.lpszClassName, OFFSET winClassName
 INVOKE 			RegisterClassEx, ADDR @winClassStruct
;创建窗口--------------------------------------------------
 INVOKE 			LoadMenu, windowInstance, IDM_MAIN
 MOV				mainMenuHandler, EAX
 INVOKE 			LoadAccelerators, windowInstance, IDA_MAIN
 MOV 				@accHandler, EAX
 INVOKE 			CreateWindowEx, WS_EX_CLIENTEDGE, OFFSET winClassName, OFFSET winDefaultTitle,\
					WS_OVERLAPPEDWINDOW, 100, 100, 700, 500, NULL, mainMenuHandler, windowInstance, NULL
 MOV 				mainWindowHandler, EAX
 ;显示窗口--------------------------------------------------
 INVOKE 			ShowWindow, mainWindowHandler, SW_SHOWNORMAL
 ;更新窗口--------------------------------------------------
 INVOKE 			UpdateWindow, mainWindowHandler				
 ;消息循环--------------------------------------------------
 .while TRUE
	INVOKE 			GetMessage, ADDR @msgStruct, NULL, 0, 0			
	.break .IF EAX == 0
	INVOKE 			TranslateAccelerator, mainWindowHandler, @accHandler, ADDR @msgStruct
	.IF		EAX == 0
		INVOKE 		TranslateMessage, ADDR @msgStruct				
		INVOKE 		DispatchMessage, ADDR @msgStruct					
	.ENDIF
 .endw
				
 INVOKE 			FreeLibrary, @rcedHandler	;;释放库	
 RET
				
winMainProc ENDP
;-----------------------------------------------------------------------	
START:

 INVOKE 	InitCommonControls
 CALL 	winMainProc
 INVOKE 	ExitProcess, NULL				

end START
;-----------------------------------------------------------------------	
	
				
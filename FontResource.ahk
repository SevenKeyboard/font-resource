#Requires AutoHotkey v2.0.0+
;==============================================================
; FontResource — GDI font resource and existence helper
;
; GitHub: https://github.com/SevenKeyboard/font-resource
; Author: SevenKeyboard Ltd. (2025)
; License: MIT License
;
; Documentation / References:
;   EnumFontFamExProc callback function
;     https://learn.microsoft.com/en-us/previous-versions/dd162618(v=vs.85)
;   LOGFONTW structure (wingdi.h)
;     https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-logfontw
;   ENUMLOGFONTEXW structure (wingdi.h)
;     https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-enumlogfontexw
;   Re: Code works with 64-bit AHK but not 32-bit
;     https://www.autohotkey.com/boards/viewtopic.php?f=76&t=86601#p380516
;==============================================================

/*
Example Usage:
    msgbox(FontResource.exist("Noto Sans KR"))                              ;  true
    msgbox(FontResource.exist("Noto Sans Not-exist"))                       ;  false
    msgbox(FontResource.exist("Noto Sans KR", "Noto Sans KR Regular"))      ;  true
    msgbox(FontResource.exist("Noto Sans KR", "Noto Sans KR Bold"))         ;  true
    msgbox(FontResource.exist("Noto Sans KR", "Noto Sans KR Not-exist"))    ;  false
*/

class VersionManager_FontResource
{
    static _ := this._init()
    static _init()    {
        global
        FONTRESOURCE_VERSION := "1.0.1"
    }
}
class FontResource
{
    static FR_PRIVATE   := 0x10
        ,FR_NOT_ENUM    := 0x20

        ;  The character set. The following values are predefined:
        ,ANSI_CHARSET           := 0
        ,BALTIC_CHARSET         := 186
        ,CHINESEBIG5_CHARSET    := 136
        ,DEFAULT_CHARSET        := 1
        ,EASTEUROPE_CHARSET     := 238
        ,GB2312_CHARSET         := 134
        ,GREEK_CHARSET          := 161
        ,HANGUL_CHARSET         := 129
        ,MAC_CHARSET            := 77
        ,OEM_CHARSET            := 255
        ,RUSSIAN_CHARSET        := 204
        ,SHIFTJIS_CHARSET       := 128
        ,SYMBOL_CHARSET         := 2
        ,TURKISH_CHARSET        := 162
        ,VIETNAMESE_CHARSET     := 163
        ;  Korean language edition of Windows:
        ,JOHAB_CHARSET          := 130
        ;  Middle East language edition of Windows:
        ,ARABIC_CHARSET         := 178
        ,HEBREW_CHARSET         := 177
        ;  Thai language edition of Windows:
        ,THAI_CHARSET           := 222

        ,DEVICE_FONTTYPE    := 0x0002
        ,RASTER_FONTTYPE    := 0x0001
        ,TRUETYPE_FONTTYPE  := 0x0004
        
        
    static add(unnamedParam1)           => dllCall("Gdi32.dll\AddFontResourceW", "WStr",unnamedParam1, "Int")
    static addEx(name, fl, res:=0)      => dllCall("Gdi32.dll\AddFontResourceExW", "WStr",name, "UInt",fl, "Ptr",res, "Int")
    static remove(lpFileName)           => dllCall("Gdi32.dll\RemoveFontResourceW", "WStr",lpFileName, "Int")
    static removeEx(name, fl, pdv:=0)   => dllCall("Gdi32.dll\RemoveFontResourceExW", "WStr",name, "UInt",fl, "Ptr",pdv, "Int")

    static sendFontChangeMessage(timeout:=100, fuFlags:=0x0002)    { ;  #define SMTO_ABORTIFHUNG 0x0002
        static HWND_BROADCAST:=0xffff, WM_FONTCHANGE:=0x1D
        if (timeout)    {
            lr:=dllCall("User32.dll\SendMessageTimeoutW"
                ,"Ptr",HWND_BROADCAST
                ,"UInt",WM_FONTCHANGE
                ,"Ptr",0
                ,"Ptr",0
                ,"UInt",fuFlags
                ,"UInt",timeout
                ,"Ptr*",&(lpdwResult:=0)
                ,"Ptr")
            return (lr?lpdwResult:0)
        }  else  {
            return dllCall("User32.dll\SendMessageW", "Ptr",HWND_BROADCAST, "UInt",WM_FONTCHANGE, "Ptr",0, "Ptr",0, "Ptr")
        }
    }
    static _enumFontFamExProcCallback:=0
    static exist(faceName:="", fullName:="", charSet:=1)    { ;  DEFAULT_CHARSET
        static LF_FACESIZE:=32
        if (faceName=="" && fullName=="")
            return false
        hDC:=dllCall("User32.dll\GetDC", "Ptr",0, "Ptr")
        if (!hDC)
            return false
        lpLogfont:=buffer(92, 0)
        numPut("UChar",charSet, lpLogfont, 23)  ;  lfCharSet
        if (faceName!=="")
            strPut(faceName, lpLogfont.Ptr+28, LF_FACESIZE) ;  lfFaceName
        numPut("UChar", 0, lpLogfont, 27) ;  lfPitchAndFamily
        if (!this._enumFontFamExProcCallback)
            this._enumFontFamExProcCallback:=callbackCreate(objBindMethod(this,"_enumFontFamExProc"),"F",4)
        obj:={exist:false, faceName:faceName, fullName:fullName}
        dllCall("Gdi32.dll\EnumFontFamiliesExW"
            ,"Ptr",hDC
            ,"Ptr",lpLogfont.Ptr
            ,"Ptr",this._enumFontFamExProcCallback
            ,"Ptr",objPtr(obj) ;  https://www.autohotkey.com/docs/v2/Objects.htm#ObjPtr
            ,"UInt",0)
        dllCall("User32.dll\ReleaseDC", "Ptr",0, "Ptr",hDC, "Int")
        return obj.exist
    }
    static _enumFontFamExProc(lpelfe, lpntme, FontType, lParam)    {
        static LF_FACESIZE:=32, LF_FULLFACESIZE:=64
        if (A_PtrSize!==8)    {
            lpelfe:=lpelfe<<32>>32
            ,lpntme:=lpntme<<32>>32
            ,lParam:=lParam<<32>>32
        }
        obj:=objFromPtrAddRef(lParam)
        ,lfFaceName := strGet(lpelfe+28, LF_FACESIZE)
        ,elfFullName:= strGet(lpelfe+92, LF_FULLFACESIZE)
        if (obj.faceName=="" || obj.faceName=lfFaceName)
        && (obj.fullName=="" || obj.fullName=elfFullName)    {
            obj.exist:=true
            return false
        }
        return true
    }
}
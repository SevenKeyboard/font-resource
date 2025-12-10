#Requires AutoHotkey v1.1.0+
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
;   ENUMLOGFONTEXA structure (wingdi.h)
;     https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-enumlogfontexa?redirectedfrom=MSDN
;   Re: Code works with 64-bit AHK but not 32-bit
;     https://www.autohotkey.com/boards/viewtopic.php?f=76&t=86601#p380516
;==============================================================

/*
Example Usage:
    msgbox % FontResource.exist("Noto Sans KR")                         ;  true
    msgbox % FontResource.exist("Noto Sans Not-exist")                  ;  false
    msgbox % FontResource.exist("Noto Sans KR", "NotoSansKR-Regular")   ;  true
    msgbox % FontResource.exist("Noto Sans KR", "NotoSansKR-Not-exist") ;  false
*/

class VersionManager_FontResource
{
    static _ := VersionManager_FontResource._init()
    _init()    {
        global
        FONTRESOURCE_VERSION := "1.0.0"
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
        
        
    add(unnamedParam1)    {
        return dllCall("Gdi32.dll\AddFontResource", "Str",unnamedParam1, "Int")
    }
    addEx(name, fl, res:=0)    {
        return dllCall("Gdi32.dll\AddFontResourceEx", "Str",name, "UInt",fl, "Ptr",res, "Int")
    }
    remove(lpFileName)    {
        return dllCall("Gdi32.dll\RemoveFontResource", "Str",unnamedParam1, "Int")
    }
    removeEx(name, fl, pdv:=0)    {
        return dllCall("Gdi32.dll\RemoveFontResourceEx", "Str",name, "UInt",fl, "Ptr",pdv, "Int")
    }
    sendFontChangeMessage(timeout:=100, fuFlags:=0x0002)    { ;  #define SMTO_ABORTIFHUNG 0x0002
        static HWND_BROADCAST:=0xffff, WM_FONTCHANGE:=0x1D
        if (timeout)    {
            lr:=dllCall("User32.dll\SendMessageTimeout"
                ,"Ptr",HWND_BROADCAST
                ,"UInt",WM_FONTCHANGE
                ,"Ptr",0
                ,"Ptr",0
                ,"UInt",fuFlags
                ,"UInt",timeout
                ,"Ptr*",lpdwResult:=0
                ,"Ptr")
            return (lr?lpdwResult:0)
        }  else  {
            return dllCall("User32.dll\SendMessage", "Ptr",HWND_BROADCAST, "UInt",WM_FONTCHANGE, "Ptr",0, "Ptr",0, "Ptr")
        }
    }
    exist(faceName:="", fullName:="", charSet:=1)    { ;  DEFAULT_CHARSET
        static LF_FACESIZE:=32
        if (faceName=="" && fullName=="")
            return false
        hDC:=dllCall("User32.dll\GetDC", "Ptr",0, "Ptr")
        varSetCapacity(lpLogfont, (A_IsUnicode?92:60), 0)
        numPut(charSet, &lpLogfont, 23, "UChar") ;  lfCharSet
        if (faceName!=="")
            strPut(faceName, &lpLogfont+28, LF_FACESIZE) ;  lfFaceName
        numPut(0, &lpLogfont, 27, "UChar") ;  lfPitchAndFamily
        dllCall("Gdi32.dll\EnumFontFamiliesEx"
            ,"Ptr",hDC
            ,"Ptr",&lpLogfont
            ,"Ptr",registerCallback("fontResource_EnumFontFamExProc_BCA7674E","F",4)
            ,"Ptr",lParam:=object(obj:={exist:false, faceName:faceName, fullName:fullName}) ;  https://www.autohotkey.com/docs/v1/lib/ObjAddRef.htm#ExBasic
            ,"UInt",0)
        dllCall("User32.dll\ReleaseDC", "Ptr",0, "Ptr",hDC, "Int"), objRelease(lParam)
        return obj.exist
    }
}
fontResource_EnumFontFamExProc_BCA7674E(lpelfe, lpntme, FontType, lParam)    { ;  EnumFontFamExProc
    static LF_FACESIZE:=32, LF_FULLFACESIZE:=64
    if (A_PtrSize!==8)    {
         lpelfe:=lpelfe<<32>>32
        ,lpntme:=lpntme<<32>>32
        ,lParam:=lParam<<32>>32
    }
     lfFaceName := strGet(lpelfe+28, LF_FACESIZE)
    ,elfFullName:= strGet(lpelfe+(A_IsUnicode?92:60), LF_FULLFACESIZE)
    if (object(lParam).faceName=="" || object(lParam).faceName==lfFaceName)
    && (object(lParam).fullName=="" || object(lParam).fullName==elfFullName)    {
        object(lParam).exist:=true
        return false
    }
    return true
}
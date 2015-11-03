--[[

    Dynosaur

        Author:         pulsar
        License:        GNU GPLv3
        Environment:    wxLua-2.8.12.3-Lua-5.1.5-MSW-Unicode

        This Project is licensed under GPLv3, read 'docs/LICENSE-Dynosaur' for more details.
        To check the version history read 'docs/CHANGELOG'.

]]


-------------------------------------------------------------------------------------------------------------------------------------
--// IMPORTS //----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// loading basic constants
dofile( "system/core/const.lua" )

--// modules path
package.path = ";./" .. LUALIB_PATH .. "?.lua" ..
               ";./" .. LUALIB_PATH .. "socket/?.lua" ..
               ";./" .. LUALIB_PATH .. "ssl/?.lua" ..
               ";./" .. LUALIB_PATH .. "aeslua/?.lua" ..
               ";./" .. CORE_PATH .. "?.lua"

--// module cpath
package.cpath = ";./" .. CLIB_PATH .. "?.dll"

--// import modules
local wx     = require( "wx" )
local socket = require( "socket" )
local http   = require( "socket.http" )
local mime   = require( "mime" )
local ssl    = require( "ssl" )
local https  = require( "ssl.https" )
local util   = require( "util" )
               require( "aeslua" )
local twodns = require( "twodns" )

--[[
local encrypted_string = aeslua_encrypt( b32_chiffre, string )
local decrypted_string = aeslua_decrypt( b32_chiffre, encrypted_string )

local domain_tbl, statuscode = twodns.domains( https )
]]


-------------------------------------------------------------------------------------------------------------------------------------
--// BASIC CONST //------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local app_name         = "Dynosaur"
local app_version      = "v0.10"
local app_copyright    = "Copyright © by pulsar"
local app_license      = "License: GPLv3"

local app_width        = 400
local app_height       = 550

--local notebook_width   = 795
--local notebook_height  = 289

local file_appicons        = CLIB_PATH .. "appicons.dll"
local file_png_applogo     = RES_PATH ..  "applogo_96x96.png"
local file_png_gpl         = RES_PATH ..  "GPLv3_160x80.png"
local file_png_twodns_16   = RES_PATH ..  "twodns_16x16.png"
local file_png_noip_16     = RES_PATH ..  "noip_16x16.png"
local file_png_dyndns_16   = RES_PATH ..  "dyndns_16x16.png"
local file_png_language_16 = RES_PATH ..  "language_16x16.png"


local dbfile = {

    [ "system" ]   = { CFG_PATH .. "system.tbl", "system" },
    [ "twodns" ]   = { CFG_PATH .. "twodns.tbl", "TwoDNS", "twodns" },
    [ "noip" ]     = { CFG_PATH .. "noip.tbl",   "NO-IP",  "noip" },
    [ "dyndns" ]   = { CFG_PATH .. "dyndns.tbl", "DynDNS", "dyndns" },
}

local logfile = {

    [ "system" ]   = { LOG_PATH .. "system.log" },
    [ "twodns" ]   = { LOG_PATH .. "twodns.log" },
    [ "noip" ]     = { LOG_PATH .. "noip.log" },
    [ "dyndns" ]   = { LOG_PATH .. "dyndns.log" },
}

-------------------------------------------------------------------------------------------------------------------------------------
--// CACHING TABLE LOOKUPS //--------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local aeslua_encrypt = aeslua.encrypt
local aeslua_decrypt = aeslua.decrypt
local util_loadtable = util.loadtable
local util_savetable = util.savetable
local util_formatbytes = util.formatbytes
local util_trimstring = util.trimstring


-------------------------------------------------------------------------------------------------------------------------------------
--// DEFAULTS //---------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// default vars
local control, X, Y
local taskbar = nil
local need_save_system = false
local need_save_twodns = false
local need_save_noip   = false
local need_save_dyndns = false

--// app icons
local app_ico_16 = wx.wxIcon( file_appicons .. ";0", wx.wxBITMAP_TYPE_ICO, 16, 16 )
local app_ico_32 = wx.wxIcon( file_appicons .. ";1", wx.wxBITMAP_TYPE_ICO, 32, 32 )

--// fonts
local log_font       = wx.wxFont( 8, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Lucida Console" )
local default_font   = wx.wxFont( 8, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_normal_1 = wx.wxFont( 9, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_normal_2 = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxNORMAL, false, "Verdana" )
local about_bold     = wx.wxFont( 10, wx.wxMODERN, wx.wxNORMAL, wx.wxFONTWEIGHT_BOLD, false, "Verdana" )

--// database tables
local lang_tbl, system_tbl, twodns_tbl, noip_tbl, dyndns_tbl


-------------------------------------------------------------------------------------------------------------------------------------
--// IDS //--------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local id_counter = wx.wxID_HIGHEST + 1
local new_id = function()
    id_counter = id_counter + 1
    return id_counter
end

ID_mb_settings    = new_id()
ID_mb_log         = new_id()
ID_mb_log_system  = new_id()
ID_mb_log_twodns  = new_id()
ID_mb_log_noip    = new_id()
ID_mb_log_dyndns  = new_id()
ID_mb_twodns      = new_id()
ID_mb_noip        = new_id()
ID_mb_dyndns      = new_id()
ID_mb_language    = new_id()


-------------------------------------------------------------------------------------------------------------------------------------
--// EVENT HANDLER //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local HandleEvents = function( event )
    local name = event:GetEventObject():DynamicCast( "wxWindow" ):GetName()
end


-------------------------------------------------------------------------------------------------------------------------------------
--// DIFFERENT FUNCS //--------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// encrypt string
local b32_chiffre = "JN74TC2JULT5DYXH2ETPRKV3RUGX7GOVR3JZGLDIBM4I6BHXV3EQ"

local log = {}
local aes = {}
local get = {}
local set = {}
local make = {}
local check = {}

--// read a logfile
log.read = function( file, parent )
    local content, size = "", 0
    local txt_filesize = "File Size: "
    local txt_file_is_empty = "Logfile is empty."
    parent:Clear()
    local f = io.open( file, "r" )
    if f then
        content = f:read( "*a" )
        size = util_formatbytes( wx.wxFileSize( file ) )
    end
    if content == "" then
        local vsep = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
        local hsep = "\t\t\t\t\t\t"
        parent:AppendText( vsep )
        parent:AppendText( hsep .. txt_file_is_empty )
    else
        parent:AppendText( content )
        parent:AppendText( "\n" .. txt_filesize .. size )
    end
    local al = parent:GetNumberOfLines()
    parent:ScrollLines( al + 1 )
end

--// write to a logfile (with timestamp)
log.write = function( txt, file )
    local timestamp = "[" .. os.date( "%Y-%m-%d/%H:%M:%S" ) .. "] "
    local f = io.open( file, "a+" )
    if f then
        f:write( timestamp .. txt .. "\n" )
        f:close()
    end
end

--// clear a logfile
log.clear = function( file )
    if file then
        local f = io.open( file, "w" )
        f:close()
    end
end

--// encrypt a string
aes.encrypt = function( pass, msg )
    if ( not pass ) or ( not type( pass ) == "string" ) and ( not msg ) or ( not type( msg ) == "string" ) then
        return nil
    end
    local cipher = aeslua_encrypt( pass, msg )
    return cipher
end

--// decrypt a string
aes.decrypt = function( pass, cipher )
    if ( not pass ) or ( not type( pass ) == "string" ) and ( not cipher ) or ( not type( cipher ) == "string" ) then
        return nil
    end
    local plain = aeslua_decrypt( pass, cipher )
    return plain
end

--// returns an array of all files (without extension) from a path with the given file spec e.g. "*.*"
get.file_array = function( path, spec )
    if not spec then spec = "*.*" end
    if path then
        local amount, arr = wx.wxDir.GetAllFiles( path, spec, wx.wxDIR_FILES )
        local modpath = path:gsub( "/", "\\" )
        for k, v in pairs( arr ) do
            arr[ k ] = v:gsub( modpath, "" ):gsub( ".tbl", "" )
        end
        return arr
    else
        log.write( "Error: get.file_array(): string expected, got " .. type( path ), logfile.system[ 1 ] )
        return nil
    end
end

--// get value from settings table
get.tbl_value = function( tbl, key )
    if ( type( tbl ) == "table" ) and  key then
        if type( key ) == "string" then
            if type( tbl[ key ] ) ~= "nil" then
                return tbl[ key ]
            else
                return nil
            end
        else
            return nil
        end
    else
        return nil
    end
end

--// set value to a table
set.tbl_value = function( tbl, key, value )
    if key and ( value ~= nil ) then
        if type( key ) ~= "string" then
            return nil
        end
        if key == "" then
            return nil
        end
        if value == "" then
            return nil
        end
        tbl[ key ] = value
        return true
    else
        return nil
    end
end

--// make empty logfiles on start (if not exists)
make.logfiles = function()
    local check_path = function( path )
        if not ( wx.wxDir.Exists( path ) ) then
            local mkdir = wx.wxMkdir( LOG_PATH )
            if not mkdir then
                -- could not create new directory
            end
        end
    end
    check_path( LOG_PATH )
    local check_file = function( file )
        if not ( wx.wxFile.Exists( file ) ) then
            local f, err = io.open( file, "w" )
            --assert( f, "Fail: " .. tostring( err ) )
            f:close()
        end
    end
    for k, v in pairs( logfile ) do
        check_file( v[ 1 ] )
    end
end
make.logfiles()

--// make empty databases on start (if not exists)
make.databases = function()
    local check_path = function( path )
        if not ( wx.wxDir.Exists( path ) ) then
            local mkdir = wx.wxMkdir( CFG_PATH )
            if not mkdir then
                -- could not create new directory
            end
        end
    end
    check_path( CFG_PATH )
    local check_file = function( key, file )
        if not ( wx.wxFile.Exists( file ) ) then
            local tbl = {}
            util_savetable( tbl, key, file )
        end
    end
    for k, v in pairs( dbfile ) do
        check_file( k, v[ 1 ] )
    end
end
make.databases()

--// language dialog
local show_lang_dialog = function( tbl, firststart )
    --// icons for app titlebar and taskbar
    local icons = wx.wxIconBundle()
    icons:AddIcon( app_ico_16 )
    icons:AddIcon( app_ico_32 )
    --// get array of lang files
    local arr = get.file_array( LANG_PATH, "*.tbl" )
    arr = wx.wxArrayString( arr )
    --// single choice dialog
    local scdi = wx.wxSingleChoiceDialog(
        wx.NULL,
        app_name .. " " .. "Language:",
        app_name,
        arr,
        wx.wxDEFAULT_DIALOG_STYLE + wx.wxOK - wx.wxCLOSE_BOX
    )
    scdi:SetIcons( icons )
    scdi:ShowModal()
    --// get users selection
    local lang = tostring( scdi:GetStringSelection() )
    --// add selection to tbl
    tbl[ "language" ] = lang
    --// close dialog and save lang to tbl
    scdi:Destroy()
    util_savetable( tbl, dbfile.system[ 2 ], dbfile.system[ 1 ] )
    if not firststart then
        --// send dialog msg
        local di = wx.wxMessageDialog( wx.NULL, "Changes will take effect after a restart.", lang_tbl.info, wx.wxOK + wx.wxICON_INFORMATION + wx.wxCENTRE )
        di:ShowModal(); di:Destroy()
    end
end

--// display lang chooser dialog on first start
local show_lang_dialog_on_first_start = function()
    local tbl = util_loadtable( dbfile.system[ 1 ] )
    if type( tbl[ "language" ] ) == "nil" then
        show_lang_dialog( tbl, true )
    end
end
show_lang_dialog_on_first_start()

--// cache database tables
local cache_tables = function()
    system_tbl = util_loadtable( dbfile.system[ 1 ] )
    twodns_tbl = util_loadtable( dbfile.twodns[ 1 ] )
    noip_tbl   = util_loadtable( dbfile.noip[ 1 ] )
    dyndns_tbl = util_loadtable( dbfile.dyndns[ 1 ] )
    lang_tbl   = util_loadtable( LANG_PATH .. system_tbl[ "language" ] .. ".tbl" )
end
cache_tables()

--// save settings if needed
local save_if_needed = function()
    if need_save_system then
        util_savetable( system_tbl, dbfile.system[ 2 ], dbfile.system[ 1 ] )
        log.write( lang_tbl.settings_tbl_saved, logfile.system[ 1 ] )
        need_save_system = false
    end
    if need_save_twodns then
        util_savetable( twodns_tbl, dbfile.twodns[ 3 ], dbfile.twodns[ 1 ] )
        log.write( lang_tbl.twodns_tbl_saved, logfile.twodns[ 1 ] )
        need_save_twodns = false
    end
    if need_save_noip then
        util_savetable( noip_tbl, dbfile.noip[ 3 ], dbfile.noip[ 1 ] )
        log.write( lang_tbl.noip_tbl_saved, logfile.noip[ 1 ] )
        need_save_noip = false
    end
    if need_save_dyndns then
        util_savetable( dyndns_tbl, dbfile.dyndns[ 3 ], dbfile.dyndns[ 1 ] )
        log.write( lang_tbl.dyndns_tbl_saved, logfile.dyndns[ 1 ] )
        need_save_dyndns = false
    end
end

--// check for whitespaces in wxTextCtrl
check.textctrl = function( parent, control )
    local s = control:GetValue()
    if s == ( "" or nil ) then
        --// send dialog msg
        local di = wx.wxMessageDialog( parent, lang_tbl.check_textctrl_empty, lang_tbl.info, wx.wxOK )
        di:ShowModal()
        di:Destroy()
    end
    local new, n = string.gsub( s, " ", "" )
    if n ~= 0 then
        --// send dialog msg
        local di = wx.wxMessageDialog( parent, lang_tbl.check_textctrl_whitespaces .. " " .. n, lang_tbl.info, wx.wxOK )
        di:ShowModal()
        di:Destroy()
        control:SetValue( new )
    end
end

--// about window
local show_about_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        lang_tbl.about .. " " .. app_name,
        wx.wxDefaultPosition,
        wx.wxSize( 320, 465 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 320, 465 ) )
    di:SetMaxSize( wx.wxSize( 320, 465 ) )

    --// app logo
    local bmp_applogo = wx.wxBitmap():ConvertToImage()
    bmp_applogo:LoadFile( file_png_applogo )
    X, Y = bmp_applogo:GetWidth(), bmp_applogo:GetHeight()
    control = wx.wxStaticBitmap( di, wx.wxID_ANY, wx.wxBitmap( bmp_applogo ), wx.wxPoint( 0, 0 ), wx.wxSize( X, Y ) )
    control:Centre( wx.wxHORIZONTAL )
    bmp_applogo:Destroy()

    --// app name / version
    control = wx.wxStaticText(
        di,
        wx.wxID_ANY,
        app_name .. " " .. app_version,
        wx.wxPoint( 0, 90 )
    )
    control:SetFont( about_bold )
    control:Centre( wx.wxHORIZONTAL )

    --// app copyright
    control = wx.wxStaticText(
        di,
        wx.wxID_ANY,
        app_copyright,
        wx.wxPoint( 0, 110 )
    )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// horizontal line
    control = wx.wxStaticLine( di, wx.wxID_ANY, wx.wxPoint( 0, 140 ), wx.wxSize( 275, 1 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// gpl text
    control = wx.wxStaticText(
        di,
        wx.wxID_ANY,
        lang_tbl.licensed_under,
        wx.wxPoint( 0, 155 )
    )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// gpl logo
    local gpl_logo = wx.wxBitmap():ConvertToImage()
    gpl_logo:LoadFile( file_png_gpl )
    control = wx.wxStaticBitmap(
        di,
        wx.wxID_ANY,
        wx.wxBitmap( gpl_logo ),
        wx.wxPoint( 0, 175 ),
        wx.wxSize( gpl_logo:GetWidth(), gpl_logo:GetHeight() )
    )
    control:Centre( wx.wxHORIZONTAL )
    gpl_logo:Destroy()

    --// horizontal line
    control = wx.wxStaticLine( di, wx.wxID_ANY, wx.wxPoint( 0, 270 ), wx.wxSize( 275, 1 ) )
    control:Centre( wx.wxHORIZONTAL )

    --// credits text
    control = wx.wxStaticText(
        di,
        wx.wxID_ANY,
        "Credits:",
        wx.wxPoint( 0, 285 )
    )
    control:SetFont( about_normal_2 )
    control:Centre( wx.wxHORIZONTAL )

    --// credits
    control = wx.wxTextCtrl(
        di,
        wx.wxID_ANY,
        "blabla\n" ..
        "bla",
        wx.wxPoint( 0, 310 ),
        wx.wxSize( 275, 90 ),
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_RICH + wx.wxSUNKEN_BORDER + wx.wxHSCROLL + wx.wxTE_CENTRE
    )
    --control:SetBackgroundColour( wx.wxColour( 225, 225, 225 ) )
    control:SetBackgroundColour( wx.wxColour( 245, 245, 245 ) )
    control:SetForegroundColour( wx.wxBLACK )
    control:Centre( wx.wxHORIZONTAL )

    --// button
    local about_btn_close = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_close, wx.wxPoint( 0, 409 ), wx.wxSize( 80, 20 ) )
    about_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    about_btn_close:Centre( wx.wxHORIZONTAL )

    --// events
    about_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        di:Destroy()
    end )

    --// show dialog
    di:ShowModal()
end

--// log window
local show_log_window = function( frame, file, caption )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        caption,
        wx.wxDefaultPosition,
        wx.wxSize( 700, 515 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 700, 515 ) )
    di:SetMaxSize( wx.wxSize( 700, 515 ) )

    --// log
    local log_text = wx.wxTextCtrl(
        di,
        wx.wxID_ANY,
        "",
        wx.wxPoint( 0, 5 ),
        wx.wxSize( 680, 450 ),
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_RICH + wx.wxSUNKEN_BORDER + wx.wxHSCROLL
    )
    log_text:SetBackgroundColour( wx.wxColour( 0, 0, 0 ) )
    log_text:SetFont( log_font )
    log_text:SetDefaultStyle( wx.wxTextAttr( wx.wxWHITE ) )
    log_text:Centre( wx.wxHORIZONTAL )

    --// button close
    local log_btn_close = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_close, wx.wxPoint( 0, 460 ), wx.wxSize( 80, 20 ) )
    log_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    log_btn_close:Centre( wx.wxHORIZONTAL )
    log_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        di:Destroy()
    end )

    --// button clear log
    local log_btn_clear = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_clear, wx.wxPoint( 605, 460 ), wx.wxSize( 80, 20 ) )
    log_btn_clear:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    log_btn_clear:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        log.clear( file )
        log_text:Clear()
        log_btn_clear:Disable()
        log.write( "Cleared logfile: " .. logfile.system[ 1 ], logfile.system[ 1 ] )
    end )

    --// read log file an add text
    log.read( file, log_text )

    --// show dialog
    di:ShowModal()
end

--// add taskbar (system tray)
local add_taskbar = function( frame, checkbox_trayicon )
    local showtray = false
    if system_tbl[ "trayicon" ] then
        showtray = true
    end
    if showtray then
        taskbar = wx.wxTaskBarIcon()
        taskbar:SetIcon( app_ico_16, app_name .. " " .. app_version )

        --// taskbar menu
        local menu = wx.wxMenu()
        menu:Append( wx.wxID_ABOUT, lang_tbl.about .. "\tF1",   lang_tbl.about .. " " .. app_name )
        menu:AppendSeparator()
        menu:Append( wx.wxID_EXIT,  lang_tbl.exit ..  "\tAlt-X", lang_tbl.exit .. " " .. app_name )

        --// taskbar menu events
        menu:Connect( wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_about_window( frame )
        end )
        menu:Connect( wx.wxID_EXIT, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            --// send dialog msg
            local di = wx.wxMessageDialog( frame, lang_tbl.really_quit, lang_tbl.info, wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
            local result = di:ShowModal()
            di:Destroy()
            if result == wx.wxID_YES then
                if ( need_save_system or need_save_twodns or need_save_noip or need_save_dyndns ) then
                    --// send dialog msg
                    local di = wx.wxMessageDialog( frame, lang_tbl.save_changes, lang_tbl.info, wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                    local result = di:ShowModal()
                    di:Destroy()
                    if result == wx.wxID_YES then
                        save_if_needed()
                    else
                        --undo_changes()
                    end
                end
                frame:Destroy()
                if taskbar then taskbar:delete() end
            end
        end )
        --// taskbar right mouse click event
        taskbar:Connect( wx.wxEVT_TASKBAR_RIGHT_DOWN,
            function( event )
                taskbar:PopupMenu( menu )
            end
        )
        --// taskbar left mouse click event
        taskbar:Connect( wx.wxEVT_TASKBAR_LEFT_DOWN,
        function( event )
            frame:Iconize( not frame:IsIconized() )
            -- new
            local show = not frame:IsIconized()
            if show then
                frame:Raise( true )
            end
        end )
        frame:Connect( wx.wxEVT_ICONIZE,
        function( event )
            local show = not frame:IsIconized()
            frame:Show( show )
            if show then
                frame:Raise( true )
            end
        end )
        frame:Connect( wx.wxEVT_CLOSE_WINDOW,
        function( event )
            frame:Iconize( true )
            return false
        end )
        frame:Connect( wx.wxEVT_DESTROY,
        function( event )

        end )
    else
        if taskbar then
            --// events
            frame:Connect( wx.wxEVT_ICONIZE,
            function( event )
                local show = not frame:IsIconized()
                frame:Show( true )
                if show then
                    frame:Raise( true )
                end
            end )
            frame:Connect( wx.wxEVT_CLOSE_WINDOW,
            function( event )
                --// send dialog msg
                local di = wx.wxMessageDialog( frame, lang_tbl.really_quit, lang_tbl.info, wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                local result = di:ShowModal(); di:Destroy()
                if result == wx.wxID_YES then
                    if ( need_save_system or need_save_twodns or need_save_noip or need_save_dyndns ) then
                        --// send dialog msg
                        local di = wx.wxMessageDialog( frame, lang_tbl.save_changes, lang_tbl.info, wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                        local result = di:ShowModal(); di:Destroy()
                        if result == wx.wxID_YES then
                            save_if_needed()
                        else
                            --undo_changes()
                        end
                    end
                    frame:Destroy()
                    frame:Iconize( false )
                    if taskbar then taskbar:delete() end
                    return false
                end
            end )
            if taskbar then taskbar:delete() end
        end
        taskbar = nil
    end
    return taskbar
end

--// settings window
local show_settings_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        lang_tbl.settings_status,
        wx.wxDefaultPosition,
        wx.wxSize( 320, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 320, 400 ) )
    di:SetMaxSize( wx.wxSize( 320, 400 ) )

    --// statusbar for dialog
    local sb = wx.wxStatusBar( di, wx.wxID_ANY ); sb:SetStatusText( "", 0 )

    --// basic settings
    control = wx.wxStaticBox( di, wx.wxID_ANY, lang_tbl.basic_settings, wx.wxPoint( 10, 10 ), wx.wxSize( 295, 100 ) )

    --// minimize to tray
    local checkbox_trayicon = wx.wxCheckBox( di, wx.wxID_ANY, lang_tbl.minimize_to_tray, wx.wxPoint( 25, 35 ), wx.wxDefaultSize )
    checkbox_trayicon:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.minimize_to_tray_status, 0 ) end )
    checkbox_trayicon:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    if system_tbl[ "trayicon" ] == true then
        checkbox_trayicon:SetValue( true )
    else
        checkbox_trayicon:SetValue( false )
    end

    --// horizontal line
    --control = wx.wxStaticLine( di, wx.wxID_ANY, wx.wxPoint( 0, 140 ), wx.wxSize( 275, 1 ) )
    --control:Centre( wx.wxHORIZONTAL )

    --// button close
    local settings_btn_close = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_close, wx.wxPoint( 0, 320 ), wx.wxSize( 80, 20 ) )
    settings_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    settings_btn_close:Centre( wx.wxHORIZONTAL )

    --// event - minimize to tray
    checkbox_trayicon:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_CHECKBOX_CLICKED,
    function( event )
        local trayicon = checkbox_trayicon:GetValue()
        system_tbl[ "trayicon" ] = trayicon
        add_taskbar( frame, checkbox_trayicon )
        need_save_system = true
    end )

    --// event - button close
    settings_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        save_if_needed()
        di:Destroy()
    end )

    --// show dialog
    di:ShowModal()
end

--// twodns window
local show_twodns_window = function( frame )
    local verify = false
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        lang_tbl.twodns_menubar_status,
        wx.wxDefaultPosition,
        wx.wxSize( 420, 400 ),
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 420, 400 ) )
    di:SetMaxSize( wx.wxSize( 420, 400 ) )

    --// statusbar for dialog
    local sb = wx.wxStatusBar( di, wx.wxID_ANY ); sb:SetStatusText( "", 0 )

    --// get all available domains
    local domain_tbl, statuscode = twodns.domains( https )

    --// add account
    control = wx.wxStaticBox( di, wx.wxID_ANY, lang_tbl.twodns_add_account, wx.wxPoint( 10, 10 ), wx.wxSize( 394, 290 ) )

    --// account type
    local twodns_account_type = wx.wxRadioBox(
        di,
        200,--wx.wxID_ANY,
        lang_tbl.twodns_radio_selection,
        wx.wxPoint( 20, 32 ),
        wx.wxSize( 180, 65 ),
        { lang_tbl.twodns_radio_new, lang_tbl.twodns_radio_existing },
        1,
        wx.wxSUNKEN_BORDER
    )
    twodns_account_type:Connect( 200, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_radio_status, 0 ) end )
    twodns_account_type:Connect( 200, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// hostname caption
    control = wx.wxStaticText( di, wx.wxID_ANY, lang_tbl.twodns_hostname, wx.wxPoint( 20, 112 ) )

    --// hostname
    local twodns_domainname_add = wx.wxTextCtrl( di, wx.wxID_ANY, "", wx.wxPoint( 20, 131 ), wx.wxSize( 205, 20 ),  wx.wxSUNKEN_BORDER )
    twodns_domainname_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_domainname_add:SetMaxLength( 40 )
    twodns_domainname_add:SetValue( lang_tbl.twodns_hostname_default )
    twodns_domainname_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_hostname_status, 0 ) end )
    twodns_domainname_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// separator dot
    control = wx.wxStaticText( di, wx.wxID_ANY, ".", wx.wxPoint( 231, 135 ) )

    --// domain caption
    control = wx.wxStaticText( di, wx.wxID_ANY, lang_tbl.twodns_domain, wx.wxPoint( 240, 112 ) )

    --// domain choice
    local twodns_domain_choice = wx.wxChoice(
        di,
        wx.wxID_ANY,
        wx.wxPoint( 240, 130 ),
        wx.wxSize( 153, 20 ),
        domain_tbl
    )
    twodns_domain_choice:Select( 0 )
    twodns_domain_choice:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_domain_status, 0 ) end )
    twodns_domain_choice:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    --if default_cfg_tbl.key_level == 0 then twodns_domain_choice:Select( 0 ) end
    --local key_level = twodns_domain_choice:GetCurrentSelection()

    --// API-Token caption
    control = wx.wxStaticText( di, wx.wxID_ANY, lang_tbl.twodns_token, wx.wxPoint( 20, 162 ) )

    --// API-Token
    local twodns_token_add = wx.wxTextCtrl( di, wx.wxID_ANY, "", wx.wxPoint( 20, 181 ), wx.wxSize( 373, 20 ),  wx.wxSUNKEN_BORDER )
    twodns_token_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_token_add:SetMaxLength( 40 )
    twodns_token_add:SetValue( lang_tbl.twodns_token_default )
    twodns_token_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_token_status, 0 ) end )
    twodns_token_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// E-Mail caption
    control = wx.wxStaticText( di, wx.wxID_ANY, lang_tbl.twodns_email, wx.wxPoint( 20, 212 ) )

    --// E-Mail
    local twodns_email_add = wx.wxTextCtrl( di, wx.wxID_ANY, "", wx.wxPoint( 20, 231 ), wx.wxSize( 373, 20 ),  wx.wxSUNKEN_BORDER )
    twodns_email_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_email_add:SetMaxLength( 40 )
    twodns_email_add:SetValue( lang_tbl.twodns_email_default )
    twodns_email_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_email_status, 0 ) end )
    twodns_email_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// button add
    local twodns_button_add = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_add, wx.wxPoint( 122, 268 ), wx.wxSize( 80, 20 ) )
    twodns_button_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_button_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_btn_add_status, 0 ) end )
    twodns_button_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    twodns_button_add:Disable()

    --// button verify
    local twodns_button_verify_add = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_verify, wx.wxPoint( 212, 268 ), wx.wxSize( 80, 20 ) )
    twodns_button_verify_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_button_verify_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.twodns_btn_verify_status, 0 ) end )
    twodns_button_verify_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// button close
    local twodns_btn_close = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_close, wx.wxPoint( 0, 320 ), wx.wxSize( 80, 20 ) )
    twodns_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( lang_tbl.close .. " " .. lang_tbl.twodns_menubar_status .. ".", 0 ) end )
    twodns_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    twodns_btn_close:Centre( wx.wxHORIZONTAL )

    --// event - account type
    twodns_account_type:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_RADIOBOX_SELECTED,
    function( event )
        need_save_twodns = true
        twodns_button_add:Disable()
        twodns_button_verify_add:Enable( true )
    end )

    --// event - hostname
    twodns_domainname_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
    function( event )
        need_save_twodns = true
        twodns_button_add:Disable()
        twodns_button_verify_add:Enable( true )
    end )
    twodns_domainname_add:Connect( wx.wxID_ANY, wx.wxEVT_KILL_FOCUS,
    function( event )
        check.textctrl( di, twodns_domainname_add )
    end )

    --// event - domain choice
    twodns_domain_choice:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_CHOICE_SELECTED,
    function( event )
        need_save_twodns = true
        twodns_button_add:Disable()
        twodns_button_verify_add:Enable( true )
    end )

    --// event - API-Token
    twodns_token_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
    function( event )
        need_save_twodns = true
        twodns_button_add:Disable()
        twodns_button_verify_add:Enable( true )
    end )
    twodns_token_add:Connect( wx.wxID_ANY, wx.wxEVT_KILL_FOCUS,
    function( event )
        check.textctrl( di, twodns_token_add )
    end )

    --// event - E-Mail
    twodns_email_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_UPDATED,
    function( event )
        need_save_twodns = true
        twodns_button_add:Disable()
        twodns_button_verify_add:Enable( true )
    end )
    twodns_email_add:Connect( wx.wxID_ANY, wx.wxEVT_KILL_FOCUS,
    function( event )
        check.textctrl( di, twodns_email_add )
    end )

    --// event - button verify
    twodns_button_verify_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        wx.wxBeginBusyCursor()
        
        --// get control values
        local account_type = twodns_account_type:GetSelection()
        local hostname = twodns_domainname_add:GetValue()
        local domain = domain_tbl[ tonumber( twodns_domain_choice:GetCurrentSelection() ) + 1 ]
        local dynaddy = hostname .. "." .. domain
        local token = twodns_token_add:GetValue()
        local email = twodns_email_add:GetValue()

        --// check if fields are empty
        if not hostname == ( "" or nil ) then verify = true end
        if not token == ( "" or nil ) then verify = true end
        if not email == ( "" or nil ) then verify = true end

        print( "hostname: " .. hostname )
        print( "domain: " .. domain )
        print( "dynaddy: " .. dynaddy )
        print( "token: " .. token )
        print( "email: " .. email .. "\n" )

        verify = true -- test
        --[[
        if verify then
            if account_type == 0 then
                -- new acc
                local statuscode = twodns.add_domain( https, dynaddy, token, email )
                if statuscode == 200 then
                    -- ok
                else
                    -- failed
                    verify = false
                end
            else
                -- existing acc
                local statuscode = twodns.add_domain( https, dynaddy, token, email )
                if statuscode == 200 then
                    -- ok
                else
                    -- failed
                    verify = false
                end
            end
        end
        ]]
        if verify then
            twodns_button_add:Enable( true )
            twodns_button_verify_add:Disable()
        end
        wx.wxEndBusyCursor()
    end )

    --// event - button add
    twodns_button_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        --// get control values
        local hostname = twodns_domainname_add:GetValue()
        local domain = domain_tbl[ tonumber( twodns_domain_choice:GetCurrentSelection() ) + 1 ]
        local token = twodns_token_add:GetValue()
        local email = twodns_email_add:GetValue()
        --// add new table entry
        twodns_tbl[ #twodns_tbl + 1 ] = {
            [ "hostname" ] = hostname,
            [ "domain" ] = domain,
            [ "token" ] = token,
            [ "email" ] = email,
        }
        --// save table
        need_save_twodns = true
        save_if_needed()
        twodns_button_add:Disable()
        --// send dialog msg
        local di = wx.wxMessageDialog( di, lang_tbl.twodns_account_added .. hostname .. "." .. domain, lang_tbl.info, wx.wxOK )
        di:ShowModal()
        di:Destroy()
    end )

    --// event - button close
    twodns_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        save_if_needed()
        di:Destroy()
    end )

    --// show dialog
    di:ShowModal()
    wx.wxEndBusyCursor()
end

--// noip window
local show_noip_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        lang_tbl.noip_menubar_status,
        wx.wxDefaultPosition,
        wx.wxSize( 420, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 420, 400 ) )
    di:SetMaxSize( wx.wxSize( 420, 400 ) )

    --// statusbar for dialog
    local sb = wx.wxStatusBar( di, wx.wxID_ANY ); sb:SetStatusText( "", 0 )

    --// basic settings
    --control = wx.wxStaticBox( di, wx.wxID_ANY, lang_tbl.basic_settings, wx.wxPoint( 10, 10 ), wx.wxSize( 295, 100 ) )


    --// button
    local noip_btn_close = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_close, wx.wxPoint( 0, 320 ), wx.wxSize( 80, 20 ) )
    noip_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    noip_btn_close:Centre( wx.wxHORIZONTAL )

    --// events
    noip_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
    function( event )
        save_if_needed()
        di:Destroy()
    end )

    --// show dialog
    di:ShowModal()
    wx.wxEndBusyCursor()
end

--// dyndns window
local show_dyndns_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        lang_tbl.dyndns_menubar_status,
        wx.wxDefaultPosition,
        wx.wxSize( 420, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 420, 400 ) )
    di:SetMaxSize( wx.wxSize( 420, 400 ) )

    --// statusbar for dialog
    local sb = wx.wxStatusBar( di, wx.wxID_ANY ); sb:SetStatusText( "", 0 )

    --// basic settings
    --control = wx.wxStaticBox( di, wx.wxID_ANY, lang_tbl.basic_settings, wx.wxPoint( 10, 10 ), wx.wxSize( 295, 100 ) )

    --// button
    local dyndns_btn_close = wx.wxButton( di, wx.wxID_ANY, lang_tbl.btn_close, wx.wxPoint( 0, 320 ), wx.wxSize( 80, 20 ) )
    dyndns_btn_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    dyndns_btn_close:Centre( wx.wxHORIZONTAL )

    --// events
    dyndns_btn_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            save_if_needed()
            di:Destroy()
        end
    )

    --// show dialog
    di:ShowModal()
    wx.wxEndBusyCursor()
end


-------------------------------------------------------------------------------------------------------------------------------------
--// MENUBAR //----------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local bmp_about_16x16    = wx.wxArtProvider.GetBitmap( wx.wxART_INFORMATION, wx.wxART_TOOLBAR )
local bmp_settings_16x16 = wx.wxArtProvider.GetBitmap( wx.wxART_LIST_VIEW,   wx.wxART_TOOLBAR )
local bmp_logs_1_16x16   = wx.wxArtProvider.GetBitmap( wx.wxART_HELP_PAGE,   wx.wxART_TOOLBAR )
local bmp_logs_2_16x16   = wx.wxArtProvider.GetBitmap( wx.wxART_HELP_PAGE,   wx.wxART_TOOLBAR )
local bmp_logs_3_16x16   = wx.wxArtProvider.GetBitmap( wx.wxART_HELP_PAGE,   wx.wxART_TOOLBAR )
local bmp_logs_4_16x16   = wx.wxArtProvider.GetBitmap( wx.wxART_HELP_PAGE,   wx.wxART_TOOLBAR )
local bmp_exit_16x16     = wx.wxArtProvider.GetBitmap( wx.wxART_QUIT,        wx.wxART_TOOLBAR )
local bmp_twodns_16x16   = wx.wxBitmap():ConvertToImage(); bmp_twodns_16x16:LoadFile( file_png_twodns_16 )
local bmp_noip_16x16     = wx.wxBitmap():ConvertToImage(); bmp_noip_16x16:LoadFile( file_png_noip_16 )
local bmp_dyndns_16x16   = wx.wxBitmap():ConvertToImage(); bmp_dyndns_16x16:LoadFile( file_png_dyndns_16 )
local bmp_language_16x16 = wx.wxBitmap():ConvertToImage(); bmp_language_16x16:LoadFile( file_png_language_16 )

local menu_item = function( menu, id, name, status, bmp )
    local mi = wx.wxMenuItem( menu, id, name, status )
    mi:SetBitmap( bmp )
    bmp:delete()
    return mi
end

local log_submenu = wx.wxMenu()
log_submenu:Append( menu_item( log_submenu, ID_mb_log_system, "&" .. lang_tbl.settings_log_menubar_status .. "\tF5", lang_tbl.open .. ":" .. " " .. logfile.system[ 1 ], bmp_logs_1_16x16 ) )
log_submenu:Append( menu_item( log_submenu, ID_mb_log_twodns, "&" .. lang_tbl.twodns_log_menubar_status ..   "\tF6", lang_tbl.open .. ":" .. " " .. logfile.twodns[ 1 ], bmp_logs_2_16x16 ) )
log_submenu:Append( menu_item( log_submenu, ID_mb_log_noip,   "&" .. lang_tbl.noip_log_menubar_status ..     "\tF7", lang_tbl.open .. ":" .. " " .. logfile.noip[ 1 ],   bmp_logs_3_16x16 ) )
log_submenu:Append( menu_item( log_submenu, ID_mb_log_dyndns, "&" .. lang_tbl.dyndns_log_menubar_status ..   "\tF8", lang_tbl.open .. ":" .. " " .. logfile.dyndns[ 1 ], bmp_logs_4_16x16 ) )

local main_menu = wx.wxMenu()
main_menu:Append( menu_item( main_menu, ID_mb_settings, lang_tbl.settings .. "\tAlt-S", lang_tbl.settings_status, bmp_settings_16x16 ) )
main_menu:Append( ID_mb_log, lang_tbl.logs, log_submenu, lang_tbl.logs_status )
main_menu:AppendSeparator()
main_menu:Append( menu_item( main_menu, ID_mb_twodns, dbfile.twodns[ 2 ] .. "\tAlt-T", lang_tbl.twodns_menubar_status, wx.wxBitmap( bmp_twodns_16x16 ) ) )
main_menu:Append( menu_item( main_menu, ID_mb_noip, dbfile.noip[ 2 ] .. "\tAlt-N", lang_tbl.noip_menubar_status, wx.wxBitmap( bmp_noip_16x16 ) ) )
main_menu:Append( menu_item( main_menu, ID_mb_dyndns, dbfile.dyndns[ 2 ] .. "\tAlt-D", lang_tbl.dyndns_menubar_status, wx.wxBitmap( bmp_dyndns_16x16 ) ) )
main_menu:AppendSeparator()
main_menu:Append( menu_item( main_menu, ID_mb_language, lang_tbl.change_language .. "\tAlt-L", lang_tbl.change_language_status, wx.wxBitmap( bmp_language_16x16 ) ) )
main_menu:AppendSeparator()
main_menu:Append( menu_item( main_menu, wx.wxID_EXIT,  lang_tbl.exit .. "\tAlt-X", lang_tbl.exit .. " " .. app_name, bmp_exit_16x16 ) )

local help_menu = wx.wxMenu()
help_menu:Append( menu_item( help_menu, wx.wxID_ABOUT, lang_tbl.about .. "\tF1", lang_tbl.about .. " " .. app_name, bmp_about_16x16 ) )

local menu_bar = wx.wxMenuBar()
menu_bar:Append( main_menu, lang_tbl.menu )
menu_bar:Append( help_menu, lang_tbl.help )


-------------------------------------------------------------------------------------------------------------------------------------
--// ICONS //------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--[[
--// icons for tabs
local tab_1_ico = wx.wxIcon( file_icon_2 .. ";0", wx.wxBITMAP_TYPE_ICO, 16, 16 )
local tab_2_ico = wx.wxIcon( file_icon_2 .. ";1", wx.wxBITMAP_TYPE_ICO, 16, 16 )
local tab_3_ico = wx.wxIcon( file_icon_2 .. ";2", wx.wxBITMAP_TYPE_ICO, 16, 16 )
local tab_4_ico = wx.wxIcon( file_icon_2 .. ";3", wx.wxBITMAP_TYPE_ICO, 16, 16 )
local tab_5_ico = wx.wxIcon( file_icon_2 .. ";4", wx.wxBITMAP_TYPE_ICO, 16, 16 )

local tab_1_bmp = wx.wxBitmap(); tab_1_bmp:CopyFromIcon( tab_1_ico )
local tab_2_bmp = wx.wxBitmap(); tab_2_bmp:CopyFromIcon( tab_2_ico )
local tab_3_bmp = wx.wxBitmap(); tab_3_bmp:CopyFromIcon( tab_3_ico )
local tab_4_bmp = wx.wxBitmap(); tab_4_bmp:CopyFromIcon( tab_4_ico )
local tab_5_bmp = wx.wxBitmap(); tab_5_bmp:CopyFromIcon( tab_5_ico )

local notebook_image_list = wx.wxImageList( 16, 16 )

local tab_1_img = notebook_image_list:Add( wx.wxBitmap( tab_1_bmp ) )
local tab_2_img = notebook_image_list:Add( wx.wxBitmap( tab_2_bmp ) )
local tab_3_img = notebook_image_list:Add( wx.wxBitmap( tab_3_bmp ) )
local tab_4_img = notebook_image_list:Add( wx.wxBitmap( tab_4_bmp ) )
local tab_5_img = notebook_image_list:Add( wx.wxBitmap( tab_5_bmp ) )
]]

-------------------------------------------------------------------------------------------------------------------------------------
--// FRAME & PANEL //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// icons for app titlebar and taskbar
local icons = wx.wxIconBundle()
icons:AddIcon( app_ico_16 )
icons:AddIcon( app_ico_32 )

local frame = wx.wxFrame(
    wx.NULL,
    wx.wxID_ANY,
    app_name .. " " .. app_version,
    wx.wxPoint( 0, 0 ),
    wx.wxSize( app_width, app_height ),
    wx.wxMINIMIZE_BOX + wx.wxSYSTEM_MENU + wx.wxCAPTION + wx.wxCLOSE_BOX + wx.wxCLIP_CHILDREN -- + wx.wxFRAME_TOOL_WINDOW
)
frame:Centre( wx.wxBOTH )
frame:SetMenuBar( menu_bar )
frame:SetIcons( icons )

local status_bar = frame:CreateStatusBar( 1 )
frame:SetStatusText( "Dynosaur - snappy but makes you happy :)", 0 )
local panel = wx.wxPanel( frame, wx.wxID_ANY, wx.wxPoint( 0, 0 ), wx.wxSize( app_width, app_height ) )
panel:SetBackgroundColour( wx.wxColour( 240, 240, 240 ) )


-------------------------------------------------------------------------------------------------------------------------------------
--// MAIN LOOP //--------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

log.write( app_name .. " " .. app_version .. " " .. lang_tbl.txt_ready, logfile.system[ 1 ] )

--// main function
local main = function()
    local taskbar = add_taskbar( frame, checkbox_trayicon )

    frame:Connect( wx.wxID_ANY, wx.wxEVT_DESTROY,
        function( event )

        end
    )
    frame:Connect( wx.wxID_ANY, wx.wxEVT_CLOSE_WINDOW,
        function( event )
            --// send dialog msg
            local di = wx.wxMessageDialog( frame, lang_tbl.really_quit, lang_tbl.info, wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
            local result = di:ShowModal(); di:Destroy()
            if result == wx.wxID_YES then
                if need_save_system then
                    --// send dialog msg
                    local di = wx.wxMessageDialog( frame, lang_tbl.save_changes, lang_tbl.info, wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                    local result = di:ShowModal(); di:Destroy()
                    if result == wx.wxID_YES then
                        save_if_needed()
                    else
                        --undo_changes()
                    end
                end
                frame:Destroy()
                if taskbar then taskbar:delete() end
            end
        end
    )
    --// menu bar events
    frame:Connect( wx.wxID_EXIT, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            frame:Close( true )
        end
    )
    frame:Connect( wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_about_window( frame )
        end
    )
    frame:Connect( ID_mb_log_system, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.system[ 1 ], lang_tbl.settings_log_menubar_status )
        end
    )
    frame:Connect( ID_mb_log_twodns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.twodns[ 1 ], lang_tbl.twodns_log_menubar_status )
        end
    )
    frame:Connect( ID_mb_log_noip, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.noip[ 1 ], lang_tbl.noip_log_menubar_status )
        end
    )
    frame:Connect( ID_mb_log_dyndns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.dyndns[ 1 ], lang_tbl.dyndns_log_menubar_status )
        end
    )
    frame:Connect( ID_mb_settings, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_settings_window( frame )
        end
    )
    frame:Connect( ID_mb_twodns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            wx.wxBeginBusyCursor()
            show_twodns_window( frame )
        end
    )
    frame:Connect( ID_mb_noip, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            wx.wxBeginBusyCursor()
            show_noip_window( frame )
        end
    )
    frame:Connect( ID_mb_dyndns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            wx.wxBeginBusyCursor()
            show_dyndns_window( frame )
        end
    )
    frame:Connect( ID_mb_language, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_lang_dialog( system_tbl, false )
        end
    )

    --frame:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_NOTEBOOK_PAGE_CHANGED, HandleEvents )
    frame:Show( true )
end

main()
wx.wxGetApp():MainLoop()
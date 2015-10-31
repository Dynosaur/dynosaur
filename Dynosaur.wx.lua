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
local encrypted_string = encrypt( b32_chiffre, string )
local decrypted_string = decrypt( b32_chiffre, encrypted_string )

local domain_tbl, statuscode = twodns.domains( https )
]]


-------------------------------------------------------------------------------------------------------------------------------------
--// BASIC CONST //------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local app_name             = "Dynosaur"
local app_version          = "v0.07"
local app_copyright        = "Copyright © by pulsar"
local app_license          = "License: GPLv3"

local app_width            = 400
local app_height           = 550

--local notebook_width       = 795
--local notebook_height      = 289

local file_appicons        = CLIB_PATH .. "appicons.dll"
local file_png_applogo     = RES_PATH ..  "applogo_96x96.png"
local file_png_gpl         = RES_PATH ..  "GPLv3_160x80.png"
local file_png_twodns_16   = RES_PATH ..  "twodns_16x16.png"
local file_png_noip_16     = RES_PATH ..  "noip_16x16.png"
local file_png_dyndns_16   = RES_PATH ..  "dyndns_16x16.png"


local dbfile = {

    [ "system" ]           = { CFG_PATH .. "system.tbl",   "Settings", "Application Settings", "system" },
    [ "twodns" ]           = { CFG_PATH .. "twodns.tbl",   "TwoDNS",   "TwoDNS Service Settings", "twodns" },
    [ "noip" ]             = { CFG_PATH .. "noip.tbl",     "NO-IP",    "NO-IP Service Settings", "noip" },
    [ "dyndns" ]           = { CFG_PATH .. "dyndns.tbl",   "DynDNS",   "DynDNS Service Settings", "dyndns" },
}

local logfile = {

    [ "system" ]           = { LOG_PATH .. "system.log", "System Log" },
    [ "twodns" ]           = { LOG_PATH .. "twodns.log", "TwoDNS Log" },
    [ "noip" ]             = { LOG_PATH .. "noip.log",   "NO-IP Log" },
    [ "dyndns" ]           = { LOG_PATH .. "dyndns.log", "DynDNS Log" },
}

-------------------------------------------------------------------------------------------------------------------------------------
--// CACHING TABLE LOOKUPS //--------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local encrypt = aeslua.encrypt
local decrypt = aeslua.decrypt
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
local system_tbl, twodns_tbl, noip_tbl, dyndns_tbl


-------------------------------------------------------------------------------------------------------------------------------------
--// IDS //--------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local id_counter = wx.wxID_HIGHEST + 1
local new_id = function()
    id_counter = id_counter + 1
    return id_counter
end

ID_open_settings        = new_id()

ID_open_log             = new_id()
ID_open_log_system      = new_id()
ID_open_log_twodns      = new_id()
ID_open_log_noip        = new_id()
ID_open_log_dyndns      = new_id()

ID_twodns               = new_id()
ID_twodns_hostname_add  = new_id()
ID_twodns_domain_add    = new_id()
ID_twodns_token_add     = new_id()
ID_twodns_email_add     = new_id()

ID_noip                 = new_id()

ID_dyndns               = new_id()


-------------------------------------------------------------------------------------------------------------------------------------
--// EVENT HANDLER //----------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

local HandleEvents = function( event )
    local name = event:GetEventObject():DynamicCast( "wxWindow" ):GetName()
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

local menu_item = function( menu, id, name, status, bmp )
    local mi = wx.wxMenuItem( menu, id, name, status )
    mi:SetBitmap( bmp )
    bmp:delete()
    return mi
end

local log_submenu = wx.wxMenu()
log_submenu:Append( menu_item( log_submenu, ID_open_log_system, "&" .. logfile.system[ 2 ] .. "\tF5", "Open: " .. logfile.system[ 1 ], bmp_logs_1_16x16 ) )
log_submenu:Append( menu_item( log_submenu, ID_open_log_twodns, "&" .. logfile.twodns[ 2 ] .. "\tF6", "Open: " .. logfile.twodns[ 1 ], bmp_logs_2_16x16 ) )
log_submenu:Append( menu_item( log_submenu, ID_open_log_noip,   "&" .. logfile.noip[ 2 ] ..   "\tF7", "Open: " .. logfile.noip[ 1 ],   bmp_logs_3_16x16 ) )
log_submenu:Append( menu_item( log_submenu, ID_open_log_dyndns, "&" .. logfile.dyndns[ 2 ] .. "\tF8", "Open: " .. logfile.dyndns[ 1 ], bmp_logs_4_16x16 ) )

local main_menu = wx.wxMenu()
main_menu:Append( menu_item( main_menu, ID_open_settings, dbfile.system[ 2 ] .. "\tAlt-S", dbfile.system[ 3 ], bmp_settings_16x16 ) )
main_menu:Append( ID_open_log, "Logs", log_submenu, "Log files" )
main_menu:AppendSeparator()
main_menu:Append( menu_item( main_menu, ID_twodns, dbfile.twodns[ 2 ] .. "\tAlt-T", dbfile.twodns[ 3 ], wx.wxBitmap( bmp_twodns_16x16 ) ) )
main_menu:Append( menu_item( main_menu, ID_noip, dbfile.noip[ 2 ] ..     "\tAlt-N", dbfile.noip[ 3 ], wx.wxBitmap( bmp_noip_16x16 ) ) )
main_menu:Append( menu_item( main_menu, ID_dyndns, dbfile.dyndns[ 2 ] .. "\tAlt-D", dbfile.dyndns[ 3 ], wx.wxBitmap( bmp_dyndns_16x16 ) ) )
main_menu:AppendSeparator()
main_menu:Append( menu_item( main_menu, wx.wxID_EXIT,  "Exit\tAlt-X", "Exit " .. app_name, bmp_exit_16x16 ) )

local help_menu = wx.wxMenu()
help_menu:Append( menu_item( help_menu, wx.wxID_ABOUT, "About\tF1", "About " .. app_name, bmp_about_16x16 ) )

local menu_bar = wx.wxMenuBar()
menu_bar:Append( main_menu, "Menu" )
menu_bar:Append( help_menu, "Help" )


-------------------------------------------------------------------------------------------------------------------------------------
--// DIFFERENT FUNCS //--------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

--// encrypt string
local b32_chiffre = "JN74TC2JULT5DYXH2ETPRKV3RUGX7GOVR3JZGLDIBM4I6BHXV3EQ"

--// enrypt a string --> aeslua-0.2.1 (LGPLv2.1 license)
local encryptstring = function( pass, msg )
    if ( not pass ) or ( not type( pass ) == "string" ) and ( not msg ) or ( not type( msg ) == "string" ) then
        return nil
    end
    local cipher = aeslua_encrypt( pass, msg )
    return cipher
end

--// decrypt a string --> aeslua-0.2.1 (LGPLv2.1 license)
local decryptstring = function( pass, cipher )
    if ( not pass ) or ( not type( pass ) == "string" ) and ( not cipher ) or ( not type( cipher ) == "string" ) then
        return nil
    end
    local plain = aeslua_decrypt( pass, cipher )
    return plain
end

--// create empty logfiles on start (if not exists)
local make_logs = function()
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
make_logs()

--// create empty databases on start (if not exists)
local make_dbs = function()
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
make_dbs()

--// cache database tables
local cache_tables = function()
    system_tbl = util_loadtable( dbfile.system[ 1 ] )
    twodns_tbl = util_loadtable( dbfile.twodns[ 1 ] )
    noip_tbl   = util_loadtable( dbfile.noip[ 1 ] )
    dyndns_tbl = util_loadtable( dbfile.dyndns[ 1 ] )
end
cache_tables()

--// log read/write/clear
local log = {}
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
log.write = function( txt, file )
    local timestamp = "[" .. os.date( "%Y-%m-%d/%H:%M:%S" ) .. "] "
    local f = io.open( file, "a+" )
    f:write( timestamp .. txt .. "\n" )
    f:close()
end
log.clear = function( file )
    local f = io.open( file, "w" )
    f:close()
end

--// get value from settings table
local get_tbl_system_value = function( key )
    if key then
        if type( key ) == "string" then
            if type( system_tbl[ key ] ) ~= "nil" then
                return system_tbl[ key ]
            else
                log.write( "Error: get_tbl_system_value() function: entry not found", file_system_log )
            end
        else
            log.write( "Error: get_tbl_system_value() function: string expected, got " .. type( key ), file_system_log )
        end
    else
        log.write( "Error: get_tbl_system_value() function: string expected, got nil", file_system_log )
    end
end

--// set value to settings table
local set_tbl_system_value = function( key, value )
    if key and ( value ~= nil ) then
        if type( key ) ~= "string" then
            log.write( "Error: set_tbl_system_value() function: string expected for param #1, got " .. type( key ), file_system_log )
        end
        if key == "" then
            log.write( "Error: set_tbl_system_value() function: string expected for param #1, got nil", file_system_log )
        end
        if value == "" then
            log.write( "Error: set_tbl_system_value() function: string expected for param #2, got nil", file_system_log )
        end
        if type( system_tbl[ key ] ) == "nil" then
            log.write( "Error: set_tbl_system_value() function: entry not found", file_system_log )
        else
            system_tbl[ key ] = value
            need_save_system = true
        end
    else
        log.write( "Error: set_tbl_system_value() function: missing param", file_system_log )
    end
end

--// save settings if needed
local save_if_needed = function()
    if need_save_system then
        util_savetable( system_tbl, dbfile.system[ 4 ], dbfile.system[ 1 ] )
        log.write( "Settings: saved.", logfile.system[ 1 ] )
        need_save_system = false
    end
    if need_save_twodns then
        util_savetable( twodns_tbl, dbfile.twodns[ 4 ], dbfile.twodns[ 1 ] )
        log.write( "TwoDNS Settings: saved.", logfile.twodns[ 1 ] )
        need_save_twodns = false
    end
    if need_save_noip then
        util_savetable( noip_tbl, dbfile.noip[ 4 ], dbfile.noip[ 1 ] )
        log.write( "NO-IP Settings: saved.", logfile.noip[ 1 ] )
        need_save_noip = false
    end
    if need_save_dyndns then
        util_savetable( dyndns_tbl, dbfile.dyndns[ 4 ], dbfile.dyndns[ 1 ] )
        log.write( "DynDNS Settings: saved.", logfile.dyndns[ 1 ] )
        need_save_dyndns = false
    end
end

--// about window
local show_about_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        "About Dynosaur",
        wx.wxDefaultPosition,
        wx.wxSize( 320, 495 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 320, 270 ) )
    di:SetMaxSize( wx.wxSize( 320, 270 ) )
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
        "Licensed under:",
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
        wx.wxSize( 275, 120 ),
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_RICH + wx.wxSUNKEN_BORDER + wx.wxHSCROLL + wx.wxTE_CENTRE
    )
    --control:SetBackgroundColour( wx.wxColour( 225, 225, 225 ) )
    control:SetBackgroundColour( wx.wxColour( 245, 245, 245 ) )
    control:SetForegroundColour( wx.wxBLACK )
    control:Centre( wx.wxHORIZONTAL )
    --// button
    local button_ok = wx.wxButton( di, wx.wxID_ANY, "CLOSE", wx.wxPoint( 0, 439 ), wx.wxSize( 70, 20 ) )
    button_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    button_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            di:Destroy()
        end
    )
    button_ok:Centre( wx.wxHORIZONTAL )

    local result = di:ShowModal()
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
    di:SetMinSize( wx.wxSize( 320, 270 ) )
    di:SetMaxSize( wx.wxSize( 320, 270 ) )
    --// log
    local log_text = wx.wxTextCtrl(
        di,
        wx.wxID_ANY,
        "SETTINGS",
        wx.wxPoint( 0, 5 ),
        wx.wxSize( 680, 450 ),
        wx.wxTE_READONLY + wx.wxTE_MULTILINE + wx.wxTE_RICH + wx.wxSUNKEN_BORDER + wx.wxHSCROLL
    )
    log_text:SetBackgroundColour( wx.wxColour( 0, 0, 0 ) )
    log_text:SetFont( log_font )
    log_text:SetDefaultStyle( wx.wxTextAttr( wx.wxWHITE ) )
    log_text:Centre( wx.wxHORIZONTAL )
    --// button close
    local button_ok = wx.wxButton( di, wx.wxID_ANY, "CLOSE", wx.wxPoint( 0, 460 ), wx.wxSize( 70, 20 ) )
    button_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    button_ok:Centre( wx.wxHORIZONTAL )
    button_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            di:Destroy()
        end
    )
    --// button clear log
    local button_clear = wx.wxButton( di, wx.wxID_ANY, "CLEAR", wx.wxPoint( 615, 460 ), wx.wxSize( 70, 20 ) )
    button_clear:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    button_clear:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            log.clear( file )
            log_text:Clear()
            button_clear:Disable()
            log.write( "Cleared logfile: " .. logfile.system[ 1 ], logfile.system[ 1 ] )
        end
    )
    --// read log file an add text
    log.read( file, log_text )

    local result = di:ShowModal()
end

--// add taskbar (system tray)
local add_taskbar = function( frame, checkbox_trayicon )
    local showtray = false
    if system_tbl[ "trayicon" ] then
        showtray = true
    end
    --if checkbox_trayicon:IsChecked() then
    if showtray then
        taskbar = wx.wxTaskBarIcon()
        taskbar:SetIcon( app_ico_16, app_name .. " " .. _VERSION )
        --// taskbar menu
        local menu = wx.wxMenu()
        menu:Append( wx.wxID_ABOUT, "About\tF1",   "About " .. app_name )
        menu:AppendSeparator()
        menu:Append( wx.wxID_EXIT,  "Exit\tAlt-X", "Exit " .. app_name )
        --// taskbar menu events
        menu:Connect( ID_open_settings, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                show_settings_window( frame )
            end
        )
        menu:Connect( ID_twodns, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                wx.wxBeginBusyCursor()
                show_twodns_window( frame )
            end
        )
        menu:Connect( ID_noip, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                wx.wxBeginBusyCursor()
                show_noip_window( frame )
            end
        )
        menu:Connect( ID_dyndns, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                wx.wxBeginBusyCursor()
                show_dyndns_window( frame )
            end
        )
        menu:Connect( wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                show_about_window( frame )
            end
        )
        menu:Connect( wx.wxID_EXIT, wx.wxEVT_COMMAND_MENU_SELECTED,
            function( event )
                --// send dialog msg
                local di = wx.wxMessageDialog( frame, "Really quit?", "INFO", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                local result = di:ShowModal()
                di:Destroy()
                if result == wx.wxID_YES then
                    if ( need_save_system or need_save_twodns or need_save_noip or need_save_dyndns ) then
                        --// send dialog msg
                        local di = wx.wxMessageDialog( frame, "Save changes?", "INFO", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
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
            end
        )
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
            end
        )
        frame:Connect( wx.wxEVT_ICONIZE,
            function( event )
                local show = not frame:IsIconized()
                frame:Show( show )
                if show then
                    frame:Raise( true )
                end
            end
        )
        frame:Connect( wx.wxEVT_CLOSE_WINDOW,
            function( event )
                frame:Iconize( true )
                return false
            end
        )
        frame:Connect( wx.wxEVT_DESTROY,
            function( event )

            end
        )
    else
        if taskbar then
            frame:Connect( wx.wxEVT_ICONIZE,
                function( event )
                    local show = not frame:IsIconized()
                    frame:Show( true )
                    if show then
                        frame:Raise( true )
                    end
                end
            )
            frame:Connect( wx.wxEVT_CLOSE_WINDOW,
                function( event )
                    --// send dialog msg
                    local di = wx.wxMessageDialog( frame, "Really quit?", "INFO", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                    local result = di:ShowModal()
                    di:Destroy()
                    if result == wx.wxID_YES then
                        if ( need_save_system or need_save_twodns or need_save_noip or need_save_dyndns ) then
                            --// send dialog msg
                            local di = wx.wxMessageDialog( frame, "Save changes?", "INFO", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
                            local result = di:ShowModal()
                            di:Destroy()
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
                end
            )
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
        dbfile.system[ 3 ],
        wx.wxDefaultPosition,
        wx.wxSize( 320, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 320, 400 ) )
    di:SetMaxSize( wx.wxSize( 320, 400 ) )

    --// basic settings
    control = wx.wxStaticBox( di, wx.wxID_ANY, "Basic Settings", wx.wxPoint( 10, 10 ), wx.wxSize( 295, 100 ) )

    --// minimize to tray
    local checkbox_trayicon = wx.wxCheckBox( di, wx.wxID_ANY, "Minimize to tray", wx.wxPoint( 25, 35 ), wx.wxDefaultSize )
    checkbox_trayicon:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_CHECKBOX_CLICKED,
        function( event )
            local trayicon = checkbox_trayicon:GetValue()
            system_tbl[ "trayicon" ] = trayicon
            add_taskbar( frame, checkbox_trayicon )
            need_save_system = true
        end
    )
    if system_tbl[ "trayicon" ] == true then
        checkbox_trayicon:SetValue( true )
    else
        checkbox_trayicon:SetValue( false )
    end

    --// horizontal line
    --control = wx.wxStaticLine( di, wx.wxID_ANY, wx.wxPoint( 0, 140 ), wx.wxSize( 275, 1 ) )
    --control:Centre( wx.wxHORIZONTAL )

    --// button
    local button_ok = wx.wxButton( di, wx.wxID_ANY, "CLOSE", wx.wxPoint( 0, 343 ), wx.wxSize( 70, 20 ) )
    button_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    button_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            save_if_needed()
            di:Destroy()
        end
    )
    button_ok:Centre( wx.wxHORIZONTAL )

    local result = di:ShowModal()
end

--// twodns window
local show_twodns_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        dbfile.twodns[ 3 ],
        wx.wxDefaultPosition,
        wx.wxSize( 420, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 420, 400 ) )
    di:SetMaxSize( wx.wxSize( 420, 400 ) )

    --// statusbar for dialog
    local sb = wx.wxStatusBar( di, wx.wxID_ANY )
    sb:SetStatusText( "", 0 )

    --// add existing account
    control = wx.wxStaticBox( di, wx.wxID_ANY, "ADD AN EXISTING ACCOUNT", wx.wxPoint( 10, 10 ), wx.wxSize( 394, 210 ) )

    --// get all available domains
    local domain_tbl, statuscode = twodns.domains( https )

    --// hostname caption
    control = wx.wxStaticText( di, wx.wxID_ANY, "Hostname:", wx.wxPoint( 20, 32 ) )

    --// hostname
    local twodns_domainname_add = wx.wxTextCtrl( di, ID_twodns_hostname_add, "", wx.wxPoint( 20, 51 ), wx.wxSize( 205, 20 ),  wx.wxSUNKEN_BORDER )
    twodns_domainname_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_domainname_add:SetMaxLength( 40 )
    twodns_domainname_add:SetValue( "<HOSTNAME>" )
    twodns_domainname_add:Connect( ID_twodns_hostname_add, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Enter your Hostname here.", 0 ) end )
    twodns_domainname_add:Connect( ID_twodns_hostname_add, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// separator dot
    control = wx.wxStaticText( di, wx.wxID_ANY, ".", wx.wxPoint( 231, 55 ) )

    --// domain caption
    control = wx.wxStaticText( di, wx.wxID_ANY, "Domain:", wx.wxPoint( 240, 32 ) )

    --// domain choice
    local twodns_domain_choice = wx.wxChoice(
        di,
        ID_twodns_domain_add,
        wx.wxPoint( 240, 50 ),
        wx.wxSize( 153, 20 ),
        domain_tbl
    )
    twodns_domain_choice:Select( 0 )
    twodns_domain_choice:Connect( ID_twodns_domain_add, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Choose your Domain here.", 0 ) end )
    twodns_domain_choice:Connect( ID_twodns_domain_add, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    --if default_cfg_tbl.key_level == 0 then domain_choice:Select( 0 ) end
    --local key_level = domain_choice:GetCurrentSelection()

    --// API-Token caption
    control = wx.wxStaticText( di, wx.wxID_ANY, "API-Token:", wx.wxPoint( 20, 82 ) )

    --// API-Token
    local twodns_token_add = wx.wxTextCtrl( di, ID_twodns_token_add, "", wx.wxPoint( 20, 101 ), wx.wxSize( 373, 20 ),  wx.wxSUNKEN_BORDER )
    twodns_token_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_token_add:SetMaxLength( 40 )
    twodns_token_add:SetValue( "<API-TOKEN>" )
    twodns_token_add:Connect( ID_twodns_token_add, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Enter your API-Token here.", 0 ) end )
    twodns_token_add:Connect( ID_twodns_token_add, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// E-Mail caption
    control = wx.wxStaticText( di, wx.wxID_ANY, "E-Mail:", wx.wxPoint( 20, 132 ) )

    --// E-Mail
    local twodns_email_add = wx.wxTextCtrl( di, ID_twodns_email_add, "", wx.wxPoint( 20, 151 ), wx.wxSize( 373, 20 ),  wx.wxSUNKEN_BORDER )
    twodns_email_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_email_add:SetMaxLength( 40 )
    twodns_email_add:SetValue( "<E-MAIL>" )
    twodns_email_add:Connect( ID_twodns_email_add, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Enter your E-Mail Address here.", 0 ) end )
    twodns_email_add:Connect( ID_twodns_email_add, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )

    --// button add
    local twodns_button_add = wx.wxButton( di, wx.wxID_ANY, "ADD", wx.wxPoint( 212, 188 ), wx.wxSize( 70, 20 ) )
    twodns_button_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_button_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Add this Account to the Database.", 0 ) end )
    twodns_button_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    twodns_button_add:Disable()
    twodns_button_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )

        end
    )

    --// button verify
    local twodns_button_verify_add = wx.wxButton( di, wx.wxID_ANY, "VERIFY", wx.wxPoint( 132, 188 ), wx.wxSize( 70, 20 ) )
    twodns_button_verify_add:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_button_verify_add:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Verify this Account.", 0 ) end )
    twodns_button_verify_add:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    twodns_button_verify_add:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            wx.wxBeginBusyCursor()

            -- check something

            wx.wxEndBusyCursor()
            twodns_button_add:Enable( true )
        end
    )

    --// button close
    local twodns_button_close = wx.wxButton( di, wx.wxID_ANY, "CLOSE", wx.wxPoint( 0, 320 ), wx.wxSize( 70, 20 ) )
    twodns_button_close:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    twodns_button_close:Connect( wx.wxID_ANY, wx.wxEVT_ENTER_WINDOW, function( event ) sb:SetStatusText( "Close " .. dbfile.twodns[ 3 ] .. ".", 0 ) end )
    twodns_button_close:Connect( wx.wxID_ANY, wx.wxEVT_LEAVE_WINDOW, function( event ) sb:SetStatusText( "", 0 ) end )
    twodns_button_close:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            save_if_needed()
            di:Destroy()
        end
    )
    twodns_button_close:Centre( wx.wxHORIZONTAL )

    local result = di:ShowModal()
    wx.wxEndBusyCursor()
end

--// noip window
local show_noip_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        dbfile.noip[ 3 ],
        wx.wxDefaultPosition,
        wx.wxSize( 320, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 320, 400 ) )
    di:SetMaxSize( wx.wxSize( 320, 400 ) )

    --// basic settings
    control = wx.wxStaticBox( di, wx.wxID_ANY, "Basic Settings", wx.wxPoint( 10, 10 ), wx.wxSize( 295, 100 ) )


    --// button
    local button_ok = wx.wxButton( di, wx.wxID_ANY, "CLOSE", wx.wxPoint( 0, 343 ), wx.wxSize( 70, 20 ) )
    button_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    button_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            save_if_needed()
            di:Destroy()
        end
    )
    button_ok:Centre( wx.wxHORIZONTAL )

    local result = di:ShowModal()
    wx.wxEndBusyCursor()
end

--// dyndns window
local show_dyndns_window = function( frame )
    --// dialog window
    local di = wx.wxDialog(
        frame,
        wx.wxID_ANY,
        dbfile.dyndns[ 3 ],
        wx.wxDefaultPosition,
        wx.wxSize( 320, 400 ),
        --wx.wxSTAY_ON_TOP + wx.wxRESIZE_BORDER
        wx.wxSTAY_ON_TOP + wx.wxDEFAULT_DIALOG_STYLE - wx.wxCLOSE_BOX - wx.wxMAXIMIZE_BOX - wx.wxMINIMIZE_BOX
    )
    di:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    di:SetMinSize( wx.wxSize( 320, 400 ) )
    di:SetMaxSize( wx.wxSize( 320, 400 ) )

    --// basic settings
    control = wx.wxStaticBox( di, wx.wxID_ANY, "Basic Settings", wx.wxPoint( 10, 10 ), wx.wxSize( 295, 100 ) )


    --// button
    local button_ok = wx.wxButton( di, wx.wxID_ANY, "CLOSE", wx.wxPoint( 0, 343 ), wx.wxSize( 70, 20 ) )
    button_ok:SetBackgroundColour( wx.wxColour( 255, 255, 255 ) )
    button_ok:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_BUTTON_CLICKED,
        function( event )
            save_if_needed()
            di:Destroy()
        end
    )
    button_ok:Centre( wx.wxHORIZONTAL )

    local result = di:ShowModal()
    wx.wxEndBusyCursor()
end

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

local panel = wx.wxPanel( frame, wx.wxID_ANY, wx.wxPoint( 0, 0 ), wx.wxSize( app_width, app_height ) )
panel:SetBackgroundColour( wx.wxColour( 240, 240, 240 ) )


-------------------------------------------------------------------------------------------------------------------------------------
--// IMAGE TEST //-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------
--[[
print( "\n[ico_64]" )
if ico_64:Ok() then
    bmp_64 = wx.wxBitmap()
    bmp_64:CopyFromIcon( ico_64 )
    if bmp_64:Ok() then
        X, Y = bmp_64:GetWidth(), bmp_64:GetHeight()
        print( "Width:  " .. X )
        print( "Height: " .. Y )
        control = wx.wxStaticBitmap( panel, wx.wxID_ANY, wx.wxBitmap( bmp_64 ), wx.wxPoint( 0, 50 ), wx.wxSize( X, Y ) )
        control:Centre( wx.wxHORIZONTAL )
    else
        print( "bmp_64:Ok() -> false" )
    end
else
    print( "ico_64:Ok() -> false" )
end
]]


--[[
ico_64 = wx.wxIcon( file_icons_2 .. ";0", wx.wxBITMAP_TYPE_ICO, 64, 64 )

bmp_64 = wx.wxBitmap()--:ConvertToImage()
bmp_64:CopyFromIcon( ico_64 )
--bmp_64:ConvertToImage()
X, Y = bmp_64:GetWidth(), bmp_64:GetHeight()
control = wx.wxStaticBitmap( panel, wx.wxID_ANY, wx.wxBitmap( bmp_64 ), wx.wxPoint( 0, 50 ), wx.wxSize( X, Y ) )
--bmp_64:Destroy()
]]



-- wxBITMAP_TYPE_ICO_RESOURCE

--[[ small bg test
local file_img_bg      = "bg.png"
local gui_bg = wx.wxBitmap():ConvertToImage()
gui_bg:LoadFile( file_img_bg )
local X, Y = gui_bg:GetWidth(), gui_bg:GetHeight()
control = wx.wxStaticBitmap( panel, wx.wxID_ANY, wx.wxBitmap( gui_bg ), wx.wxPoint( 0, 0 ), wx.wxSize( X, Y ) )
gui_bg:Destroy()
]]


-------------------------------------------------------------------------------------------------------------------------------------
--// MAIN LOOP //--------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------

log.write( app_name .. " " .. app_version .. " ready.", logfile.system[ 1 ] )

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
            local di = wx.wxMessageDialog( frame, "Really quit?", "INFO", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
            local result = di:ShowModal()
            di:Destroy()
            if result == wx.wxID_YES then
                if need_save_system then
                    --// send dialog msg
                    local di = wx.wxMessageDialog( frame, "Save changes?", "INFO", wx.wxYES_NO + wx.wxICON_QUESTION + wx.wxCENTRE )
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
    frame:Connect( ID_open_log_system, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.system[ 1 ], logfile.system[ 2 ] )
        end
    )
    frame:Connect( ID_open_log_twodns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.twodns[ 1 ], logfile.twodns[ 2 ] )
        end
    )
    frame:Connect( ID_open_log_noip, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.noip[ 1 ], logfile.noip[ 2 ] )
        end
    )
    frame:Connect( ID_open_log_dyndns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_log_window( frame, logfile.dyndns[ 1 ], logfile.dyndns[ 2 ] )
        end
    )
    frame:Connect( ID_open_settings, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            show_settings_window( frame )
        end
    )
    frame:Connect( ID_twodns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            wx.wxBeginBusyCursor()
            show_twodns_window( frame )
        end
    )
    frame:Connect( ID_noip, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            wx.wxBeginBusyCursor()
            show_noip_window( frame )
        end
    )
    frame:Connect( ID_dyndns, wx.wxEVT_COMMAND_MENU_SELECTED,
        function( event )
            wx.wxBeginBusyCursor()
            show_dyndns_window( frame )
        end
    )

    --frame:Connect( wx.wxID_ANY, wx.wxEVT_COMMAND_NOTEBOOK_PAGE_CHANGED, HandleEvents )
    frame:Show( true )
end

main()
wx.wxGetApp():MainLoop()
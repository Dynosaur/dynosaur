--[[

    util.lua written by blastbeat and pulsar

    based on "luadch/core/util.lua"


    Description:

    table = util.loadtable( path )  -- loads a local table from file

    util.savearray( array, path )  -- saves an array to a local file

    util.savetable( tbl, name, path )  -- saves a table to a local file

    number, number, number, number = util.formatseconds( t )  -- converts time to: days, hours, minutes, seconds (for example: d, h, m, s = util.formatseconds( os.difftime( os.time( ), signal.get( "start" ) ) ) )

    string/nil = util.formatbytes( bytes )  -- returns converted bytes as a sting e.g. "209.81 GB"

    number = util.generatepass( len )  -- returns a random generated alphanumerical password with length = len; if no param is specified then len = 20

    number = util.date( )  -- returns current date in new luadch date style: yyyymmddhhmmss

    number, number, number, number, number/nil, err = util.difftime( t1, t2 )  -- returns difftime between two luadch date style values (new luadch date style) (for example : y, d, h, m, s = util.difftime( util.date(), 20140617031630 ) )

    number/nil, err = util.convertepochdate( t )  -- convert os.time() "epoch" date to luadch date style: yyyymmddhhmmss (as number)

]]


----------------------------
--[DEFINITION/DECLARATION]--
----------------------------

--// functions
local sortserialize
local savearray
local savetable
local loadtable
local formatseconds
local formatbytes
local generatepass
local date
local difftime
local convertepochdate
local trimstring

--// table lookups
local os_time = os.time
local os_date = os.date
local os_difftime = os.difftime
local math_floor = math.floor
local math_random = math.random
local math_randomseed = math.randomseed
local string_format = string.format


----------
--[CODE]--
----------

sortserialize = function( tbl, name, file, tab, r )
    tab = tab or ""
    local temp = { }
    for key, k in pairs( tbl ) do
        --if type( key ) == "string" or "number" then
            table.insert( temp, key )
        --end
    end
    table.sort( temp )
    local str = tab .. name
    if r then
        file:write( str .. " {\n\n" )
    else
        file:write( str .. " = {\n\n" )
    end
    for k, key in ipairs( temp ) do
        if ( type( tbl[ key ] ) ~= "function" ) then
            local skey = ( type( key ) == "string" ) and string.format( "[ %q ]", key ) or string.format( "[ %d ]", key )
            if type( tbl[ key ] ) == "table" then
                sortserialize( tbl[ key ], skey, file, tab .. "    " )
                file:write( ",\n" )
            else
                local svalue = ( type( tbl[ key ] ) == "string" ) and string.format( "%q", tbl[ key ] ) or tostring( tbl[ key ] )
                file:write( tab .. "    " .. skey .. " = " .. svalue )
                file:write( ",\n" )
            end
        end
    end
    file:write( "\n" )
    file:write( tab .. "}" )
end

savetable = function( tbl, name, path )
    local file, err = io.open( path, "w+" )
    if file then
        file:write( "local " .. name .. "\n\n" )
        sortserialize( tbl, name, file, "" )
        file:write( "\n\nreturn " .. name )
        file:close( )
        return true
    else
        return false, err
    end
end

loadtable = function( path )
    local file, err = io.open( path, "r" )
    if not file then
        return nil, err
    end
    local content = file:read "*a"
    file:close( )
    local chunk, err = loadstring( content )
    if chunk then
        local ret = chunk( )
        if ret and type( ret ) == "table" then
            return ret
        else
            return nil, "invalid table"
        end
    end
    return nil, err
end

savearray = function( array, path )
    array = array or { }
    local file, err = io.open( path, "w+" )
    if not file then
        return false, err
    end
    local iterate, savetbl
    iterate = function( tbl )
        local tmp = { }
        for key, value in pairs( tbl ) do
            tmp[ #tmp + 1 ] = tostring( key )
        end
        table.sort( tmp )
        for i, key in ipairs( tmp ) do
            key = tonumber( key ) or key
            if type( tbl[ key ] ) == "table" then
                file:write( ( ( type( key ) ~= "number" ) and tostring( key ) .. " = " ) or " " )
                savetbl( tbl[ key ] )
            else
                file:write( ( ( type( key ) ~= "number" and tostring( key ) .. " = " ) or "" ) .. ( ( type( tbl[ key ] ) == "string" ) and string.format( "%q", tbl[ key ] ) or tostring( tbl[ key ] ) ) .. ", " )
            end
        end
    end
    savetbl = function( tbl )
        local tmp = { }
        for key, value in pairs( tbl ) do
            tmp[ #tmp + 1 ] = tostring( key )
        end
        table.sort( tmp )
        file:write( "{ " )
        iterate( tbl )
        file:write( "}, " )
    end
    file:write( "return {\n\n" )
    for i, tbl in ipairs( array ) do
        if type( tbl ) == "table" then
            file:write( "    { " )
            iterate( tbl )
            file:write( "},\n" )
        else
            file:write( "    " .. string.format( "%q", tostring( tbl ) ) .. ",\n" )
        end
    end
    file:write( "\n}" )
    file:close( )
    return true
end

formatseconds = function( t )
    return
        math_floor( t / ( 60 * 60 * 24 ) ),
        math_floor( t / ( 60 * 60 ) ) % 24,
        math_floor( t / 60 ) % 60,
        t % 60
end

--// convert bytes to the right unit  / based on a function by Night
formatbytes = function( bytes )
    local bytes = tonumber( bytes )
    if ( not bytes ) or ( not type( bytes ) == "number" ) or ( bytes < 0 ) or ( bytes == 1 / 0 ) then
        --return nil, "util.lua: error in formatbytes(), parameter not valid"
        return nil
    end
    if bytes == 0 then return "0 B" end
    local i, units = 1, { "B", "KB", "MB", "GB", "TB", "PB", "EB", "YB" }
    while bytes >= 1024 do
        bytes = bytes / 1024
        i = i + 1
    end
    if units[ i ] == "B" then
        return string_format( "%.0f", bytes ) .. " " .. ( units[ i ] or "?" )
    else
        return string_format( "%.2f", bytes ) .. " " .. ( units[ i ] or "?" )
    end
end

generatepass = function( len )
    local len = tonumber( len )
    if not ( type( len ) == "number" ) or ( len < 0 ) or ( len > 1000 ) then len = 20 end
    local lower = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
                    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" }
    local upper = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }
    math_randomseed( os_time() )
    local pwd = ""
    for i = 1, len do
        local X = math_random( 0, 9 )
        if X < 4 then
            pwd = pwd .. math_random( 0, 9 )
        elseif ( X >= 4 ) and ( X < 6 ) then
            pwd = pwd .. upper[ math_random( 1, 25 ) ]
        else
            pwd = pwd .. lower[ math_random( 1, 25 ) ]
        end
    end
    return pwd
end

--// returns current date in new luadch date style: yyyymmddhhmmss (as number)
date = function()
    local year = os_date( "%Y" )
    local month = os_date( "%m" )
    local day = os_date( "%d" )
    local hour = os_date( "%H" )
    local minutes = os_date( "%M" )
    local seconds = os_date( "%S" )
    return tonumber( year .. month .. day .. hour .. minutes .. seconds )
end

--// returns difftime between two date values (new luadch date style)
difftime = function( t1, t2 )
    local err
    if not t1 then
        err = "util.lua: error in param #1: got nil"
        return nil, err
    end
    if not t2 then
        err = "util.lua: error in param #2: got nil"
        return nil, err
    end
    if type( t1 ) ~= "number" then
        err = "util.lua: error in param #1: number expected, got " .. type( t1 )
        return nil, err
    end
    if type( t2 ) ~= "number" then
        err = "util.lua: error in param #2: number expected, got " .. type( t2 )
        return nil, err
    end
    local t1, t2 = tostring( t1 ), tostring( t2 )
    local y1, m1, d1, h1, M1, s1
    local y2, m2, d2, h2, M2, s2
    local diff, T1, T2
    local y, d, h, m, s
    if #t1 ~= 14 then
        err = "util.lua: error in param #1: not valid"
        return nil, err
    else
        y1 = t1:sub( 1, 4 )
        m1 = t1:sub( 5, 6 )
        d1 = t1:sub( 7, 8 )
        h1 = t1:sub( 9, 10 )
        M1 = t1:sub( 11, 12 )
        s1 = t1:sub( 13, 14 )
    end
    if #t2 ~= 14 then
        err = "util.lua: error in param #2: not valid"
        return nil, err
    else
        y2 = t2:sub( 1, 4 )
        m2 = t2:sub( 5, 6 )
        d2 = t2:sub( 7, 8 )
        h2 = t2:sub( 9, 10 )
        M2 = t2:sub( 11, 12 )
        s2 = t2:sub( 13, 14 )
    end
    T1 = os_time( { year = y1, month = m1, day = d1, hour = h1, min = M1, sec = s1 } )
    T2 = os_time( { year = y2, month = m2, day = d2, hour = h2, min = M2, sec = s2 } )
    diff = os_difftime( T1, T2 )
    y = math_floor( diff / ( 60 * 60 * 24 ) / 365 )
    d = math_floor( diff / ( 60 * 60 * 24 ) ) % 365
    h = math_floor( diff / ( 60 * 60 ) ) % 24
    m = math_floor( diff / 60 ) % 60
    s = diff % 60
    return y, d, h, m, s
end

--// convert os.time() "epoch" date to luadch date style: yyyymmddhhmmss (as number)
convertepochdate = function( t )
    local err
    if type( t ) ~= "number" then
        err = "util.lua: error: number expected, got " .. type( t )
        return nil, err
    end
    local date, y, m, d, h, M, s
    date = os_date( "*t", t )
    y = tostring( date.year )
    m = tostring( date.month )
    d = tostring( date.day )
    h = tostring( date.hour )
    M = tostring( date.min )
    s = tostring( date.sec )
    if #m == 1 then m = "0" .. m end
    if #d == 1 then d = "0" .. d end
    if #h == 1 then h = "0" .. h end
    if #M == 1 then M = "0" .. M end
    if #s == 1 then s = "0" .. s end
    return tonumber( y .. m .. d .. h .. M .. s ), err
end

--// trim whitespaces from both ends of a string
trimstring = function( str )
    local err
    local str = tostring( str )
    if type( str ) ~= "string" then
        err = "util.lua: error: string expected, got " .. type( str )
        return nil, err
    end
    return string_find( str, "^%s*$" ) and "" or string_match( str, "^%s*(.*%S)" )
end

string2table = function( str )
    local chunk, err = loadstring( str )
    if chunk then
        local ret = chunk( )
        if ret and type( ret ) == "table" then
            return ret
        else
            return nil, "invalid table"
        end
    end
    return nil, err
end

return {

    savetable = savetable,
    loadtable = loadtable,
    savearray = savearray,
    formatseconds = formatseconds,
    formatbytes = formatbytes,
    generatepass = generatepass,
    date = date,
    difftime = difftime,
    convertepochdate = convertepochdate,
    trimstring = trimstring,
    string2table = string2table,

}
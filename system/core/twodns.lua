--[[

    twodns.lua by pulsar

        usage:

            table/nil, statuscode = twodns.domains( https )
            table/nil, statuscode = twodns.accinfo( https, email, token )

]]


--// caching table lookups
local string_gmatch = string.gmatch

--// functions
local domains, accinfo

--// return available domains as array
domains = function( https )
    local address = "https://api.twodns.de/domains"
    local body, code, headers, status = https.request( address )
    if tostring( code ) == "200" then
        body = body:gsub('%[',''):gsub('%]',''):gsub('{',''):gsub('}',''):gsub('"',''):gsub('name:',''):gsub(',',' ')
        t, i = {}, 1
        for v in string_gmatch( body, "(%S+)" ) do
            t[ i ] = v
            i = i + 1
        end
        return t, code
    end
    return nil, code
end

--// return users complete account info as table
accinfo = function( https, email, token )
    local string2table = function( str )
        local chunk, err = loadstring( str )
        if chunk then
            local ret = chunk()
            if ret and type( ret ) == "table" then
                return ret
            else
                return nil, "invalid table"
            end
        end
        return nil, err
    end
    local response = {}
    local save = ltn12.sink.table( response )
    local body, code, headers, status = https.request{
        url = "https://api.twodns.de/users/me",
        method = "GET",
        sink = save,
        headers = { authorization = "Basic " .. ( mime.b64( email .. ":" .. token ) ), }
    }
    if tostring( code ) == "200" then
        local sink_data = response[ 1 ]
        local sink_len = sink_data:len()
        local sink_data = sink_data:sub( 2, sink_len - 1 )
        local sink_str = sink_data:gsub('%[','{'):gsub('%]','}'):gsub(':','='):gsub('"=','" ] = '):gsub('{"','{ %[ "'):gsub(',"',',%[ "'):gsub('"api_token','%[ "api_token')
        local t_header = "local twodns\n\ntwodns = {\n\n"
        local t_footer = "\n\n}\n\nreturn twodns"
        local t, err = string2table( t_header .. sink_str .. t_footer )
        if t then
            return t, code
        else
            return nil, err
        end
    end
    return nil, code
end

return {

    domains = domains,
    accinfo = accinfo,

}
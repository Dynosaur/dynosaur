--[[

    twodns.lua by pulsar

        description: returns a table with all available domains

        usage: table/nil, statuscode = twodns.domains( https )

]]

--// caching table lookups
local string_gmatch = string.gmatch

--// functions
local domains

--// return available domains as array
domains = function( https )
    local address = "https://api.twodns.de/domains"
    local body, code, headers, status = https.request( address )
    body = tostring( body )
    if body then
        body = body:gsub('%[',''):gsub('%]',''):gsub('{',''):gsub('}',''):gsub('"',''):gsub('name:',''):gsub(',',' ')
        t, i = {}, 1
        for v in string_gmatch( body, "(%S+)" ) do
            t[ i ] = v
            i = i + 1
        end
        return t, code
    else
        return nil, code
    end
end


return {

    domains = domains,

}
-- scripts/bossmeter/core/serializer.lua
-- Safe, self-contained JSON-compatible serializer/deserializer and RPC chunker.
-- Avoids loadstring() for security and works identically in DST and standard Lua 5.1.

local Serializer = {}

local function escape_str(s)
    local map = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t',
    }
    return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
        return map[c] or string.format("\\u%04x", string.byte(c))
    end) .. '"'
end

local function is_array(t)
    local max_idx = 0
    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
            return false, 0
        end
        if k > max_idx then max_idx = k end
        count = count + 1
    end
    if count == 0 then
        return true, 0
    end
    -- Treat as array if dense or nearly dense
    return max_idx == count, max_idx
end

local function encode_value(val, buf)
    local t = type(val)
    if t == "nil" then
        table.insert(buf, "null")
    elseif t == "boolean" then
        table.insert(buf, val and "true" or "false")
    elseif t == "number" then
        if val ~= val or val == math.huge or val == -math.huge then
            table.insert(buf, "0")
        else
            table.insert(buf, string.format("%.6g", val))
        end
    elseif t == "string" then
        table.insert(buf, escape_str(val))
    elseif t == "table" then
        local arr, len = is_array(val)
        if arr and len > 0 then
            table.insert(buf, "[")
            for i = 1, len do
                if i > 1 then table.insert(buf, ",") end
                encode_value(val[i], buf)
            end
            table.insert(buf, "]")
        else
            table.insert(buf, "{")
            local keys = {}
            for k, _ in pairs(val) do
                if type(k) == "string" or type(k) == "number" then
                    table.insert(keys, k)
                end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for i, k in ipairs(keys) do
                if i > 1 then table.insert(buf, ",") end
                table.insert(buf, escape_str(tostring(k)))
                table.insert(buf, ":")
                encode_value(val[k], buf)
            end
            table.insert(buf, "}")
        end
    else
        table.insert(buf, "null")
    end
end

--- Encode a Lua value (table, array, primitive) into a compact JSON string.
function Serializer.Encode(val)
    local buf = {}
    encode_value(val, buf)
    return table.concat(buf)
end

-- Recursive descent JSON parser
local function skip_ws(str, pos)
    local _, next_pos = str:find("^[ \t\r\n]*", pos)
    return (next_pos or pos - 1) + 1
end

local decode_value

local function decode_string(str, pos)
    pos = pos + 1 -- skip opening quote
    local buf = {}
    local len = #str
    while pos <= len do
        local c = str:sub(pos, pos)
        if c == '"' then
            return table.concat(buf), pos + 1
        elseif c == '\\' then
            local nxt = str:sub(pos + 1, pos + 1)
            local unesc = {
                ['"'] = '"',
                ['\\'] = '\\',
                ['/'] = '/',
                ['b'] = '\b',
                ['f'] = '\f',
                ['n'] = '\n',
                ['r'] = '\r',
                ['t'] = '\t',
            }
            if unesc[nxt] then
                table.insert(buf, unesc[nxt])
                pos = pos + 2
            elseif nxt == 'u' then
                local hex = str:sub(pos + 2, pos + 5)
                local code = tonumber(hex, 16) or 32
                if code < 128 then
                    table.insert(buf, string.char(code))
                else
                    table.insert(buf, "?")
                end
                pos = pos + 6
            else
                table.insert(buf, nxt)
                pos = pos + 2
            end
        else
            local next_special = str:find('[\\"]', pos)
            if not next_special then
                error("unterminated string at " .. pos)
            end
            table.insert(buf, str:sub(pos, next_special - 1))
            pos = next_special
        end
    end
    error("unterminated string")
end

local function decode_number(str, pos)
    local s, e = str:find("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if not s then
        error("invalid number at " .. pos)
    end
    local num = tonumber(str:sub(s, e))
    if not num then
        error("invalid number literal at " .. pos)
    end
    return num, e + 1
end

local function decode_array(str, pos)
    pos = skip_ws(str, pos + 1)
    local arr = {}
    if str:sub(pos, pos) == "]" then
        return arr, pos + 1
    end
    local idx = 1
    while true do
        local val
        val, pos = decode_value(str, pos)
        arr[idx] = val
        idx = idx + 1
        pos = skip_ws(str, pos)
        local c = str:sub(pos, pos)
        if c == "]" then
            return arr, pos + 1
        elseif c == "," then
            pos = skip_ws(str, pos + 1)
        else
            error("expected ',' or ']' at " .. pos)
        end
    end
end

local function decode_object(str, pos)
    pos = skip_ws(str, pos + 1)
    local obj = {}
    if str:sub(pos, pos) == "}" then
        return obj, pos + 1
    end
    while true do
        if str:sub(pos, pos) ~= '"' then
            error("expected string key at " .. pos)
        end
        local key
        key, pos = decode_string(str, pos)
        pos = skip_ws(str, pos)
        if str:sub(pos, pos) ~= ":" then
            error("expected ':' at " .. pos)
        end
        pos = skip_ws(str, pos + 1)
        local val
        val, pos = decode_value(str, pos)
        obj[key] = val
        pos = skip_ws(str, pos)
        local c = str:sub(pos, pos)
        if c == "}" then
            return obj, pos + 1
        elseif c == "," then
            pos = skip_ws(str, pos + 1)
        else
            error("expected ',' or '}' at " .. pos)
        end
    end
end

decode_value = function(str, pos)
    pos = skip_ws(str, pos)
    local c = str:sub(pos, pos)
    if c == '"' then
        return decode_string(str, pos)
    elseif c == "{" then
        return decode_object(str, pos)
    elseif c == "[" then
        return decode_array(str, pos)
    elseif c == "t" and str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif c == "f" and str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif c == "n" and str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    elseif c == "-" or (c >= "0" and c <= "9") then
        return decode_number(str, pos)
    else
        error("unexpected token '" .. c .. "' at " .. pos)
    end
end

--- Decode a JSON string back into a Lua value.
-- @return boolean ok, any result_or_err
function Serializer.Decode(str)
    if type(str) ~= "string" or str == "" then
        return false, "empty payload"
    end
    local ok, res = pcall(function()
        local val, _ = decode_value(str, 1)
        return val
    end)
    return ok, res
end

--- Split a payload string into fixed-size chunks for RPC transmission.
function Serializer.ChunkPayload(payload, chunk_size)
    local size = chunk_size or 4096
    local chunks = {}
    local len = #payload
    if len == 0 then
        return { "" }
    end
    local pos = 1
    while pos <= len do
        table.insert(chunks, payload:sub(pos, pos + size - 1))
        pos = pos + size
    end
    return chunks
end

--- Reassembler for chunked RPC messages.
local Reassembler = {}
Reassembler.__index = Reassembler

function Serializer.NewReassembler()
    return setmetatable({ pending = {} }, Reassembler)
end

--- Push a chunk. Returns complete payload string when all chunks arrive, or nil.
function Reassembler:Push(msg_id, idx, total, data)
    if total <= 1 then
        return data
    end
    local entry = self.pending[msg_id]
    if not entry then
        entry = { total = total, received = 0, parts = {} }
        self.pending[msg_id] = entry
    end
    if not entry.parts[idx] then
        entry.parts[idx] = data
        entry.received = entry.received + 1
    end
    if entry.received >= entry.total then
        self.pending[msg_id] = nil
        return table.concat(entry.parts)
    end
    return nil
end

return Serializer

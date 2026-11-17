-- tests/test_serializer.lua

local Serializer = require("bossmeter/core/serializer")

return function(T)
    local payload = {
        session_id = 1,
        boss_name = '独眼"巨鹿"\nTest',
        duration = 12.5,
        victory = true,
        players = {
            KU_P1 = { id = "KU_P1", name = "Wilson" },
        },
        series = { 10, 20, 0, 35.5 },
    }

    local encoded = Serializer.Encode(payload)
    T.assert_true(type(encoded) == "string" and #encoded > 0, "encoded non-empty string")

    local ok, decoded = Serializer.Decode(encoded)
    T.assert_true(ok, "decode succeeded: " .. tostring(decoded))
    T.assert_eq(decoded.session_id, 1, "session_id roundtrip")
    T.assert_eq(decoded.boss_name, payload.boss_name, "escaped string roundtrip")
    T.assert_near(decoded.duration, 12.5, 1e-4, "float roundtrip")
    T.assert_eq(decoded.victory, true, "boolean roundtrip")
    T.assert_eq(decoded.players.KU_P1.name, "Wilson", "nested table roundtrip")
    T.assert_eq(#decoded.series, 4, "array length roundtrip")
    T.assert_near(decoded.series[4], 35.5, 1e-4, "array element roundtrip")

    -- Chunking & reassembly
    local big = string.rep("abcdef1234", 50) -- 500 bytes
    local chunks = Serializer.ChunkPayload(big, 128)
    T.assert_eq(#chunks, 4, "500 bytes split into 4 chunks of <=128")

    local reassembler = Serializer.NewReassembler()
    local res = nil
    -- Push out of order
    res = reassembler:Push(99, 3, 4, chunks[3])
    T.assert_true(res == nil, "not complete after 1 chunk")
    res = reassembler:Push(99, 1, 4, chunks[1])
    res = reassembler:Push(99, 4, 4, chunks[4])
    res = reassembler:Push(99, 2, 4, chunks[2])
    T.assert_eq(res, big, "reassembled payload matches original")
end

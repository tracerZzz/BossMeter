-- tests/run_tests.lua
-- Minimal zero-dependency Lua 5.1 unit test runner for Tracer core.

package.path = "./scripts/?.lua;./scripts/?/init.lua;./tests/?.lua;" .. package.path

local T = {
    passed = 0,
    failed = 0,
    errors = {},
}

function T.assert_true(cond, msg)
    if cond then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        table.insert(T.errors, "FAIL: " .. (msg or "expected true"))
    end
end

function T.assert_eq(actual, expected, msg)
    if actual == expected then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        table.insert(T.errors, string.format("FAIL: %s (expected=%s, actual=%s)",
            msg or "equality", tostring(expected), tostring(actual)))
    end
end

function T.assert_near(actual, expected, eps, msg)
    eps = eps or 1e-4
    if type(actual) == "number" and math.abs(actual - expected) <= eps then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        table.insert(T.errors, string.format("FAIL: %s (expected=%s, actual=%s)",
            msg or "near", tostring(expected), tostring(actual)))
    end
end

local suites = {
    "test_registry_metrics",
    "test_session",
    "test_serializer",
}

for _, name in ipairs(suites) do
    local ok, suite_fn = pcall(require, name)
    if not ok then
        T.failed = T.failed + 1
        table.insert(T.errors, "ERROR loading " .. name .. ": " .. tostring(suite_fn))
    else
        print("Running " .. name .. "...")
        suite_fn(T)
    end
end

print(string.format("\nResults: %d passed, %d failed", T.passed, T.failed))
if T.failed > 0 then
    for _, err in ipairs(T.errors) do
        print("  " .. err)
    end
    os.exit(1)
end

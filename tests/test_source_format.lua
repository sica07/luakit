require "lunit"
require "lfs"

module("test_source_format", lunit.testcase, package.seeall)

-- Modification of code by David Kastrup
-- From: http://lua-users.org/wiki/DirTreeIterator

function files(dir, pattern)
    assert(dir and dir ~= "", "directory parameter is missing or empty")
    if string.sub(dir, -1) == "/" then
        dir = string.sub(dir, 1, -2)
    end

    local ignore = { ["."] = true, [".."] = true, [".git"] = true, ["tokenize.h"] = true, ["tokenize.c"] = true }

    local function yieldtree(dir)
        for entry in lfs.dir(dir) do
            if not ignore[entry] then
                entry = dir.."/"..entry
                local attr = lfs.attributes(entry)
                if attr.mode == "directory" then
                    yieldtree(entry)
                elseif attr.mode == "file" and entry:match(pattern) then
                    coroutine.yield(entry, attr)
                end
            end
        end
    end

    return coroutine.wrap(function() yieldtree(dir) end)
end

function test_vim_modeline ()
    local modeline_pat = "[^\n]\n\n// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80\n?$"
    local missing = {}

    for file in files(".", "%.[ch]$") do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()
        if not contents:match(modeline_pat) then
            table.insert(missing, file)
        end
    end

    if #missing > 0 then
        local err = {}
        for _, file in ipairs(missing) do
            err[#err+1] = "  " .. file:sub(3)
        end
        fail("Some files do not have modelines:\n" .. table.concat(err, "\n"))
    end
end

function test_include_guard ()
    local include_guard_pat = "#ifndef LUAKIT_%s\n#define LUAKIT_%s\n\n"
    local missing = {}

    for file in files(".", "%.h$") do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        local s = file:sub(3):gsub("[%.%/]", "_"):upper()
        local pat = include_guard_pat:format(s, s)
        if not contents:match(pat) then
            table.insert(missing, file)
        end
    end

    if #missing > 0 then
        local align = 0
        for _, file in ipairs(missing) do
            align = math.max(align, file:len())
        end

        local err = {}
        for _, file in ipairs(missing) do
            local s = file:sub(3):gsub("[%.%/]", "_"):upper()
            err[#err+1] = string.format("  %-" .. tostring(align-1) .. "sexpected LUAKIT_%s", file:sub(3), s)
        end
        fail("Some files do not have include guards:\n" .. table.concat(err, "\n"))
    end
end

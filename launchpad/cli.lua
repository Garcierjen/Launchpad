--[[
  "Buakaw a pen khon kampuca tae kaw mai yaum rub" -some cambodian
  cli launchpad made by garcier
  :keep you desktop clean (hide icon view)
--]]
package.cpath = "./dep/?.dll;" .. package.cpath
local ffi = require("ffi")
local C = ffi.load("Kernel32")
local shell32 = ffi.load("Shell32")

local bit = {
  band = function(a, b) return a & b end,
  bor  = function(a, b) return a | b end,
  bxor = function(a, b) return a ~ b end,
  bnot = function(a)    return ~a end,
  lshift = function(a, b) return a << b end,
  rshift = function(a, b) return a >> b end,
}

ffi.cdef[[
typedef void* HANDLE;
typedef unsigned long DWORD;
typedef unsigned short WORD;
typedef int BOOL;
typedef short SHORT;
typedef char CHAR;
typedef unsigned short WCHAR;

typedef struct _COORD {
  SHORT X;
  SHORT Y;
} COORD;

typedef struct _KEY_EVENT_RECORD {
  BOOL bKeyDown;
  WORD wRepeatCount;
  WORD wVirtualKeyCode;
  WORD wVirtualScanCode;
  union {
    WCHAR UnicodeChar;
    CHAR AsciiChar;
  } uChar;
  DWORD dwControlKeyState;
} KEY_EVENT_RECORD;

typedef struct _INPUT_RECORD {
  WORD EventType;
  union {
    KEY_EVENT_RECORD KeyEvent;
  };
} INPUT_RECORD;

typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
  COORD dwSize;
  COORD dwCursorPosition;
  WORD  wAttributes;
  COORD srWindow;
  COORD dwMaximumWindowSize;
} CONSOLE_SCREEN_BUFFER_INFO;

HANDLE GetStdHandle(DWORD nStdHandle);
BOOL GetConsoleMode(HANDLE hConsoleHandle, DWORD* lpMode);
BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
BOOL ReadConsoleInputA(HANDLE hConsoleInput, INPUT_RECORD* lpBuffer, DWORD nLength, DWORD* lpNumberOfEventsRead);
BOOL SetConsoleCursorPosition(HANDLE hConsoleOutput, COORD dwCursorPosition);
BOOL GetConsoleScreenBufferInfo(HANDLE hConsoleOutput, CONSOLE_SCREEN_BUFFER_INFO* lpConsoleScreenBufferInfo);
]]

local STD_INPUT_HANDLE  = -10
local STD_OUTPUT_HANDLE = -11
local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
local VK_RETURN = 0x0D
local VK_UP = 0x26
local VK_DOWN = 0x28
local VK_Q = 0x51
local LEFT_CTRL_PRESSED  = 0x0008
local RIGHT_CTRL_PRESSED = 0x0004
local hIn  = C.GetStdHandle(STD_INPUT_HANDLE)
local hOut = C.GetStdHandle(STD_OUTPUT_HANDLE)

local mode = ffi.new("DWORD[1]")
if C.GetConsoleMode(hOut, mode) ~= 0 then
    mode[0] = bit.bor(mode[0], ENABLE_VIRTUAL_TERMINAL_PROCESSING)
    C.SetConsoleMode(hOut, mode[0])
end

local function clear_screen()
  os.execute("cls")
end

local function set_cursor(x, y)
  local coord = ffi.new("COORD")
  coord.X = x
  coord.Y = y
  C.SetConsoleCursorPosition(hOut, coord)
end

local function get_key()
    local buf = ffi.new("INPUT_RECORD[1]")
    local read = ffi.new("DWORD[1]")
    repeat
        C.ReadConsoleInputA(hIn, buf, 1, read)
    until buf[0].EventType == 1 and buf[0].KeyEvent.bKeyDown ~= 0

    local key = buf[0].KeyEvent.wVirtualKeyCode
    local mod = buf[0].KeyEvent.dwControlKeyState
    return key, mod
end

local function get_desktop_paths()
    return {
        os.getenv("USERPROFILE") .. "\\Desktop",
        os.getenv("PUBLIC") .. "\\Desktop"
    }
end

local function is_launchable(file)
    local ext = file:match("^.+(%..+)$")
    return ext and ({ [".exe"]=true, [".lnk"]=true, [".url"]=true })[ext:lower()]
end

local function list_launchable_files()
    local list = {}
    for _, dir in ipairs(get_desktop_paths()) do
        local command = string.format('dir /b "%s"', dir)
        local pipe = io.popen(command, "r")
        if pipe then
            for line in pipe:lines() do
                if is_launchable(line) then
                    table.insert(list, { name = line, path = dir .. "\\" .. line })
                end
            end
            pipe:close()
        end
    end
    return list
end

local function get_terminal_width()
    local info = ffi.new("CONSOLE_SCREEN_BUFFER_INFO")
    if C.GetConsoleScreenBufferInfo(hOut, info) ~= 0 then
        return info.dwSize.X
    end
    return 80
end

local function get_terminal_height()
    local handle = io.popen("mode con")
    if not handle then return 25 end
    local output = handle:read("*a")
    handle:close()
    local height = output:match("Lines:%s*(%d+)")
    return tonumber(height) or 25
end

local function draw_menu(items, selected)
    clear_screen()
    local width = get_terminal_width()
    local height = get_terminal_height()

    local title = "================ Launchpad ================"
  

    local menu_lines = #items + 3


    local vertical_padding = math.floor((height - menu_lines) / 2)
    if vertical_padding < 0 then vertical_padding = 0 end

    for _ = 1, vertical_padding do
        print()
    end

    local title_padding = math.floor((width - #title) / 2)
    if title_padding < 0 then title_padding = 0 end
    print(string.rep(" ", title_padding) .. title)

    for i, item in ipairs(items) do
        local display_name = item.name:gsub("%.%w+$", "")
        local text = " " .. display_name .. " "
        local padding = math.floor((width - #text) / 2)
        if padding < 0 then padding = 0 end

        io.write(string.rep(" ", padding))

        if i == selected then
            io.write("\x1b[47;30m") 
            io.write(text)
            io.write("\x1b[0m") 
        else
            io.write(text)
        end

        io.write("\n")
    end
end



local function launch(item)
    os.execute(string.format('start "" "%s"', item.path))
end

local function run()
    local items = list_launchable_files()
    if #items == 0 then
        print("No apps found on desktop.")
        return
    end

    local selected = 1
    draw_menu(items, selected)

    while true do
        local key, mod = get_key()
        local ctrl = bit.band(mod, LEFT_CTRL_PRESSED) ~= 0 or bit.band(mod, RIGHT_CTRL_PRESSED) ~= 0
        if key == VK_UP then
            selected = selected - 1
            if selected < 1 then selected = #items end
        elseif key == VK_DOWN then
            selected = selected + 1
            if selected > #items then selected = 1 end
        elseif key == VK_RETURN then
            launch(items[selected])
            break
        end

        draw_menu(items, selected)
    end
end

run()

--[[

  /$$$$$$  /$$   /$$ /$$$$$$ /$$$$$$$          /$$$$$$ 
 /$$__  $$| $$  | $$|_  $$_/| $$__  $$        /$$__  $$
| $$  \__/| $$  | $$  | $$  | $$  \ $$       | $$  \ $$
| $$      | $$$$$$$$  | $$  | $$$$$$$//$$$$$$|  $$$$$$/
| $$      | $$__  $$  | $$  | $$____/|______/ >$$__  $$
| $$    $$| $$  | $$  | $$  | $$             | $$  \ $$
|  $$$$$$/| $$  | $$ /$$$$$$| $$             |  $$$$$$/
 \______/ |__/  |__/|______/|__/              \______/ 
                                                       

Author: @MrRoblick

Repo: https://github.com/MrRoblick/chip8-luau
Version: 1.0.0
License: MIT

]]

--!strict
--!native
--!optimize 2


--[[ CONSTANTS ]]
local MEMORY_SIZE = 4096
local SCREEN_WIDTH = 64
local SCREEN_HEIGHT = 32

local FONT_START = 0x50
local PROGRAM_START = 0x200

local GFX_SIZE = (SCREEN_WIDTH * SCREEN_HEIGHT) // 8 -- 256 bytes
local KEYPAD_SIZE = 2 -- 16 bits

-- [[ OFFSETS ]]
local MEMORY_OFFSET = 0                                 -- 4096
local V_OFFSET = MEMORY_OFFSET + MEMORY_SIZE            -- 16
local I_OFFSET = V_OFFSET + 16                          -- 2
local PC_OFFSET = I_OFFSET + 2                          -- 2
local STACK_OFFSET = PC_OFFSET + 2                      -- 32
local SP_OFFSET = STACK_OFFSET + (16 * 2)               -- 1
local DELAY_TIMER_OFFSET = SP_OFFSET + 1                -- 1
local SOUND_TIMER_OFFSET = DELAY_TIMER_OFFSET + 1       -- 1
local GFX_OFFSET = SOUND_TIMER_OFFSET + 1               -- 256
local KEYPAD_OFFSET = GFX_OFFSET + GFX_SIZE             -- 2
local DRAW_FLAG_OFFSET = KEYPAD_OFFSET + KEYPAD_SIZE    -- 1

local BUFFER_SIZE = DRAW_FLAG_OFFSET + 1


local FONT_SET_BUFFER = buffer.fromstring(
	"\xF0\x90\x90\x90\xF0\x20\x60\x20\x20\x70\xF0\x10\xF0\x80\xF0\xF0\x10\xF0\x10\xF0\x90\x90\xF0\x10\x10\xF0\x80\xF0\x10\xF0\xF0\x80\xF0\x90\xF0\xF0\x10\x20\x40\x40\xF0\x90\xF0\x90\xF0\xF0\x90\xF0\x10\xF0\xF0\x90\xF0\x90\x90\xE0\x90\xE0\x90\xE0\xF0\x80\x80\x80\xF0\xE0\x90\x90\x90\xE0\xF0\x80\xF0\x80\xF0\xF0\x80\xF0\x80\x80"
)


-- [[ HELPERS ]]
@native @checked local function WriteDelayTimer(self: buffer, ValueU8: number): ()
	buffer.writeu8(self, DELAY_TIMER_OFFSET, ValueU8)
end
@native @checked local function ReadDelayTimer(self: buffer): number
	return buffer.readu8(self, DELAY_TIMER_OFFSET)
end

@native @checked local function WriteSoundTimer(self: buffer, ValueU8: number): ()
	buffer.writeu8(self, SOUND_TIMER_OFFSET, ValueU8)
end
@native @checked local function ReadSoundTimer(self: buffer): number
	return buffer.readu8(self, SOUND_TIMER_OFFSET)
end

@native @checked local function WritePC(self: buffer, ValueU16: number)
	buffer.writeu16(self, PC_OFFSET, ValueU16)
end
@native @checked local function ReadPC(self: buffer): number
	return buffer.readu16(self, PC_OFFSET)
end

@native @checked local function WriteSP(self: buffer, ValueU8: number): ()
	buffer.writeu8(self, SP_OFFSET, ValueU8)
end
@native @checked local function ReadSP(self: buffer): number
	return buffer.readu8(self, SP_OFFSET)
end

@native @checked local function WriteV(self: buffer, Reg: number, ValueU8: number): ()
	buffer.writeu8(self, V_OFFSET + Reg, ValueU8)
end
@native @checked local function ReadV(self: buffer, Reg: number): number
	return buffer.readu8(self, V_OFFSET + Reg)
end

@native @checked local function WriteI(self: buffer, ValueU16: number): ()
	buffer.writeu16(self, I_OFFSET, ValueU16)
end
@native @checked local function ReadI(self: buffer): number
	return buffer.readu16(self, I_OFFSET)
end


@native @checked local function WriteStack(self: buffer, Idx: number, ValueU16: number): ()
	buffer.writeu16(self, STACK_OFFSET + Idx*2, ValueU16)
end
@native @checked local function ReadStack(self: buffer, Idx: number): number
	return buffer.readu16(self, STACK_OFFSET + Idx*2)
end

@native @checked local function WriteDrawFlag(self: buffer, ValueU8: number): ()
	buffer.writeu8(self, DRAW_FLAG_OFFSET, ValueU8)
end
@native @checked local function ReadDrawFlag(self: buffer): number
	return buffer.readu8(self, DRAW_FLAG_OFFSET)
end


@native @checked local function WriteMemoryU8(self: buffer, Offset: number, ValueU8: number): ()
	buffer.writeu8(self, MEMORY_OFFSET + Offset, ValueU8)
end
@native @checked local function ReadMemoryU8(self: buffer, Offset: number): number
	return buffer.readu8(self, MEMORY_OFFSET + Offset)
end

@native @checked local function ClearScreen(self: buffer): ()
	buffer.fill(self, GFX_OFFSET, 0, GFX_SIZE)
	buffer.writeu8(self, DRAW_FLAG_OFFSET, 1)
end

@native @checked local function ReadPixel(self: buffer, Index: number): number
	return buffer.readbits(self, (GFX_OFFSET * 8) + Index, 1)
end
@native @checked local function WritePixel(self: buffer, Index: number, Pix: number): ()
	buffer.writebits(self, (GFX_OFFSET * 8) + Index, 1, Pix)
end

@native @checked local function ReadKeypad(self: buffer, Key: number): number
	return buffer.readbits(self, (KEYPAD_OFFSET * 8) + Key, 1)
end
@native @checked local function WriteKeypad(self: buffer, Key: number, State: number): ()
	buffer.writebits(self, (KEYPAD_OFFSET * 8) + Key, 1, State)
end

@native @checked local function Reset(self: buffer): ()
	buffer.fill(self, 0, 0, buffer.len(self))
	WritePC(self, PROGRAM_START)
	WriteDrawFlag(self, 1)
	buffer.copy(self, MEMORY_OFFSET + FONT_START, FONT_SET_BUFFER, 0, buffer.len(FONT_SET_BUFFER))
end


local CHIP8 = {}

local __class = {} do
	@native @checked function __class.LoadROM(self: CHIP8Instance, Rom: buffer): ()
		buffer.copy(self._data, MEMORY_OFFSET + PROGRAM_START, Rom, 0, buffer.len(Rom))
	end
	@native @checked function __class.TickTimers(self: CHIP8Instance): ()
		local data = self._data
		
		local dT = ReadDelayTimer(data)
		if dT > 0 then
			WriteDelayTimer(data, dT - 1)
		end
		
		local sT = ReadSoundTimer(data)
		if sT > 0 then
			WriteSoundTimer(data, sT - 1)
		end
	end
	
	@native @checked function __class.ReadPixels(self: CHIP8Instance): buffer
		local Buf = buffer.create(GFX_SIZE)
		buffer.copy(Buf, 0, self._data, GFX_OFFSET, GFX_SIZE)
		return Buf
	end
	
	@native @checked function __class.SetInput(self: CHIP8Instance, Key: number, State: boolean): ()
		WriteKeypad(self._data, Key, if State then 1 else 0)
	end
	
	@native @checked function __class.GetInput(self: CHIP8Instance, Key: number): boolean
		return ReadKeypad(self._data, KEYPAD_OFFSET + Key) == 1
	end
	
	@native @checked function __class.Reset(self: CHIP8Instance): ()
		Reset(self._data)
	end
	
	@native @checked function __class.Step(self: CHIP8Instance): ()
		local data = self._data
		
		local pc = ReadPC(data)
		local Op = bit32.bor(
			bit32.lshift(ReadMemoryU8(data, pc), 8),
			ReadMemoryU8(data, pc + 1)
		)
		
		pc += 2
		WritePC(data, pc)
		
		local x = bit32.rshift(bit32.band(Op, 0x0F00), 8)
		local y = bit32.rshift(bit32.band(Op, 0x00F0), 4)
		local n = bit32.band(Op, 0x000F)
		local kk = bit32.band(Op, 0x00FF)
		local nnn = bit32.band(Op, 0x0FFF)
		
		local opC = bit32.band(Op, 0xF000)
		if opC == 0x0000 then
			if Op == 0x00E0 then
				ClearScreen(data)
			elseif Op == 0x00EE then
				local sp = ReadSP(data)
				if sp == 0 then
					return
				end
				
				local newSp = sp - 1
				WriteSP(data, newSp)
				WritePC(data, ReadStack(data, newSp))
			end
		elseif opC == 0x1000 then
			WritePC(data, nnn)
		elseif opC == 0x2000 then
			local sp = ReadSP(data)
			if sp >= 16 then
				return
			end
			WriteStack(data, sp, pc)
			WriteSP(data, sp + 1)
			WritePC(data, nnn)
		elseif opC == 0x3000 then
			if ReadV(data, x) == kk then
				WritePC(data, pc + 2)
			end
		elseif opC == 0x4000 then
			if ReadV(data, x) ~= kk then
				WritePC(data, pc + 2)
			end
		elseif opC == 0x5000 then
			if n == 0 and ReadV(data, x) == ReadV(data, y) then
				WritePC(data, pc + 2)
			end
		elseif opC == 0x6000 then
			WriteV(data, x, kk)
		elseif opC == 0x7000 then
			WriteV(data, x, ReadV(data, x) + kk)
		elseif opC == 0x8000 then
			if n == 0x0 then
				WriteV(data, x, ReadV(data, y))
			elseif n == 0x1 then
				WriteV(data, x, bit32.bor(ReadV(data, x), ReadV(data, y)))
			elseif n == 0x2 then
				 WriteV(data, x, bit32.band(ReadV(data, x), ReadV(data, y)))
			elseif n == 0x3 then
				WriteV(data, x, bit32.bxor(ReadV(data, x), ReadV(data, y)))
			elseif n == 0x4 then
				local sum = ReadV(data, x) + ReadV(data, y)
				
				WriteV(data, 0xF, 0)
				if sum > 0xFF then
					WriteV(data, 0xF, 1)
				end
				
				WriteV(data, x, sum)
			elseif n == 0x5 then
				WriteV(data, 0xF, 0)
				local tX = ReadV(data, x)
				local tY = ReadV(data, y)
				if tX >= tY then
					WriteV(data, 0xF, 1)
				end
				WriteV(data, x, tX - tY)
			elseif n == 0x6 then
				WriteV(data, 0xF, bit32.band(ReadV(data, x), 0x01))
				WriteV(data, x, bit32.rshift(ReadV(data, x), 1))
			elseif n == 0x7 then
				WriteV(data, 0xF, 0)
				local tX = ReadV(data, x)
				local tY = ReadV(data, y)
				if tY >= tX then
					WriteV(data, 0xF, 1)
				end
				WriteV(data, x, tY - tX)
			elseif n == 0xE then
				WriteV(data, 0xF, bit32.band(bit32.rshift(ReadV(data, x), 7), 0x01))
				WriteV(data, x, bit32.lshift(ReadV(data, x), 1))
			end
		elseif opC == 0x9000 then
			if n == 0 and ReadV(data, x) ~= ReadV(data, y) then
				WritePC(data, pc + 2)
			end
		elseif opC == 0xA000 then
			WriteI(data, nnn)
		elseif opC == 0xB000 then
			WritePC(data, nnn + ReadV(data, 0))
		elseif opC == 0xC000 then
			local rand = self._rand
			local b = rand:NextInteger(0, 255)
			WriteV(data, x, bit32.band(b, kk))
		elseif opC == 0xD000 then
			local vx = ReadV(data, x) % SCREEN_WIDTH
			local vy = ReadV(data, y) % SCREEN_HEIGHT
			
			WriteV(data, 0xF, 0)
			for row = 0, n-1 do
				local sprite = ReadMemoryU8(data, ReadI(data) + row)
				for col = 0, 7 do
					local bit = bit32.band(bit32.rshift(sprite, (7 - col)), 0x1)
					if bit == 0 then
						continue
					end
					local px = (vx + col) % SCREEN_WIDTH
					local py = (vy + row) % SCREEN_HEIGHT
					local p = px + py * SCREEN_WIDTH
					
					if ReadPixel(data, p) == 1 then
						WriteV(data, 0xF, 1)
					end
					WritePixel(data, p, bit32.bxor(ReadPixel(data, p), 1))
				end
			end
			WriteDrawFlag(data, 1)
		elseif opC == 0xE000 then
			if kk == 0x9E then
				local key = bit32.band(ReadV(data, x), 0x0F)
				if ReadKeypad(data, key) == 1 then
					WritePC(data, pc + 2)
				end
			elseif kk == 0xA1 then
				local key = bit32.band(ReadV(data, x), 0x0F)
				if ReadKeypad(data, key) == 0 then
					WritePC(data, pc + 2)
				end
			end
		elseif opC == 0xF000 then
			if kk == 0x07 then
				WriteV(data, x, ReadDelayTimer(data))
			elseif kk == 0x0A then
				local pressed = false
				for i = 0, 15 do
					if ReadKeypad(data, i) == 1 then
						WriteV(data, x, i)
						pressed = true
						break
					end
				end
				
				if not pressed then
					WritePC(data, pc - 2)
				end
			elseif kk == 0x15 then
				WriteDelayTimer(data, ReadV(data, x))
			elseif kk == 0x18 then
				WriteSoundTimer(data, ReadV(data, x))
			elseif kk == 0x1E then
				WriteI(data, ReadI(data) + ReadV(data, x))
			elseif kk == 0x29 then
				WriteI(data, FONT_START + bit32.band(ReadV(data, x), 0x0F) * 5)
			elseif kk == 0x33 then
				local val = ReadV(data, x)
				local i = ReadI(data)
				WriteMemoryU8(data, i, val // 100)
				WriteMemoryU8(data, i + 1, (val // 10) % 10)
				WriteMemoryU8(data, i + 2, val % 10)
			elseif kk == 0x55 then
				for i = 0, x do
					WriteMemoryU8(data, ReadI(data) + i, ReadV(data, i))
				end
			elseif kk == 0x65 then
				for i = 0, x do
					WriteV(data, i, ReadMemoryU8(data, ReadI(data) + i))
				end
			end
		end
	end
	
	table.freeze(__class)
end



local __meta = table.freeze({__index=__class})

export type CHIP8Instance = typeof(table.freeze(setmetatable(
	{} :: {
		_data: buffer,
		_rand: Random,
	}, __meta
)))

@native @checked function CHIP8.new(RandomGenerator: Random?): CHIP8Instance
	local data = buffer.create(BUFFER_SIZE)
	Reset(data)
	return table.freeze(setmetatable({
		_data = data,
		_rand = RandomGenerator or Random.new(),
	}, __meta))
end

CHIP8.ScreenWidth = SCREEN_WIDTH
CHIP8.ScreenHeight = SCREEN_HEIGHT

return table.freeze(CHIP8)

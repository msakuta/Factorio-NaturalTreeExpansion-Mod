
local freq = 16
local freq2 = freq ^ 2
local totalgen = 0
local chunksize = 32
local tickfreq = 60

local function fmod(a,m)
	return a - math.floor(a / m) * m
end

local function test_entity(surface,area,names)
	for i = 1,#names do
		if 0 ~= surface.count_entities_filtered{area = area, type = names[i]} then
			return false
		end
	end
	return true
end

local shuffle_src = {}

for i = 1,freq do
	for j = 1,freq do
		shuffle_src[i * freq + j] = i * freq + j
	end
end

local shuffle = {}

while 0 < #shuffle_src do
	local p = math.random(1,#shuffle_src)
	table.insert(shuffle, shuffle_src[p])
	table.remove(shuffle_src, p)
end

function on_tick(event)
	if game.tick % tickfreq == 0 then
		local m = math.floor(game.tick / tickfreq)
		if m == 0 then
			local str = ""
			for i = 1,#shuffle do
				str = str .. shuffle[i] ..","
			end
			game.players[1].print("[" .. str .. "]")
		end
		local num = 0
		local allnum = 0
		local chunkBuf = {}
		local str = ""
		local mm = m % #shuffle + 1
		local mx = shuffle[mm] % freq
		local my = math.floor(shuffle[mm] / freq)
		local surface = game.surfaces[1]
		local totalc = 0
		for chunk in surface.get_chunks() do
			allnum = allnum + 1
			if fmod(chunk.x + mx, freq) == 0 and fmod(chunk.y + my, freq) == 0 then
				local area = {{chunk.x * chunksize, chunk.y * chunksize}, {(chunk.x + 1) * chunksize, (chunk.y + 1) * chunksize}}
				local c = surface.count_entities_filtered{area = area, type = "tree"}
				totalc = totalc + c
				if 0 < c then
					local trees = surface.find_entities_filtered{area = area, type = "tree"}
					if 0 < #trees then
						local tree = trees[math.random(#trees)]
						local newpos
						local success = false
						for try = 1,10 do
							newpos = {tree.position.x + (math.random(-5,5)), tree.position.y + (math.random(-5,5))}
							if 0 == surface.count_entities_filtered{area = {{newpos[1] - 1, newpos[2] - 1}, {newpos[1] + 1, newpos[2] + 1}}, type = "tree"} and
							test_entity(surface, {{newpos[1] - 2, newpos[2] - 2}, {newpos[1] + 2, newpos[2] + 2}}, {"turret", "ammo-turret", "mining-drill", "wall"}) then
								success = true
								break
							end
						end
						if success then
							num = num + 1
							chunkBuf[num] = chunk

							surface.create_entity{name = tree.name, position = newpos, force = tree.force}
							if num < 5 then
								str = str .. "(" .. chunk.x .. ", " .. chunk.y .. ")" .. c .. "[" .. newpos[1] .. "," .. newpos[2] .. "],"
							end
						end
					end
				end
			end
		end
		totalgen = totalgen + num
		if m % 10 == 0 then
			game.players[1].print("[" .. m .. "] Chunks[" .. num .. "/" .. allnum .. "](" .. totalc .. ")" .. totalgen .. ": " .. str)
		end
	end
end

-- Register event handlers
script.on_event(defines.events.on_tick, function(event) on_tick(event) end)

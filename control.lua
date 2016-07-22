require "config"

local freq = 16
local freq2 = freq ^ 2
local totalgen = 0
local chunksize = 32
local original_tree_count = 0

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

local function test_tile(surface,newpos,names)
	tile = surface.get_tile(newpos[1],newpos[2])
	if not tile.valid then
		return false
	end
	for i = 1,#names do
		if tile.name == names[i] then
			return false
		end
	end
	return true
end

local function eqany(a,b)
	for i = 1,#b do
		if a == b[i] then
			return true
		end
	end
	return false
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
	if game.tick % tree_expansion_frequency == 0 then
		local m = math.floor(game.tick / tree_expansion_frequency)
		if m == 0 then
			local str = ""
			for i = 1,#shuffle do
				str = str .. shuffle[i] ..","
			end
			game.players[1].print("[" .. str .. "]")
		end
		local num = 0
		local allnum = 0
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
						local nondeadtree = false
						local tree = trees[math.random(#trees)]
						-- Draw trees until we get a non-dead tree.
						for try = 1,10 do
							if not eqany(tree.name, {"dead-tree", "dry-tree", "dead-grey-trunk", "dry-hairy-tree", "dead-dry-hairy-tree"}) then
								nondeadtree = true
								break
							end
						end
						if nondeadtree then
							local newpos
							local success = false
							-- Try until randomly generated position does not block something.
							for try = 1,10 do
								newpos = {tree.position.x + (math.random(-5,5)), tree.position.y + (math.random(-5,5))}
								local newarea = {{newpos[1] - 1, newpos[2] - 1}, {newpos[1] + 1, newpos[2] + 1}}
								local newarea2 = {{newpos[1] - 2, newpos[2] - 2}, {newpos[1] + 2, newpos[2] + 2}}
								if 0 == surface.count_entities_filtered{area = newarea, type = "tree"} and
								test_tile(surface, newpos, {"out-of-map", "deepwater", "deepwater-green", "water",
									"water-green", "grass", "sand", "sand-dark", "stone-path", "concrete", "hazard-concrete-left", "hazard-concrete-right",
									"dirt", "dirt-dark"}) and
								0 == surface.count_entities_filtered{area = newarea2, force = "player"} then
									success = true
									break
								end
							end
							if success then
								num = num + 1
								surface.create_entity{name = tree.name, position = newpos, force = tree.force}
							end
						end
					end
				end
			end
		end
		totalgen = totalgen + num
		if m % 1 == 0 then
			local function counttrees()
				local c=0
				for i=1,9 do
					c = c + game.forces.neutral.get_entity_count("tree-" .. string.format("%02d", i))
				end
				return c
			end

			if not game.players[1].gui.left.trees then
				game.players[1].gui.left.add{type="frame", name="trees", caption="Trees", direction="vertical"}
				original_tree_count = game.surfaces[1].count_entities_filtered{area={{-10000,-10000},{10000,10000}},type="tree"}
				game.players[1].gui.left.trees.add{type="label",name="m",caption="Cycle: " .. m % #shuffle .. "/" .. #shuffle}
				game.players[1].gui.left.trees.add{type="label",name="total",caption="Total trees: " .. counttrees() .. "/" .. original_tree_count}
				game.players[1].gui.left.trees.add{type="label",name="count",caption="Added trees: " .. totalgen}
			else
				game.players[1].gui.left.trees.m.caption = "Cycle: " .. m % #shuffle .. "/" .. #shuffle
				game.players[1].gui.left.trees.total.caption = "Total trees: " .. counttrees() .. "/" .. (original_tree_count + totalgen)
				game.players[1].gui.left.trees.count.caption = "Added trees: " .. totalgen
			end
		end
		if m % 1000 == 0 and false then
			game.players[1].print("[" .. m .. "] Chunks[" .. num .. "/" .. allnum .. "](" .. totalc .. ")" .. totalgen .. ": " .. str)
		end
	end
end

-- Register event handlers
script.on_event(defines.events.on_tick, function(event) on_tick(event) end)

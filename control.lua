require "config"

local freq = 16
local freq2 = freq ^ 2
local totalgen = 0
local chunksize = 32
local original_tree_count = 0

local tree_names = {
	"tree-01",
	"tree-02",
	"tree-02-red",
	"tree-03",
	"tree-04",
	"tree-05",
	"tree-06",
	"tree-06-brown",
	"tree-07",
	"tree-08",
	"tree-08-brown",
	"tree-08-red",
	"tree-09",
	"tree-09-brown",
	"tree-09-red"
}

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

-- Playermap is a 2-D map that indicates approximate location of player owned
-- entities. It is used for optimizing the algorithm to quickly determine proximity
-- of the player's properties which would be of player's interest.
-- Because LuaSurface.count_entities_filtered() is slow for large area, we want
-- to call it as few times as possible.
-- This is similar in function as chunks, but playermap element is greater than
-- chunks, because it's not good idea to make scripting languages like Lua
-- calculating large set of data. Also we only need very rough estimation, so
-- chunk granularity is too fine for us.
local playermap_freq = 4
local playermap = {}

local function update_player_map(m, surface)
	local mm = m % #shuffle + 1
	local mx = shuffle[mm] % freq
	local my = math.floor(shuffle[mm] / freq)
	for chunk in surface.get_chunks() do
		if fmod(chunk.x + mx, freq) == 0 and fmod(chunk.y + my, freq) == 0 and
			0 < surface.count_entities_filtered{area = {{chunk.x * chunksize, chunk.y * chunksize}, {(chunk.x + 1) * chunksize, (chunk.y + 1) * chunksize}}, force = "player"} then
			local px = math.floor(chunk.x / 4)
			local py = math.floor(chunk.y / 4)
			if playermap[py] == nil then
				playermap[py] = {}
			end
			playermap[py][px] = m
		end
	end
end

function on_tick(event)
	-- First, cache player map data by searching player owned entities.
	if game.tick % tree_expansion_frequency == 0 then
		local m = math.floor(game.tick / tree_expansion_frequency)
		update_player_map(m, game.surfaces[1])
	end

	-- Delay the loop as half a phase of update_player_map to reduce
	-- 'petit-freeze' duration as possible.
	if math.floor(game.tick + tree_expansion_frequency / 2) % tree_expansion_frequency == 0 then
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

			-- Check if any of player's entity is in proximity of this chunk.
			local function checkPlayerMap()
				local px = math.floor(chunk.x / 4)
				local py = math.floor(chunk.y / 4)
				for y=-1,1 do
					if playermap[py + y] then
						for x=-1,1 do
							if playermap[py + y][px + x] and m < playermap[py + y][px + x] + freq2 then
								return true
							end
						end
					end
				end
				return false
			end

			-- Grow trees on only the player's proximity since the player is not
			-- interested nor has means to observe deep in the unknown region.
			if fmod(chunk.x + mx, freq) == 0 and fmod(chunk.y + my, freq) == 0 and
				checkPlayerMap() then
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
								0 == surface.count_entities_filtered{area = newarea2, force = "player"} and
								surface.can_place_entity{name = tree.name, position = newpos, force = tree.force} then
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
		if enable_debug_window then
			-- LuaSurface.count_entities_filtered() is slow, LuaForce.get_entity_count() is much faster, but
			-- it needs entity name argument, not type. So we must repeat it for all types of trees.
			local function counttrees()
				local c=0
				for i=1,#tree_names do
					c = c + game.forces.neutral.get_entity_count(tree_names[i])
				end
				return c
			end

			-- Return [rows,active,visited] playermap chunks
			local function countPlayerMap()
				local ret = {0,0,0}
				for i,v in pairs(playermap) do
					ret[1] = ret[1] + 1
					for j,w in pairs(v) do
						if m < w + freq2 then
							ret[2] = ret[2] + 1
						end
						ret[3] = ret[3] + 1
					end
				end
				return ret
			end

			if not game.players[1].gui.left.trees then
				game.players[1].gui.left.add{type="frame", name="trees", caption="Trees", direction="vertical"}
				-- original_tree_count = game.surfaces[1].count_entities_filtered{area={{-10000,-10000},{10000,10000}},type="tree"}
				game.players[1].gui.left.trees.add{type="label",name="m",caption="Cycle: " .. m % #shuffle .. "/" .. #shuffle}
				game.players[1].gui.left.trees.add{type="label",name="total",caption="Total trees: " .. counttrees()}
				game.players[1].gui.left.trees.add{type="label",name="count",caption="Added trees: " .. totalgen}
				game.players[1].gui.left.trees.add{type="label",name="playermap"}
			else
				game.players[1].gui.left.trees.m.caption = "Cycle: " .. m % #shuffle .. "/" .. #shuffle
				game.players[1].gui.left.trees.total.caption = "Total trees: " .. counttrees()
				game.players[1].gui.left.trees.count.caption = "Added trees: " .. totalgen
			end
			local cc = countPlayerMap()
			game.players[1].gui.left.trees.playermap.caption = "Playermap: " .. cc[1] .. "/" .. cc[2] .. "/" .. cc[3]
		end
	end
end

-- Register event handlers
script.on_event(defines.events.on_tick, function(event) on_tick(event) end)

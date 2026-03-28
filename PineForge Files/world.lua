-- world.lua
-- Block grid, chunk lifecycle, and mesh building.
-- One Pine3D object per height band per chunk.

local world = {}

local cfg, Pine3D, noise, ThreeDFrame, objects, worldId, PineForge
local models       = {}
local grid         = {}
local loadedChunks = {}
local chunkLoadQueue   = {}
local chunkUnloadQueue = {}
-- Chunks are split into NUM_BANDS vertical slabs. Each band is its own Pine3D
-- object so the painter-algorithm sort key stays accurate near chunk borders.
local NUM_BANDS   = 4
local chunkObj    = {}
local dirtyChunks = {}   -- dirtyChunks[cx][cz] = true
local seedModel   = nil  -- any valid Pine3D model for object creation
-- Maps each Pine3D object → poly index → {x,y,z,face} for click hit-testing.
local objPolyMap  = {}   -- objPolyMap[objRef] = { [polyIdx] = {x,y,z,face} }

function world.init(deps)
	cfg=deps.config; Pine3D=deps.Pine3D; noise=deps.noise
	ThreeDFrame=deps.ThreeDFrame; objects=deps.objects
	worldId=deps.worldId; PineForge=deps.PineForge
	for _,name in ipairs(cfg.blockIds) do
		if cfg.isVanilla(name) then
			models[name]=Pine3D.loadModel("models/"..name)
			if not seedModel then seedModel=models[name] end
		end
	end
end

function world.refreshModModels()
	for fullId,bd in pairs(cfg.modBlocks) do models[fullId]=bd.model end
end

local function getModel(id) return models[id] end
function world.setWorldId(id, worldData)
	worldId = id
	if worldData then
		cfg.seed              = worldData.seed              or cfg.seed
		cfg.chunkSize         = worldData.chunkSize         or cfg.chunkSize
		cfg.maxHeightTerrain  = worldData.maxHeightTerrain  or cfg.maxHeightTerrain
		cfg.maxHeightChunk    = worldData.maxHeightChunk    or cfg.maxHeightChunk
		cfg.terrainSmoothness = worldData.terrainSmoothness or cfg.terrainSmoothness
	end
end

-- face → { triA, triB } index pairs
local FACE_IDX={bottom={1,2},top={3,4},north={5,6},south={7,8},east={9,10},west={11,12}}

local function getFaceColors(id,face)
	local m=getModel(id)
	if not m then return colors.white,colors.gray end
	local idx=FACE_IDX[face]
	local l=m[idx[1]] and m[idx[1]].c or colors.white
	local d=m[idx[2]] and m[idx[2]].c or colors.gray
	if type(l)~="number" then l=colors.white end
	if type(d)~="number" then d=colors.gray end
	return l,d
end

local function buildFace(face,x,y,z,ox,oy,oz,l,d)
	local lx,ly,lz = x-ox, y-oy, z-oz
	local x0,y0,z0 = lx-0.5, ly-0.5, lz-0.5
	local x1,y1,z1 = lx+0.5, ly+0.5, lz+0.5
	if face=="top" then
		return {x1=x0,y1=y1,z1=z0,x2=x0,y2=y1,z2=z1,x3=x1,y3=y1,z3=z1,c=l},
		       {x1=x0,y1=y1,z1=z0,x2=x1,y2=y1,z2=z1,x3=x1,y3=y1,z3=z0,c=d}
	elseif face=="bottom" then
		return {x1=x0,y1=y0,z1=z0,x2=x1,y2=y0,z2=z0,x3=x1,y3=y0,z3=z1,c=l},
		       {x1=x0,y1=y0,z1=z0,x2=x1,y2=y0,z2=z1,x3=x0,y3=y0,z3=z1,c=d}
	elseif face=="north" then
		return {x1=x0,y1=y0,z1=z0,x2=x0,y2=y0,z2=z1,x3=x0,y3=y1,z3=z0,c=l},
		       {x1=x0,y1=y1,z1=z0,x2=x0,y2=y0,z2=z1,x3=x0,y3=y1,z3=z1,c=d}
	elseif face=="south" then
		return {x1=x1,y1=y0,z1=z0,x2=x1,y2=y1,z2=z0,x3=x1,y3=y1,z3=z1,c=l},
		       {x1=x1,y1=y0,z1=z0,x2=x1,y2=y1,z2=z1,x3=x1,y3=y0,z3=z1,c=d}
	elseif face=="east" then
		return {x1=x0,y1=y0,z1=z0,x2=x1,y2=y1,z2=z0,x3=x1,y3=y0,z3=z0,c=l},
		       {x1=x0,y1=y0,z1=z0,x2=x0,y2=y1,z2=z0,x3=x1,y3=y1,z3=z0,c=d}
	elseif face=="west" then
		return {x1=x0,y1=y0,z1=z1,x2=x1,y2=y0,z2=z1,x3=x0,y3=y1,z3=z1,c=l},
		       {x1=x1,y1=y0,z1=z1,x2=x1,y2=y1,z2=z1,x3=x0,y3=y1,z3=z1,c=d}
	end
end

local function exposed(x,y,z,face)
	if face=="top"    then return not(grid[x] and grid[x][y+1] and grid[x][y+1][z]) end
	if face=="bottom" then return y>0 and not(grid[x] and grid[x][y-1] and grid[x][y-1][z]) end
	if face=="north"  then return not(grid[x-1] and grid[x-1][y] and grid[x-1][y][z]) end
	if face=="south"  then return not(grid[x+1] and grid[x+1][y] and grid[x+1][y][z]) end
	if face=="east"   then return not(grid[x] and grid[x][y] and grid[x][y][z-1]) end
	if face=="west"   then return not(grid[x] and grid[x][y] and grid[x][y][z+1]) end
end

local FACES={"top","bottom","north","south","east","west"}

function world.buildChunkMesh(cx,cz)
	local cs  = cfg.chunkSize
	local mhc = cfg.maxHeightChunk

	local centerX = cx*cs + cs*0.5 + 0.5
	local centerZ = cz*cs + cs*0.5 + 0.5

	local bandH = math.ceil((mhc + 1) / NUM_BANDS)   -- rows per band

	local bandPolys    = {}
	local bandPolyInfo = {}
	for b = 1, NUM_BANDS do
		bandPolys[b]    = {}
		bandPolyInfo[b] = {}
	end

	for a = 1, cs do
		local wx = cx*cs + a
		local gx = grid[wx]
		if gx then
			local lastBand = 0
			local oy, bp, bi = 0, nil, nil
			for y = 0, mhc do
				local gy = gx[y]
				if gy then
					local band = math.min(NUM_BANDS, math.floor(y / bandH) + 1)
					if band ~= lastBand then
						local bandMin = (band-1)*bandH
						local bandMax = math.min(mhc, band*bandH - 1)
						oy       = (bandMin + bandMax) * 0.5
						bp       = bandPolys[band]
						bi       = bandPolyInfo[band]
						lastBand = band
					end

					for b2 = 1, cs do
						local wz  = cz*cs + b2
						local blk = gy[wz]
						if blk then
							local id = blk.originalModel
							for _, face in ipairs(FACES) do
								if exposed(wx, y, wz, face) then
									local l, d = getFaceColors(id, face)
									local tA, tB = buildFace(face, wx, y, wz, centerX, oy, centerZ, l, d)
									bp[#bp+1] = tA
									bp[#bp+1] = tB
									bi[#bi+1] = {x=wx, y=y, z=wz, face=face}
									bi[#bi+1] = {x=wx, y=y, z=wz, face=face}
								end
							end
						end
					end
				end
			end
		end
	end

	if not chunkObj[cx]       then chunkObj[cx]       = {} end
	if not chunkObj[cx][cz]   then chunkObj[cx][cz]   = {} end

	for band = 1, NUM_BANDS do
		local bandMin = (band-1)*bandH
		local bandMax = math.min(mhc, band*bandH - 1)
		local oy      = (bandMin + bandMax) * 0.5

		local obj = chunkObj[cx][cz][band]
		if not obj then
			if seedModel then
				obj = ThreeDFrame:newObject(seedModel, centerX, oy, centerZ)
				chunkObj[cx][cz][band] = obj
				objects[#objects+1]    = obj
			end
		else
			obj[1] = centerX
			obj[2] = oy
			obj[3] = centerZ
		end

		if obj then
			obj:setModel(bandPolys[band])
			objPolyMap[obj] = bandPolyInfo[band]
		end
	end
end


function world.getPolyBlockInfo(obj, polyIdx)
	local pm = objPolyMap[obj]
	if not pm then return nil end
	return pm[polyIdx]
end

function world.markChunkDirty(cx,cz)
	if not dirtyChunks[cx] then dirtyChunks[cx]={} end
	dirtyChunks[cx][cz]=true
end

function world.flushDirtyChunks()
	for cx,row in pairs(dirtyChunks) do
		for cz in pairs(row) do
			if loadedChunks[cx] and loadedChunks[cx][cz] then
				world.buildChunkMesh(cx,cz)
			end
		end
	end
	dirtyChunks={}
end

function world.flushOneDirtyChunk()
	for cx,row in pairs(dirtyChunks) do
		for cz in pairs(row) do
			dirtyChunks[cx][cz]=nil
			if loadedChunks[cx] and loadedChunks[cx][cz] then
				world.buildChunkMesh(cx,cz); return true
			end
		end
	end
	return false
end

local function chunkOf(x,z)
	local cs=cfg.chunkSize
	return math.floor((x-1)/cs),math.floor((z-1)/cs)
end

local function dirty(x,z)
	local cs=cfg.chunkSize
	local cx,cz=chunkOf(x,z)
	world.markChunkDirty(cx,cz)
	local lx=(x-1)%cs; local lz=(z-1)%cs
	if lx==0      then world.markChunkDirty(cx-1,cz) end
	if lx==cs-1   then world.markChunkDirty(cx+1,cz) end
	if lz==0      then world.markChunkDirty(cx,cz-1) end
	if lz==cs-1   then world.markChunkDirty(cx,cz+1) end
end

function world.setBlock(x,y,z,id)
	if not grid[x] then grid[x]={} end
	if not grid[x][y] then grid[x][y]={} end
	if grid[x][y][z] then return end
	grid[x][y][z]={originalModel=id or "dirt"}
	dirty(x,z)
end

function world.getBlock(x,y,z)
	return grid[x] and grid[x][y] and grid[x][y][z] or nil
end

function world.removeBlock(x,y,z)
	local blk=world.getBlock(x,y,z)
	if not blk then return end
	local rid=blk.originalModel
	grid[x][y][z]=nil
	dirty(x,z)
	if PineForge then PineForge.fire("blockBreak",x,y,z,rid) end
end

function world.replaceBlock(x,y,z,id)
	if grid[x] and grid[x][y] then grid[x][y][z]=nil end
	world.setBlock(x,y,z,id)
end

function world.placeBlock(x,y,z,id)
	world.setBlock(x,y,z,id)
	world.flushDirtyChunks()
	if PineForge then PineForge.fire("blockPlace",x,y,z,id) end
end

function world.breakBlock(x,y,z)
	world.removeBlock(x,y,z)
	world.flushDirtyChunks()
end

local function generateChunk(chunkX,chunkZ)
	local cs=cfg.chunkSize; local mhT=cfg.maxHeightTerrain
	local seed=cfg.seed
	math.randomseed(seed)
	local mapNoise=noise.createNoise(cs,chunkX,chunkZ,seed,cfg.terrainSmoothness)
	local wh=0.3*mhT
	for a=1,cs do
		for b=1,cs do
			local hr=mapNoise[a][b]*mhT
			local h=math.floor(hr)
			if hr<wh then
				for y=0,h-2 do world.setBlock(chunkX*cs+a,y,chunkZ*cs+b,"dirt") end
				if h-1>=0 then world.setBlock(chunkX*cs+a,h-1,chunkZ*cs+b,"sand") end
				for y=h,math.floor(wh) do world.setBlock(chunkX*cs+a,y,chunkZ*cs+b,"water") end
			else
				for y=0,h-1 do world.setBlock(chunkX*cs+a,y,chunkZ*cs+b,"dirt") end
				if h==math.floor(wh) then world.setBlock(chunkX*cs+a,h,chunkZ*cs+b,"sand")
				else world.setBlock(chunkX*cs+a,h,chunkZ*cs+b,"grass") end
			end
		end
	end
	local tc=math.max(1,math.random(1,cs*cs*0.005))
	for _=1,tc do
		local a=math.random(3,cs-2); local b=math.random(3,cs-2)
		local x=chunkX*cs+a; local z=chunkZ*cs+b
		local py=mhT+1
		while not world.getBlock(x,py-1,z) do py=py-1 end
		if world.getBlock(x,py-1,z).originalModel=="grass" then
			local ht=math.random(1,3)
			for y=py,py+ht+1 do world.setBlock(x,y,z,"wood") end
			for tx=x-2,x+2 do for tz=z-2,z+2 do for ty=py+ht,py+ht+1 do
				if not world.getBlock(tx,ty,tz) then
					if not(tx==x-2 and tz==z-2 or tx==x+2 and tz==z-2 or
					       tx==x+2 and tz==z+2 or tx==x-2 and tz==z+2)
					   or math.random(1,2)==1 then
						world.setBlock(tx,ty,tz,"leaves")
					end
				end
			end end end
			for tx=x-1,x+1 do for tz=z-1,z+1 do for ty=py+ht+2,py+ht+3 do
				if not world.getBlock(tx,ty,tz) then
					if not(tx~=x and tz~=z and ty==py+ht+3) or math.random(1,3)==1 then
						world.setBlock(tx,ty,tz,"leaves")
					end
				end
			end end end
		end
	end
	if PineForge then
		local function gS(x,y,z,id) if y>=0 and y<=cfg.maxHeightChunk then world.setBlock(x,y,z,id) end end
		local function gR(x,y,z,id) if y>=0 and y<=cfg.maxHeightChunk then world.replaceBlock(x,y,z,id) end end
		local function gD(x,y,z)    if y>=0 and y<=cfg.maxHeightChunk then world.removeBlock(x,y,z) end end
		local function gG(x,y,z) local b=world.getBlock(x,y,z); return b and{name=b.originalModel} or nil end
		PineForge.fire("worldGen",chunkX,chunkZ,mapNoise,gS,gG,gR,gD)
	end
end

local function unloadChunk(x,z)
	if not(loadedChunks[x] and loadedChunks[x][z]) then return false end
	local cs=cfg.chunkSize
	local enc={}; local le={}; local ld={}; local lc=0
	local LC="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	local function glc(id)
		if cfg.isVanilla(id) then return cfg.idEncode[id] end
		if not le[id] then lc=lc+1; local ch=LC:sub(lc,lc)
			if ch=="" then error("too many mod block types") end
			le[id]=ch; ld[ch]=id end
		return le[id]
	end
	local lc2=""; local cc=0
	local function fl()
		if cc==0 then return end
		enc[#enc+1]=cc==1 and lc2 or (cc..lc2); cc=0
	end
	for a=1,cs do
		local gx=grid[x*cs+a]
		if gx then
			for y=0,cfg.maxHeightChunk do
				local gy=gx[y]
				if gy then
					for b=1,cs do
						local blk=gy[z*cs+b]; local ch="a"
						if blk then ch=glc(blk.originalModel); gy[z*cs+b]=nil end
						if ch==lc2 then cc=cc+1 else fl(); lc2=ch; cc=1 end
					end
				else
					if lc2=="a" then cc=cc+cs else fl(); lc2="a"; cc=cs end
				end
			end
		else
			local ac=cfg.maxHeightChunk*cs
			if lc2=="a" then cc=cc+ac else fl(); lc2="a"; cc=ac end
		end
	end
	fl()
	local hl={tostring(cs),tostring(cfg.maxHeightChunk)}
	local me={}; for ch,id in pairs(ld) do me[#me+1]=ch.."="..id end
	if #me>0 then hl[#hl+1]="MOD_BLOCKS:"..#me; for _,e in ipairs(me) do hl[#hl+1]=e end end
	hl[#hl+1]=table.concat(enc)
	local f=fs.open("worlds/"..worldId.."/chunk_"..x..","..z..".txt","w")
	f.write(table.concat(hl,"\n")); f.close()
	if chunkObj[x] and chunkObj[x][z] then
		local bands = chunkObj[x][z]
		for band = 1, NUM_BANDS do
			local old = bands[band]
			if old then
				for i = #objects, 1, -1 do
					if objects[i] == old then table.remove(objects, i); break end
				end
				objPolyMap[old] = nil
			end
		end
		chunkObj[x][z] = nil
	end
	loadedChunks[x][z]=nil
	if PineForge then PineForge.fire("chunkUnload",x,z) end
	return true
end

local function loadChunkFromRaw(raw,chunkX,chunkZ)
	local lines={}; for l in raw:gmatch("[^\n]+") do lines[#lines+1]=l end
	local cs=tonumber(lines[1]); local ch=tonumber(lines[2])
	local ld={}; local di=3
	if lines[3] and lines[3]:sub(1,11)=="MOD_BLOCKS:" then
		local count=tonumber(lines[3]:sub(12)); di=3+count+1
		for i=1,count do local e=lines[3+i]; if e then local c,id=e:match("^(.)=(.+)$")
			if c and id then ld[c]=id end end end
	end
	local rle=lines[di] or ""; local bl={}; local i=1; local nc=""
	while i<=#rle do
		local c=rle:sub(i,i); local n=tonumber(c)
		if n then nc=nc..n
		else local id=c=="a" and "air" or ld[c] or cfg.idDecode[c]
			local cnt=1; if #nc>0 then cnt=tonumber(nc); nc="" end
			for _=1,cnt do bl[#bl+1]=id end
		end
		i=i+1
	end
	local idx=1
	for a=1,cs do for y=0,ch do for b=1,cs do
		local id=bl[idx]; if id and id~="air" then
			world.setBlock(chunkX*cs+a,y,chunkZ*cs+b,id) end
		idx=idx+1
	end end end
end

local function loadChunk(x,z,camera)
	if loadedChunks[x] and loadedChunks[x][z] then return false end
	local rd=cfg.renderDistance; local cs=cfg.chunkSize
	local px=math.floor(camera.x/cs); local pz=math.floor(camera.z/cs)
	if x<px-rd or x>px+rd or z<pz-rd or z>pz+rd then return false end
	local fp="worlds/"..worldId.."/chunk_"..x..","..z..".txt"
	local f=fs.open(fp,"r")
	if not f then generateChunk(x,z)
	else local r=f.readAll(); f.close(); loadChunkFromRaw(r,x,z) end
	world.buildChunkMesh(x,z)
	world.markChunkDirty(x-1,z); world.markChunkDirty(x+1,z)
	world.markChunkDirty(x,z-1); world.markChunkDirty(x,z+1)
	if not loadedChunks[x] then loadedChunks[x]={} end
	loadedChunks[x][z]=true
	if PineForge then PineForge.fire("chunkLoad",x,z) end
	return true
end

local function queueChunk(x,z,t)
	if t=="load" then
		for i=#chunkUnloadQueue,1,-1 do
			if chunkUnloadQueue[i][1]==x and chunkUnloadQueue[i][2]==z then table.remove(chunkUnloadQueue,i) end
		end
		for i=1,#chunkLoadQueue do
			if chunkLoadQueue[i][1]==x and chunkLoadQueue[i][2]==z then return end
		end
		chunkLoadQueue[#chunkLoadQueue+1]={x,z}
	elseif t=="unload" then
		for i=#chunkLoadQueue,1,-1 do
			if chunkLoadQueue[i][1]==x and chunkLoadQueue[i][2]==z then
				table.remove(chunkLoadQueue,i); loadedChunks[x][z]=nil; return end
		end
		for i=1,#chunkUnloadQueue do
			if chunkUnloadQueue[i][1]==x and chunkUnloadQueue[i][2]==z then return end
		end
		chunkUnloadQueue[#chunkUnloadQueue+1]={x,z}
	end
end

function world.stepChunkQueue(camera)
	if #chunkUnloadQueue>0 then
		local t=table.remove(chunkUnloadQueue,1)
		if not unloadChunk(t[1],t[2]) then return world.stepChunkQueue(camera) end
		return true
	elseif #chunkLoadQueue>0 then
		local t=table.remove(chunkLoadQueue,1)
		if not loadChunk(t[1],t[2],camera) then return world.stepChunkQueue(camera) end
		world.flushOneDirtyChunk(); return true
	end
	return world.flushOneDirtyChunk()
end

function world.updateWorld(camera)
	local rd=cfg.renderDistance; local cs=cfg.chunkSize
	local px=math.floor(camera.x/cs); local pz=math.floor(camera.z/cs)
	for x=px-rd,px+rd do for z=pz-rd,pz+rd do
		if not loadedChunks[x] or not loadedChunks[x][z] then queueChunk(x,z,"load") end
	end end
	for x=px-rd-2,px+rd+2 do for z=pz-rd-2,pz+rd+2 do
		if x<px-rd or x>px+rd or z<pz-rd or z>pz+rd then
			if loadedChunks[x] and loadedChunks[x][z] then queueChunk(x,z,"unload") end
		end
	end end
end

function world.saveAll(camera)
	for cx,a in pairs(loadedChunks) do for cz in pairs(a) do queueChunk(cx,cz,"unload") end end
	chunkLoadQueue={}
	while world.stepChunkQueue(camera) do end
end

function world.getGrid()         return grid         end
function world.getLoadedChunks() return loadedChunks end
function world.updateBlockMesh() end

return world

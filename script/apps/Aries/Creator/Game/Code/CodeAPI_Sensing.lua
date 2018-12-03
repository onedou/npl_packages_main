--[[
Title: CodeAPI
Author(s): LiXizhi
Date: 2018/5/16
Desc: sandbox API environment
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Sensing.lua");
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/Windows/MouseEvent.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/SceneContext/SelectionManager.lua");
NPL.load("(gl)script/ide/System/Scene/Viewports/ViewportManager.lua");
local ViewportManager = commonlib.gettable("System.Scene.Viewports.ViewportManager");
local SelectionManager = commonlib.gettable("MyCompany.Aries.Game.SelectionManager");
local MouseEvent = commonlib.gettable("System.Windows.MouseEvent");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local env_imp = commonlib.gettable("MyCompany.Aries.Game.Code.env_imp");

local maxDist = 9999999999;

local function getActor_(actor, objName)
	if(objName and objName ~= "self") then
		actor = GameLogic.GetCodeGlobal():GetActorByName(objName);
	end
	return actor;
end

local function getActorEntity_(actor, objName)
	actor = getActor_(actor, objName);
	if(actor) then
		return actor:GetEntity();
	end
end


-- @param objName: another actor name or actor object, if there are multiple instances of the same actor, any collision will return true
--  "@a" means nearby players. 
--  "block" or nil means scene blocks. if number string like "62", it means given block id. 
-- @return false if actor is not touching another object. Or return the side on which the actor is touching
function env_imp:isTouching(objName)
	local actor = self.actor;
	if(not actor) then
		return;
	end

--	local actor2 = GameLogic.GetCodeGlobal():GetActorByName(objName);
--	if(actor2) then
--		if(actor:IsTouchingEntity(actor2:GetEntity())) then
--			return true;
--		end
--	end
	local entity = env_imp.GetEntity(self);
	if(entity) then
		if(objName==nil) then
			return actor:IsTouchingBlock();
		elseif(type(objName) == "string") then
			if(objName == "@a") then
				return actor:IsTouchingPlayers();
			elseif(objName == "block") then
				return actor:IsTouchingBlock();
			elseif(objName:match("^%d+$")) then
				local blockId = tonumber(objName);
				return actor:IsTouchingBlock(blockId);
			else
				return actor:IsTouchingActorByName(objName);	
			end
		elseif(type(objName) == "number") then
			return actor:IsTouchingBlock(objName);
		elseif(type(objName) == "table" and objName.GetEntity) then
			return actor:IsTouchingEntity(objName:GetEntity());
		end
	end
end


-- @param objName: another actor name, or "mouse-pointer", or "@p" for current player
-- @return in block coordinate
function env_imp:distanceTo(actorName)
	local actor = self.actor;
	if(not actor) then
		return maxDist
	end
	local dist = maxDist;
	if(actorName == "mouse-pointer") then
		local entity = env_imp.GetEntity(self);
		if(entity) then
			local result = SelectionManager:MousePickBlock(true, false, false); 
			if(result and result.blockX) then
				local x, y, z = BlockEngine:real(result.blockX, result.blockY, result.blockZ);
				dist = entity:GetDistanceSq(x,y,z);
				if(dist > 0.0000001) then
					dist = math.sqrt(dist);
				end
			end
		end
	elseif(actorName == "@p") then
		-- distance to current player
		local entity = env_imp.GetEntity(self);
		if(entity) then
			local entity2 = EntityManager.GetPlayer();
			if(entity2) then
				local x, y, z = entity2:GetPosition();
				dist = entity:GetDistanceSq(x,y,z);
				if(dist > 0.0000001) then
					dist = math.sqrt(dist);
				end
			end
		end
	else
		local actor2;
		if(type(actorName) == "string") then
			actor2 = GameLogic.GetCodeGlobal():GetActorByName(actorName);
		elseif(type(actorName) == "table") then
			actor2 = actorName;
		end
		
		if(actor2) then
			dist = actor:DistanceTo(actor2) or maxDist;
		end
	end
	if(dist < maxDist) then
		dist = BlockEngine:block_float(dist)
	end
	return dist;
end

-- @param keyname: if nil or "any", it means any key, such as "a-z", "space", "return", "escape"
-- return true or false or nil
function env_imp:isKeyPressed(keyname)
	return GameLogic.GetCodeGlobal():IsKeyPressed(keyname);
end

-- if left mouse button is down
function env_imp:isMouseDown()
	return MouseEvent:buttons() == 1;
end

-- get block position X (always integer)
-- @param objName: if nil or "self", it means the calling actor
function env_imp:getX(objName)
	local actor = self.actor;
	local entity = getActorEntity_(actor, objName);
	if(entity) then
		local bx, by, bz = entity:GetBlockPos();
		return bx;
	end
end

-- get block position Y (always integer)
function env_imp:getY(objName)
	local actor = self.actor;
	local entity = getActorEntity_(actor, objName);
	if(entity) then
		local bx, by, bz = entity:GetBlockPos();
		return by;
	end
end

-- get block position Z (always integer)
function env_imp:getZ(objName)
	local actor = self.actor;
	local entity = getActorEntity_(actor, objName);
	if(entity) then
		local bx, by, bz = entity:GetBlockPos();
		return bz;
	end
end

function env_imp:getPlayTime(objName)
	local actor = self.actor;
	if(objName and objName ~= "self") then
		actor = GameLogic.GetCodeGlobal():GetActorByName(objName);
	end
	if(actor) then
		return actor:GetTime() or 0;
	else
		return 0;
	end
end

-- facing in degrees like 180, 0
function env_imp:getFacing(objName)
	local actor = self.actor;
	local entity = getActorEntity_(actor, objName);
	local angle = entity and entity:GetFacing() or 0;
	return angle * 180 / math.pi;
end

-- get scale percentage, default to 100
function env_imp:getScale(objName)
	local actor = self.actor;
	local entity = getActorEntity_(actor, objName);
	return entity and (entity:GetScaling() or 1) * 100;
end

-- @param text: string support basic html.  
-- if nil, it will close the dialog
-- @param buttons: nil or {"button1", "button2"}
function env_imp:ask(text, buttons)
	local actor = self.actor;
	if(actor) then
		local type_;
		if(type(buttons) == "table") then
			type_ = "buttons";
		end

		NPL.load("(gl)script/ide/System/Windows/Screen.lua");
		local Screen = commonlib.gettable("System.Windows.Screen");
		local viewport = ViewportManager:GetSceneViewport();
		local offsetX = math.floor(viewport:GetMarginRight() / Screen:GetUIScaling()[1]*0.5);

		height = 200;
		if(buttons) then
			height = math.max(height, 120 + (#buttons)*30);
		end

		NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/EnterTextDialog.lua");
		local EnterTextDialog = commonlib.gettable("MyCompany.Aries.Game.GUI.EnterTextDialog");

		if(text or buttons) then
			EnterTextDialog.ShowPage(text, self.co:MakeCallbackFunc(function(result)
				GameLogic.GetCodeGlobal():SetGlobal("answer", result);
				env_imp.resume(self);
			end, true), nil, type_, buttons, {align="_ctb", x=-offsetX, y=0, width=400, height=height})
			env_imp.yield(self)
		else
			self.co:SetTimeout(0.02, function()
				EnterTextDialog.OnClose();
				env_imp.resume(self);
			end) 
			env_imp.yield(self);
		end
		env_imp.wait(self, env_imp.GetDefaultTick(self));
	end
end

-- local block time since this block is loaded.
function env_imp:getTimer()
	return self.codeblock:GetTime()
end

function env_imp:resetTimer()
	self.codeblock:ResetTime()
end

-- check and broadcast collision event
function env_imp:broadcastCollision(callbackFunc)
	local entity = env_imp.GetEntity(self);
	if(entity) then	
		entity:BroadcastCollision();
	end
end

function env_imp:registerCollisionEvent(name, callbackFunc)
	self.codeblock:RegisterCollisionEvent(name, callbackFunc);
end
--[[
Title: Code API Globals
Author(s): LiXizhi
Date: 2018/5/27
Desc: all global user-defined variables and shared global API in CodeAPI. 
Each world has a single shared global table, we allow users to list and define custom variables inside this table.
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeGlobals.lua");
local CodeGlobals = commonlib.gettable("MyCompany.Aries.Game.Code.CodeGlobals");
local _G = GameLogic.GetCodeGlobal():GetWorldGlobals();
GameLogic.GetCodeGlobal():GetCurrentMetaTable();
GameLogic.GetCodeGlobal():CreateGetTextEvent("msgname");
GameLogic.GetCodeGlobal():BroadcastStartEvent();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeUI.lua");
NPL.load("(gl)script/ide/System/Windows/Application.lua");
local Application = commonlib.gettable("System.Windows.Application");
local CodeUI = commonlib.gettable("MyCompany.Aries.Game.Code.CodeUI");
local SelectionManager = commonlib.gettable("MyCompany.Aries.Game.SelectionManager");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
local CodeGlobals = commonlib.inherit(commonlib.gettable("System.Core.ToolBase"), commonlib.gettable("MyCompany.Aries.Game.Code.CodeGlobals"));

function CodeGlobals:ctor()
	-- exposing these API to globals
	self.shared_API = {
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		tostring = tostring,
		tonumber = tonumber,
		commonlib = commonlib,
		type = type,
		unpack = unpack,
		math = { abs = math.abs, acos = math.acos, asin = math.asin, 
			  atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos, 
			  cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, 
			  fmod = math.fmod, frexp = math.frexp, huge = math.huge, 
			  ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, 
			  min = math.min, modf = math.modf, pi = math.pi, pow = math.pow, 
			  rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh, 
			  sqrt = math.sqrt, tan = math.tan, tanh = math.tanh },
		string = { byte = string.byte, char = string.char, find = string.find, 
			  format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
			  len = string.len, lower = string.lower, match = string.match, 
			  rep = string.rep, reverse = string.reverse, sub = string.sub, 
			  upper = string.upper },
		format = string.format,
		table = { insert = table.insert, maxn = table.maxn, remove = table.remove, 
			getn = table.getn,
			sort = table.sort },
		os = { clock = os.clock, difftime = os.difftime, time = os.time },
		alert = _guihelper.MessageBox, 
		real = function(bx,by,bz)
			return BlockEngine:real(bx,by,bz);
		end,
		block = function(x,y,z)
			return BlockEngine:block(x,y,z);
		end,
		select = function(block_id)
			GameLogic.SetBlockInRightHand(block_id)
		end,
		set = function(name, value)
			self:SetGlobal(name, value);
		end,
		get = function(name)
			return self:GetGlobal(name);
		end,
		hideVariable = function(name, title)
			CodeUI:HideGlobalData(name, title);
		end,
		tip = function(text, duration, color)
			return GameLogic.AddBBS("CodeGlobals", text and tostring(text), duration, color);
		end,
		-- return blockX, blockY, blockZ, block_id, side
		mousePickBlock = function(picking_dist)
			local result = SelectionManager:MousePickBlock(true, false, false, picking_dist);
			return result.blockX, result.blockY, result.blockZ, result.block_id, result.side;
		end,
		-- get block id and data at given position
		getBlock = function(x,y,z)
			return BlockEngine:GetBlockIdAndData(math.floor(x), math.floor(y), math.floor(z));
		end,
		-- set block id at given position
		setBlock = function(x,y,z, blockId, blockData)
			return BlockEngine:SetBlock(math.floor(x), math.floor(y), math.floor(z), blockId, blockData);
		end,
		-- similar to commonlib.gettable(tabNames) but in page scope.
		-- @param tabNames: table names like "models.users"
		gettable = function(tabNames)
			return commonlib.gettable(tabNames, self:GetCurrentGlobals());
		end,
		-- similar to commonlib.createtable(tabNames) but in page scope.
		-- @param tabNames: table names like "models.users"
		createtable = function (tabNames, init_params)
			return commonlib.createtable(tabNames, init_params, self:GetCurrentGlobals());
		end,
		-- same as commonlib.inherit()
		-- @param baseClass: string or table or nil
		-- @param new_class: string or table or nil
		inherit = function(baseClass, new_class, ctor)
			if(type(baseClass) == "string") then
				baseClass = commonlib.gettable(baseClass, self:GetCurrentGlobals());
			end
			if(type(new_class) == "string") then
				new_class = commonlib.gettable(new_class, self:GetCurrentGlobals());
			end
			return commonlib.inherit(baseClass, new_class, ctor);
		end
	};

	self:Reset();
end

-- call this to clear all globals to reuse this class for future use. 
function CodeGlobals:Reset()
	local curGlobals = {};
	self.curGlobals = curGlobals;
	self.cur_co = nil;

	-- look in global table first, and then in shared API. 
	local meta_table = {__index = function(tab, name)
		if(name == "__LINE__") then
			local info = debug.getinfo(2, "l")
			if(info) then
				return info.currentline;
			end
		elseif(name == "co") then
			return self.cur_co;
		elseif(name == "actor") then
			return self.cur_co and self.cur_co:GetActor();
		end
		local value = curGlobals[name];
		if(value==nil) then
			value = self.shared_API[name];
		end
		return value;
	end}
	self.curMetaTable = meta_table;

	self.text_events = {};

	self.actors = {};

	-- active code blocks
	self.codeblocks= {};

	-- clear UI if any
	CodeUI:Clear();
end

function CodeGlobals:SetCurrentCoroutine(co)
	self.cur_co = co;
end

function CodeGlobals:AddCodeBlock(codeblock)
	self.codeblocks[codeblock:GetBlockName()] = codeblock;
end

function CodeGlobals:RemoveCodeBlock(codeblock)
	if(self.codeblocks[codeblock:GetBlockName()] == codeblock) then
		self.codeblocks[codeblock:GetBlockName()] = nil;
	end
end

function CodeGlobals:GetCodeBlockByName(name)
	return self.codeblocks[name];
end

function CodeGlobals:AddActor(actor)
	self.actors[actor:GetName() or ""] = actor;
	actor:Connect("nameChanged", self, self.OnActorNameChange);
	actor:Connect("beforeRemoved", self, self.RemoveActor);
end

function CodeGlobals:RemoveActor(actor)
	if(self.actors[actor:GetName() or ""] == actor) then
		self.actors[actor:GetName() or ""] = nil;
	end
end

function CodeGlobals:OnActorNameChange(actor, oldName, newName)
	if(oldName and self.actors[oldName] == actor) then
		self.actors[oldName] = nil;
	end
	if(newName) then
		self.actors[newName] = actor;
	end
end

-- return the last added actor by name
function CodeGlobals:GetActorByName(name)
	return self.actors[name];
end

-- @param name: actor name or "@p" for current player
function CodeGlobals:FindEntityByName(name)
	local actor2 = self:GetActorByName(name);
	if(actor2) then
		return actor2:GetEntity();
	elseif(name=="@p") then
		return EntityManager.GetPlayer();
	end
end

-- all user defined variables that is shared by all blocks in the current world
function CodeGlobals:GetCurrentGlobals()
	return self.curGlobals;
end

-- @return mapping of {text, event_object}
function CodeGlobals:GetAllTextEvents()
	return self.text_events;
end

function CodeGlobals:GetTextEvent(text)
	return self.text_events[text];
end

function CodeGlobals:CreateGetTextEvent(text)
	local event = self.text_events[text];
	if(not event) then
		event = commonlib.EventSystem:new();
		self.text_events[text] = event;
	end
	return event;
end

function CodeGlobals:BroadcastStartEvent()
	self:BroadcastTextEvent("start");
end

function CodeGlobals:RegisterKeyPressedEvent(callbackFunc)
	self:CreateGetTextEvent("keyPressedEvent"):AddEventListener("msg", callbackFunc);
end

function CodeGlobals:BroadcastKeyPressedEvent(keyname, param1)
	self:SetAnyKeyDown(true);
	local event = self:GetTextEvent("keyPressedEvent");
	if(event) then
		return event:DispatchEvent({type="msg", keyname = keyname, param1 = param1});
	end
end

function CodeGlobals:UnregisterKeyPressedEvent(callbackFunc)
	self:UnregisterTextEvent("keyPressedEvent", callbackFunc)
end

function CodeGlobals:RegisterBlockClickEvent(callbackFunc)
	self:CreateGetTextEvent("onBlockClicked"):AddEventListener("msg", callbackFunc);
end

function CodeGlobals:BroadcastBlockClickEvent(blockid)
	local event = self:GetTextEvent("onBlockClicked");
	if(event) then
		local result = SelectionManager:MousePickBlock();
		if(result and result.block_id and result.block_id>0 and result.blockX) then
			return event:DispatchEvent({type="msg", blockid = result.block_id, param1 = {
				blockid = result.block_id,
				x = result.blockX, y = result.blockY, z = result.blockZ, side = result.side
			}});
		end
	end
end

function CodeGlobals:UnregisterBlockClickEvent(callbackFunc)
	self:UnregisterTextEvent("onBlockClicked", callbackFunc)
end

function CodeGlobals:HandleGameEvent(event)
	local textEvent = self:GetTextEvent(event:GetType());
	if(textEvent) then
		local msg = event.msg;
		if(not msg) then
			local trigger_entity = EntityManager.GetLastTriggerEntity();
			if(trigger_entity) then
				-- if no message body is provided, we will send the triggering entity name
				-- this is useful to get the source entity's name, such as a network player
				msg = trigger_entity:GetName();
			end
		end
		
		if(event.cmd_text and event.cmd_text~="") then
			msg = event.cmd_text;
		end

		textEvent:DispatchEvent({type="msg", msg = msg,});
	end
end

function CodeGlobals:BroadcastTextEvent(text, msg, onFinishedCallback)
	local event = self:GetTextEvent(text);
	if(event) then
		if(onFinishedCallback) then
			local nHandlerCount = event:GetEventHandlerCount("msg");
			if(nHandlerCount > 1) then
				local oldCallback = onFinishedCallback;
			
				local nCount = 0;
				onFinishedCallback = function()
					nCount = nCount + 1;
					if(nHandlerCount == nCount) then
						oldCallback();
					end
				end;
			end
		end
		event:DispatchEvent({type="msg", msg=msg, onFinishedCallback=onFinishedCallback});
	else
		if(onFinishedCallback) then
			onFinishedCallback();
		end
	end
end

function CodeGlobals:RegisterTextEvent(text, callbackFunc)
	self:CreateGetTextEvent(text):AddEventListener("msg", callbackFunc);
end

function CodeGlobals:UnregisterTextEvent(text, callbackFunc)
	local event = self:GetTextEvent(text);
	if(event) then
		event:RemoveEventListener("msg", callbackFunc);
	end
end

function CodeGlobals:GetCurrentMetaTable()
	return self.curMetaTable;
end

function CodeGlobals:GetSharedAPI()
	return shared_API;
end

function CodeGlobals:SetGlobal(name, value)
	if(name) then
		self:GetCurrentGlobals()[name] = value
	end
end

function CodeGlobals:GetGlobal(name)
	return name and self:GetCurrentGlobals()[name];
end

-- @param keyname: if nil or "any", it means any key, such as "a-z", "space", "return", "escape"
-- @return "DIK_A" or nil
function CodeGlobals:GetKeyNameFromString(name)
	if(name) then
		local name2 = "DIK_"..string.upper(name);
		if(name and DIK_SCANCODE[name2]) then
			return name2;
		end
	end
end

function CodeGlobals:GetStringFromKeyName(name)
	if(name) then
		return string.lower(name:gsub("^(DIK_)" ,""));
	end
end

function CodeGlobals:IsAnyKeyDown()
	return self.isAnyKeyDown;
end

function CodeGlobals:SetAnyKeyDown(bKeyDown)
	self.isAnyKeyDown = bKeyDown;
end

-- @param keyname: if nil or "any", it means any key, such as "a-z", "space", "return", "escape"
function CodeGlobals:IsKeyPressed(keyname)
	-- ignore key press when UI has focus
	-- TODO: use GetGUI()->IsKeyboardProcessed() in C++, instead of just MCML v2 control
	if(self:IsAnyKeyDown() and not Application:focusWidget()) then
		keyname = self:GetKeyNameFromString(keyname);
		if(keyname) then
			if(ParaUI.IsKeyPressed(DIK_SCANCODE[keyname])) then
				return true;
			end
		end
	end
	return false;
end
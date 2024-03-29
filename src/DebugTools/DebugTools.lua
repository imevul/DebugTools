local CONST_ADDON_NAME = 'Imevul Debug Tools'
DebugTools = LibStub('AceAddon-3.0'):NewAddon(CONST_ADDON_NAME, 'AceConsole-3.0', 'AceHook-3.0')
AceGUI = LibStub('AceGUI-3.0')

DT = DebugTools
DebugTools.excluded = ''


function DebugTools:OnInitialize()
	local defaults = {
		profile = {
			excluded = ''
		}
	}

	self.db = LibStub('AceDB-3.0'):New('IDTProfileDB', defaults, 'profile')
	self.db.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
	self.db.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
	self.db.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

	local options = {
		name = CONST_ADDON_NAME,
		handler = DebugTools,
		type = 'group',
		args = {
		},
	}
	options.args.profile = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)

	local AceConfig = LibStub('AceConfig-3.0')
	AceConfig:RegisterOptionsTable(CONST_ADDON_NAME, options, nil)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(CONST_ADDON_NAME, CONST_ADDON_NAME)

	self:registerChatCommands()
end

function DebugTools:OnEnable()
	self:RefreshConfig()
end

function DebugTools:RefreshConfig()
	self:setExcluded(self.db.profile.excluded)
end

function DebugTools:registerChatCommands()
	self:RegisterChatCommand('idt', DebugTools.handleDTCommand)
end

function DebugTools:createWindow()
	local frame = AceGUI:Create('Window')
	frame:SetTitle(CONST_ADDON_NAME)
	frame:SetWidth(1024)
	frame:SetHeight(800)
	frame:SetStatusText('...')
	frame:SetCallback('OnClose', function(widget) widget:ReleaseChildren(); AceGUI:Release(widget) end)
	frame:SetLayout('Flow')

	local searchBox = AceGUI:Create('EditBox')
	searchBox:SetLabel('Search:')
	searchBox:SetFullWidth(true)
	searchBox:SetCallback('OnEscapePressed', function(widget) widget.editbox:ClearFocus() end)
	searchBox:SetCallback('OnEnterPressed', function(widget, event, text) widget.editbox:ClearFocus(); self:search(text) end)
	frame:AddChild(searchBox)

	local container = AceGUI:Create('SimpleGroup')
	container:SetFullWidth(true)
	container:SetFullHeight(true)
	container:SetLayout('Fill')
	frame:AddChild(container)

	local function drawGroup1(tabContainer)
		self.table = Table.create(tabContainer, _G, '_G', {
			{ name = 'TYPE', size = 0.1 },
			{ name = 'INDEX', size = 0.4 },
			{ name = 'VALUE', size = 0.39 },
			{ name = 'LENGTH', size = 0.06 },
			{ name = 'ACTION', size = 0.04 },
		})
	end

	local function drawGroup2(tabContainer)
		local innerContainer = AceGUI:Create('SimpleGroup')
		innerContainer:SetFullWidth(true)
		innerContainer:SetFullHeight(true)
		innerContainer:SetLayout('Flow')
		tabContainer:AddChild(innerContainer)

		local desc = AceGUI:Create('Label')
		desc:SetText('Exclude results containing (1 per line)')
		desc:SetFullWidth(true)
		innerContainer:AddChild(desc)

		local mlEditBox = AceGUI:Create('MultiLineEditBox')
		mlEditBox:SetFullWidth(true)
		mlEditBox:SetFullHeight(true)
		mlEditBox:SetNumLines(30)
		mlEditBox:SetText(self.excluded)
		mlEditBox:SetCallback('OnEnterPressed', function(widget, event, text) DebugTools:setExcluded(text) end)
		innerContainer:AddChild(mlEditBox)
	end

	-- Callback function for OnGroupSelected
	local function SelectGroup(container, event, group)
		container:ReleaseChildren()
		self.table = nil
		if group == 'tab1' then
			drawGroup1(container)
		elseif group == 'tab2' then
			drawGroup2(container)
		end
	end

	-- Create the TabGroup
	local tab =  AceGUI:Create('TabGroup')
	tab:SetLayout('Flow')
	-- Setup which tabs to show
	tab:SetTabs({{text='Globals', value='tab1'}, {text='Settings', value='tab2'}})
	-- Register callback
	tab:SetCallback('OnGroupSelected', SelectGroup)
	-- Set initial Tab (this will fire the OnGroupSelected callback)
	tab:SelectTab('tab1')

	-- add to the frame container
	container:AddChild(tab)
end

function DebugTools.showRunDialog(path, fnc)
	if type(fnc) ~= 'function' then return end
	DebugTools.closeRunDialog()

	local inputFrame = AceGUI:Create('Frame')
	DebugTools.runDialog = inputFrame
	inputFrame:SetWidth(360)
	inputFrame:SetHeight(80)
	inputFrame:SetLayout('List')
	inputFrame:SetCallback('OnClose', DebugTools.closeRunDialog)

	local label = AceGUI:Create('Label')
	label:SetText(path .. '(...)')
	inputFrame:AddChild(label)

	local inputField = AceGUI:Create('EditBox')
	inputFrame:AddChild(inputField)
	inputField:SetCallback('OnEscapePressed', DebugTools.closeRunDialog)
	inputField:SetCallback('OnEnterPressed', function(_, _, text)
		DebugTools.closeRunDialog()
		local params = DebugToolsHelpers.stringSplit(text, ',')

		local status, ret = pcall(fnc, unpack(params))

		if status then
			if type(ret) == 'table' then
				DebugTools.printTable(ret)
			else
				print(tostring(ret))
			end
		else
			print('|c00ff0000An error occurred: |r', ret)
		end
	end)
	inputField.editbox:SetFocus()
end

function DebugTools.closeRunDialog()
	if DebugTools.runDialog then
		local tmp = DebugTools.runDialog
		DebugTools.runDialog = nil
		tmp:Release()
	end
end

function DebugTools:isExcluded(text)
	if self.excluded:match(text) then
		return true
	end

	return false
end

function DebugTools:addExclude(text)
	if self:isExcluded(text) then return end

	self:setExcluded(self.excluded .. text .. "\n")
end

function DebugTools:setExcluded(text)
	self.excluded = text
	self.db.profile.excluded = text
end

function DebugTools.handleDTCommand()
	DebugTools:createWindow()
end

function DebugTools:search(text)
	if self.table then
		self.table:setFilter(text)
	end
end

function DebugTools.printTable(tbl)
	if not tbl then
		return
	end

	if type(tbl) == 'table' then
		for k, v in pairs(tbl) do
			print("[" .. tostring(k) .. "]" .. ": '" .. tostring(v) .. "' (" .. type(v) .. ")")
		end
	else
		print(tostring(tbl))
	end
end

function DebugTools.filter(tbl, key, value, invert)
	local res = {}
	if type(tbl) ~= 'table' then return tbl end

	for k, v in pairs(tbl) do
		if key ~= nil then
			if type(key) == 'string' or type(key) == 'number' then
				if k == key or (type(k) == 'string' and k:match(key)) then
					if not invert then
						res[k] = v
					end
				else
					if invert then
						res[k] = v
					end
				end
			elseif type(key) == 'table' then
				local match = false
				for _, key2 in ipairs(key) do
					if k == key2 or (type(k) == 'string' and k:match(key2)) then
						match = true
						break
					end
				end

				if (match and not invert) or (not match and invert) then
					res[k] = v
				end
			else
				if not invert then
					res[k] = v
				end
			end
		end

		if value ~= nil then
			if v == value or (type(v) == 'string' and v:match(value)) then
				if not invert then
					res[k] = v
				end
			else
				if invert then
					res[k] = v
				end
			end
		end
	end

	return res
end

function DebugTools.getItemInfo(itemId)
	local _, link = GetItemInfo(itemId)
	if not link then
		GameTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0:0:0:0:0")
	end

	return link
end

function DebugTools.printMythics(from, to)
	for itemId = from, to, 1 do
		print(tostring(itemId) .. ': ' .. tostring(DebugTools.getItemInfo(itemId)))
	end
end

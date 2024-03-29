Table = {}
Table.__index = Table

Row = {}
Row.__index = Row

Column = {}
Column.__index = Column

function Table.create(parent, data, name, columns)
	local table = {
		name = name,
		data = data,
		filter = nil,
		state = {},
		columns = columns
	}

	local topContainer = AceGUI:Create('SimpleGroup')
	table.topContainer = topContainer
	topContainer:SetFullWidth(true)
	topContainer:SetFullHeight(true)
	topContainer:SetLayout('Flow')
	parent:AddChild(topContainer)

	local toolbar = AceGUI:Create('SimpleGroup')
	toolbar:SetFullWidth(true)
	toolbar:SetLayout('Flow')
	topContainer:AddChild(toolbar)

	local pathDisplay = AceGUI:Create('SimpleGroup')
	table.pathDisplay = pathDisplay
	pathDisplay:SetRelativeWidth(0.9)
	pathDisplay:SetLayout('Flow')
	toolbar:AddChild(pathDisplay)

	local refreshButton = AceGUI:Create('Button')
	table.refreshButton = refreshButton
	refreshButton:SetText('Refresh')
	refreshButton:SetRelativeWidth(0.09)
	toolbar:AddChild(refreshButton)

	local headerContainer = AceGUI:Create('SimpleGroup')
	table.headerContainer = headerContainer
	headerContainer:SetFullWidth(true)
	headerContainer:SetLayout('Flow')
	topContainer:AddChild(headerContainer)

	local separator = AceGUI:Create('Heading')
	separator:SetText('')
	separator:SetFullWidth(true)
	topContainer:AddChild(separator)

	local scrollContainer = AceGUI:Create('SimpleGroup')
	topContainer:AddChild(scrollContainer)
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetFullHeight(true)
	--scrollContainer:SetAutoAdjustHeight(true)
	scrollContainer:SetLayout('Fill')

	local scrollFrame = AceGUI:Create('ScrollFrame')
	table.scrollFrame = scrollFrame
	scrollFrame:SetFullWidth(true)
	scrollFrame:SetFullHeight(true)
	scrollFrame:SetLayout('Flow')
	scrollContainer:AddChild(scrollFrame)

	local container = AceGUI:Create('SimpleGroup')
	table.container = container
	container:SetFullWidth(true)
	container:SetFullHeight(true)
	container:SetLayout('List')
	scrollFrame:AddChild(container)

	table = setmetatable(table, Table)
	table:addHeader(table.columns)
	table:refreshPath()
	refreshButton:SetCallback('OnClick', table:onRefresh())
	table:refresh()

	return table
end

function Table:onRefresh()
	return function()
		self:refresh()
	end
end

function Table:refresh()
	self:loadData(self:getPathData())
end

function Table:onSetFilter()
	return function(text)
		self:setFilter(text)
	end
end

function Table:setFilter(text)
	if text == '' then text = nil end
	self.filter = text
	self:refresh()
end

function Table:filterData(data)
	if self.filter and type(data) == 'table' then
		data = DebugTools.filter(data, self.filter)
	end

	local excluded = DebugToolsHelpers.stringSplit(DebugTools.excluded, "\n")
	data = DebugTools.filter(data, excluded, nil, true)

	return data
end

function Table:popState()
	if #self.state > 0 then
		table.remove(self.state, #self.state)
		self:refreshPath()
		self:loadData(self:getPathData())
	end
end

function Table:pushState(state)
	table.insert(self.state, state)
	self:refreshPath()
end

function Table:addPathFragment(text, index)
	text = (' %s '):format(tostring(text))
	local fragment
	if index then
		fragment = AceGUI:Create('InteractiveLabel')
		fragment:SetUserData('index', index)
		fragment:SetCallback('OnClick', function(widget)
			local index = widget:GetUserData('index')
			self:loadPath(index)
		end)
		fragment:SetHighlight(1, 0.9, 0.2, 0.2)
	else
		fragment = AceGUI:Create('Label')
	end

	fragment:SetText(text)
	fragment:SetWidth(fragment.label:GetStringWidth())
	self.pathDisplay:AddChild(fragment)
end

function Table:refreshPath()
	self.pathDisplay:ReleaseChildren()

	self:addPathFragment(self.name, 0)

	for index, state in ipairs(self.state) do
		self:addPathFragment('>')
		self:addPathFragment(state, index)
	end

	self.pathDisplay:AddChild(AceGUI:Create('Label'))
end

function Table:loadPath(index)
	self:loadData(self:getPathData(index))
	
	for i = #self.state, index + 1, -1 do
		table.remove(self.state, i)
	end

	self:refreshPath()
end

function Table:getPath(index)
	local data = self.data
	if index == nil then index = #self.state end
	if index == 0 then return self.name end

	local ret = self.name
	local found = false

	for stateIndex, state in ipairs(self.state) do
		ret = ret .. '.' .. tostring(state)
		if data then data = data[state] or nil end
		if stateIndex == index then
			found = true
			break
		end
	end

	if not found then
		ret = ret .. '.' .. index
	end

	return ret
end

function Table:getPathData(index)
	local data = self.data
	if index == nil then index = #self.state end
	if index == 0 then return self:filterData(data) end

	for stateIndex, state in ipairs(self.state) do
		if data then data = data[state] or nil end
		if stateIndex == index then break end
	end

	return self:filterData(data)
end

function Table:clear()
--	self.headerContainer:ReleaseChildren()
	self.container:ReleaseChildren()
end

function Table:addRow()
	local row = {}
	local container = AceGUI:Create('SimpleGroup')
	row.container = container
	container:SetFullWidth(true)
	container:SetLayout('Flow')
	self.container:AddChild(container)

	return setmetatable(row, Row)
end

function Row:addColumn(text, relWidth, userData, onClick, color)
	local column = {}
	local container = AceGUI:Create('InteractiveLabel')
	column.container = container
	container:SetText(text)
	container:SetRelativeWidth(relWidth)

	if color then
		container:SetColor(color.r, color.g, color.b)
	end

	if userData then
		container:SetUserData(userData.index, userData.value)
	end

	if onClick then
		container:SetCallback('OnClick', onClick)
		container:SetHighlight(1, 0.9, 0.2, 0.2)
	end

	self.container:AddChild(container)

	return setmetatable(column, Column)
end

function Row:addActions(relWidth, userData, actions)
	local column = {}
	local container = AceGUI:Create('SimpleGroup')
	column.container = container
	container:SetLayout('Flow')
	container:SetRelativeWidth(relWidth)

	for _, action in ipairs(actions) do
		local aBtn = AceGUI:Create('Button')
		aBtn:SetUserData(userData.index, userData.value)
		aBtn:SetText(action.text)
		aBtn:SetCallback('OnClick', action.callback)

		if action.isDisabled and type(action.isDisabled == 'function') then
			aBtn:SetDisabled(action.isDisabled(userData.index))
		end

		container:AddChild(aBtn)
	end

	self.container:AddChild(container)

	return setmetatable(column, Column)
end

function Table:loadData(data)
	self:clear()
	self.scrollFrame:SetScroll(0)

	if type(data) == 'table' then
		local maxCount = 38
		for k, v in pairs(data) do
			self:addValue(k, v)

			maxCount = maxCount - 1
			if maxCount <= 0 then break end
		end
	elseif type(data) == 'number' or type(data) == 'string' or type(data) == 'boolean' then
		self:addValue(nil, data)
	elseif type(data) == 'function' then
		self:addValue(nil, tostring(data))
	elseif type(data) == 'userdata' then
		self:addValue(nil, tostring(data))
	elseif type(data) == 'nil' then
		self:addValue(nil, nil)
	else
		self:addValue(nil, 'Cannot display - Unknown type')
	end
end

function Table:addHeader(columns)
	local row = {}
	local container = AceGUI:Create('SimpleGroup')
	row.container = container
	container:SetFullWidth(true)
	container:SetLayout('Flow')
	self.headerContainer:AddChild(container)
	row = setmetatable(row, Row)

	for _, column in ipairs(columns) do
		row:addColumn(column.name, column.size, nil, nil, { r = 1, g = 0.9, b = 0.3 })
	end
end

function Table:addValue(index, value)
	local row = self:addRow()

	local color = nil
	local strType = type(value)
	local strValue = tostring(value)
	if strType == 'table' or strType == 'function' or strType == 'userdata' or strType == 'thread' then
		color = { r = 0.5, g = 0.5, b = 0.5 }
	end

	row:addColumn(strType, self.columns[1].size or 0.1, {index='index', value=index}, self:onSelectValue())
	row:addColumn(tostring(index), self.columns[2].size or 0.4, {index='index', value=index}, self:onSelectValue())

	local strLength = nil
	if type(value) == 'table' then
		strLength = tostring(math.max(#value, DebugToolsHelpers.tableCount(value)))
	elseif type(value) == 'string' then
		strLength = tostring(#value)
	else
		strLength = nil
	end

	row:addColumn(strValue, self.columns[3].size or 0.3, {index='index', value=index}, self:onSelectValue(), color)

	if strLength then
		row:addColumn(strLength, self.columns[4].size or 0.05, {index='index', value=index}, self:onSelectValue())
	else
		row:addColumn(strLength, self.columns[4].size or 0.05, {index='index', value=index})
	end

	row:addActions(
		self.columns[5].size or 0.05,
		{index='index', value=index},
		{
			{
				text = '!',
				isDisabled = function(index)
					return DebugTools:isExcluded(index)
				end,
				callback = function(widget, event, button)
					DebugTools:addExclude(widget:GetUserData('index'))
					self:refresh()
				end
			}
		}
	)
end

function Table:onSelectValue()
	return function(widget, _, button)
		local index = widget:GetUserData('index')
		if index then
			if button == 'LeftButton' then
				self:pushState(index)
				self:loadData(self:getPathData())
			elseif button == 'MiddleButton' then
				local data = self:getPathData()
				data = data[index]

				if type(data) == 'function' then
					DebugTools.showRunDialog(self:getPath(index), data)
					print(tostring(data))
				end
			elseif button == 'RightButton' then
				self:popState()
			end
		end
	end
end

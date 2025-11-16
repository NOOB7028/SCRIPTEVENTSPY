-- 引入必要服务
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 创建GUI容器
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterEditorGui"
screenGui.Parent = PlayerGui

-- 通用样式函数：黑色背景+圆角15（去掉描边）
local function applyButtonStyle(button)
	-- 黑色背景
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	-- 圆角15（修正为UDim类型，去掉UDim2）
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15) -- 正确类型：UDim，不是UDim2
	corner.Parent = button
end

-- 创建控制按钮（左上角）
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Text = "角色大小编辑"
toggleButton.Size = UDim2.new(0, 150, 0, 35)
toggleButton.Position = UDim2.new(0, 10, 0, 10)
toggleButton.TextColor3 = Color3.new(1, 1, 1) -- 白色文字
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextScaled = true
toggleButton.Parent = screenGui
-- 应用按钮样式（黑色+圆角，无描边）
applyButtonStyle(toggleButton)

-- 创建载体帧（改为图片标签，使用指定图片）
local containerFrame = Instance.new("ImageLabel")
containerFrame.Name = "ContainerFrame"
containerFrame.Size = UDim2.new(0, 350, 0, 400)
containerFrame.Position = UDim2.new(0, 10, 0, 55)
containerFrame.Image = "rbxassetid://6770543129"
containerFrame.ScaleType = Enum.ScaleType.Slice
containerFrame.SliceCenter = Rect.new(10, 10, 100, 100)
containerFrame.BackgroundTransparency = 1
containerFrame.BorderSizePixel = 0
containerFrame.Visible = false
-- 载体帧圆角（UDim类型修正）
local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 15) -- 正确类型
containerCorner.Parent = containerFrame
containerFrame.Parent = screenGui

-- 拖动相关变量
local isDragging = false
local dragStartPos = nil
local frameStartPos = nil
local isTouchingTitleBar = false

-- 载体帧标题栏（拖动区域）
local titleBar = Instance.new("TextButton")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.4)
titleBar.Text = ""
titleBar.BorderSizePixel = 0
-- 标题栏圆角（上半部分，UDim类型修正）
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 15) -- 正确类型
titleCorner.Parent = titleBar
titleBar.Parent = containerFrame

-- 标题文本
local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "角色部件大小编辑（拖动标题栏移动）"
titleLabel.Size = UDim2.new(1, -10, 1, 0)
titleLabel.Position = UDim2.new(0, 5, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextScaled = true
titleLabel.Parent = titleBar

-- 添加滚动框（滑动条大小适配内容）
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Name = "ScrollingFrame"
scrollingFrame.Size = UDim2.new(1, -20, 1, -45)
scrollingFrame.Position = UDim2.new(0, 10, 0, 35)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.ScrollBarThickness = 6
scrollingFrame.ScrollBarImageColor3 = Color3.new(0, 0, 0)
scrollingFrame.ScrollBarImageTransparency = 0.3
-- 滑动条圆角（UDim类型修正）
local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 3) -- 正确类型
scrollCorner.Parent = scrollingFrame
scrollingFrame.Parent = containerFrame

-- 列表布局（自动计算内容大小）
local listLayout = Instance.new("UIListLayout")
listLayout.Name = "ListLayout"
listLayout.Padding = UDim.new(0, 10)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = scrollingFrame

-- 列表约束
local listConstraint = Instance.new("UISizeConstraint")
listConstraint.MaxSize = Vector2.new(320, math.huge)
listConstraint.Parent = scrollingFrame

-- 刷新角色部件列表
local function refreshCharacterList()
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local character = LocalPlayer.Character
	if not character then return end

	local validParts = {}
	for _, instance in ipairs(character:GetDescendants()) do
		if instance:IsA("BasePart") or instance:IsA("MeshPart") or instance:IsA("UnionOperation") then
			table.insert(validParts, instance)
		end
	end

	local partCount = #validParts
	local maxVisibleParts = 5
	local itemHeight = 80
	if partCount <= maxVisibleParts then
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, partCount * (itemHeight + listLayout.Padding.Offset))
	else
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, maxVisibleParts * (itemHeight + listLayout.Padding.Offset))
	end

	for _, instance in ipairs(validParts) do
		local itemFrame = Instance.new("Frame")
		itemFrame.Name = "ItemFrame_" .. instance.Name
		itemFrame.Size = UDim2.new(1, 0, 0, itemHeight)
		itemFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
		itemFrame.BorderSizePixel = 1
		itemFrame.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
		-- 条目圆角（UDim类型修正）
		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 8) -- 正确类型
		itemCorner.Parent = itemFrame
		itemFrame.Parent = scrollingFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text = instance.Name .. " (" .. instance.ClassName .. ")"
		nameLabel.Size = UDim2.new(1, 0, 0, 25)
		nameLabel.Position = UDim2.new(0, 5, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.SourceSans
		nameLabel.TextScaled = true
		nameLabel.Parent = itemFrame

		local sizeLabel = Instance.new("TextLabel")
		sizeLabel.Text = "大小 (X, Y, Z):"
		sizeLabel.Size = UDim2.new(0, 100, 0, 25)
		sizeLabel.Position = UDim2.new(0, 5, 0, 35)
		sizeLabel.BackgroundTransparency = 1
		sizeLabel.TextColor3 = Color3.new(1, 1, 1)
		sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
		sizeLabel.Parent = itemFrame

		-- X轴输入
		local xInput = Instance.new("TextBox")
		xInput.PlaceholderText = "X"
		xInput.Text = tostring(instance.Size.X)
		xInput.Size = UDim2.new(0, 60, 0, 25)
		xInput.Position = UDim2.new(0, 110, 0, 35)
		xInput.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
		xInput.TextColor3 = Color3.new(1, 1, 1)
		xInput.TextXAlignment = Enum.TextXAlignment.Center
		local xCorner = Instance.new("UICorner")
		xCorner.CornerRadius = UDim.new(0, 5) -- 正确类型
		xCorner.Parent = xInput
		xInput.Parent = itemFrame

		-- Y轴输入
		local yInput = Instance.new("TextBox")
		yInput.PlaceholderText = "Y"
		yInput.Text = tostring(instance.Size.Y)
		yInput.Size = UDim2.new(0, 60, 0, 25)
		yInput.Position = UDim2.new(0, 180, 0, 35)
		yInput.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
		yInput.TextColor3 = Color3.new(1, 1, 1)
		yInput.TextXAlignment = Enum.TextXAlignment.Center
		local yCorner = Instance.new("UICorner")
		yCorner.CornerRadius = UDim.new(0, 5) -- 正确类型
		yCorner.Parent = yInput
		yInput.Parent = itemFrame

		-- Z轴输入
		local zInput = Instance.new("TextBox")
		zInput.PlaceholderText = "Z"
		zInput.Text = tostring(instance.Size.Z)
		zInput.Size = UDim2.new(0, 60, 0, 25)
		zInput.Position = UDim2.new(0, 250, 0, 35)
		zInput.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
		zInput.TextColor3 = Color3.new(1, 1, 1)
		zInput.TextXAlignment = Enum.TextXAlignment.Center
		local zCorner = Instance.new("UICorner")
		zCorner.CornerRadius = UDim.new(0, 5) -- 正确类型
		zCorner.Parent = zInput
		zInput.Parent = itemFrame

		-- 应用按钮
		local applyButton = Instance.new("TextButton")
		applyButton.Text = "应用大小"
		applyButton.Size = UDim2.new(0, 100, 0, 25)
		applyButton.Position = UDim2.new(0, 110, 0, 60)
		applyButton.TextColor3 = Color3.new(1, 1, 1)
		applyButton.Parent = itemFrame
		-- 应用按钮样式（黑色+圆角，无描边）
		applyButtonStyle(applyButton)

		-- 应用按钮事件
		applyButton.MouseButton1Click:Connect(function()
			local x = tonumber(xInput.Text)
			local y = tonumber(yInput.Text)
			local z = tonumber(zInput.Text)

			if x and y and z and x > 0 and y > 0 and z > 0 then
				instance.Size = Vector3.new(x, y, z)
				xInput.Text = tostring(instance.Size.X)
				yInput.Text = tostring(instance.Size.Y)
				zInput.Text = tostring(instance.Size.Z)
			else
				xInput.Text = tostring(instance.Size.X)
				yInput.Text = tostring(instance.Size.Y)
				zInput.Text = tostring(instance.Size.Z)
			end
		end)
	end
end

-- 拖动逻辑
local function startDrag(inputPos)
	local pos2D = Vector2.new(inputPos.X, inputPos.Y)
	isDragging = true
	dragStartPos = pos2D
	frameStartPos = containerFrame.Position
	titleBar.BackgroundColor3 = Color3.new(0.3, 0.3, 0.5)
end

local function endDrag()
	isDragging = false
	isTouchingTitleBar = false
	titleBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.4)
end

local function updateDrag(inputPos)
	local pos2D = Vector2.new(inputPos.X, inputPos.Y)
	if isDragging and dragStartPos and frameStartPos then
		local delta = pos2D - dragStartPos
		local newPos = UDim2.new(
			frameStartPos.X.Scale,
			frameStartPos.X.Offset + delta.X,
			frameStartPos.Y.Scale,
			frameStartPos.Y.Offset + delta.Y
		)
		local screenSize = workspace.CurrentCamera.ViewportSize
		newPos = UDim2.new(
			0, math.clamp(newPos.X.Offset, 0, screenSize.X - containerFrame.AbsoluteSize.X),
			0, math.clamp(newPos.Y.Offset, 0, screenSize.Y - containerFrame.AbsoluteSize.Y)
		)
		containerFrame.Position = newPos
	end
end

-- 检查位置是否在标题栏内
local function isPositionInTitleBar(pos)
	local titleBarPos = titleBar.AbsolutePosition
	local titleBarSize = titleBar.AbsoluteSize
	local pos2D = Vector2.new(pos.X, pos.Y)
	return pos2D.X >= titleBarPos.X 
		and pos2D.X <= titleBarPos.X + titleBarSize.X
		and pos2D.Y >= titleBarPos.Y 
		and pos2D.Y <= titleBarPos.Y + titleBarSize.Y
end

-- 鼠标事件
titleBar.MouseButton1Down:Connect(function(x, y)
	startDrag(Vector2.new(x, y))
end)

-- 统一处理输入
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		endDrag()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
		updateDrag(input.Position)
	elseif input.UserInputType == Enum.UserInputType.Touch and isDragging then
		updateDrag(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		local touchPos = Vector2.new(input.Position.X, input.Position.Y)
		if isPositionInTitleBar(touchPos) then
			isTouchingTitleBar = true
			startDrag(touchPos)
		end
	end
end)

-- 按钮点击事件
toggleButton.MouseButton1Click:Connect(function()
	containerFrame.Visible = not containerFrame.Visible
	if containerFrame.Visible then
		refreshCharacterList()
	end
end)

-- 角色加载事件
LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)
	if containerFrame.Visible then
		refreshCharacterList()
	end
end)

-- 初始检查
if LocalPlayer.Character then
	refreshCharacterList()
end

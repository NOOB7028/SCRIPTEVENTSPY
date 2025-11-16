local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OPEN_MENU_KEY = "G"
local MAIN_IMAGE_ID = "rbxassetid://159420929"
local MENU_BUTTON_IMAGE_ID = "rbxassetid://22328718"
local BUTTON_FONT = Enum.Font.SourceSansBold
local TITLE_TEXT = "EventSpy"
local EVENT_LIST_PADDING = UDim.new(0, 8)
local SCROLL_BAR_THICKNESS = 6
local TIP_SPACING = 8

local localPlayer = Players.LocalPlayer
while not localPlayer do
	localPlayer = Players.LocalPlayer
	task.wait()
end

local interceptedEvents = {
	{Name = "System", Args = "Monitoring started", Path = "Local", Direction = "Client", Time = os.clock(), Type = "System", Source = "Self"}
}
local blockList = {}
local selectedEvent = nil
local eventFrames = {}
local eventContainer = nil
local eventDataMap = {}
local isWindowVisible = true
local openButtonGui = nil
local mainImage = nil
local currentDetailGui = nil
local disableTips = false

local function formatArgs(args)
	local argsStr = ""
	for i, arg in ipairs(args) do
		local argType = typeof(arg)
		local argVal = tostring(arg)
		if argType == "table" then
			argVal = "Table (" .. #arg .. " entries)"
		elseif argType == "Instance" then
			argVal = argType .. " (" .. arg.Name .. ")"
		end
		argsStr ..= i .. ": " .. argType .. " = " .. argVal .. "\n"
	end
	return argsStr ~= "" and argsStr or "No arguments"
end

local function getCallSource()
	local source = "Unknown"
	local success, info = pcall(function()
		return debug.getinfo(4, "S") 
	end)
	if success and info and info.source then
		source = info.source:gsub("@", "") 
		local playerScriptIndex = source:find("PlayerScripts")
		if playerScriptIndex then
			source = source:sub(playerScriptIndex)
		end
	end
	return source
end

local function createCustomHint(message, duration)
	if disableTips then return end
	local hintGui = Instance.new("ScreenGui")
	hintGui.Name = "CustomHint"
	hintGui.IgnoreGuiInset = true
	hintGui.ResetOnSpawn = false
	hintGui.Parent = localPlayer.PlayerGui
	local hintFrame = Instance.new("Frame")
	hintFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	hintFrame.BackgroundTransparency = 0.8
	hintFrame.Position = UDim2.new(1, 0, 1, 0)
	hintFrame.AnchorPoint = Vector2.new(1, 1)
	hintFrame.Size = UDim2.new(0, 200, 0, 40)
	hintFrame.Parent = hintGui
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 8)
	hintCorner.Parent = hintFrame
	local hintText = Instance.new("TextLabel")
	hintText.Text = message
	hintText.TextColor3 = Color3.new(1, 1, 1)
	hintText.BackgroundTransparency = 1
	hintText.Size = UDim2.new(1, 0, 1, 0)
	hintText.TextScaled = true
	hintText.Parent = hintFrame
	local enterTween = TweenService:Create(
		hintFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, -20, 1, -20)}
	)
	enterTween:Play()
	enterTween.Completed:Wait()
	task.wait(duration)
	local exitTween = TweenService:Create(
		hintFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(1, 0, 1, 0)}
	)
	exitTween:Play()
	exitTween.Completed:Wait()
	hintGui:Destroy()
end

local function safeSendNotification(params)
	if disableTips then return end
	while true do
		local success = pcall(function()
			StarterGui:SetCore("SendNotification", params)
		end)
		if success then
			break
		else
			task.wait(0.5)
		end
	end
end

local function waitForPlayerLoad()
	safeSendNotification({
		Title = "Loading",
		Text = "System initialized",
		Duration = 0
	})
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 10)
	safeSendNotification({
		Title = "",
		Text = "",
		Duration = 0.1
	})
end

local function showEventDetailFrame(eventData)
	local newText = 
		"Args:\n" .. eventData.Args .. 
		"\n\nSource Script: " .. eventData.Source ..
		"\n\nPath: " .. eventData.Path .. 
		"\n\nTime: " .. string.format("%.2f", eventData.Time)

	if currentDetailGui then
		currentDetailGui:Destroy()
		currentDetailGui = nil
	end

	local detailGui = Instance.new("ScreenGui")
	detailGui.Name = "EventDetailGui"
	detailGui.IgnoreGuiInset = true
	detailGui.ResetOnSpawn = false
	detailGui.Parent = localPlayer.PlayerGui
	currentDetailGui = detailGui

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.BackgroundTransparency = 1
	contentFrame.Size = UDim2.new(0, 400, 0, 280)
	contentFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	contentFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	contentFrame.ZIndex = 11
	contentFrame.Parent = detailGui
	contentFrame.Active = true

	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "BackgroundFrame"
	backgroundFrame.Size = UDim2.new(1, 0, 1, 0)
	backgroundFrame.Position = UDim2.new(0, 0, 0, 0)
	backgroundFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
	backgroundFrame.ZIndex = 10
	backgroundFrame.Parent = contentFrame

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, 10)
	backgroundCorner.Parent = backgroundFrame

	local titleText = Instance.new("TextLabel")
	titleText.Name = "TitleText"
	titleText.Text = eventData.Name .. " (" .. eventData.Direction .. " - " .. eventData.Type .. ")"
	titleText.TextColor3 = Color3.new(1, 1, 1)
	titleText.BackgroundTransparency = 1
	titleText.Size = UDim2.new(1, 0, 0, 30)
	titleText.Position = UDim2.new(0, 0, 0, TIP_SPACING * 2)
	titleText.TextXAlignment = Enum.TextXAlignment.Center
	titleText.Font = BUTTON_FONT
	titleText.TextSize = 16
	titleText.ZIndex = 12
	titleText.Parent = contentFrame

	local contentText = Instance.new("TextBox")
	contentText.Name = "ContentText"
	contentText.Text = newText
	contentText:SetAttribute("OriginalText", newText)
	contentText.TextColor3 = Color3.new(0.9, 0.9, 0.9)
	contentText.BackgroundTransparency = 1
	contentText.Size = UDim2.new(1, -TIP_SPACING * 2, 1, -100)
	contentText.Position = UDim2.new(0, TIP_SPACING, 0, 50)
	contentText.TextWrapped = true
	contentText.Font = Enum.Font.SourceSans
	contentText.TextSize = 14
	contentText.ZIndex = 12
	contentText.ClearTextOnFocus = false
	contentText.Parent = contentFrame

	contentText.InputChanged:Connect(function()
		local originalText = contentText:GetAttribute("OriginalText")
		if contentText.Text ~= originalText then
			contentText.Text = originalText
		end
	end)

	contentText.FocusLost:Connect(function()
		local originalText = contentText:GetAttribute("OriginalText")
		if contentText.Text ~= originalText then
			contentText.Text = originalText
		end
	end)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "Close"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Font = BUTTON_FONT
	closeButton.TextSize = 14
	closeButton.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
	closeButton.Size = UDim2.new(0, 80, 0, 30)
	closeButton.Position = UDim2.new(0.5, 0, 1, -TIP_SPACING * 2 - 30)
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	closeButton.ZIndex = 12
	closeButton.Parent = contentFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		if currentDetailGui then
			currentDetailGui:Destroy()
			currentDetailGui = nil
		end
	end)

	local isDragging = false
	local startPos = nil
	local originalPos = nil

	local function onInputBegan(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			startPos = input.Position
			originalPos = contentFrame.Position
			contentFrame.ZIndex = 13
		end
	end

	local function onInputChanged(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or 
			input.UserInputType == Enum.UserInputType.Touch then
			if isDragging and startPos then
				local delta = input.Position - startPos
				contentFrame.Position = UDim2.new(
					originalPos.X.Scale,
					originalPos.X.Offset + delta.X,
					originalPos.Y.Scale,
					originalPos.Y.Offset + delta.Y
				)
			end
		end
	end

	local function onInputEnded(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch) then
			isDragging = false
			contentFrame.ZIndex = 11
		end
	end

	contentFrame.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
end

local function setupEventFrameDrag(frame)
	local isDragging = false
	local startPos = nil
	local originalPos = nil
	local isClicked = false

	local function onInputBegan(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			isClicked = true
			isDragging = false
			startPos = input.Position
			originalPos = frame.Position
			frame.ZIndex = 10
		end
	end

	local function onInputChanged(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or 
			input.UserInputType == Enum.UserInputType.Touch then
			if startPos and (input.Position - startPos).Magnitude > 5 then
				isDragging = true
				isClicked = false
			end
			if isDragging then
				local delta = input.Position - startPos
				frame.Position = UDim2.new(
					originalPos.X.Scale,
					originalPos.X.Offset + delta.X,
					originalPos.Y.Scale,
					originalPos.Y.Offset + delta.Y
				)
			end
		end
	end

	local function onInputEnded(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch) and isClicked and not isDragging then
			local eventData = eventDataMap[frame]
			if eventData then
				selectedEvent = eventData
				for _, f in ipairs(eventFrames) do
					local name = string.match(f.Name, "Event_(.-)_")
					name = string.gsub(name, "%(Function%)", "")
					f.BackgroundTransparency = if blockList[name] then 0 else 0.3
					f.BackgroundColor3 = if blockList[name] then Color3.new(0.4, 0.2, 0.2) else Color3.new(0.25, 0.25, 0.25)
				end
				frame.BackgroundTransparency = 0
				frame.BackgroundColor3 = Color3.new(0.3, 0.5, 0.8)
				showEventDetailFrame(eventData)
			end
		end
		isDragging = false
		isClicked = false
		frame.ZIndex = 5
	end

	frame.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
end

local function updateEventFrames()
	local previouslySelectedName = selectedEvent and selectedEvent.Name or nil

	for _, frame in ipairs(eventFrames) do
		eventDataMap[frame] = nil
		frame:Destroy()
	end
	eventFrames = {}

	local validEvents = {}
	for _, eventData in ipairs(interceptedEvents) do
		if eventData.Direction == "Server" then
			table.insert(validEvents, eventData)
		end
	end

	for i = #validEvents, 1, -1 do
		local eventData = validEvents[i]

		local eventFrame = Instance.new("Frame")
		eventFrame.Name = "Event_" .. eventData.Name .. "_" .. i
		eventFrame.Size = UDim2.new(1, 0, 0, 30)
		eventFrame.LayoutOrder = #validEvents - i + 1
		eventFrame.ZIndex = 5
		eventFrame.Parent = eventContainer
		eventFrame.Active = true
		eventFrame.Selectable = false

		local eventNameClean = string.gsub(eventData.Name, "%(Function%)", "")
		eventFrame.BackgroundColor3 = if blockList[eventNameClean] then Color3.new(0.4, 0.2, 0.2) else Color3.new(0.25, 0.25, 0.25)
		eventFrame.BackgroundTransparency = if blockList[eventNameClean] then 0 else 0.3

		local eventCorner = Instance.new("UICorner")
		eventCorner.CornerRadius = UDim.new(0, 4)
		eventCorner.Parent = eventFrame

		local eventText = Instance.new("TextLabel")
		eventText.Text = eventData.Name .. " (" .. eventData.Type .. ")"
		eventText.TextColor3 = Color3.new(1, 1, 1)
		eventText.BackgroundTransparency = 1
		eventText.Size = UDim2.new(1, 0, 1, 0)
		eventText.Font = Enum.Font.SourceSans
		eventText.TextSize = 14
		eventText.TextXAlignment = Enum.TextXAlignment.Left
		eventText.TextTruncate = Enum.TextTruncate.AtEnd
		eventText.Parent = eventFrame
		eventText.ZIndex = 6

		eventDataMap[eventFrame] = eventData
		setupEventFrameDrag(eventFrame)
		table.insert(eventFrames, eventFrame)
	end

	if previouslySelectedName then
		for _, frame in ipairs(eventFrames) do
			local eventData = eventDataMap[frame]
			if eventData and eventData.Name == previouslySelectedName then
				selectedEvent = eventData
				frame.BackgroundTransparency = 0
				frame.BackgroundColor3 = Color3.new(0.3, 0.5, 0.8)
				break
			end
		end
	end
end

local function setupButtonHover(button, normalColor, hoverColor)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {
			BackgroundColor3 = hoverColor
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {
			BackgroundColor3 = normalColor
		}):Play()
	end)
end

local function createOpenButton()
	if not UserInputService.TouchEnabled then return end
	if openButtonGui then return end

	openButtonGui = Instance.new("ScreenGui")
	openButtonGui.Name = "OpenMenuButton"
	openButtonGui.IgnoreGuiInset = true
	openButtonGui.ResetOnSpawn = false
	openButtonGui.Parent = localPlayer.PlayerGui

	local button = Instance.new("ImageLabel")
	button.Name = "OpenButton"
	button.Image = MENU_BUTTON_IMAGE_ID
	button.Size = UDim2.new(0, 60, 0, 60)
	button.Position = UDim2.new(0.5, 0, 0.9, 0)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.BackgroundTransparency = 1
	button.ScaleType = Enum.ScaleType.Stretch
	button.ZIndex = 10
	button.Parent = openButtonGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button

	local isDragging = false
	local startPos = nil
	local originalPos = nil

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			startPos = input.Position
			originalPos = button.Position
			button.ZIndex = 11
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
			input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startPos
			button.Position = UDim2.new(
				originalPos.X.Scale,
				originalPos.X.Offset + delta.X,
				originalPos.Y.Scale,
				originalPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch) and isDragging then
			isDragging = false
			button.ZIndex = 10
		end
	end)

	button.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch) and not isDragging and mainImage then
			mainImage.Visible = true
			isWindowVisible = true
			if openButtonGui then
				openButtonGui.Enabled = false
			end
		end
	end)

	openButtonGui.Enabled = false
end

local function hookRemote(remote)
	local success, originalMethod = pcall(function()
		if remote:IsA("RemoteEvent") then
			return remote.FireServer
		elseif remote:IsA("RemoteFunction") then
			return remote.InvokeServer
		end
	end)
	if not success then
		local temp = remote:IsA("RemoteEvent") and Instance.new("RemoteEvent") or Instance.new("RemoteFunction")
		originalMethod = remote:IsA("RemoteEvent") and temp.FireServer or temp.InvokeServer
		temp:Destroy()
	end

	if remote:IsA("RemoteEvent") then
		remote.FireServer = function(self, ...)
			local args = {...}
			local source = getCallSource()
			local eventData = {
				Name = self.Name,
				Args = formatArgs(args),
				Path = self:GetFullName(),
				Direction = "Server",
				Time = os.clock(),
				Type = "RemoteEvent",
				Source = source
			}
			table.insert(interceptedEvents, eventData)
			updateEventFrames()

			if not blockList[self.Name] then
				return originalMethod(self, ...)
			else
				createCustomHint("Blocked: " .. self.Name, 1)
			end
		end
	elseif remote:IsA("RemoteFunction") then
		remote.InvokeServer = function(self, ...)
			local args = {...}
			local source = getCallSource()
			local eventData = {
				Name = self.Name,
				Args = formatArgs(args),
				Path = self:GetFullName(),
				Direction = "Server",
				Time = os.clock(),
				Type = "RemoteFunction",
				Source = source
			}
			table.insert(interceptedEvents, eventData)
			updateEventFrames()

			if not blockList[self.Name] then
				local result = {originalMethod(self, ...)}
				return unpack(result)
			else
				createCustomHint("Blocked: " .. self.Name, 1)
				return nil
			end
		end
	end
end

local function monitorNewRemotes(container)
	container.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
			hookRemote(descendant)
			local eventType = descendant:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction"
			table.insert(interceptedEvents, {
				Name = descendant.Name,
				Args = "New " .. eventType .. " detected",
				Path = descendant:GetFullName(),
				Direction = "Server",
				Time = os.clock(),
				Type = eventType,
				Source = "Runtime Detection"
			})
			updateEventFrames()
		end
	end)
end

local function hookRemoteEvents()
	local containers = {ReplicatedStorage, Workspace, game:GetService("StarterPack")}
	for _, container in ipairs(containers) do
		local success, descendants = pcall(function()
			return container:GetDescendants()
		end)
		if success then
			for _, descendant in ipairs(descendants) do
				if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
					hookRemote(descendant)
				end
			end
		end
		monitorNewRemotes(container)
	end
	createCustomHint("Hooks initialized - monitoring remotes", 2)
end

local function collectExistingRemotes()
	local containers = {ReplicatedStorage, Workspace, game:GetService("StarterPack")}
	for _, container in ipairs(containers) do
		local success, descendants = pcall(function()
			return container:GetDescendants()
		end)
		if success then
			for _, descendant in ipairs(descendants) do
				if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
					local eventType = descendant:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction"
					table.insert(interceptedEvents, {
						Name = descendant.Name,
						Args = "Existing " .. eventType,
						Path = descendant:GetFullName(),
						Direction = "Server",
						Time = os.clock(),
						Type = eventType,
						Source = "Initial Scan"
					})
				end
			end
		end
	end
end

waitForPlayerLoad()

local textScreenGui = Instance.new("ScreenGui")
textScreenGui.Name = "LoadTextGui"
textScreenGui.IgnoreGuiInset = true
textScreenGui.ResetOnSpawn = false
textScreenGui.Parent = localPlayer.PlayerGui

local textLabel = Instance.new("TextLabel")
textLabel.Name = "LoadText"
textLabel.Parent = textScreenGui
textLabel.Text = "EventSpy"
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
textLabel.Size = UDim2.new(0.6, 0, 0.15, 0)
textLabel.TextScaled = true
textLabel.TextWrapped = false
textLabel.TextTransparency = 0.6

local tweenInfoLinear = TweenInfo.new(1, Enum.EasingStyle.Linear)
local tween1 = TweenService:Create(textLabel, tweenInfoLinear, {TextTransparency = 0.8})
tween1:Play()
tween1.Completed:Wait()

local tween2 = TweenService:Create(textLabel, tweenInfoLinear, {TextTransparency = 0.7})
tween2:Play()
tween2.Completed:Wait()

task.wait(2)

local tween3 = TweenService:Create(
	textLabel,
	TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	{TextTransparency = 0}
)
tween3:Play()
tween3.Completed:Wait()

textScreenGui:Destroy()

local windowGui = Instance.new("ScreenGui")
windowGui.Name = "EventSpyWindow"
windowGui.IgnoreGuiInset = true
windowGui.ResetOnSpawn = false
windowGui.Parent = localPlayer.PlayerGui

mainImage = Instance.new("ImageLabel")
mainImage.Name = "MainWindow"
mainImage.Image = MAIN_IMAGE_ID
mainImage.Size = UDim2.new(0, 700, 0, 400)
mainImage.Position = UDim2.new(0.5, 0, 0.5, 0)
mainImage.AnchorPoint = Vector2.new(0.5, 0.5)
mainImage.BackgroundTransparency = 0
mainImage.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
mainImage.ScaleType = Enum.ScaleType.Stretch
mainImage.ZIndex = 2
mainImage.Parent = windowGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainImage

local dragFrame = Instance.new("Frame")
dragFrame.Name = "DragArea"
dragFrame.Size = UDim2.new(1, 0, 0, 36)
dragFrame.Position = UDim2.new(0, 0, 0, 0)
dragFrame.BackgroundTransparency = 0.7
dragFrame.ZIndex = 4
dragFrame.Parent = mainImage

local dragCorner = Instance.new("UICorner")
dragCorner.CornerRadius = UDim.new(0, 8)
dragCorner.Parent = dragFrame

local dragGradient = Instance.new("UIGradient")
dragGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
})
dragGradient.Parent = dragFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "WindowTitle"
titleLabel.Text = TITLE_TEXT .. " - Remote Monitor (Client → Server)"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 10, 0, 40)
titleLabel.Size = UDim2.new(1, -20, 0, 30)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.SourceSansSemibold
titleLabel.TextSize = 18
titleLabel.ZIndex = 4
titleLabel.Parent = mainImage

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "EventScroll"
scrollFrame.Position = UDim2.new(0, 10, 0, 80)
scrollFrame.Size = UDim2.new(1, -20, 1, -180)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = SCROLL_BAR_THICKNESS
scrollFrame.ClipsDescendants = true
scrollFrame.ZIndex = 4
scrollFrame.Parent = mainImage

eventContainer = Instance.new("Frame")
eventContainer.Name = "EventListContainer"
eventContainer.Size = UDim2.new(1, -SCROLL_BAR_THICKNESS, 0, 0)
eventContainer.BackgroundTransparency = 1
eventContainer.Parent = scrollFrame
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

local eventListLayout = Instance.new("UIListLayout")
eventListLayout.Name = "EventLayout"
eventListLayout.Parent = eventContainer
eventListLayout.FillDirection = Enum.FillDirection.Vertical
eventListLayout.SortOrder = Enum.SortOrder.LayoutOrder
eventListLayout.Padding = EVENT_LIST_PADDING

eventListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	eventContainer.Size = UDim2.new(1, -SCROLL_BAR_THICKNESS, 0, eventListLayout.AbsoluteContentSize.Y)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, eventListLayout.AbsoluteContentSize.Y)
end)

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonArea"
buttonContainer.Position = UDim2.new(0, 10, 1, -90)
buttonContainer.Size = UDim2.new(1, -20, 0, 80)
buttonContainer.BackgroundTransparency = 1
buttonContainer.ZIndex = 4
buttonContainer.Parent = mainImage

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Parent = buttonContainer
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local runButton = Instance.new("TextButton")
runButton.Name = "RunBtn"
runButton.Text = "Run"
runButton.TextColor3 = Color3.new(1, 1, 1)
runButton.Font = BUTTON_FONT
runButton.TextSize = 16
runButton.BackgroundColor3 = Color3.new(0.2, 0.7, 0.3)
runButton.Size = UDim2.new(0, 110, 0, 40)
runButton.LayoutOrder = 1
runButton.ZIndex = 5
runButton.Parent = buttonContainer

local runCorner = Instance.new("UICorner")
runCorner.CornerRadius = UDim.new(0, 6)
runCorner.Parent = runButton

local blockButton = Instance.new("TextButton")
blockButton.Name = "BlockBtn"
blockButton.Text = "Block"
blockButton.TextColor3 = Color3.new(1, 1, 1)
blockButton.Font = BUTTON_FONT
blockButton.TextSize = 16
blockButton.BackgroundColor3 = Color3.new(0.7, 0.2, 0.2)
blockButton.Size = UDim2.new(0, 110, 0, 40)
blockButton.LayoutOrder = 2
blockButton.ZIndex = 5
blockButton.Parent = buttonContainer

local blockCorner = Instance.new("UICorner")
blockCorner.CornerRadius = UDim.new(0, 6)
blockCorner.Parent = blockButton

local hotkeyInput = Instance.new("TextBox")
hotkeyInput.Name = "HotkeyInput"
hotkeyInput.PlaceholderText = "Hotkey"
hotkeyInput.Text = OPEN_MENU_KEY
hotkeyInput.TextColor3 = Color3.new(1, 1, 1)
hotkeyInput.PlaceholderColor3 = Color3.new(0.6, 0.6, 0.6)
hotkeyInput.Font = BUTTON_FONT
hotkeyInput.TextSize = 16
hotkeyInput.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
hotkeyInput.Size = UDim2.new(0, 80, 0, 40)
hotkeyInput.LayoutOrder = 3
hotkeyInput.ZIndex = 5
hotkeyInput.TextXAlignment = Enum.TextXAlignment.Center
hotkeyInput.Parent = buttonContainer

local hotkeyCorner = Instance.new("UICorner")
hotkeyCorner.CornerRadius = UDim.new(0, 6)
hotkeyCorner.Parent = hotkeyInput

local refreshButton = Instance.new("TextButton")
refreshButton.Name = "RefreshBtn"
refreshButton.Text = "Refresh"
refreshButton.TextColor3 = Color3.new(1, 1, 1)
refreshButton.Font = BUTTON_FONT
refreshButton.TextSize = 16
refreshButton.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
refreshButton.Size = UDim2.new(0, 100, 0, 40)
refreshButton.LayoutOrder = 4
refreshButton.ZIndex = 5
refreshButton.Parent = buttonContainer

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 6)
refreshCorner.Parent = refreshButton

local tipsToggleButton = Instance.new("TextButton")
tipsToggleButton.Name = "TipsToggleBtn"
tipsToggleButton.Text = "NO MORE TIPS"
tipsToggleButton.TextColor3 = Color3.new(1, 1, 1)
tipsToggleButton.Font = BUTTON_FONT
tipsToggleButton.TextSize = 14
tipsToggleButton.BackgroundColor3 = Color3.new(0.5, 0.5, 0.2)
tipsToggleButton.Size = UDim2.new(0, 120, 0, 40)
tipsToggleButton.LayoutOrder = 5
tipsToggleButton.ZIndex = 5
tipsToggleButton.Parent = buttonContainer

local tipsCorner = Instance.new("UICorner")
tipsCorner.CornerRadius = UDim.new(0, 6)
tipsCorner.Parent = tipsToggleButton

hotkeyInput:GetPropertyChangedSignal("Text"):Connect(function()
	local filtered = hotkeyInput.Text:gsub("[^A-Za-z]", ""):sub(1, 1):upper()
	if filtered ~= hotkeyInput.Text then
		hotkeyInput.Text = filtered
	end
end)

hotkeyInput.FocusLost:Connect(function(enterPressed)
	if hotkeyInput.Text and hotkeyInput.Text ~= "" then
		local newKey = hotkeyInput.Text:upper()
		OPEN_MENU_KEY = newKey
		createCustomHint("Hotkey set to: " .. newKey, 1)
	else
		hotkeyInput.Text = OPEN_MENU_KEY
	end
end)

refreshButton.MouseButton1Click:Connect(function()
	updateEventFrames()
	createCustomHint("List refreshed", 1)
end)

tipsToggleButton.MouseButton1Click:Connect(function()
	disableTips = not disableTips
	tipsToggleButton.Text = disableTips and "ENABLE TIPS" or "NO MORE TIPS"
	tipsToggleButton.BackgroundColor3 = disableTips and Color3.new(0.2, 0.5, 0.2) or Color3.new(0.5, 0.5, 0.2)
	if not disableTips then
		createCustomHint("Tips enabled", 1)
	else
		createCustomHint("Tips disabled", 1)
	end
end)

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseBtn"
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 0.4, 0.4)
closeButton.Font = BUTTON_FONT
closeButton.TextSize = 16
closeButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -5, 0.5, 0)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.ZIndex = 5
closeButton.Parent = dragFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

runButton.MouseButton1Click:Connect(function()
	if selectedEvent and selectedEvent.Direction == "Server" then
		local eventName = selectedEvent.Name
		local remote = nil
		local containers = {ReplicatedStorage, Workspace}
		for _, container in ipairs(containers) do
			remote = container:FindFirstChild(eventName, true)
			if remote then break end
		end

		if remote then
			local success = pcall(function()
				if remote:IsA("RemoteEvent") then
					remote:FireServer()
				elseif remote:IsA("RemoteFunction") then
					remote:InvokeServer()
				end
			end)
			if success then
				createCustomHint("Executed: " .. eventName, 1)
			else
				createCustomHint("Failed to execute: " .. eventName, 1)
			end
		else
			createCustomHint("Remote not found", 1)
		end
	else
		createCustomHint("No remote selected", 1)
	end
end)

blockButton.MouseButton1Click:Connect(function()
	if selectedEvent then
		local eventName = selectedEvent.Name
		blockList[eventName] = not blockList[eventName]
		local status = blockList[eventName] and "blocked" or "unblocked"
		createCustomHint(eventName .. " " .. status, 1)
		updateEventFrames()
	else
		createCustomHint("No event selected", 1)
	end
end)

closeButton.MouseButton1Click:Connect(function()
	if not mainImage then return end
	isWindowVisible = not isWindowVisible
	mainImage.Visible = isWindowVisible

	if currentDetailGui then
		currentDetailGui:Destroy()
		currentDetailGui = nil
	end

	if UserInputService.TouchEnabled then
		if not isWindowVisible then
			createOpenButton()
			if openButtonGui then
				openButtonGui.Enabled = true
			end
			createCustomHint("Press button to open menu", 2)
		else
			if openButtonGui then
				openButtonGui.Enabled = false
			end
		end
	else
		if not isWindowVisible then
			createCustomHint("Press " .. OPEN_MENU_KEY .. " to open menu", 2)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if not UserInputService.TouchEnabled and input.KeyCode == Enum.KeyCode[OPEN_MENU_KEY] and not isWindowVisible and mainImage then
		mainImage.Visible = true
		isWindowVisible = true
	end
end)

local isDraggingWindow = false
local dragStartPosWindow = nil
local frameStartPosWindow = nil

local function startDragWindow(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
		input.UserInputType == Enum.UserInputType.Touch) and isWindowVisible and mainImage then
		isDraggingWindow = true
		dragStartPosWindow = input.Position
		frameStartPosWindow = mainImage.Position
	end
end

local function dragMoveWindow(input)
	if isDraggingWindow and mainImage and (input.UserInputType == Enum.UserInputType.MouseMovement or 
		input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartPosWindow
		mainImage.Position = UDim2.new(
			frameStartPosWindow.X.Scale,
			frameStartPosWindow.X.Offset + delta.X,
			frameStartPosWindow.Y.Scale,
			frameStartPosWindow.Y.Offset + delta.Y
		)
	end
end

local function endDragWindow(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
		input.UserInputType == Enum.UserInputType.Touch) and isDraggingWindow then
		isDraggingWindow = false
	end
end

dragFrame.InputBegan:Connect(startDragWindow)
UserInputService.InputChanged:Connect(dragMoveWindow)
UserInputService.InputEnded:Connect(endDragWindow)

setupButtonHover(runButton, Color3.new(0.2, 0.7, 0.3), Color3.new(0.3, 0.8, 0.4))
setupButtonHover(blockButton, Color3.new(0.7, 0.2, 0.2), Color3.new(0.8, 0.3, 0.3))
setupButtonHover(closeButton, Color3.new(0.2, 0.2, 0.2), Color3.new(0.3, 0.3, 0.3))
setupButtonHover(refreshButton, Color3.new(0.4, 0.4, 0.4), Color3.new(0.5, 0.5, 0.5))
setupButtonHover(tipsToggleButton, 
	Color3.new(0.5, 0.5, 0.2), 
	Color3.new(0.6, 0.6, 0.3)
)

collectExistingRemotes()
hookRemoteEvents()
updateEventFrames()

RunService.Heartbeat:Connect(function() end)

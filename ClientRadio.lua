-- Seei // Clientside Radio Transmitter
-- Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Teams = game:GetService('Teams')
local TweenService = game:GetService('TweenService')
local UIS = game:GetService('UserInputService')

-- Variables // Tables
local RadioAssets =ReplicatedStorage.Radio
local RadioEventServer = RadioAssets.RadioCommunicatorServer
local RadioEventClient = RadioAssets.RadioCommunicatorClient
local LocalPlayer = Players.LocalPlayer

local tInfo = TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- 	<Tool>
local RadioTool = script.Parent
local Equipped = false
local ActiveChannel = nil
local myChannels = {}
local ExistingNumberchannel = nil
local activateButton = Enum.KeyCode.Y -- button a player presses to active the radio when it is out
local isActive = false
local MsgRecievedAudio = RadioTool.Handle.MsgRecieved

-- 	<GUI>
local MessageTemplate = RadioAssets.MessageTemplate
local ChannelButton = RadioAssets.ChannelButtonTemplate
local RadioGui = LocalPlayer.PlayerGui:WaitForChild('RadioGui')
RadioGui.Enabled = false

local EquipTween = TweenService:Create(RadioGui.RadioFrame, tInfo, {['Position'] = UDim2.new(0, 0, 0.661, 0)})
local DequipTween = TweenService:Create(RadioGui.RadioFrame, tInfo, {['Position'] = UDim2.new(0, 0, 1, 0)})
RadioGui.RadioFrame.Position = UDim2.new(0, 0, 1, 0) -- set the gui's position to off screen

-- Functions
-- Anyone with a radio should be able to view general communications but the client will check if a player should or shouldn't be able to view
-- specific communication channels such as SD, ScD, or MTF communication channels

local function LoadMessages(Channel)
	-- moves messages from their respective folder to the radio ui
	local msgFolder = RadioGui[Channel .. 'Folder']
	ActiveChannel = Channel
	RadioGui.RadioFrame.ChannelBG[Channel .. 'Button'].TextColor3 = Color3.fromRGB(0, 85, 0)
	for _, MessageObject in pairs(msgFolder:GetChildren()) do
		MessageObject.Parent = RadioGui.RadioFrame.RadioBG
		MessageObject.Visible = true	
	end
end

local function UnloadMessages()
	-- moves messages from the radio ui to their respective folder
	if not ActiveChannel then return end
	local msgFolder = RadioGui[ActiveChannel .. 'Folder']
	RadioGui.RadioFrame.ChannelBG[ActiveChannel .. 'Button'].TextColor3 = Color3.fromRGB(255, 255, 255)
	for _, MessageObject in pairs(RadioGui.RadioFrame.RadioBG:GetChildren()) do
		if MessageObject:IsA('TextLabel') then -- to account for ui list layout
			MessageObject.Parent = msgFolder
			MessageObject.Visible = false
		end
	end
end

local function CreateMessage(Channel, msg, sender)
	local msgFolder = RadioGui[Channel .. 'Folder']
	local idx = #msgFolder:GetChildren()
	
	local newMessage = MessageTemplate:Clone()
	newMessage.Name = 'Message'
	local R, G, B = sender.Team.TeamColor.Color.R*255, sender.Team.TeamColor.Color.G*255, sender.Team.TeamColor.Color.B*255
	newMessage.Text = string.format('<font color="rgb(%i,%i,%i)">%s</font>: %s',R, G, B, sender.Name, msg)
	
	if Channel == ActiveChannel then -- load the message directly instead of loading it into a folder
		for _, MessageObject in pairs(RadioGui.RadioFrame.RadioBG:GetChildren()) do -- increment index of messages and delete the 9th message
			if MessageObject:IsA('TextLabel') then
				if MessageObject.Index.Value < 8 then
					MessageObject.Index.Value += 1
				else
					MessageObject:Destroy()
				end
			end
		end
		newMessage.Parent = RadioGui.RadioFrame.RadioBG
		newMessage.Visible = true
	else -- load the message into a folder, which is the default behavior
		for _, MessageObject in pairs(msgFolder:GetChildren()) do -- increment index of messages and delete the 9th message
			if MessageObject.Index.Value < 8 then
				MessageObject.Index.Value += 1
			else
				MessageObject:Destroy()
			end
		end
		newMessage.Parent = msgFolder
		newMessage.Visible = false
	end
end

local function SetupChannel(Channel)
	
	local NewChannelButton = ChannelButton:Clone()
	NewChannelButton.Parent = RadioGui.RadioFrame.ChannelBG
	NewChannelButton.MouseButton1Click:Connect(function()
		if Channel ~= ActiveChannel then
			RadioEventServer:FireServer(Channel, myChannels)
		end
		UnloadMessages()
		LoadMessages(Channel)
	end)
	NewChannelButton.Name = Channel .. 'Button'
	NewChannelButton.Text = Channel
	-- create a new folder for storing message sent in this channel
	local NewChannelFolder = Instance.new('Folder')
	NewChannelFolder.Parent = RadioGui
	NewChannelFolder.Name = Channel .. 'Folder'
	
end

-- in the future set up channels after game start
SetupChannel(Teams.Foundation.Name) -- setting up the basic foundation channel
SetupChannel(LocalPlayer.Team.Name) -- setting up the player's team's channel
table.insert(myChannels, LocalPlayer.Team.Name) 
LoadMessages(Teams.Foundation.Name) -- start with foundation messages loaded to not confuse players

RadioTool.Equipped:Connect(function()
	RadioGui.Enabled = true
	EquipTween:Play()
	Equipped = true
end)

RadioTool.Unequipped:Connect(function()
	DequipTween:Play()
	Equipped = false
	task.spawn(function() -- run this in parallel and check if the radio tool is equipped before setting the radio gui to disabled to prevent spam clicking radio breaking the UI
		DequipTween.Completed:Connect(function() 
			if Equipped then return end
			RadioGui.Enabled = false
		end)
	end)
end)

UIS.InputBegan:Connect(function(input, gPE)
	if not gPE then -- so that typing doesn't interfere with input
		if input.KeyCode == activateButton then
			isActive = not isActive
			RadioEventServer:FireServer(nil, nil, isActive)
			if not isActive then
				RadioGui.RadioFrame.IsActive.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			else
				RadioGui.RadioFrame.IsActive.BackgroundColor3 = Color3.fromRGB(85, 170, 0)
			end
		end
	end
end)

RadioEventClient.OnClientEvent:Connect(function(msg, channel, sender) -- recieved a message
	CreateMessage(channel, msg, sender)
	-- play audio here for whenever a player gets a message
	MsgRecievedAudio:Play()
end)

RadioGui.RadioFrame.AddNumberChannel.MouseButton1Click:Connect(function() -- creating new channels 
	local NumberChannelField = RadioGui.RadioFrame.NumberToAdd
	-- check if the number is between 100 and 1000 and round it
	local ChannelNumber = math.round(tonumber(NumberChannelField.Text))
	if ChannelNumber and ChannelNumber >= 100 and ChannelNumber <1000 then
		ChannelNumber = tostring(ChannelNumber)
		if ExistingNumberchannel then
			table.remove(myChannels, table.find(myChannels, ExistingNumberchannel))
			RadioGui.RadioFrame.ChannelBG[ExistingNumberchannel .. 'Button']:Destroy()
		end
		table.insert(myChannels, ChannelNumber)
		SetupChannel(ChannelNumber)
		ExistingNumberchannel = ChannelNumber
	-- if the channel number isn't valid then change text to be ERR
	else
		RadioGui.RadioFrame.NumberToAdd.Text = "ERR INVLD"
	end
end)

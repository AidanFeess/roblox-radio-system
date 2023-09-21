-- Seei // Server Side Radio Middleman
-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local TextService = game:GetService('TextService')
local Teams = game:GetService('Teams')

-- Variables // Tables
local RadioAssets = ReplicatedStorage:WaitForChild('Radio')
local RadioEventServer = RadioAssets.RadioCommunicatorServer
local RadioEventClient = RadioAssets.RadioCommunicatorClient
local MessageTemplate = RadioAssets.MessageTemplate

local RadioActivePlayers = {} -- later we can integrate this with the loading system so that when a player is loaded they get added to this list

-- Functions
local function cleanMessage(msg, userId)
	local filterResult
	local success, result = pcall(function()
		return TextService:FilterStringAsync(msg, userId)
	end)
	
	if success then
		filterResult = result
	else
		warn('Could not filter message [',msg,']:',result)
	end
	
	return filterResult:GetNonChatStringForBroadcastAsync()
end

local function generateRadioMessage(Msg, SendingChannel, Sender)
	-- verify if recieving users should actually recieve that data
	for Client, ChannelData in pairs(RadioActivePlayers) do
		if SendingChannel ~= 'Foundation' then
			for _, OwnedChannel in ChannelData.PlayerChannels do
				if tostring(OwnedChannel) == tostring(SendingChannel) then
					RadioEventClient:FireClient(Client, Msg, SendingChannel, Sender)
					break
				end
			end
		elseif SendingChannel == 'Foundation' then
			RadioEventClient:FireClient(Client, Msg, SendingChannel, Sender) -- just send all general foundation messages to every player with a radio
		end
	end
end

local function addPlayerToRadio(player, channel, ownedChannels)
	RadioActivePlayers[player] = {
		ActiveChannel = channel or 'Foundation',
		PlayerChannels = ownedChannels
	}
end

Players.PlayerAdded:Connect(function(player)
	local char = player.Character
	if not char or not char.Parent then
		char = player.CharacterAdded:Wait()
	end
	
	player.Chatted:Connect(function(message)
		
		local success, errMsg = pcall(function()
			if char and char:FindFirstChildOfClass('Tool').Name == 'Radio' then
				if not RadioActivePlayers[player] then RadioActivePlayers[player] = {ActiveChannel = 'Foundation', PlayerChannels = {}} end
				-- need to put a check in here to make sure the radio channel is either 1. an approved channel (i.e. a team channel) or 2. a valid number channel (i.e. 101 or 102 but not 99, 1000, or 101.1)
				generateRadioMessage(cleanMessage(message, player.UserId), RadioActivePlayers[player].ActiveChannel, player)
			end
		end)
		
	end)
	
end)

RadioEventServer.OnServerEvent:Connect(function(player, Channel, ownedChannels)
	addPlayerToRadio(player, Channel, ownedChannels)
end)

Players.PlayerRemoving:Connect(function(player)
	RadioActivePlayers[player] = nil
end)

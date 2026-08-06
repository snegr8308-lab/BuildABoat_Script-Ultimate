-- services --
local vim = game:GetService("VirtualInputManager")
local players = game:GetService("Players")
local TS = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local runService = game:GetService("RunService")
local coreGui = game:GetService("CoreGui")
local httpService = game:GetService("HttpService")

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local HRP = character:WaitForChild("HumanoidRootPart")

-- Universal HTTP Request for Discord Webhooks --
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- flags & values --
local tweening = false
local index = 1

-- WindUI Initialization --
local Version = "1.6.66"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. Version .. "/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Profix hub AutoBuild",
    Icon = "rbxassetid://119122088865300",
    Author = "by Enormus ",
    Folder = "MySuperHub",
    NewElements = true,
    Size = UDim2.fromOffset(580, 520),
    ToggleKey = Enum.KeyCode.LeftShift,
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.2,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

-- Injecting Custom Font (Jura)
task.spawn(function()
    task.wait(1.5)
    for _, gui in pairs(coreGui:GetChildren()) do
        if gui.Name == "WindUI" then
            for _, element in pairs(gui:GetDescendants()) do
                if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
                    pcall(function() element.Font = Enum.Font.Jura end)
                end
            end
        end
    end
end)

-- Execution Popup
WindUI:Popup({
    Title = "Script Loaded",
    Icon = "Shield",
    Content = "Profix hub AutoBuild activated",
    Buttons = { { Title = "Continue", Icon = "arrow-right", Callback = function() end, Variant = "Primary" } }
})

-- Info Tab
local InfoTab = Window:Tab({ Title = "Information", Icon = "user", ShowTabTitle = true })

local accountAge = player.AccountAge .. " days"
local avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=420&h=420"
local execName = identifyexecutor and identifyexecutor() or "Unknown"

InfoTab:Paragraph({
    Title = "Welcome, " .. player.DisplayName .. "!",
    Desc = "Executor: " .. execName .. "\nAccount Age: " .. accountAge .. "\nUserID: " .. player.UserId,
    Image = avatarImage,
    ImageSize = 80
})

local FPSTag = Window:Tag({ Title = "FPS: 0", Color = Color3.fromRGB(100, 150, 255) })
local lastUpdate, frameCount = tick(), 0
runService.RenderStepped:Connect(function()
    frameCount += 1
    local now = tick()
    if now - lastUpdate >= 1 then
        local fps = math.floor(frameCount / (now - lastUpdate))
        FPSTag:SetTitle("FPS: " .. fps)
        if fps >= 50 then FPSTag:SetColor(Color3.fromRGB(0, 255, 0))
        elseif fps >= 30 then FPSTag:SetColor(Color3.fromRGB(255, 200, 0))
        else FPSTag:SetColor(Color3.fromRGB(255, 0, 0)) end
        frameCount = 0; lastUpdate = now
    end
end)

local PingTag = Window:Tag({ Title = "Ping: 0ms", Color = Color3.fromRGB(100, 200, 255) })
task.spawn(function()
    while task.wait(2) do
        local success, ping = pcall(function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        if success and ping then
            PingTag:SetTitle("Ping: " .. ping .. "ms")
        end
    end
end)
local blockData = player:WaitForChild("Data")
local blocksFolder = workspace:WaitForChild("Blocks")
local usedList = {}
local selectedBase, autofarm, ignoreAnchored = nil, false, true
local clipboard = nil

local previewFolder = Instance.new("Folder")
previewFolder.Name = "BuildPreview"
previewFolder.Parent = workspace.CurrentCamera

local function getBlockID(name)
    return blockData:FindFirstChild(name) and blockData:FindFirstChild(name).Value or 9
end

local function setTransparency(transparencyWanted, block)
    if not block or block.PPart.Transparency == transparencyWanted then return end
    local calls = transparencyWanted / 0.25
    local tool = character:FindFirstChild("PropertiesTool") or humanoid:EquipTool(player.Backpack.PropertiesTool) or character.PropertiesTool
    task.spawn(function() for i = 1, calls do tool.SetPropertieRF:InvokeServer("Transparency", { block }) end end)
end

local function rescaleBlock(block, newPos, newSize)
    if not block then return end
    local tool = character:FindFirstChild("ScalingTool") or humanoid:EquipTool(player.Backpack.ScalingTool) or character.ScalingTool
    task.spawn(function() tool.RF:InvokeServer(block, newSize, newPos) end)
end

local function getPlayerZone(playerInstance)
    local teamColor = playerInstance.TeamColor
    for _,v in pairs(workspace:GetChildren()) do
        if v:FindFirstChild("TeamColor") and v.TeamColor.Value == teamColor then return v end
    end
    return nil
end

local function placeBlock(name, pos, relativeTo, Anchored)
    local tool = character:FindFirstChild("BuildingTool") or humanoid:EquipTool(player.Backpack.BuildingTool) or character.BuildingTool
    if not relativeTo then relativeTo = getPlayerZone(player) end
    task.spawn(function() tool.RF:InvokeServer(name, getBlockID(name), relativeTo, relativeTo and relativeTo.CFrame:ToObjectSpace(pos) or CFrame.new(), ignoreAnchored and true or Anchored, pos, false) end)
end

local function paintBlock(block, color)
    if not block or not block:FindFirstChild("PPart") or block.PPart.Color == color then return end
    local tool = character:FindFirstChild("PaintingTool") or humanoid:EquipTool(player.Backpack.PaintingTool) or character.PaintingTool
    task.spawn(function() tool.RF:InvokeServer({{block, color}}) end)
end

local function getNewBlockPos(hisBase, block, myBase)
    if not block or not block:FindFirstChild("PPart") then return CFrame.new() end
    if not hisBase or not myBase then return block.PPart.CFrame end
    return myBase.CFrame * hisBase.CFrame:ToObjectSpace(block.PPart.CFrame)
end

local function copyBuild(blocks)
    local t, myBase, hisBase = {}, getPlayerZone(player), getPlayerZone(players:FindFirstChild(blocks.Name))
    for _,block in ipairs(blocks:GetChildren()) do
        if block:FindFirstChild("PPart") and not (getBlockID(block.Name) == 0 or (usedList[block.Name] or 0) > getBlockID(block.Name)) then 
            usedList[block.Name] = (usedList[block.Name] or 0) + 1
            table.insert(t, {
                Name = block.Name, Pos = getNewBlockPos(hisBase, block, myBase), Relative = getPlayerZone(player),
                Transparency = block.PPart.Transparency, Anchored = block.PPart.Anchored, Size = block.PPart.Size, Color = block.PPart.Color
            })
        end
    end
    return t
end

local function getBlock(expected, createdList)
    local best, bestDist = nil, math.huge
    for _, b in ipairs(createdList) do
        if b and b:FindFirstChild("PPart") and b.Name == expected.Name then
            local dist = (b.PPart.Position - expected.Pos.Position).Magnitude
            if dist < bestDist then bestDist = dist; best = b end
        end
    end
    return best
end

local function getPlayerBase()
    for _,child in pairs(blocksFolder:GetChildren()) do if child.Name == player.Name then return child end end
end

local function getPlayers()
    local playersy = {}
    for _,playery in pairs(players:GetChildren()) do table.insert(playersy, playery.DisplayName) end
    return playersy
end

local function getRealName(DisplayNamey)
    for _,v in pairs(players:GetChildren()) do if v.DisplayName == DisplayNamey then return v.Name end end
    return nil
end

local function showPreview(t)
    previewFolder:ClearAllChildren()
    if not t then return end
    for _, v in ipairs(t) do
        local p = Instance.new("Part")
        p.Size = v.Size; p.CFrame = v.Pos; p.Color = v.Color; p.Transparency = 0.6; p.Material = Enum.Material.Neon
        p.Anchored = true; p.CanCollide = false; p.CastShadow = false; p.Parent = previewFolder
    end
    WindUI:Notify({ Title = "Preview", Content = "Base displayed with semi-transparent blocks.", Duration = 3 })
end
-- BUILD TAB --
local autoBuildTab = Window:Tab({ Title = "Building", Icon = "hammer", ShowTabTitle = true })

local dd = autoBuildTab:Dropdown({
    Title = "Select Player Base to Copy",
    Values = getPlayers(),
    Value = "None Selected",
    Callback = function(Options)
        local opt = type(Options) == "table" and Options[1] or Options
        local realName = getRealName(opt)
        for _,folder in pairs(blocksFolder:GetChildren()) do if folder.Name == realName then selectedBase = folder end end
    end,
})
players.PlayerAdded:Connect(function() dd:Refresh(getPlayers()) end)

autoBuildTab:Button({ Title = "Copy Base", Callback = function() if selectedBase then clipboard = copyBuild(selectedBase); WindUI:Notify({ Title = "Success", Content = "Copied!", Duration = 3 }) end end })

autoBuildTab:Section({ Title = "Visualization" })
autoBuildTab:Button({ Title = "Show Preview", Callback = function() if clipboard then showPreview(clipboard) end end })
autoBuildTab:Button({ Title = "Clear Preview", Callback = function() previewFolder:ClearAllChildren() end })

autoBuildTab:Section({ Title = "Pasting" })
local BuildProgress = autoBuildTab:ProgressBar({ Title = "Build Progress", Desc = "Idle...", Value = { Min = 0, Max = 100, Default = 0 } })

local function pasteBuild(t, folder)
    previewFolder:ClearAllChildren()
    local tCount = #t; if tCount == 0 then return end
    
    for i, v in ipairs(t) do
        placeBlock(v.Name, v.Pos, v.Relative, v.Anchored)
        BuildProgress:Set({ Value = math.floor((i / tCount) * 50), Desc = "Placing blocks (" .. i .. "/" .. tCount .. ")" })
        if i % 20 == 0 then task.wait(0.05) end
    end
    task.wait(1)
    local playerBaseList = folder:GetChildren()
    for i, v in ipairs(t) do
        local b = getBlock(v, playerBaseList)
        if b then rescaleBlock(b, v.Pos, v.Size); paintBlock(b, v.Color); setTransparency(v.Transparency, b) end
        BuildProgress:Set({ Value = math.floor(50 + ((i / tCount) * 50)), Desc = "Applying properties (" .. i .. "/" .. tCount .. ")" })
        if i % 20 == 0 then task.wait(0.05) end
    end
    BuildProgress:Set({ Value = 100, Desc = "Build Finished!" })
end
autoBuildTab:Button({ Title = "Paste Base", Callback = function() if clipboard then task.spawn(function() pasteBuild(clipboard, getPlayerBase()) end) end end })
autoBuildTab:Toggle({ Title = "Ignore Anchored State", Value = true, Callback = function(Value) ignoreAnchored = Value end })

-- AUTO FARM TAB (NEW UPDATES HERE) --
local autoFarmTab = Window:Tab({ Title = "Auto Farm", Icon = "coins", ShowTabTitle = true })

local statsBox = autoFarmTab:Paragraph({ Title = "Farm Statistics", Desc = "Status: Inactive\nEarned Gold: 0\nEstimated Gold/Hour: 0" })

-- Auto Farm Variables
local startGold = 0
local startTime = 0
local currentEarned = 0
local currentGPH = 0

autoFarmTab:Toggle({ 
    Title = "Toggle Auto Farm", 
    Value = false, 
    Callback = function(value) 
        autofarm = value 
        if value then
            local goldNode = player:FindFirstChild("Data") and player.Data:FindFirstChild("Gold")
            startGold = goldNode and goldNode.Value or 0
            startTime = tick()
        else
            statsBox:Set({ Title = "Farm Statistics", Desc = "Status: Inactive\nEarned Gold: " .. currentEarned .. "\nEstimated Gold/Hour: 0" })
        end
    end 
})

autoFarmTab:Section({ Title = "Discord Webhook API" })
local webhookUrl = ""
local webhookInterval = 5
local enableWebhook = false

autoFarmTab:Input({
    Title = "Discord Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text) webhookUrl = text end
})

autoFarmTab:Slider({
    Title = "Send Interval (Minutes)",
    Step = 1,
    Value = { Min = 1, Max = 60, Default = 5 },
    Callback = function(value) webhookInterval = value end
})

autoFarmTab:Toggle({ 
    Title = "Enable Discord Logging", 
    Value = false, 
    Callback = function(value) enableWebhook = value end 
})

-- Stat calculation loop
task.spawn(function()
    while task.wait(1) do
        if autofarm then
            local goldNode = player:FindFirstChild("Data") and player.Data:FindFirstChild("Gold")
            if goldNode then
                local currentGold = goldNode.Value
                currentEarned = currentGold - startGold
                local elapsedSeconds = tick() - startTime
                
                if elapsedSeconds > 0 then
                    currentGPH = math.floor((currentEarned / elapsedSeconds) * 3600)
                end
                
                statsBox:Set({ Title = "Farm Statistics", Desc = "Status: Active\nEarned Gold: " .. currentEarned .. "\nEstimated Gold/Hour: " .. currentGPH })
            end
        end
    end
end)

-- Discord Webhook loop
task.spawn(function()
    local lastWebhookTime = tick()
    while task.wait(1) do
        if enableWebhook and autofarm and webhookUrl ~= "" then
            if (tick() - lastWebhookTime) >= (webhookInterval * 60) then
                lastWebhookTime = tick()
                
                local data = {
                    content = "",
                    embeds = {{
                        title = "💰 BABFT Auto Farm Report",
                        color = 3447003,
                        fields = {
                            { name = "Player", value = player.Name, inline = true },
                            { name = "Earned Gold", value = tostring(currentEarned), inline = true },
                            { name = "Est. Gold/Hour", value = tostring(currentGPH), inline = true }
                        },
                        footer = { text = "WindUI BABFT Ultimate" },
                        timestamp = DateTime.now():ToIsoDate()
                    }}
                }

                if httpRequest then
                    pcall(function()
                        httpRequest({
                            Url = webhookUrl,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = httpService:JSONEncode(data)
                        })
                    end)
                end
            end
        end
    end
end)

-- SETTINGS TAB --
local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings", ShowTabTitle = true })
settingsTab:Dropdown({
    Title = "Select Theme",
    Values = {"Sky", "Violet", "Amber", "Emerald, Dark, Rainbow, Plant"},
    Value = "Sky",
    Callback = function(Options)
        local theme = type(Options) == "table" and Options[1] or Options
        WindUI:SetTheme(theme)
    end
})
settingsTab:Button({
    Title = "Destroy UI", 
    Callback = function() 
        previewFolder:ClearAllChildren()
        for _,v in pairs(coreGui:GetChildren()) do if v.Name == "WindUI" then v:Destroy() end end
    end 
})

-- Auto farm logic loop
task.spawn(function()
    while true do
        task.wait()
        if autofarm and HRP then
            if index == 11 then
                local normalStages = workspace:FindFirstChild("BoatStages") and workspace.BoatStages:FindFirstChild("NormalStages")
                local chest = normalStages and normalStages:FindFirstChild("TheEnd") and normalStages.TheEnd:FindFirstChild("GoldenChest")
                if chest then
                    HRP:PivotTo(chest:GetPivot() + Vector3.new(0,0,-10))
                    local ii = 0
                    repeat 
                        task.wait(1); ii += 1
                        if ii % 20 == 0 and HRP then HRP:PivotTo(chest:GetPivot() + Vector3.new(0,0,-10)) end
                    until not HRP or (HRP.Position - chest:GetPivot().Position).Magnitude > 500
                    index = 1
                end
            else
                local normalStages = workspace:FindFirstChild("BoatStages") and workspace.BoatStages:FindFirstChild("NormalStages")
                local darkPart = normalStages and normalStages:FindFirstChild("CaveStage"..index) and normalStages["CaveStage"..index]:FindFirstChild("DarknessPart")
                if darkPart then
                    character:PivotTo(darkPart.CFrame - Vector3.new(0,0,15))
                    local tween = TS:Create(HRP,TweenInfo.new(2,Enum.EasingStyle.Linear),{CFrame = darkPart.CFrame + Vector3.new(0,0,20)})
                    tweening = true; tween:Play(); tween.Completed:Wait(); tweening = false
                    index += 1
                end
            end
        end
    end
end)

runService.Heartbeat:Connect(function() if tweening and HRP then HRP.Velocity = Vector3.zero end end)
player.CharacterAdded:Connect(function(char) character, HRP, humanoid = char, char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid") end)

task.spawn(function()
    while task.wait(100) do vim:SendKeyEvent(true, Enum.KeyCode.Tilde, false, nil); task.wait(0.1); vim:SendKeyEvent(false, Enum.KeyCode.Tilde, false, nil) end
end)

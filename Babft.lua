local getgenv = getgenv or function() return _G end
local env = getgenv()

-- services --
env.vim = game:GetService("VirtualInputManager")
env.players = game:GetService("Players")
env.TS = game:GetService("TweenService")
env.workspace = game:GetService("Workspace")
env.runService = game:GetService("RunService")
env.coreGui = game:GetService("CoreGui")
env.httpService = game:GetService("HttpService")

env.player = env.players.LocalPlayer
env.character = env.player.Character or env.player.CharacterAdded:Wait()
env.humanoid = env.character:WaitForChild("Humanoid")
env.HRP = env.character:WaitForChild("HumanoidRootPart")

-- Universal HTTP Request for Discord Webhooks --
env.httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- flags & values --
env.tweening = false
env.index = 1

-- WindUI Initialization --
local Version = "1.6.66"
env.WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. Version .. "/main.lua"))()

env.Window = env.WindUI:CreateWindow({
    Title = "Profix hub AutoBuild",
    Icon = "rbxassetid://119122088865300",
    Author = "by Enormus ",
    Folder = "Profix hub(Babft)",
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

-- Injecting Custom Font (Jura) --
task.spawn(function()
    task.wait(1.5)
    for _, gui in pairs(env.coreGui:GetChildren()) do
        if gui.Name == "WindUI" then
            for _, element in pairs(gui:GetDescendants()) do
                if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
                    pcall(function() element.Font = Enum.Font.Jura end)
                end
            end
        end
    end
end)

-- Execution Popup --
env.WindUI:Popup({
    Title = "Script Loaded",
    Icon = "Shield",
    Content = "Profix hub AutoBuild activated",
    Buttons = { { Title = "Continue", Icon = "arrow-right", Callback = function() end, Variant = "Primary" } }
})

-- Info Tab --
local InfoTab = env.Window:Tab({ Title = "Information", Icon = "user", ShowTabTitle = true })

local accountAge = env.player.AccountAge .. " days"
local avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. env.player.UserId .. "&w=420&h=420"
local execName = identifyexecutor and identifyexecutor() or "Unknown"

InfoTab:Paragraph({
    Title = "Welcome, " .. env.player.DisplayName .. "!",
    Desc = "Executor: " .. execName .. "\nAccount Age: " .. accountAge .. "\nUserID: " .. env.player.UserId,
    Image = avatarImage,
    ImageSize = 80
})

local FPSTag = env.Window:Tag({ Title = "FPS: 0", Color = Color3.fromRGB(100, 150, 255) })
local lastUpdate, frameCount = tick(), 0
env.runService.RenderStepped:Connect(function()
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

local PingTag = env.Window:Tag({ Title = "Ping: 0ms", Color = Color3.fromRGB(100, 200, 255) })
task.spawn(function()
    while task.wait(2) do
        local success, ping = pcall(function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        if success and ping then
            PingTag:SetTitle("Ping: " .. ping .. "ms")
        end
    end
end)

env.blockData = env.player:WaitForChild("Data")
env.blocksFolder = env.workspace:WaitForChild("Blocks")
env.usedList = {}
env.selectedBase, env.autofarm, env.ignoreAnchored = nil, false, true
env.clipboard = nil

env.previewFolder = Instance.new("Folder")
env.previewFolder.Name = "BuildPreview"
env.previewFolder.Parent = env.workspace.CurrentCamera

local function getBlockID(name)
    return env.blockData:FindFirstChild(name) and env.blockData:FindFirstChild(name).Value or 9
end

local function setTransparency(transparencyWanted, block)
    if not block or block.PPart.Transparency == transparencyWanted then return end
    local calls = transparencyWanted / 0.25
    local tool = env.character:FindFirstChild("PropertiesTool") or env.humanoid:EquipTool(env.player.Backpack.PropertiesTool) or env.character.PropertiesTool
    task.spawn(function() for i = 1, calls do tool.SetPropertieRF:InvokeServer("Transparency", { block }) end end)
end

local function rescaleBlock(block, newPos, newSize)
    if not block then return end
    local tool = env.character:FindFirstChild("ScalingTool") or env.humanoid:EquipTool(env.player.Backpack.ScalingTool) or env.character.ScalingTool
    task.spawn(function() tool.RF:InvokeServer(block, newSize, newPos) end)
end

local function getPlayerZone(playerInstance)
    local teamColor = playerInstance.TeamColor
    for _,v in pairs(env.workspace:GetChildren()) do
        if v:FindFirstChild("TeamColor") and v.TeamColor.Value == teamColor then return v end
    end
    return nil
end

local function placeBlock(name, pos, relativeTo, Anchored)
    local tool = env.character:FindFirstChild("BuildingTool") or env.humanoid:EquipTool(env.player.Backpack.BuildingTool) or env.character.BuildingTool
    if not relativeTo then relativeTo = getPlayerZone(env.player) end
    task.spawn(function() tool.RF:InvokeServer(name, getBlockID(name), relativeTo, relativeTo and relativeTo.CFrame:ToObjectSpace(pos) or CFrame.new(), env.ignoreAnchored and true or Anchored, pos, false) end)
end

local function paintBlock(block, color)
    if not block or not block:FindFirstChild("PPart") or block.PPart.Color == color then return end
    local tool = env.character:FindFirstChild("PaintingTool") or env.humanoid:EquipTool(env.player.Backpack.PaintingTool) or env.character.PaintingTool
    task.spawn(function() tool.RF:InvokeServer({{block, color}}) end)
end

local function getNewBlockPos(hisBase, block, myBase)
    if not block or not block:FindFirstChild("PPart") then return CFrame.new() end
    if not hisBase or not myBase then return block.PPart.CFrame end
    return myBase.CFrame * hisBase.CFrame:ToObjectSpace(block.PPart.CFrame)
end

local function copyBuild(blocks)
    local t, myBase, hisBase = {}, getPlayerZone(env.player), getPlayerZone(env.players:FindFirstChild(blocks.Name))
    for _,block in ipairs(blocks:GetChildren()) do
        if block:FindFirstChild("PPart") and not (getBlockID(block.Name) == 0 or (env.usedList[block.Name] or 0) > getBlockID(block.Name)) then 
            env.usedList[block.Name] = (env.usedList[block.Name] or 0) + 1
            table.insert(t, {
                Name = block.Name, Pos = getNewBlockPos(hisBase, block, myBase), Relative = getPlayerZone(env.player),
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
    for _,child in pairs(env.blocksFolder:GetChildren()) do if child.Name == env.player.Name then return child end end
end

local function getPlayers()
    local playersy = {}
    for _,playery in pairs(env.players:GetChildren()) do table.insert(playersy, playery.DisplayName) end
    return playersy
end

local function getRealName(DisplayNamey)
    local v = env.players:FindFirstChild(DisplayNamey)
    if v then return v.Name end
    for _,p in pairs(env.players:GetChildren()) do if p.DisplayName == DisplayNamey then return p.Name end end
    return nil
end

local function showPreview(t)
    env.previewFolder:ClearAllChildren()
    if not t then return end
    for _, v in ipairs(t) do
        local p = Instance.new("Part")
        p.Size = v.Size; p.CFrame = v.Pos; p.Color = v.Color; p.Transparency = 0.6; p.Material = Enum.Material.Neon
        p.Anchored = true; p.CanCollide = false; p.CastShadow = false; p.Parent = env.previewFolder
    end
    env.WindUI:Notify({ Title = "Preview", Content = "Base displayed with semi-transparent blocks.", Duration = 3 })
end

-- BUILD TAB --
local autoBuildTab = env.Window:Tab({ Title = "Building", Icon = "hammer", ShowTabTitle = true })

local dd = autoBuildTab:Dropdown({
    Title = "Select Player Base to Copy",
    Values = getPlayers(),
    Value = "None Selected",
    Callback = function(Options)
        local opt = type(Options) == "table" and Options[1] or Options
        local realName = getRealName(opt)
        for _,folder in pairs(env.blocksFolder:GetChildren()) do if folder.Name == realName then env.selectedBase = folder end end
    end,
})
env.players.PlayerAdded:Connect(function() dd:Refresh(getPlayers()) end)

autoBuildTab:Button({ Title = "Copy Base", Callback = function() if env.selectedBase then env.clipboard = copyBuild(env.selectedBase); env.WindUI:Notify({ Title = "Success", Content = "Copied!", Duration = 3 }) end end })

autoBuildTab:Section({ Title = "Visualization" })
autoBuildTab:Button({ Title = "Show Preview", Callback = function() if env.clipboard then showPreview(env.clipboard) end end })
autoBuildTab:Button({ Title = "Clear Preview", Callback = function() env.previewFolder:ClearAllChildren() end })

autoBuildTab:Section({ Title = "Pasting" })
local BuildProgress = autoBuildTab:ProgressBar({ Title = "Build Progress", Desc = "Idle...", Value = { Min = 0, Max = 100, Default = 0 } })

local function pasteBuild(t, folder)
    env.previewFolder:ClearAllChildren()
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
autoBuildTab:Button({ Title = "Paste Base", Callback = function() if env.clipboard then task.spawn(function() pasteBuild(env.clipboard, getPlayerBase()) end) end end })
autoBuildTab:Toggle({ Title = "Ignore Anchored State", Value = true, Callback = function(Value) env.ignoreAnchored = Value end })
local getgenv = getgenv or function() return _G end
local env = getgenv()

local Window = env.Window
local WindUI = env.WindUI
local player = env.player
local character = env.character
local humanoid = env.humanoid
local HRP = env.HRP
local workspace = env.workspace
local runService = env.runService
local coreGui = env.coreGui
local httpService = env.httpService
local httpRequest = env.httpRequest
local previewFolder = env.previewFolder

-- AUTO FARM TAB --
local autoFarmTab = Window:Tab({ Title = "Auto Farm", Icon = "coins", ShowTabTitle = true })

-- Безопасное получение золота
local function getGoldValue()
    local success, value = pcall(function()
        if player:FindFirstChild("Data") and player.Data:FindFirstChild("Gold") then
            return player.Data.Gold.Value
        elseif player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gold") then
            return player.leaderstats.Gold.Value
        end
        return 0
    end)
    if success and value then return value end
    return 0
end
env.getGoldValue = getGoldValue

env.startGold = 0
env.startTime = 0
env.currentEarned = 0
env.currentGPH = 0
env.currentGPS = 0
env.currentGPM = 0

-- Флаги отображения параметров в HUD
env.showGoldFlag = true
env.showGPSFlag = true
env.showGPMFlag = true
env.showGPHFlag = true

-- Флаги для вебхука Discord (отдельные тогглы)
env.whIncludeName = true
env.whIncludeCount = true
env.whIncludeNamesList = false
env.whIncludeGold = true
env.whIncludeGPS = true
env.whIncludeGPM = true
env.whIncludeGPH = true

-- Вывод статистики
env.statsBox = autoFarmTab:Paragraph({ 
    Title = "Farm Statistics", 
    Desc = "Gold: " .. getGoldValue() .. "\nFarm in hour: 0" 
})

autoFarmTab:Toggle({ 
    Title = "Toggle Auto Farm", 
    Value = false, 
    Callback = function(value) 
        env.autofarm = value 
        if value then
            env.startGold = getGoldValue()
            env.startTime = tick()
        else
            env.startGold = getGoldValue()
            env.startTime = tick()
            env.currentGPH = 0
            env.currentGPS = 0
            env.currentGPM = 0
        end
    end 
})

-- Floating HUD Logic Variables
env.hudGui = nil
local hudFrame = nil
local hudText = nil
env.hudWidth = 240
env.hudHeight = 130

local function buildHudTextString()
    local lines = {"💰 Profix Hub HUD"}
    if env.showGoldFlag then
        table.insert(lines, string.format("• Gold: %d", getGoldValue()))
    end
    if env.showGPSFlag then
        table.insert(lines, string.format("• Gold / Sec: %.1f", env.currentGPS))
    end
    if env.showGPMFlag then
        table.insert(lines, string.format("• Gold / Min: %.1f", env.currentGPM))
    end
    if env.showGPHFlag then
        table.insert(lines, string.format("• Gold / Hour: %.0f", env.currentGPH))
    end
    return table.concat(lines, "\n")
end
env.buildHudTextString = buildHudTextString

local function toggleFloatingHUD(state)
    if state then
        if env.hudGui then env.hudGui:Destroy() end
        
        env.hudGui = Instance.new("ScreenGui")
        env.hudGui.Name = "ProfixHub_FloatingHUD"
        env.hudGui.ResetOnSpawn = false
        pcall(function() env.hudGui.Parent = coreGui end)
        if not env.hudGui.Parent then env.hudGui.Parent = player.PlayerGui end
        
        hudFrame = Instance.new("Frame")
        hudFrame.Size = UDim2.new(0, env.hudWidth, 0, env.hudHeight)
        hudFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
        hudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        hudFrame.BackgroundTransparency = 0.25
        hudFrame.BorderSizePixel = 0
        hudFrame.Active = true
        hudFrame.Draggable = true
        hudFrame.Parent = env.hudGui
        env.hudFrame = hudFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = hudFrame
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(100, 150, 255)
        stroke.Thickness = 1.5
        stroke.Parent = hudFrame
        
        hudText = Instance.new("TextLabel")
        hudText.Size = UDim2.new(1, -16, 1, -16)
        hudText.Position = UDim2.new(0, 8, 0, 8)
        hudText.BackgroundTransparency = 1
        hudText.Font = Enum.Font.Jura
        hudText.TextSize = 14
        hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
        hudText.TextXAlignment = Enum.TextXAlignment.Left
        hudText.TextYAlignment = Enum.TextYAlignment.Top
        hudText.TextWrapped = true
        hudText.Text = buildHudTextString()
        hudText.Parent = hudFrame
        env.hudText = hudText
    else
        if env.hudGui then
            env.hudGui:Destroy()
            env.hudGui = nil
            env.hudFrame = nil
            env.hudText = nil
        end
    end
end

autoFarmTab:Section({ Title = "Floating HUD Overlay" })

autoFarmTab:Toggle({
    Title = "Show Floating Gold HUD",
    Value = false,
    Callback = function(value)
        toggleFloatingHUD(value)
    end
})

autoFarmTab:Section({ Title = "HUD Display Settings (What to Show)" })

autoFarmTab:Toggle({
    Title = "Show Gold Amount",
    Value = true,
    Callback = function(v) env.showGoldFlag = v end
})

autoFarmTab:Toggle({
    Title = "Show Gold / Sec",
    Value = true,
    Callback = function(v) env.showGPSFlag = v end
})

autoFarmTab:Toggle({
    Title = "Show Gold / Min",
    Value = true,
    Callback = function(v) env.showGPMFlag = v end
})

autoFarmTab:Toggle({
    Title = "Show Gold / Hour",
    Value = true,
    Callback = function(v) env.showGPHFlag = v end
})

autoFarmTab:Slider({
    Title = "Floating HUD Size",
    Step = 10,
    Value = { Min = 180, Max = 400, Default = 240 },
    Callback = function(value)
        env.hudWidth = value
        env.hudHeight = math.floor(value * 0.5)
        if env.hudFrame then
            env.hudFrame.Size = UDim2.new(0, env.hudWidth, 0, env.hudHeight)
        end
    end
})

autoFarmTab:Section({ Title = "Discord Webhook API" })
env.webhookUrl = ""
env.webhookInterval = 5
env.enableWebhook = false

autoFarmTab:Input({
    Title = "Discord Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text) env.webhookUrl = text end
})

autoFarmTab:Slider({
    Title = "Send Interval (Minutes)",
    Step = 1,
    Value = { Min = 1, Max = 60, Default = 5 },
    Callback = function(value) env.webhookInterval = value end
})

autoFarmTab:Toggle({ 
    Title = "Enable Discord Logging", 
    Value = false, 
    Callback = function(value) env.enableWebhook = value end 
})

autoFarmTab:Section({ Title = "Webhook Content Toggles" })

autoFarmTab:Toggle({
    Title = "Webhook: Send Player Name",
    Value = true,
    Callback = function(v) env.whIncludeName = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Players Count",
    Value = true,
    Callback = function(v) env.whIncludeCount = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Player Names List",
    Value = false,
    Callback = function(v) env.whIncludeNamesList = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold Amount",
    Value = true,
    Callback = function(v) env.whIncludeGold = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold / Sec",
    Value = true,
    Callback = function(v) env.whIncludeGPS = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold / Min",
    Value = true,
    Callback = function(v) env.whIncludeGPM = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold / Hour",
    Value = true,
    Callback = function(v) env.whIncludeGPH = v end
})

-- SETTINGS TAB --
local settingsTab = Window:Tab({ Title = "Settings", Icon = "settings", ShowTabTitle = true })
settingsTab:Dropdown({
    Title = "Select Theme",
    Values = {"Sky", "Violet", "Amber", "Emerald"},
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
        if env.hudGui then env.hudGui:Destroy() end
        for _,v in pairs(coreGui:GetChildren()) do if v.Name == "WindUI" then v:Destroy() end end
    end 
})
local getgenv = getgenv or function() return _G end
local env = getgenv()

local player = env.player
local character = env.character
local humanoid = env.humanoid
local HRP = env.HRP
local workspace = env.workspace
local runService = env.runService
local httpService = env.httpService
local httpRequest = env.httpRequest

-- Обновление золота каждую секунду и расчет статистики
task.spawn(function()
    while true do
        task.wait(1)
        
        pcall(function()
            if env.autofarm then
                if workspace:FindFirstChild("ClaimRiverResultsGold") then
                    workspace.ClaimRiverResultsGold:FireServer()
                end
                
                local currentGold = env.getGoldValue()
                env.currentEarned = currentGold - env.startGold
                if env.currentEarned < 0 then env.currentEarned = 0 end
                
                local elapsedTime = tick() - env.startTime
                if elapsedTime < 1 then elapsedTime = 1 end
                
                local goldPerSec = env.currentEarned / elapsedTime
                env.currentGPS = goldPerSec
                env.currentGPM = goldPerSec * 60
                env.currentGPH = goldPerSec * 3600
            else
                env.currentGPS = 0
                env.currentGPM = 0
                env.currentGPH = 0
            end
        end)
        
        pcall(function()
            if env.statsBox then
                env.statsBox:Set({ 
                    Title = "Farm Statistics", 
                    Desc = string.format("Gold: %d\nFarm in hour: %.0f", env.getGoldValue(), env.currentGPH) 
                })
            end
        end)

        pcall(function()
            if env.hudText and env.hudText.Parent then
                env.hudText.Text = env.buildHudTextString()
            end
        end)
    end
end)

-- Discord Webhook loop --
task.spawn(function()
    local lastWebhookTime = tick()
    while task.wait(1) do
        if env.enableWebhook and env.autofarm and env.webhookUrl ~= "" then
            if (tick() - lastWebhookTime) >= (env.webhookInterval * 60) then
                lastWebhookTime = tick()
                
                local fields = {}
                
                if env.whIncludeName then
                    table.insert(fields, { name = "Player", value = player.Name, inline = true })
                end
                if env.whIncludeCount then
                    table.insert(fields, { name = "Players Online", value = tostring(#env.players:GetPlayers()), inline = true })
                end
                if env.whIncludeNamesList then
                    local namesList = {}
                    for _, p in ipairs(env.players:GetPlayers()) do
                        table.insert(namesList, p.Name)
                    end
                    table.insert(fields, { name = "All Players", value = table.concat(namesList, ", "), inline = false })
                end
                if env.whIncludeGold then
                    table.insert(fields, { name = "Current Gold", value = tostring(env.getGoldValue()), inline = true })
                end
                if env.whIncludeGPS then
                    table.insert(fields, { name = "Gold / Sec", value = string.format("%.1f", env.currentGPS), inline = true })
                end
                if env.whIncludeGPM then
                    table.insert(fields, { name = "Gold / Min", value = string.format("%.1f", env.currentGPM), inline = true })
                end
                if env.whIncludeGPH then
                    table.insert(fields, { name = "Gold / Hour", value = tostring(math.floor(env.currentGPH)), inline = true })
                end
                
                local data = {
                    content = "",
                    embeds = {{
                        title = "💰 BABFT Auto Farm Report",
                        color = 3447003,
                        fields = fields,
                        footer = { text = "WindUI BABFT Ultimate" },
                        timestamp = DateTime.now():ToIsoDate()
                    }}
                }

                if httpRequest then
                    pcall(function()
                        httpRequest({
                            Url = env.webhookUrl,
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

-- Auto farm logic loop --
task.spawn(function()
    while true do
        task.wait()
        if env.autofarm and HRP then
            if env.index == 11 then
                local normalStages = workspace:FindFirstChild("BoatStages") and workspace.BoatStages:FindFirstChild("NormalStages")
                local chest = normalStages and normalStages:FindFirstChild("TheEnd") and normalStages.TheEnd:FindFirstChild("GoldenChest")
                if chest then
                    HRP:PivotTo(chest:GetPivot() + Vector3.new(0,0,-10))
                    local ii = 0
                    repeat 
                        task.wait(1); ii += 1
                        if ii % 20 == 0 and HRP then HRP:PivotTo(chest:GetPivot() + Vector3.new(0,0,-10)) end
                    until not HRP or (HRP.Position - chest:GetPivot().Position).Magnitude > 500
                    env.index = 1
                end
            else
                local normalStages = workspace:FindFirstChild("BoatStages") and workspace.BoatStages:FindFirstChild("NormalStages")
                local darkPart = normalStages and normalStages:FindFirstChild("CaveStage"..env.index) and normalStages["CaveStage"..env.index]:FindFirstChild("DarknessPart")
                if darkPart then
                    character:PivotTo(darkPart.CFrame - Vector3.new(0,0,15))
                    local tween = env.TS:Create(HRP,TweenInfo.new(2,Enum.EasingStyle.Linear),{CFrame = darkPart.CFrame + Vector3.new(0,0,20)})
                    env.tweening = true; tween:Play(); tween.Completed:Wait(); env.tweening = false
                    env.index += 1
                end
            end
        end
    end
end)

runService.Heartbeat:Connect(function() if env.tweening and HRP then HRP.Velocity = Vector3.zero end end)
player.CharacterAdded:Connect(function(char) character, HRP, humanoid = char, char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid") end)

task.spawn(function()
    while task.wait(100) do env.vim:SendKeyEvent(true, Enum.KeyCode.Tilde, false, nil); task.wait(0.1); env.vim:SendKeyEvent(false, Enum.KeyCode.Tilde, false, nil) end
end)

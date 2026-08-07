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

local startGold = 0
local startTime = 0
local currentEarned = 0
local currentGPH = 0
local currentGPS = 0
local currentGPM = 0

-- Флаги отображения параметров в HUD
local showGoldFlag = true
local showGPSFlag = true
local showGPMFlag = true
local showGPHFlag = true

-- Флаги для вебхука Discord (отдельные тогглы)
local whIncludeName = true
local whIncludeCount = true
local whIncludeNamesList = false
local whIncludeGold = true
local whIncludeGPS = true
local whIncludeGPM = true
local whIncludeGPH = true

-- Вывод статистики
local statsBox = autoFarmTab:Paragraph({ 
    Title = "Farm Statistics", 
    Desc = "Gold: " .. getGoldValue() .. "\nFarm in hour: 0" 
})

autoFarmTab:Toggle({ 
    Title = "Toggle Auto Farm", 
    Value = false, 
    Callback = function(value) 
        env.autofarm = value 
        if value then
            startGold = getGoldValue()
            startTime = tick()
        else
            startGold = getGoldValue()
            startTime = tick()
            currentGPH = 0
            currentGPS = 0
            currentGPM = 0
        end
    end 
})

-- Floating HUD Logic Variables
local hudGui = nil
local hudFrame = nil
local hudText = nil
local hudWidth = 240
local hudHeight = 130
env.hudGui = nil

local function buildHudTextString()
    local lines = {"💰 Profix Hub HUD"}
    if showGoldFlag then
        table.insert(lines, string.format("• Gold: %d", getGoldValue()))
    end
    if showGPSFlag then
        table.insert(lines, string.format("• Gold / Sec: %.1f", currentGPS))
    end
    if showGPMFlag then
        table.insert(lines, string.format("• Gold / Min: %.1f", currentGPM))
    end
    if showGPHFlag then
        table.insert(lines, string.format("• Gold / Hour: %.0f", currentGPH))
    end
    return table.concat(lines, "\n")
end

local function toggleFloatingHUD(state)
    if state then
        if hudGui then hudGui:Destroy() end
        
        hudGui = Instance.new("ScreenGui")
        hudGui.Name = "ProfixHub_FloatingHUD"
        hudGui.ResetOnSpawn = false
        pcall(function() hudGui.Parent = coreGui end)
        if not hudGui.Parent then hudGui.Parent = player.PlayerGui end
        env.hudGui = hudGui
        
        hudFrame = Instance.new("Frame")
        hudFrame.Size = UDim2.new(0, hudWidth, 0, hudHeight)
        hudFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
        hudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        hudFrame.BackgroundTransparency = 0.25
        hudFrame.BorderSizePixel = 0
        hudFrame.Active = true
        hudFrame.Draggable = true
        hudFrame.Parent = hudGui
        
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
    else
        if hudGui then
            hudGui:Destroy()
            hudGui = nil
            env.hudGui = nil
            hudFrame = nil
            hudText = nil
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
    Callback = function(v) showGoldFlag = v end
})

autoFarmTab:Toggle({
    Title = "Show Gold / Sec",
    Value = true,
    Callback = function(v) showGPSFlag = v end
})

autoFarmTab:Toggle({
    Title = "Show Gold / Min",
    Value = true,
    Callback = function(v) showGPMFlag = v end
})

autoFarmTab:Toggle({
    Title = "Show Gold / Hour",
    Value = true,
    Callback = function(v) showGPHFlag = v end
})

autoFarmTab:Slider({
    Title = "Floating HUD Size",
    Step = 10,
    Value = { Min = 180, Max = 400, Default = 240 },
    Callback = function(value)
        hudWidth = value
        hudHeight = math.floor(value * 0.5)
        if hudFrame then
            hudFrame.Size = UDim2.new(0, hudWidth, 0, hudHeight)
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

autoFarmTab:Section({ Title = "Webhook Content Toggles" })

autoFarmTab:Toggle({
    Title = "Webhook: Send Player Name",
    Value = true,
    Callback = function(v) whIncludeName = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Players Count",
    Value = true,
    Callback = function(v) whIncludeCount = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Player Names List",
    Value = false,
    Callback = function(v) whIncludeNamesList = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold Amount",
    Value = true,
    Callback = function(v) whIncludeGold = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold / Sec",
    Value = true,
    Callback = function(v) whIncludeGPS = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold / Min",
    Value = true,
    Callback = function(v) whIncludeGPM = v end
})

autoFarmTab:Toggle({
    Title = "Webhook: Send Gold / Hour",
    Value = true,
    Callback = function(v) whIncludeGPH = v end
})

-- Обновление золота каждую секунду и расчет статистики
task.spawn(function()
    while true do
        task.wait(1)
        
        pcall(function()
            if env.autofarm then
                if workspace:FindFirstChild("ClaimRiverResultsGold") then
                    workspace.ClaimRiverResultsGold:FireServer()
                end
                
                local currentGold = getGoldValue()
                currentEarned = currentGold - startGold
                if currentEarned < 0 then currentEarned = 0 end
                
                local elapsedTime = tick() - startTime
                if elapsedTime < 1 then elapsedTime = 1 end
                
                local goldPerSec = currentEarned / elapsedTime
                currentGPS = goldPerSec
                currentGPM = goldPerSec * 60
                currentGPH = goldPerSec * 3600
            else
                currentGPS = 0
                currentGPM = 0
                currentGPH = 0
            end
        end)
        
        pcall(function()
            statsBox:Set({ 
                Title = "Farm Statistics", 
                Desc = string.format("Gold: %d\nFarm in hour: %.0f", getGoldValue(), currentGPH) 
            })
        end)

        pcall(function()
            if hudText and hudText.Parent then
                hudText.Text = buildHudTextString()
            end
        end)
    end
end)

-- Discord Webhook loop --
task.spawn(function()
    local lastWebhookTime = tick()
    while task.wait(1) do
        if enableWebhook and env.autofarm and webhookUrl ~= "" then
            if (tick() - lastWebhookTime) >= (webhookInterval * 60) then
                lastWebhookTime = tick()
                
                local fields = {}
                
                if whIncludeName then
                    table.insert(fields, { name = "Player", value = player.Name, inline = true })
                end
                if whIncludeCount then
                    table.insert(fields, { name = "Players Online", value = tostring(#env.players:GetPlayers()), inline = true })
                end
                if whIncludeNamesList then
                    local namesList = {}
                    for _, p in ipairs(env.players:GetPlayers()) do
                        table.insert(namesList, p.Name)
                    end
                    table.insert(fields, { name = "All Players", value = table.concat(namesList, ", "), inline = false })
                end
                if whIncludeGold then
                    table.insert(fields, { name = "Current Gold", value = tostring(getGoldValue()), inline = true })
                end
                if whIncludeGPS then
                    table.insert(fields, { name = "Gold / Sec", value = string.format("%.1f", currentGPS), inline = true })
                end
                if whIncludeGPM then
                    table.insert(fields, { name = "Gold / Min", value = string.format("%.1f", currentGPM), inline = true })
                end
                if whIncludeGPH then
                    table.insert(fields, { name = "Gold / Hour", value = tostring(math.floor(currentGPH)), inline = true })
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

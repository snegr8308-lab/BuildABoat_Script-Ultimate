-- services --
local vim = game:GetService("VirtualInputManager")
local players = game:GetService("Players")
local TS = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

-- local player
local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local HRP = character:WaitForChild("HumanoidRootPart")

-- flags --
local tweening = false

-- auto farm values --
local index = 1

-- list for special blocks like glue that have multiple welds
local specialList = {"Glue"}
--paths
local blockData = player:WaitForChild("Data")
local blocksFolder = workspace:WaitForChild("Blocks")
-- variable to track paste percentage and show the player
local pastePercent = 0
-- variable to track how many used of each block there is ( doesnt scale with count unfortunately)
local usedList = {}

-- player input
local selectedBase = nil
local autofarm = false
local rescaleClick = false
local playerToBring = nil
local ignoreAnchored = true
local sitInMouseClickSeatToggle = false

-- auto build
local clipboard = nil

local function getBlockID(name)
    return blockData:FindFirstChild(name) and blockData:FindFirstChild(name).Value or 9
end

local function setTransparency(transparencyWanted : number, block : Model) : ()
    if not block then return end
    if block.PPart.Transparency == transparencyWanted then return end
    local calls = transparencyWanted / 0.25
    local tool
    if character:FindFirstChild("PropertiesTool") then
        tool = character["PropertiesTool"]
    else
        humanoid:EquipTool(player.Backpack.PropertiesTool)
        task.wait()
        tool = character.PropertiesTool
    end

    local args = { "Transparency", { block } }

    task.spawn(function()
        for i = 1,calls do
            tool.SetPropertieRF:InvokeServer(unpack(args))
        end
    end)
end

local function setAnchored(block : Model)
    if not block then return end
    local tool
    if character:FindFirstChild("PropertiesTool") then
        tool = character["PropertiesTool"]
    else
        humanoid:EquipTool(player.Backpack.PropertiesTool)
        task.wait()
        tool = character.PropertiesTool
    end

    local args = { "Anchored", { block } }
    task.spawn(function()
        tool.SetPropertieRF:InvokeServer(unpack(args))
    end)
end

local function rescaleBlock(block:Model,newPos:CFrame,newSize:Vector3) : ()
    if not block then 
        print("Block Not Found, Function rescaleBlock")
        return 
    end
    local tool
    if character:FindFirstChild("ScalingTool") then
        tool = character["ScalingTool"]
    else
        humanoid:EquipTool(player.Backpack.ScalingTool)
        task.wait()
        tool = character.ScalingTool
    end

    local args = { block, newSize, newPos }
    task.spawn(function()
        tool.RF:InvokeServer(unpack(args))
    end)
end

local function getPlayerZone(playerInstance : Player) : BasePart
    local teamColor = playerInstance.TeamColor
    for _,v in pairs(workspace:GetChildren()) do
        if v:FindFirstChild("TeamColor") and v.TeamColor.Value then
            if v.TeamColor.Value == teamColor then
                return v
            end
        end
    end
    print("Base Not Found for player: ".. playerInstance.Name)
    return nil
end

local function placeBlock(name : string,pos : CFrame,relativeTo : BasePart,Anchored : boolean) : ()
    local tool
    if character:FindFirstChild("BuildingTool") then
        tool = character["BuildingTool"]
    else
        humanoid:EquipTool(player.Backpack.BuildingTool)
        task.wait()
        tool = character.BuildingTool
    end
    if not relativeTo then relativeTo = getPlayerZone(player) end
    local args = {
        name,
        getBlockID(name),
        relativeTo,
        relativeTo and relativeTo.CFrame:ToObjectSpace(pos) or CFrame.new(),
        ignoreAnchored and true or Anchored,
        pos,
        false, 
    }
    task.spawn(function()
        tool.RF:InvokeServer(unpack(args))
    end)
end

local function paintBlock(block : Model, color : Color3)
    if not block then return end
    if not block:FindFirstChild("PPart") then return end
    if block.PPart.Color == color then return end
    local tool
    if character:FindFirstChild("PaintingTool") then
        tool = character["PaintingTool"]
    else
        humanoid:EquipTool(player.Backpack.PaintingTool)
        task.wait()
        tool = character.PaintingTool
    end
    local args = { { block, color } }
    task.spawn(function()
        tool.RF:InvokeServer(args)
    end)
end

local function getJoint(model : Model) : JointInstance?
    for _,v in pairs(model.PPart:GetChildren()) do
        if v:IsA("Snap") or v:IsA("Weld") then
            if v.Part1 then 
                if not (v.Part1.Parent == model) then
                    return v.Part1
                end
            end
        end
    end
    return getPlayerZone(player)
end

local function getNewBlockPos(hisBase : BasePart?, block : Model, myBase : BasePart?) : CFrame
    if not block or not block:FindFirstChild("PPart") then
        return CFrame.new()
    end

    if not hisBase or not myBase then
        return block.PPart.CFrame
    end

    local offset = hisBase.CFrame:ToObjectSpace(block.PPart.CFrame)
    return myBase.CFrame * offset
end
local function copyBuild(blocks : Folder) : table
    local t = {}
    local myBase = getPlayerZone(player)
    local hisBase = getPlayerZone(players:FindFirstChild(blocks.Name))

    for _,block in ipairs(blocks:GetChildren()) do
        if block:FindFirstChild("PPart") then
            if not (getBlockID(block.Name) == 0 or (usedList[block.Name] or 0) > getBlockID(block.Name)) then 
                local relative = getJoint(block)
                relative = relative == hisBase and myBase or relative
                if usedList[block.Name] then
                    usedList[block.Name] += 1
                else
                    usedList[block.Name] = 1
                end
                table.insert(t, {
                    Name = block.Name,
                    Pos = getNewBlockPos(hisBase, block, myBase),
                    Relative = getPlayerZone(player),
                    Transparency = block.PPart.Transparency,
                    Anchored = block.PPart.Anchored,
                    Size = block.PPart.Size,
                    Color = block.PPart.Color
                })
            else
                print("You Dont Have Enough: ".. block.Name .. "s")
            end
        end
    end
    return t
end

local function getMissingBlocks(expectedList, createdList)
    local missing = {}
    for i, v in ipairs(expectedList) do
        local found = false
        for _, b in ipairs(createdList) do
            if b and b:FindFirstChild("PPart") and (b.Name == v.Name) then
                found = true
                break
            end
        end
        if not found then
            table.insert(missing, {Index = i, Name = v.Name, Pos = v.Pos})
        end
    end
    return missing
end

local function getBlock(expected, createdList)
    local best = nil
    local bestDist = math.huge
    for _, b in ipairs(createdList) do
        if b and b:FindFirstChild("PPart") and b.Name == expected.Name then
            local dist = (b.PPart.Position - expected.Pos.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                best = b
            end
        end
    end
    return best
end

local function getPlayerBase() : Folder
    for _,child in pairs(blocksFolder:GetChildren()) do
        if child.Name == player.Name then
            return child
        end
    end
end

local function pasteBuild(t, folder)
    pastePercent = 0
    local childrenDebug = 0
    local c
    local blocks = {}
    local tCount = #t
    local lastPlaced = tick()
    c = folder.ChildAdded:Connect(function(child)
        childrenDebug += 1
        lastPlaced = tick()
    end) 
    for i,v in ipairs(t) do
        placeBlock(v.Name,v.Pos,v.Relative,v.Anchored)
        pastePercent += 50/tCount
        if i % 20 == 0 then task.wait(0.05) end
    end
    repeat task.wait(0.1) until tick() - lastPlaced > 5
    
    local playerBaseList = folder:GetChildren()
    for i,v in ipairs(t) do
        local b = getBlock(v,playerBaseList)
        rescaleBlock(b,v.Pos,v.Size)
        paintBlock(b,v.Color)
        setTransparency(v.Transparency,b)
        if i % 20 == 0 then task.wait(0.05) end
        pastePercent += 50/tCount
    end
    c:Disconnect()
    pastePercent = 0
end

local function getPlayers()
    local playersy = {}
    for _,playery in pairs(game:GetService("Players"):GetChildren()) do
        table.insert(playersy,playery.DisplayName)
    end
    return playersy
end

local function bringPlayer(playerToBring : Player , firstSeat : Seat, secondSeat : Seat) : ()
    local originalPos = character:GetPivot()
    local otherPlayerCharacter = playerToBring.Character
    if not otherPlayerCharacter then return end
    
    local offset = firstSeat.CFrame:Inverse() * secondSeat.CFrame
    repeat
        local torso = otherPlayerCharacter:FindFirstChild("LowerTorso") or otherPlayerCharacter:FindFirstChild("Torso")
        if torso then
            local newPivot = torso.CFrame * offset:Inverse()
            firstSeat:PivotTo(newPivot + Vector3.new(math.random(-1,1),math.random(-1,1),math.random(-1,1)))
        end
        task.wait(0.5)
    until not otherPlayerCharacter.Parent or otherPlayerCharacter.Humanoid.SeatPart
    firstSeat:PivotTo(originalPos)
end

local function getCar() : Model
    return humanoid.SeatPart and humanoid.SeatPart.Parent or nil
end

local function getRealName(DisplayNamey : string) : string
    for _,v in pairs(players:GetChildren()) do
        if v.DisplayName == DisplayNamey then return v.Name end
    end
    return nil
end

-- ВАЖНО: Загрузка WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
   Title = "Build a boat auto build",
   Icon = "rbxaassetid://73632565856418",
   IconThemed = true,
   Author = "by Enormus"
})

-- Ставим крутую тему по умолчанию
WindUI:SetTheme("Violet")
-- ==========================================
-- КРУТЫЕ ТЕГИ СВЕРХУ (FPS И PING)
-- ==========================================
local FPSTag = Window:Tag({
    Title = "FPS: 0",
    Color = Color3.fromRGB(100, 150, 255)
})

local lastUpdate = tick()
local frameCount = 0
runService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    if now - lastUpdate >= 1 then
        local fps = math.floor(frameCount / (now - lastUpdate))
        FPSTag:SetTitle("FPS: " .. fps)
        
        if fps >= 50 then
            FPSTag:SetColor(Color3.fromRGB(0, 255, 0)) -- Green
        elseif fps >= 30 then
            FPSTag:SetColor(Color3.fromRGB(255, 200, 0)) -- Yellow
        else
            FPSTag:SetColor(Color3.fromRGB(255, 0, 0)) -- Red
        end
        
        frameCount = 0
        lastUpdate = now
    end
end)

local PingTag = Window:Tag({
    Title = "Ping: 0ms",
    Color = Color3.fromRGB(100, 200, 255)
})

task.spawn(function()
    while true do
        local success, ping = pcall(function()
            local Stats = game:GetService("Stats")
            local pingValue = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            return math.floor(pingValue)
        end)
        
        if success and ping then
            PingTag:SetTitle("Ping: " .. ping .. " ms")
            if ping <= 50 then
                PingTag:SetColor(Color3.fromRGB(0, 255, 0))
            elseif ping <= 100 then
                PingTag:SetColor(Color3.fromRGB(255, 200, 0))
            elseif ping <= 200 then
                PingTag:SetColor(Color3.fromRGB(255, 150, 0))
            else
                PingTag:SetColor(Color3.fromRGB(255, 0, 0))
            end
        end
        task.wait(2)
    end
end)

-- ==========================================
-- СОЗДАНИЕ ВКЛАДОК
-- ==========================================
local autoBuildTab = Window:Tab({Title = "Building", Icon = "hammer"})
local autoFarmTab = Window:Tab({Title = "Auto Farm", Icon = "coins"})
local settingsTab = Window:Tab({Title = "UI Settings", Icon = "settings"}) -- Новая вкладка для тем

-- НАСТРОЙКИ UI (Выбор тем из скриншота)
settingsTab:Dropdown({
    Title = "Select UI Theme",
    Options = {"Dark", "Light", "Sky", "Violet", "Amber", "Emerald", "Rose", "Red"},
    Callback = function(Value)
        local val = type(Value) == "table" and Value[1] or Value
        WindUI:SetTheme(val)
        WindUI:Notify({Title = "Theme Applied", Content = "Current theme: " .. val, Duration = 3})
    end
})

-- BUILDING Вкладка
autoBuildTab:Button({
    Title = "Place Wood Block",
    Callback = function() placeBlock("WoodBlock",HRP.CFrame,nil,true) end,
})

autoBuildTab:Toggle({
    Title = "Rescale Block ( click block )",
    Value = false,
    Callback = function(Value) rescaleClick = Value end,
})

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
    if rescaleClick and mouse.Target then
        rescaleBlock(mouse.Target.Parent, mouse.Target.CFrame, Vector3.new(4,4,4))
    end
end)

local dd = autoBuildTab:Dropdown({
    Title = "Choose Player Base To Copy",
    Options = getPlayers(),
    Callback = function(Value)
        local val = type(Value) == "table" and Value[1] or Value
        local realName = getRealName(val)
        for _,folder in pairs(blocksFolder:GetChildren()) do
            if folder.Name == realName then selectedBase = folder end
        end
    end,
})

autoBuildTab:Button({
    Title = "Copy Base",
    Callback = function()
        if selectedBase then clipboard = copyBuild(selectedBase)
        else WindUI:Notify({Title = "Error", Content = "No Player Selected or Left", Duration = 5}) end
    end,
})

autoBuildTab:Button({
    Title = "Paste Base",
    Callback = function()
        if clipboard then pasteBuild(clipboard, getPlayerBase()) end
    end,
})

-- Продвинутый Параграф с Иконкой (из скриншота 52682.jpg)
local pasteStatus = autoBuildTab:Paragraph({
    Title = "Auto Build Progress", 
    Desc = "Status: Idle (0%)",
    Image = "check-circle",
    ImageSize = 20
})

task.spawn(function()
    while task.wait(0.2) do
        if pasteStatus and pasteStatus.Set then
            local currentPercent = math.floor(pastePercent)
            pasteStatus:Set({
                Title = "Auto Build Progress", 
                Desc = "Status: Building... " .. currentPercent .. "%"
            })
        end
    end
end)

autoBuildTab:Toggle({
    Title = "Ignore Anchored State",
    Value = true,
    Callback = function(Value) ignoreAnchored = Value end,
})

-- AUTO FARM Вкладка
autoFarmTab:Toggle({
    Title = "Auto Farm Toggle",
    Value = false,
    Callback = function(value) autofarm = value end,
})

-- FUN Вкладка
local firstSeat = nil
local secondSeat = nil

local dd2 = funTab:Dropdown({
    Title = "Choose Player To Lock Or Bring",
    Options = getPlayers(),
    Callback = function(Value)
        local val = type(Value) == "table" and Value[1] or Value
        local realName = getRealName(val)
        playerToBring = players:FindFirstChild(realName)
    end,
})

-- Авто-обновление списков игроков каждую 1 секунду
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if dd and dd.Refresh then dd:Refresh(getPlayers()) end
            if dd2 and dd2.Refresh then dd2:Refresh(getPlayers()) end
        end)
    end
end)

funTab:Button({
    Title = "Sit In The First Seat and Click",
    Callback = function() firstSeat = humanoid.SeatPart end,
})

funTab:Button({
    Title = "Sit In The Second Seat and Click",
    Callback = function() secondSeat = humanoid.SeatPart end,
})

funTab:Button({
    Title = "Bring Player",
    Callback = function()
        if secondSeat and firstSeat and secondSeat ~= firstSeat then
            if playerToBring then bringPlayer(playerToBring,firstSeat,secondSeat)
            else WindUI:Notify({Title = "Error", Content = "Select Player!", Duration = 5}) end
        else WindUI:Notify({Title = "Error", Content = "Select 2 Different Seats!", Duration = 5}) end
    end,
})

funTab:Button({
    Title = "Car Fly",
    Callback = function()
        local UserInputService = game:GetService("UserInputService")
        local flying = false
        local flySpeed = 50
        local flyConnection
        local bv 
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CarFlyGUI"
        screenGui.Parent = player:WaitForChild("PlayerGui")
        
        local frame = Instance.new("Frame", screenGui)
        frame.Size = UDim2.new(0, 220, 0, 120)
        frame.Position = UDim2.new(0.05, 0, 0.4, 0)
        frame.BackgroundColor3 = Color3.fromRGB(163, 255, 137)
        
        local toggleButton = Instance.new("TextButton", frame)
        toggleButton.Size, toggleButton.Position = UDim2.new(0, 100, 0, 30), UDim2.new(0, 10, 0, 10)
        toggleButton.Text = "Toggle Fly"
        
        local speedLabel = Instance.new("TextLabel", frame)
        speedLabel.Size, speedLabel.Position = UDim2.new(0, 50, 0, 30), UDim2.new(0, 120, 0, 10)
        speedLabel.Text = tostring(flySpeed)
        
        local plusButton = Instance.new("TextButton", frame)
        plusButton.Size, plusButton.Position, plusButton.Text = UDim2.new(0, 30, 0, 30), UDim2.new(0, 180, 0, 10), "+"
        local minusButton = Instance.new("TextButton", frame)
        minusButton.Size, minusButton.Position, minusButton.Text = UDim2.new(0, 30, 0, 30), UDim2.new(0, 180, 0, 50), "-"
        
        local destroyButton = Instance.new("TextButton", frame)
        destroyButton.Size, destroyButton.Position = UDim2.new(0, 100, 0, 30), UDim2.new(0, 10, 0, 80)
        destroyButton.Text, destroyButton.BackgroundColor3 = "Destroy GUI", Color3.fromRGB(255, 80, 80)

        local ctrl = {f=0, b=0, l=0, r=0}
        UserInputService.InputBegan:Connect(function(input, proc)
            if proc then return end
            if input.KeyCode == Enum.KeyCode.W then ctrl.f = 1 elseif input.KeyCode == Enum.KeyCode.S then ctrl.b = -1 end
            if input.KeyCode == Enum.KeyCode.A then ctrl.l = -1 elseif input.KeyCode == Enum.KeyCode.D then ctrl.r = 1 end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then ctrl.f = 0 elseif input.KeyCode == Enum.KeyCode.S then ctrl.b = 0 end
            if input.KeyCode == Enum.KeyCode.A then ctrl.l = 0 elseif input.KeyCode == Enum.KeyCode.D then ctrl.r = 0 end
        end)

        toggleButton.MouseButton1Click:Connect(function()
            flying = not flying
            local car = getCar()
            if car and car.PrimaryPart then
                local pPart = car.PrimaryPart
                if flying then
                    if not bv then bv = Instance.new("BodyVelocity", pPart); bv.MaxForce = Vector3.new(9e9, 9e9, 9e9) end
                    if not flyConnection then
                        flyConnection = runService.RenderStepped:Connect(function()
                            if not flying then return end
                            local cam = workspace.CurrentCamera
                            local moveDir = (cam.CFrame.LookVector * (ctrl.f + ctrl.b)) + ((cam.CFrame * CFrame.new(ctrl.l + ctrl.r, 0, 0)).p - cam.CFrame.p)
                            bv.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * flySpeed or Vector3.zero
                            pPart.CFrame = CFrame.new(pPart.Position, pPart.Position + cam.CFrame.LookVector)
                        end)
                    end
                else
                    if bv then bv:Destroy() bv = nil end
                    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
                end
            end
        end)

        plusButton.MouseButton1Click:Connect(function() flySpeed = flySpeed + 10; speedLabel.Text = tostring(flySpeed) end)
        minusButton.MouseButton1Click:Connect(function() flySpeed = math.max(10, flySpeed - 10); speedLabel.Text = tostring(flySpeed) end)
        destroyButton.MouseButton1Click:Connect(function()
            flying = false
            if bv then bv:Destroy() bv = nil end
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            screenGui:Destroy()
        end)
    end,
})

task.spawn(function()
    while true do
        task.wait()
        if autofarm then
            if not HRP then continue end
            if index == 11 then
                local Stages = workspace:FindFirstChild("BoatStages")
                if not Stages then continue end
                local endpoint = Stages:FindFirstChild("NormalStages") and Stages.NormalStages:FindFirstChild("TheEnd")
                local chest = endpoint and endpoint:FindFirstChild("GoldenChest")
                if not chest then continue end
                HRP:PivotTo(chest:GetPivot() + Vector3.new(0,0,-10))
                local ii = 0
                repeat 
                    task.wait(1) 
                    ii += 1
                    if ii % 20 == 0 then HRP:PivotTo(chest:GetPivot() + Vector3.new(0,0,-10)) end
                    if not HRP then continue end
                until (HRP.Position - chest:GetPivot().Position).Magnitude > 500
                index = 1
            else
                local stages = workspace:FindFirstChild("BoatStages")
                if not stages then continue end
                local normalStages = stages:FindFirstChild("NormalStages")
                local stage = normalStages and normalStages:FindFirstChild("CaveStage"..index)
                local darkPart = stage and stage:FindFirstChild("DarknessPart")
                if not darkPart then continue end
                character:PivotTo(darkPart.CFrame - Vector3.new(0,0,15))
                local tween2 = TS:Create(HRP,TweenInfo.new(2,Enum.EasingStyle.Linear),{CFrame = darkPart.CFrame + Vector3.new(0,0,20)})
                tweening = true
                tween2:Play()
                tween2.Completed:Wait()
                tweening = false
                index += 1
            end
        end
    end
end)

runService.Heartbeat:Connect(function()
    if tweening then HRP.Velocity = Vector3.zero end
end)

player.CharacterAdded:Connect(function(charactery)
    character = charactery
    HRP = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
end)

task.spawn(function()
    while task.wait(100) do
        vim:SendKeyEvent(true, Enum.KeyCode.Tilde, false, nil)
        task.wait(0.1)
        vim:SendKeyEvent(false, Enum.KeyCode.Tilde, false, nil)
    end
end)

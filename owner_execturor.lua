-- ========== НАСТРОЙКИ ==========
local SERVER_URL = "https://disciplined-luck-production-a2ce.up.railway.app" -- ЗАМЕНИ НА СВОЙ URL
local POLL_INTERVAL = 2

-- ========== ПРОВЕРКА ОВНЕРА ==========
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local OWNER_NAMES = {"FFG_VSEV1SHN1", "Kirysha1235674"}
local isOwner = false

for _, name in ipairs(OWNER_NAMES) do
    if player.DisplayName == name or player.Name == name then
        isOwner = true
        break
    end
end

if not isOwner then
    warn("❌ Ты не овнер!")
    return
end

print("✅ Овнер авторизован:", player.DisplayName)

-- ========== ПЕРЕМЕННЫЕ ==========
local bots = {}
local selectedBots = {}
local gui = nil

-- ========== ПОЛУЧЕНИЕ СПИСКА БОТОВ ==========
local function fetchBots()
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = SERVER_URL .. "/",
            Method = "GET"
        })
        return HttpService:JSONDecode(response.Body)
    end)
    
    if success then
        -- Получаем детальную инфу через отдельный эндпоинт (добавим на сервер)
        return result
    end
    return nil
end

-- ========== ОТПРАВКА КОМАНДЫ ==========
local function sendCommand(command, params)
    local targetBots = #selectedBots > 0 and selectedBots or "all"
    
    local success, result = pcall(function()
        HttpService:RequestAsync({
            Url = SERVER_URL .. "/api/owner/command",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                targetBots = targetBots,
                command = command,
                params = params,
                owner = player.Name
            })
        })
    end)
    
    if success then
        print("✅ Команда отправлена:", command)
    else
        warn("❌ Ошибка отправки команды")
    end
end

-- ========== СОЗДАНИЕ GUI ==========
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BotControlPanel"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Draggable
    local dragging, dragInput, dragStart, startPos
    
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    local headerTitle = Instance.new("TextLabel")
    headerTitle.Size = UDim2.new(1, -20, 1, 0)
    headerTitle.Position = UDim2.new(0, 10, 0, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "🤖 BOT CONTROL PANEL"
    headerTitle.TextColor3 = Color3.new(1, 1, 1)
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = 20
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.Parent = header
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Bot List Section
    local botListFrame = Instance.new("ScrollingFrame")
    botListFrame.Name = "BotList"
    botListFrame.Size = UDim2.new(0.45, 0, 1, -120)
    botListFrame.Position = UDim2.new(0, 10, 0, 60)
    botListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    botListFrame.BorderSizePixel = 0
    botListFrame.ScrollBarThickness = 6
    botListFrame.Parent = mainFrame
    
    local botListCorner = Instance.new("UICorner")
    botListCorner.CornerRadius = UDim.new(0, 8)
    botListCorner.Parent = botListFrame
    
    local botListLayout = Instance.new("UIListLayout")
    botListLayout.Padding = UDim.new(0, 5)
    botListLayout.Parent = botListFrame
    
    -- Controls Section
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "Controls"
    controlsFrame.Size = UDim2.new(0.5, -15, 1, -120)
    controlsFrame.Position = UDim2.new(0.5, 5, 0, 60)
    controlsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    controlsFrame.BorderSizePixel = 0
    controlsFrame.Parent = mainFrame
    
    local controlsCorner = Instance.new("UICorner")
    controlsCorner.CornerRadius = UDim.new(0, 8)
    controlsCorner.Parent = controlsFrame
    
    local controlsLayout = Instance.new("UIListLayout")
    controlsLayout.Padding = UDim.new(0, 8)
    controlsLayout.Parent = controlsFrame
    controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local controlsPadding = Instance.new("UIPadding")
    controlsPadding.PaddingTop = UDim.new(0, 10)
    controlsPadding.PaddingLeft = UDim.new(0, 10)
    controlsPadding.PaddingRight = UDim.new(0, 10)
    controlsPadding.Parent = controlsFrame
    
    -- Target Player Input
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, 0, 0, 25)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "Цель (ник игрока):"
    targetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextSize = 14
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = controlsFrame
    
    local targetInput = Instance.new("TextBox")
    targetInput.Name = "TargetInput"
    targetInput.Size = UDim2.new(1, 0, 0, 35)
    targetInput.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    targetInput.BorderSizePixel = 0
    targetInput.PlaceholderText = "Введи ник..."
    targetInput.Text = ""
    targetInput.TextColor3 = Color3.new(1, 1, 1)
    targetInput.Font = Enum.Font.Gotham
    targetInput.TextSize = 14
    targetInput.Parent = controlsFrame
    
    local targetInputCorner = Instance.new("UICorner")
    targetInputCorner.CornerRadius = UDim.new(0, 6)
    targetInputCorner.Parent = targetInput
    
    -- Keys Input
    local keysLabel = Instance.new("TextLabel")
    keysLabel.Size = UDim2.new(1, 0, 0, 25)
    keysLabel.BackgroundTransparency = 1
    keysLabel.Text = "Клавиши (через запятую):"
    keysLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keysLabel.Font = Enum.Font.Gotham
    keysLabel.TextSize = 14
    keysLabel.TextXAlignment = Enum.TextXAlignment.Left
    keysLabel.Parent = controlsFrame
    
    local keysInput = Instance.new("TextBox")
    keysInput.Name = "KeysInput"
    keysInput.Size = UDim2.new(1, 0, 0, 35)
    keysInput.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    keysInput.BorderSizePixel = 0
    keysInput.PlaceholderText = "W,A,S,D,Space"
    keysInput.Text = "W,A,S,D"
    keysInput.TextColor3 = Color3.new(1, 1, 1)
    keysInput.Font = Enum.Font.Gotham
    keysInput.TextSize = 14
    keysInput.Parent = controlsFrame
    
    local keysInputCorner = Instance.new("UICorner")
    keysInputCorner.CornerRadius = UDim.new(0, 6)
    keysInputCorner.Parent = keysInput
    
    -- Buttons
    local function createButton(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.Parent = controlsFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        return btn
    end
    
    createButton("🎯 FLING (один раз)", Color3.fromRGB(220, 53, 69), function()
        local target = targetInput.Text
        if target ~= "" then
            sendCommand("fling", {target = target})
        end
    end)
    
    createButton("⚡ FLING (постоянно)", Color3.fromRGB(255, 87, 34), function()
        local target = targetInput.Text
        if target ~= "" then
            sendCommand("fling_continuous", {target = target})
        end
    end)
    
    createButton("📍 ТЕЛЕПОРТ К ИГРОКУ", Color3.fromRGB(33, 150, 243), function()
        local target = targetInput.Text
        if target ~= "" then
            sendCommand("teleport", {target = target})
        end
    end)
    
    createButton("⌨️ СПАМИТЬ КЛАВИШИ", Color3.fromRGB(156, 39, 176), function()
        local keys = {}
        for key in keysInput.Text:gmatch("[^,]+") do
            table.insert(keys, key:match("^%s*(.-)%s*$"))
        end
        sendCommand("spam_keys", {keys = keys})
    end)
    
    createButton("⏹️ СТОП ВСЁ", Color3.fromRGB(96, 125, 139), function()
        sendCommand("stop", {})
    end)
    
    -- Status Bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, -20, 0, 30)
    statusBar.Position = UDim2.new(0, 10, 1, -40)
    statusBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusBar
    
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, -10, 1, 0)
    statusText.Position = UDim2.new(0, 5, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "🔄 Загрузка..."
    statusText.TextColor3 = Color3.fromRGB(100, 200, 100)
    statusText.Font = Enum.Font.Gotham
    statusText.TextSize = 12
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = statusBar
    
    return {
        gui = screenGui,
        botList = botListFrame,
        statusText = statusText,
        targetInput = targetInput,
        keysInput = keysInput
    }
end

-- ========== ОБНОВЛЕНИЕ СПИСКА БОТОВ ==========
local function updateBotList(guiElements)
    -- Очищаем список
    for _, child in ipairs(guiElements.botList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Делаем запрос к серверу для получения списка ботов
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = SERVER_URL .. "/api/owner/bots",
            Method = "GET"
        })
        return HttpService:JSONDecode(response.Body)
    end)
    
    if success and result.bots then
        bots = result.bots
        
        for i, bot in ipairs(bots) do
            local botFrame = Instance.new("Frame")
            botFrame.Size = UDim2.new(1, -10, 0, 60)
            botFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            botFrame.BorderSizePixel = 0
            botFrame.Parent = guiElements.botList
            
            local botCorner = Instance.new("UICorner")
            botCorner.CornerRadius = UDim.new(0, 6)
            botCorner.Parent = botFrame
            
            local checkBox = Instance.new("TextButton")
            checkBox.Size = UDim2.new(0, 20, 0, 20)
            checkBox.Position = UDim2.new(0, 5, 0.5, -10)
            checkBox.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            checkBox.Text = ""
            checkBox.BorderSizePixel = 0
            checkBox.Parent = botFrame
            
            local checkCorner = Instance.new("UICorner")
            checkCorner.CornerRadius = UDim.new(0, 4)
            checkCorner.Parent = checkBox
            
            local botName = Instance.new("TextLabel")
            botName.Size = UDim2.new(1, -35, 0, 20)
            botName.Position = UDim2.new(0, 30, 0, 5)
            botName.BackgroundTransparency = 1
            botName.Text = bot.displayName
            botName.TextColor3 = Color3.new(1, 1, 1)
            botName.Font = Enum.Font.GothamBold
            botName.TextSize = 14
            botName.TextXAlignment = Enum.TextXAlignment.Left
            botName.Parent = botFrame
            
            local botStatus = Instance.new("TextLabel")
            botStatus.Size = UDim2.new(1, -35, 0, 15)
            botStatus.Position = UDim2.new(0, 30, 0, 25)
            botStatus.BackgroundTransparency = 1
            botStatus.Text = "🟢 " .. (bot.status or "idle")
            botStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
            botStatus.Font = Enum.Font.Gotham
            botStatus.TextSize = 11
            botStatus.TextXAlignment = Enum.TextXAlignment.Left
            botStatus.Parent = botFrame
            
            local botId = Instance.new("TextLabel")
            botId.Size = UDim2.new(1, -35, 0, 15)
            botId.Position = UDim2.new(0, 30, 0, 40)
            botId.BackgroundTransparency = 1
            botId.Text = "@" .. bot.username
            botId.TextColor3 = Color3.fromRGB(120, 120, 120)
            botId.Font = Enum.Font.Gotham
            botId.TextSize = 10
            botId.TextXAlignment = Enum.TextXAlignment.Left
            botId.Parent = botFrame
            
            -- Selection toggle
            checkBox.MouseButton1Click:Connect(function()
                local isSelected = table.find(selectedBots, bot.id)
                if isSelected then
                    table.remove(selectedBots, isSelected)
                    checkBox.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                else
                    table.insert(selectedBots, bot.id)
                    checkBox.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
                end
            end)
        end
        
        guiElements.statusText.Text = string.format("✅ Ботов онлайн: %d | Выбрано: %d", #bots, #selectedBots)
    else
        guiElements.statusText.Text = "❌ Ошибка загрузки ботов"
    end
end

-- ========== ЗАПУСК ==========
local guiElements = createGUI()

-- Обновление списка ботов каждые 3 секунды
task.spawn(function()
    while guiElements.gui and guiElements.gui.Parent do
        updateBotList(guiElements)
        task.wait(3)
    end
end)

print("✅ Control Panel загружен!")

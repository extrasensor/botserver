-- ========== НАСТРОЙКИ ==========
local SERVER_URL = "https://твой-проект.railway.app" -- ЗАМЕНИ НА СВОЙ URL
local POLL_INTERVAL = 2 -- Проверка команд каждые 2 секунды

-- ========== СЕРВИСЫ ==========
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ========== ПЕРЕМЕННЫЕ ==========
local botId = nil
local isRunning = true
local currentTask = nil

-- ========== РЕГИСТРАЦИЯ БОТА ==========
local function registerBot()
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = SERVER_URL .. "/api/bot/register",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                username = player.Name,
                displayName = player.DisplayName,
                userId = player.UserId
            })
        })
        return HttpService:JSONDecode(response.Body)
    end)
    
    if success and result.success then
        botId = result.botId
        print("✅ Бот зарегистрирован:", botId)
        return true
    else
        warn("❌ Ошибка регистрации:", result)
        return false
    end
end

-- ========== ОТПРАВКА СТАТУСА ==========
local function sendStatus(status, message)
    if not botId then return end
    
    pcall(function()
        HttpService:RequestAsync({
            Url = SERVER_URL .. "/api/bot/status",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                botId = botId,
                status = status,
                message = message
            })
        })
    end)
end

-- ========== ПОЛУЧЕНИЕ КОМАНД ==========
local function fetchCommands()
    if not botId then return {} end
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = SERVER_URL .. "/api/bot/commands/" .. botId,
            Method = "GET"
        })
        return HttpService:JSONDecode(response.Body)
    end)
    
    if success and result.commands then
        return result.commands
    end
    return {}
end

-- ========== FLING ФУНКЦИЯ ==========
local function flingPlayer(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character then
        sendStatus("error", "Игрок не найден: " .. targetName)
        return
    end
    
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    
    sendStatus("flinging", "Флингую: " .. targetName)
    
    -- Базовый fling метод
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = rootPart
    
    local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 9e9, 0)
    bodyAngularVelocity.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyAngularVelocity.Parent = rootPart
    
    -- Телепорт к цели и спин
    for i = 1, 100 do
        if not isRunning or not target.Character then break end
        
        rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
        task.wait(0.01)
    end
    
    bodyVelocity:Destroy()
    bodyAngularVelocity:Destroy()
    
    sendStatus("idle", "Fling завершен")
end

-- ========== НЕПРЕРЫВНЫЙ FLING ==========
local function continuousFling(targetName)
    currentTask = RunService.Heartbeat:Connect(function()
        local target = Players:FindFirstChild(targetName)
        if not target or not target.Character then
            if currentTask then currentTask:Disconnect() end
            sendStatus("idle", "Цель потеряна")
            return
        end
        
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and rootPart then
            rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
            rootPart.AssemblyLinearVelocity = Vector3.new(9e9, 9e9, 9e9)
        end
    end)
    
    sendStatus("flinging_continuous", "Постоянный fling: " .. targetName)
end

-- ========== ТЕЛЕПОРТ К ИГРОКУ ==========
local function teleportToPlayer(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character then
        sendStatus("error", "Игрок не найден: " .. targetName)
        return
    end
    
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if targetRoot then
        rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 3, 0)
        sendStatus("idle", "Телепорт к: " .. targetName)
    end
end

-- ========== ПРОЖИМ КЛАВИШ ==========
local function spamKeys(keys)
    if currentTask then currentTask:Disconnect() end
    
    sendStatus("spamming_keys", "Спамлю клавиши: " .. table.concat(keys, ", "))
    
    currentTask = RunService.Heartbeat:Connect(function()
        for _, key in ipairs(keys) do
            local keyCode = Enum.KeyCode[key]
            if keyCode then
                pcall(function()
                    game:GetService("VirtualInputManager"):SendKeyEvent(true, keyCode, false, game)
                    task.wait(0.01)
                    game:GetService("VirtualInputManager"):SendKeyEvent(false, keyCode, false, game)
                end)
            end
        end
    end)
end

-- ========== ОСТАНОВКА ТЕКУЩЕЙ ЗАДАЧИ ==========
local function stopCurrentTask()
    if currentTask then
        currentTask:Disconnect()
        currentTask = nil
    end
    sendStatus("idle", "Задача остановлена")
end

-- ========== ОБРАБОТКА КОМАНД ==========
local function executeCommand(cmd)
    local command = cmd.command
    local params = cmd.params
    
    print("📥 Команда получена:", command)
    
    if command == "fling" then
        flingPlayer(params.target)
        
    elseif command == "fling_continuous" then
        stopCurrentTask()
        continuousFling(params.target)
        
    elseif command == "teleport" then
        teleportToPlayer(params.target)
        
    elseif command == "spam_keys" then
        stopCurrentTask()
        spamKeys(params.keys)
        
    elseif command == "stop" then
        stopCurrentTask()
        
    elseif command == "follow" then
        -- TODO: следование за игроком
        sendStatus("following", "Слежу за: " .. params.target)
        
    else
        sendStatus("error", "Неизвестная команда: " .. command)
    end
end

-- ========== ОСНОВНОЙ ЦИКЛ ==========
local function mainLoop()
    while isRunning do
        local commands = fetchCommands()
        
        for _, cmd in ipairs(commands) do
            executeCommand(cmd)
        end
        
        task.wait(POLL_INTERVAL)
    end
end

-- ========== ЗАПУСК ==========
print("🤖 Инициализация бота...")

if registerBot() then
    sendStatus("idle", "Готов к работе")
    task.spawn(mainLoop)
else
    warn("❌ Не удалось подключиться к серверу")
end

-- ========== ОЧИСТКА ПРИ ВЫХОДЕ ==========
player.CharacterRemoving:Connect(function()
    isRunning = false
    stopCurrentTask()
end)

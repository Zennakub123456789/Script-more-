-- Roblox Animation Controller - Combined Script (Mobile Optimized)
-- Place this as a LocalScript in StarterPlayerScripts
-- สคริปควบคุมแอนิเมชัน Roblox แบบรวมทุกอย่างในที่เดียว รองรับมือถือ

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Mobile Detection / ตรวจสอบมือถือ
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local screenSize = workspace.CurrentCamera.ViewportSize

-- Animation Controller Variables / ตัวแปรควบคุมแอนิเมชัน
local animationController = {
    isPlaying = false,
    isPaused = false,
    currentTime = 0,
    duration = 10,
    speed = 1,
    isLooping = false,
    keyframes = {},
    selectedParts = {},
    tweens = {},
    initialTransforms = {}
}

-- Animation Module Functions / ฟังก์ชันโมดูลแอนิเมชัน
local AnimationModule = {}

-- Store initial transform of a part / เก็บข้อมูลตำแหน่งเริ่มต้นของชิ้นส่วน
function AnimationModule.storeInitialTransform(part, animationController)
    if not animationController.initialTransforms then
        animationController.initialTransforms = {}
    end
    
    animationController.initialTransforms[part] = {
        cframe = part.CFrame,
        size = part.Size,
        transparency = part.Transparency,
        color = part.Color,
        material = part.Material
    }
end

-- Create a new keyframe / สร้างคีย์เฟรมใหม่
function AnimationModule.createKeyframe(part, time, animationController)
    local keyframe = {
        time = time,
        part = part,
        cframe = part.CFrame,
        size = part.Size,
        transparency = part.Transparency,
        color = part.Color,
        easingStyle = Enum.EasingStyle.Linear,
        easingDirection = Enum.EasingDirection.InOut
    }
    
    if not animationController.keyframes[part] then
        animationController.keyframes[part] = {}
    end
    
    table.insert(animationController.keyframes[part], keyframe)
    
    -- Sort keyframes by time / เรียงคีย์เฟรมตามเวลา
    table.sort(animationController.keyframes[part], function(a, b)
        return a.time < b.time
    end)
    
    return keyframe
end

-- Add keyframe at current time / เพิ่มคีย์เฟรมที่เวลาปัจจุบัน
function AnimationModule.addKeyframeAtCurrentTime(animationController)
    for _, part in pairs(animationController.selectedParts) do
        AnimationModule.createKeyframe(part, animationController.currentTime, animationController)
    end
    print("เพิ่มคีย์เฟรมที่เวลา: " .. animationController.currentTime)
end

-- Interpolate between keyframes / การประมานค่าระหว่างคีย์เฟรม
function AnimationModule.interpolateKeyframes(keyframe1, keyframe2, alpha)
    local result = {}
    
    result.cframe = keyframe1.cframe:Lerp(keyframe2.cframe, alpha)
    result.size = keyframe1.size:Lerp(keyframe2.size, alpha)
    result.transparency = keyframe1.transparency + (keyframe2.transparency - keyframe1.transparency) * alpha
    result.color = keyframe1.color:Lerp(keyframe2.color, alpha)
    
    return result
end

-- Find surrounding keyframes / หาคีย์เฟรมที่อยู่รอบๆ
function AnimationModule.findSurroundingKeyframes(partKeyframes, currentTime)
    if #partKeyframes == 0 then return nil, nil end
    if #partKeyframes == 1 then return partKeyframes[1], partKeyframes[1] end
    
    local prevKeyframe = partKeyframes[1]
    local nextKeyframe = partKeyframes[#partKeyframes]
    
    for i = 1, #partKeyframes - 1 do
        if partKeyframes[i].time <= currentTime and partKeyframes[i + 1].time > currentTime then
            prevKeyframe = partKeyframes[i]
            nextKeyframe = partKeyframes[i + 1]
            break
        end
    end
    
    return prevKeyframe, nextKeyframe
end

-- Update animation / อัปเดตแอนิเมชัน
function AnimationModule.updateAnimation(animationController)
    for part, keyframes in pairs(animationController.keyframes) do
        if #keyframes > 0 then
            local prevKeyframe, nextKeyframe = AnimationModule.findSurroundingKeyframes(keyframes, animationController.currentTime)
            
            if prevKeyframe and nextKeyframe then
                local alpha = 0
                if nextKeyframe.time > prevKeyframe.time then
                    alpha = (animationController.currentTime - prevKeyframe.time) / (nextKeyframe.time - prevKeyframe.time)
                end
                
                local easedAlpha = TweenService:GetValue(alpha, nextKeyframe.easingStyle, nextKeyframe.easingDirection)
                local interpolated = AnimationModule.interpolateKeyframes(prevKeyframe, nextKeyframe, easedAlpha)
                
                if part and part.Parent then
                    part.CFrame = interpolated.cframe
                    part.Size = interpolated.size
                    part.Transparency = math.clamp(interpolated.transparency, 0, 1)
                    part.Color = interpolated.color
                end
            end
        end
    end
end

-- Play animation / เล่นแอนิเมชัน
function AnimationModule.playAnimation(animationController)
    if #animationController.selectedParts == 0 then
        warn("ไม่มีชิ้นส่วนที่เลือกสำหรับแอนิเมชัน!")
        return false
    end
    
    for _, part in pairs(animationController.selectedParts) do
        if not animationController.keyframes[part] or #animationController.keyframes[part] == 0 then
            AnimationModule.createKeyframe(part, 0, animationController)
            AnimationModule.createKeyframe(part, animationController.duration, animationController)
        end
    end
    
    return true
end

-- Stop animation / หยุดแอนิเมชัน
function AnimationModule.stopAnimation(animationController)
    for _, tween in pairs(animationController.tweens) do
        if tween then
            tween:Cancel()
        end
    end
    animationController.tweens = {}
end

-- Pause animation / หยุดแอนิเมชันชั่วคราว
function AnimationModule.pauseAnimation(animationController)
    for _, tween in pairs(animationController.tweens) do
        if tween then
            tween:Pause()
        end
    end
end

-- Resume animation / เล่นแอนิเมชันต่อ
function AnimationModule.resumeAnimation(animationController)
    for _, tween in pairs(animationController.tweens) do
        if tween then
            tween:Play()
        end
    end
end

-- Reset animation / รีเซ็ตแอนิเมชัน
function AnimationModule.resetAnimation(animationController)
    for part, initialTransform in pairs(animationController.initialTransforms or {}) do
        if part and part.Parent then
            part.CFrame = initialTransform.cframe
            part.Size = initialTransform.size
            part.Transparency = initialTransform.transparency
            part.Color = initialTransform.color
            part.Material = initialTransform.material
        end
    end
end

-- Save animation / บันทึกแอนิเมชัน
function AnimationModule.saveAnimation(animationController)
    local animationData = {
        duration = animationController.duration,
        keyframes = {},
        selectedParts = {}
    }
    
    for part, keyframes in pairs(animationController.keyframes) do
        animationData.keyframes[part.Name] = {}
        for _, keyframe in pairs(keyframes) do
            table.insert(animationData.keyframes[part.Name], {
                time = keyframe.time,
                cframe = {
                    position = {keyframe.cframe.Position.X, keyframe.cframe.Position.Y, keyframe.cframe.Position.Z},
                    rotation = {keyframe.cframe:ToEulerAnglesXYZ()}
                },
                size = {keyframe.size.X, keyframe.size.Y, keyframe.size.Z},
                transparency = keyframe.transparency,
                color = {keyframe.color.R, keyframe.color.G, keyframe.color.B},
                easingStyle = keyframe.easingStyle.Name,
                easingDirection = keyframe.easingDirection.Name
            })
        end
    end
    
    for _, part in pairs(animationController.selectedParts) do
        table.insert(animationData.selectedParts, part.Name)
    end
    
    local jsonData = HttpService:JSONEncode(animationData)
    print("บันทึกแอนิเมชันแล้ว!")
    
    local saveData = workspace:FindFirstChild("AnimationSaveData")
    if not saveData then
        saveData = Instance.new("StringValue")
        saveData.Name = "AnimationSaveData"
        saveData.Parent = workspace
    end
    saveData.Value = jsonData
    
    return jsonData
end

-- Load animation / โหลดแอนิเมชัน
function AnimationModule.loadAnimation(animationController)
    local saveData = workspace:FindFirstChild("AnimationSaveData")
    if not saveData or saveData.Value == "" then
        warn("ไม่พบข้อมูลแอนิเมชันที่จะโหลด!")
        return false
    end
    
    local success, animationData = pcall(function()
        return HttpService:JSONDecode(saveData.Value)
    end)
    
    if not success then
        warn("ไม่สามารถถอดรหัสข้อมูลแอนิเมชันได้!")
        return false
    end
    
    animationController.keyframes = {}
    animationController.selectedParts = {}
    animationController.duration = animationData.duration or 10
    
    for _, partName in pairs(animationData.selectedParts) do
        local part = workspace:FindFirstChild(partName, true)
        if part then
            table.insert(animationController.selectedParts, part)
            AnimationModule.storeInitialTransform(part, animationController)
        end
    end
    
    for partName, keyframes in pairs(animationData.keyframes) do
        local part = workspace:FindFirstChild(partName, true)
        if part then
            animationController.keyframes[part] = {}
            for _, keyframeData in pairs(keyframes) do
                local keyframe = {
                    time = keyframeData.time,
                    part = part,
                    cframe = CFrame.new(
                        keyframeData.cframe.position[1],
                        keyframeData.cframe.position[2],
                        keyframeData.cframe.position[3]
                    ) * CFrame.Angles(
                        keyframeData.cframe.rotation[1],
                        keyframeData.cframe.rotation[2],
                        keyframeData.cframe.rotation[3]
                    ),
                    size = Vector3.new(
                        keyframeData.size[1],
                        keyframeData.size[2],
                        keyframeData.size[3]
                    ),
                    transparency = keyframeData.transparency,
                    color = Color3.new(
                        keyframeData.color[1],
                        keyframeData.color[2],
                        keyframeData.color[3]
                    ),
                    easingStyle = Enum.EasingStyle[keyframeData.easingStyle] or Enum.EasingStyle.Linear,
                    easingDirection = Enum.EasingDirection[keyframeData.easingDirection] or Enum.EasingDirection.InOut
                }
                table.insert(animationController.keyframes[part], keyframe)
            end
            
            table.sort(animationController.keyframes[part], function(a, b)
                return a.time < b.time
            end)
        end
    end
    
    print("โหลดแอนิเมชันสำเร็จ!")
    return true
end

-- GUI Creation / สร้าง GUI
local function createMainGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AnimationController"
    screenGui.Parent = playerGui
    
    -- Responsive sizing / ขนาดที่ตอบสนอง
    local frameWidth = isMobile and math.min(screenSize.X * 0.95, 450) or 400
    local frameHeight = isMobile and math.min(screenSize.Y * 0.85, 600) or 500
    local buttonHeight = isMobile and 45 or 30
    local fontSize = isMobile and 16 or 14
    
    -- Main Frame / เฟรมหลัก
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    mainFrame.Position = isMobile and UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2) or UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title / ชื่อเรื่อง
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.Text = "ตัวควบคุมแอนิเมชัน"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    -- Control Panel / แผงควบคุม
    local controlPanel = Instance.new("Frame")
    controlPanel.Name = "ControlPanel"
    controlPanel.Size = UDim2.new(1, -20, 0, isMobile and 120 or 80)
    controlPanel.Position = UDim2.new(0, 10, 0, 50)
    controlPanel.BackgroundTransparency = 1
    controlPanel.Parent = mainFrame
    
    -- Add UIGridLayout for mobile / เพิ่ม UIGridLayout สำหรับมือถือ
    local gridLayout = nil
    if isMobile then
        gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0, (frameWidth - 40) / 3, 0, buttonHeight)
        gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
        gridLayout.Parent = controlPanel
    end
    
    -- Play Button / ปุ่มเล่น
    local playButton = Instance.new("TextButton")
    playButton.Name = "PlayButton"
    playButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 60, 0, buttonHeight)
    playButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
    playButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    playButton.Text = "เล่น"
    playButton.TextColor3 = Color3.new(1, 1, 1)
    playButton.TextScaled = true
    playButton.Font = Enum.Font.SourceSans
    playButton.Parent = controlPanel
    
    local playCorner = Instance.new("UICorner")
    playCorner.CornerRadius = UDim.new(0, 4)
    playCorner.Parent = playButton
    
    -- Stop Button / ปุ่มหยุด
    local stopButton = Instance.new("TextButton")
    stopButton.Name = "StopButton"
    stopButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 60, 0, buttonHeight)
    stopButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 70, 0, 0)
    stopButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    stopButton.Text = "หยุด"
    stopButton.TextColor3 = Color3.new(1, 1, 1)
    stopButton.TextScaled = true
    stopButton.Font = Enum.Font.SourceSans
    stopButton.Parent = controlPanel
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 4)
    stopCorner.Parent = stopButton
    
    -- Pause Button / ปุ่มหยุดชั่วคราว
    local pauseButton = Instance.new("TextButton")
    pauseButton.Name = "PauseButton"
    pauseButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 60, 0, buttonHeight)
    pauseButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 140, 0, 0)
    pauseButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
    pauseButton.Text = isMobile and "หยุด" or "หยุดชั่วคราว"
    pauseButton.TextColor3 = Color3.new(1, 1, 1)
    pauseButton.TextScaled = true
    pauseButton.Font = Enum.Font.SourceSans
    pauseButton.Parent = controlPanel
    
    local pauseCorner = Instance.new("UICorner")
    pauseCorner.CornerRadius = UDim.new(0, 4)
    pauseCorner.Parent = pauseButton
    
    -- Reset Button / ปุ่มรีเซ็ต
    local resetButton = Instance.new("TextButton")
    resetButton.Name = "ResetButton"
    resetButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 60, 0, buttonHeight)
    resetButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 210, 0, 0)
    resetButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    resetButton.Text = "รีเซ็ต"
    resetButton.TextColor3 = Color3.new(1, 1, 1)
    resetButton.TextScaled = true
    resetButton.Font = Enum.Font.SourceSans
    resetButton.Parent = controlPanel
    
    local resetCorner = Instance.new("UICorner")
    resetCorner.CornerRadius = UDim.new(0, 4)
    resetCorner.Parent = resetButton
    
    -- Loop Button / ปุ่มเล่นซ้ำ
    local loopButton = Instance.new("TextButton")
    loopButton.Name = "LoopButton"
    loopButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 60, 0, buttonHeight)
    loopButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 280, 0, 0)
    loopButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    loopButton.Text = isMobile and "ซ้ำ" or "ซ้ำ: ปิด"
    loopButton.TextColor3 = Color3.new(1, 1, 1)
    loopButton.TextScaled = true
    loopButton.Font = Enum.Font.SourceSans
    loopButton.Parent = controlPanel
    
    local loopCorner = Instance.new("UICorner")
    loopCorner.CornerRadius = UDim.new(0, 4)
    loopCorner.Parent = loopButton
    
    -- Speed Control / ควบคุมความเร็ว
    local speedFrame = Instance.new("Frame")
    speedFrame.Name = "SpeedFrame"
    speedFrame.Size = UDim2.new(1, -20, 0, isMobile and 70 or 50)
    speedFrame.Position = UDim2.new(0, 10, 0, isMobile and 180 or 140)
    speedFrame.BackgroundTransparency = 1
    speedFrame.Parent = mainFrame
    
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(0, 80, 0, 30)
    speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "ความเร็ว: 1.0x"
    speedLabel.TextColor3 = Color3.new(1, 1, 1)
    speedLabel.TextScaled = true
    speedLabel.Font = Enum.Font.SourceSans
    speedLabel.Parent = speedFrame
    
    local speedSlider = Instance.new("Frame")
    speedSlider.Name = "SpeedSlider"
    speedSlider.Size = isMobile and UDim2.new(1, -100, 0, 20) or UDim2.new(0, 200, 0, 10)
    speedSlider.Position = UDim2.new(0, 90, 0, isMobile and 15 or 10)
    speedSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    speedSlider.Parent = speedFrame
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 5)
    sliderCorner.Parent = speedSlider
    
    local speedHandle = Instance.new("Frame")
    speedHandle.Name = "SpeedHandle"
    speedHandle.Size = isMobile and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 20, 0, 20)
    speedHandle.Position = isMobile and UDim2.new(0.5, -15, 0, -5) or UDim2.new(0.5, -10, 0, -5)
    speedHandle.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    speedHandle.Parent = speedSlider
    
    local handleCorner = Instance.new("UICorner")
    handleCorner.CornerRadius = UDim.new(0, 10)
    handleCorner.Parent = speedHandle
    
    -- Timeline / ไทม์ไลน์
    local timelineFrame = Instance.new("Frame")
    timelineFrame.Name = "TimelineFrame"
    timelineFrame.Size = UDim2.new(1, -20, 0, isMobile and 100 or 80)
    timelineFrame.Position = UDim2.new(0, 10, 0, isMobile and 260 or 200)
    timelineFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    timelineFrame.Parent = mainFrame
    
    local timelineCorner = Instance.new("UICorner")
    timelineCorner.CornerRadius = UDim.new(0, 4)
    timelineCorner.Parent = timelineFrame
    
    local timelineLabel = Instance.new("TextLabel")
    timelineLabel.Name = "TimelineLabel"
    timelineLabel.Size = UDim2.new(1, 0, 0, 20)
    timelineLabel.Position = UDim2.new(0, 0, 0, 0)
    timelineLabel.BackgroundTransparency = 1
    timelineLabel.Text = "ไทม์ไลน์"
    timelineLabel.TextColor3 = Color3.new(1, 1, 1)
    timelineLabel.TextScaled = true
    timelineLabel.Font = Enum.Font.SourceSans
    timelineLabel.Parent = timelineFrame
    
    -- Progress Bar / แถบความคืบหน้า
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Size = UDim2.new(1, -20, 0, 10)
    progressBar.Position = UDim2.new(0, 10, 0, 25)
    progressBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    progressBar.Parent = timelineFrame
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 5)
    progressCorner.Parent = progressBar
    
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.Position = UDim2.new(0, 0, 0, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    progressFill.Parent = progressBar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 5)
    fillCorner.Parent = progressFill
    
    -- Time Display / แสดงเวลา
    local timeDisplay = Instance.new("TextLabel")
    timeDisplay.Name = "TimeDisplay"
    timeDisplay.Size = UDim2.new(1, 0, 0, 20)
    timeDisplay.Position = UDim2.new(0, 0, 0, 45)
    timeDisplay.BackgroundTransparency = 1
    timeDisplay.Text = "0.0วินาที / 10.0วินาที"
    timeDisplay.TextColor3 = Color3.new(1, 1, 1)
    timeDisplay.TextScaled = true
    timeDisplay.Font = Enum.Font.SourceSans
    timeDisplay.Parent = timelineFrame
    
    -- Parts Selection / การเลือกชิ้นส่วน
    local partsFrame = Instance.new("Frame")
    partsFrame.Name = "PartsFrame"
    partsFrame.Size = UDim2.new(1, -20, 0, isMobile and 180 or 150)
    partsFrame.Position = UDim2.new(0, 10, 0, isMobile and 370 or 290)
    partsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    partsFrame.Parent = mainFrame
    
    local partsCorner = Instance.new("UICorner")
    partsCorner.CornerRadius = UDim.new(0, 4)
    partsCorner.Parent = partsFrame
    
    local partsLabel = Instance.new("TextLabel")
    partsLabel.Name = "PartsLabel"
    partsLabel.Size = UDim2.new(1, 0, 0, 25)
    partsLabel.Position = UDim2.new(0, 0, 0, 0)
    partsLabel.BackgroundTransparency = 1
    partsLabel.Text = "ชิ้นส่วนที่เลือก"
    partsLabel.TextColor3 = Color3.new(1, 1, 1)
    partsLabel.TextScaled = true
    partsLabel.Font = Enum.Font.SourceSans
    partsLabel.Parent = partsFrame
    
    local partsScrollFrame = Instance.new("ScrollingFrame")
    partsScrollFrame.Name = "PartsScrollFrame"
    partsScrollFrame.Size = UDim2.new(1, -20, 1, -35)
    partsScrollFrame.Position = UDim2.new(0, 10, 0, 30)
    partsScrollFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    partsScrollFrame.BorderSizePixel = 0
    partsScrollFrame.ScrollBarThickness = 8
    partsScrollFrame.Parent = partsFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 4)
    scrollCorner.Parent = partsScrollFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = partsScrollFrame
    
    -- Save/Load Buttons / ปุ่มบันทึก/โหลด
    local saveLoadFrame = Instance.new("Frame")
    saveLoadFrame.Name = "SaveLoadFrame"
    saveLoadFrame.Size = UDim2.new(1, -20, 0, isMobile and 60 or 40)
    saveLoadFrame.Position = UDim2.new(0, 10, 0, frameHeight - (isMobile and 70 or 60))
    saveLoadFrame.BackgroundTransparency = 1
    saveLoadFrame.Parent = mainFrame
    
    -- Mobile grid layout for save/load buttons / เลย์เอาต์แบบตารางสำหรับปุ่มมือถือ
    local saveLoadGrid = nil
    if isMobile then
        saveLoadGrid = Instance.new("UIGridLayout")
        saveLoadGrid.CellSize = UDim2.new(0, (frameWidth - 40) / 3, 0, buttonHeight)
        saveLoadGrid.CellPadding = UDim2.new(0, 5, 0, 5)
        saveLoadGrid.Parent = saveLoadFrame
    end
    
    local saveButton = Instance.new("TextButton")
    saveButton.Name = "SaveButton"
    saveButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 80, 0, buttonHeight)
    saveButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
    saveButton.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    saveButton.Text = "บันทึก"
    saveButton.TextColor3 = Color3.new(1, 1, 1)
    saveButton.TextScaled = true
    saveButton.Font = Enum.Font.SourceSans
    saveButton.Parent = saveLoadFrame
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 4)
    saveCorner.Parent = saveButton
    
    local loadButton = Instance.new("TextButton")
    loadButton.Name = "LoadButton"
    loadButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 80, 0, buttonHeight)
    loadButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 90, 0, 0)
    loadButton.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
    loadButton.Text = "โหลด"
    loadButton.TextColor3 = Color3.new(1, 1, 1)
    loadButton.TextScaled = true
    loadButton.Font = Enum.Font.SourceSans
    loadButton.Parent = saveLoadFrame
    
    local loadCorner = Instance.new("UICorner")
    loadCorner.CornerRadius = UDim.new(0, 4)
    loadCorner.Parent = loadButton
    
    local addKeyframeButton = Instance.new("TextButton")
    addKeyframeButton.Name = "AddKeyframeButton"
    addKeyframeButton.Size = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 100, 0, buttonHeight)
    addKeyframeButton.Position = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 190, 0, 0)
    addKeyframeButton.BackgroundColor3 = Color3.fromRGB(100, 0, 150)
    addKeyframeButton.Text = isMobile and "คีย์เฟรม" or "เพิ่มคีย์เฟรม"
    addKeyframeButton.TextColor3 = Color3.new(1, 1, 1)
    addKeyframeButton.TextScaled = true
    addKeyframeButton.Font = Enum.Font.SourceSans
    addKeyframeButton.Parent = saveLoadFrame
    
    local keyframeCorner = Instance.new("UICorner")
    keyframeCorner.CornerRadius = UDim.new(0, 4)
    keyframeCorner.Parent = addKeyframeButton
    
    -- Mobile Selection Button / ปุ่มเลือกชิ้นส่วนสำหรับมือถือ
    local selectButton = nil
    if isMobile then
        selectButton = Instance.new("TextButton")
        selectButton.Name = "SelectButton"
        selectButton.Size = UDim2.new(0, 0, 0, 0)
        selectButton.Position = UDim2.new(0, 0, 0, 0)
        selectButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
        selectButton.Text = "เลือก"
        selectButton.TextColor3 = Color3.new(1, 1, 1)
        selectButton.TextScaled = true
        selectButton.Font = Enum.Font.SourceSans
        selectButton.Parent = controlPanel
        
        local selectCorner = Instance.new("UICorner")
        selectCorner.CornerRadius = UDim.new(0, 4)
        selectCorner.Parent = selectButton
    end
    
    return screenGui, {
        mainFrame = mainFrame,
        playButton = playButton,
        stopButton = stopButton,
        pauseButton = pauseButton,
        resetButton = resetButton,
        loopButton = loopButton,
        speedLabel = speedLabel,
        speedSlider = speedSlider,
        speedHandle = speedHandle,
        progressFill = progressFill,
        timeDisplay = timeDisplay,
        partsScrollFrame = partsScrollFrame,
        saveButton = saveButton,
        loadButton = loadButton,
        addKeyframeButton = addKeyframeButton,
        selectButton = selectButton
    }
end

-- Update Progress Bar / อัปเดตแถบความคืบหน้า
function updateProgressBar(gui)
    local progress = animationController.currentTime / animationController.duration
    gui.progressFill.Size = UDim2.new(progress, 0, 1, 0)
    gui.timeDisplay.Text = string.format("%.1fวินาที / %.1fวินาที", animationController.currentTime, animationController.duration)
end

-- Update Parts List / อัปเดตรายการชิ้นส่วน
function updatePartsList(gui)
    for _, child in pairs(gui.partsScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    for i, part in pairs(animationController.selectedParts) do
        local partFrame = Instance.new("Frame")
        partFrame.Size = UDim2.new(1, 0, 0, 25)
        partFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        partFrame.Parent = gui.partsScrollFrame
        
        local partCorner = Instance.new("UICorner")
        partCorner.CornerRadius = UDim.new(0, 4)
        partCorner.Parent = partFrame
        
        local partLabel = Instance.new("TextLabel")
        partLabel.Size = UDim2.new(0.8, 0, 1, 0)
        partLabel.Position = UDim2.new(0, 5, 0, 0)
        partLabel.BackgroundTransparency = 1
        partLabel.Text = part.Name
        partLabel.TextColor3 = Color3.new(1, 1, 1)
        partLabel.TextScaled = true
        partLabel.Font = Enum.Font.SourceSans
        partLabel.TextXAlignment = Enum.TextXAlignment.Left
        partLabel.Parent = partFrame
        
        local removeButton = Instance.new("TextButton")
        removeButton.Size = UDim2.new(0.15, 0, 0.8, 0)
        removeButton.Position = UDim2.new(0.8, 0, 0.1, 0)
        removeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        removeButton.Text = "X"
        removeButton.TextColor3 = Color3.new(1, 1, 1)
        removeButton.TextScaled = true
        removeButton.Font = Enum.Font.SourceSansBold
        removeButton.Parent = partFrame
        
        local removeCorner = Instance.new("UICorner")
        removeCorner.CornerRadius = UDim.new(0, 4)
        removeCorner.Parent = removeButton
        
        removeButton.MouseButton1Click:Connect(function()
            table.remove(animationController.selectedParts, i)
            updatePartsList(gui)
        end)
    end
    
    gui.partsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, #animationController.selectedParts * 27)
end

-- Event Handlers / ตัวจัดการเหตุการณ์
local function setupEventHandlers(gui, selectionModeRef)
    -- Play Button / ปุ่มเล่น
    gui.playButton.MouseButton1Click:Connect(function()
        if not animationController.isPlaying then
            animationController.isPlaying = true
            animationController.isPaused = false
            gui.playButton.Text = "กำลังเล่น..."
            gui.pauseButton.Text = "หยุดชั่วคราว"
            AnimationModule.playAnimation(animationController)
        end
    end)
    
    -- Stop Button / ปุ่มหยุด
    gui.stopButton.MouseButton1Click:Connect(function()
        animationController.isPlaying = false
        animationController.isPaused = false
        animationController.currentTime = 0
        gui.playButton.Text = "เล่น"
        gui.pauseButton.Text = "หยุดชั่วคราว"
        AnimationModule.stopAnimation(animationController)
        updateProgressBar(gui)
    end)
    
    -- Pause Button / ปุ่มหยุดชั่วคราว
    gui.pauseButton.MouseButton1Click:Connect(function()
        if animationController.isPlaying then
            if animationController.isPaused then
                animationController.isPaused = false
                gui.pauseButton.Text = "หยุดชั่วคราว"
                AnimationModule.resumeAnimation(animationController)
            else
                animationController.isPaused = true
                gui.pauseButton.Text = "เล่นต่อ"
                AnimationModule.pauseAnimation(animationController)
            end
        end
    end)
    
    -- Reset Button / ปุ่มรีเซ็ต
    gui.resetButton.MouseButton1Click:Connect(function()
        animationController.currentTime = 0
        animationController.isPlaying = false
        animationController.isPaused = false
        gui.playButton.Text = "เล่น"
        gui.pauseButton.Text = "หยุดชั่วคราว"
        AnimationModule.resetAnimation(animationController)
        updateProgressBar(gui)
    end)
    
    -- Loop Button / ปุ่มเล่นซ้ำ
    gui.loopButton.MouseButton1Click:Connect(function()
        animationController.isLooping = not animationController.isLooping
        gui.loopButton.Text = animationController.isLooping and "ซ้ำ: เปิด" or "ซ้ำ: ปิด"
        gui.loopButton.BackgroundColor3 = animationController.isLooping and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(0, 100, 200)
    end)
    
    -- Speed Control / ควบคุมความเร็ว
    local dragging = false
    local speedDragging = false
    
    -- Mouse/Touch events for speed control / เหตุการณ์เมาส์/สัมผัสสำหรับควบคุมความเร็ว
    gui.speedHandle.MouseButton1Down:Connect(function()
        speedDragging = true
    end)
    
    if isMobile then
        gui.speedHandle.TouchTap:Connect(function()
            speedDragging = true
        end)
    end
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            speedDragging = false
        end
    end)
    
    RunService.Heartbeat:Connect(function()
        if speedDragging then
            local inputPos
            if isMobile then
                local touches = UserInputService:GetTouchEvents()
                if #touches > 0 then
                    inputPos = Vector2.new(touches[1].Position.X, touches[1].Position.Y)
                else
                    inputPos = UserInputService:GetMouseLocation()
                end
            else
                inputPos = UserInputService:GetMouseLocation()
            end
            
            if inputPos then
                local sliderPos = gui.speedSlider.AbsolutePosition
                local sliderSize = gui.speedSlider.AbsoluteSize
                
                local relativePos = math.clamp((inputPos.X - sliderPos.X) / sliderSize.X, 0, 1)
                local handleOffset = isMobile and -15 or -10
                gui.speedHandle.Position = UDim2.new(relativePos, handleOffset, 0, -5)
                
                animationController.speed = 0.1 + (relativePos * 2.9)
                gui.speedLabel.Text = "ความเร็ว: " .. string.format("%.1f", animationController.speed) .. "x"
            end
        end
    end)
    
    -- Save Button / ปุ่มบันทึก
    gui.saveButton.MouseButton1Click:Connect(function()
        AnimationModule.saveAnimation(animationController)
    end)
    
    -- Load Button / ปุ่มโหลด
    gui.loadButton.MouseButton1Click:Connect(function()
        AnimationModule.loadAnimation(animationController)
        updatePartsList(gui)
    end)
    
    -- Add Keyframe Button / ปุ่มเพิ่มคีย์เฟรม
    gui.addKeyframeButton.MouseButton1Click:Connect(function()
        AnimationModule.addKeyframeAtCurrentTime(animationController)
    end)
    
    -- Mobile Selection Button / ปุ่มเลือกชิ้นส่วนมือถือ
    if isMobile and gui.selectButton then
        gui.selectButton.MouseButton1Click:Connect(function()
            local currentMode = gui.selectButton.Text == "เลือก"
            if currentMode then
                gui.selectButton.Text = "กำลังเลือก..."
                gui.selectButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                _G.mobileSelectionMode = true
            else
                gui.selectButton.Text = "เลือก"
                gui.selectButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                _G.mobileSelectionMode = false
            end
        end)
    end
end

-- Part Selection System / ระบบเลือกชิ้นส่วน
local function setupPartSelection()
    local mouse = player:GetMouse()
    local ctrlPressed = false
    local selectionMode = false -- Mobile selection mode
    
    -- Desktop controls / ควบคุมเดสก์ทอป
    if not isMobile then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.KeyCode == Enum.KeyCode.LeftControl then
                ctrlPressed = true
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if input.KeyCode == Enum.KeyCode.LeftControl then
                ctrlPressed = false
            end
        end)
        
        mouse.Button1Down:Connect(function()
            if ctrlPressed then
                local target = mouse.Target
                if target and target.Parent:FindFirstChild("Humanoid") == nil then
                    local alreadySelected = false
                    for _, part in pairs(animationController.selectedParts) do
                        if part == target then
                            alreadySelected = true
                            break
                        end
                    end
                    
                    if not alreadySelected then
                        table.insert(animationController.selectedParts, target)
                        AnimationModule.storeInitialTransform(target, animationController)
                        updatePartsList(guiElements)
                        print("เลือกชิ้นส่วน: " .. target.Name)
                    end
                end
            end
        end)
    else
        -- Mobile touch controls / ควบคุมสัมผัสมือถือ
        _G.mobileSelectionMode = false
        UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
            if _G.mobileSelectionMode and not gameProcessed then
                local camera = workspace.CurrentCamera
                local unitRay = camera:ScreenPointToRay(touchPositions[1].X, touchPositions[1].Y)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {player.Character}
                
                local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
                
                if raycastResult then
                    local target = raycastResult.Instance
                    if target and target.Parent:FindFirstChild("Humanoid") == nil then
                        local alreadySelected = false
                        for _, part in pairs(animationController.selectedParts) do
                            if part == target then
                                alreadySelected = true
                                break
                            end
                        end
                        
                        if not alreadySelected then
                            table.insert(animationController.selectedParts, target)
                            AnimationModule.storeInitialTransform(target, animationController)
                            updatePartsList(guiElements)
                            print("เลือกชิ้นส่วน: " .. target.Name)
                        end
                    end
                end
            end
        end)
    end
    
    return selectionMode
end

-- Animation Update Loop / วงจรอัปเดตแอนิเมชัน
local function startAnimationLoop(gui)
    RunService.Heartbeat:Connect(function(deltaTime)
        if animationController.isPlaying and not animationController.isPaused then
            animationController.currentTime = animationController.currentTime + (deltaTime * animationController.speed)
            
            if animationController.currentTime >= animationController.duration then
                if animationController.isLooping then
                    animationController.currentTime = 0
                else
                    animationController.isPlaying = false
                    animationController.currentTime = animationController.duration
                    gui.playButton.Text = "เล่น"
                end
            end
            
            AnimationModule.updateAnimation(animationController)
            updateProgressBar(gui)
        end
    end)
end

-- Initialize / เริ่มต้น
local screenGui, guiElements = createMainGUI()
local selectionMode = setupPartSelection()
setupEventHandlers(guiElements, selectionMode)
startAnimationLoop(guiElements)

-- Make GUI draggable / ทำให้ GUI ลากได้
local dragging = false
local dragStart = nil
local startPos = nil

guiElements.mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = guiElements.mainFrame.Position
    end
end)

guiElements.mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            guiElements.mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

guiElements.mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

print("ระบบควบคุมแอนิเมชัน Roblox โหลดสำเร็จ! (รองรับมือถือ)")
print("คำแนะนำ:")
if isMobile then
    print("📱 โหมดมือถือ:")
    print("1. กดปุ่ม 'เลือก' เพื่อเข้าโหมดเลือกชิ้นส่วน")
    print("2. แตะที่ชิ้นส่วนเพื่อเลือก")
    print("3. กดปุ่ม 'คีย์เฟรม' เพื่อสร้างจุดแอนิเมชัน")
    print("4. ใช้ปุ่มต่างๆ เพื่อควบคุมการเล่น")
    print("5. ลากแถบความเร็วเพื่อปรับความเร็ว")
else
    print("🖥️ โหมดเดสก์ทอป:")
    print("1. กด Ctrl + คลิกที่ชิ้นส่วนเพื่อเลือก")
    print("2. คลิก 'เพิ่มคีย์เฟรม' เพื่อสร้างจุดแอนิเมชัน")
    print("3. ใช้ปุ่มต่างๆ เพื่อควบคุมการเล่น")
end
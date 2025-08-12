--!strict
-- ModernGUILib - A Modern, Responsive Roblox GUI Library
-- Combined Version - All modules in one file

local ModernGUILib = {}

-- ========================================
-- CONFIG MODULE
-- ========================================
local Config = {}

Config.DefaultTheme = "Dark"

Config.DefaultColors = {
    Primary = Color3.fromRGB(50, 150, 250), -- Blue
    Secondary = Color3.fromRGB(70, 70, 70), -- Dark Gray
    Background = Color3.fromRGB(30, 30, 30), -- Very Dark Gray
    Text = Color3.fromRGB(240, 240, 240), -- Off-white
    Accent = Color3.fromRGB(250, 100, 50), -- Orange
}

Config.DefaultFont = Enum.Font.GothamBold
Config.DefaultFontSize = 18

Config.AnimationSpeed = 0.2 -- seconds
Config.AnimationEasingStyle = Enum.EasingStyle.Quad
Config.AnimationEasingDirection = Enum.EasingDirection.Out

-- ========================================
-- UTIL MODULE
-- ========================================
local Util = {}

-- Function to create a new UI element with common properties
function Util.createUI(className: string, parent: Instance, name: string?): Instance
    local ui = Instance.new(className)
    if name then
        ui.Name = name
    end
    ui.Parent = parent
    return ui
end

-- Function to set common UI properties (e.g., scale, position, anchor point)
function Util.setProperties(ui: GuiObject, properties: { [string]: any })
    for prop, value in pairs(properties) do
        ui[prop] = value
    end
end

-- Function to tween UI properties
function Util.tween(instance: Instance, properties: { [string]: any }, time: number, easingStyle: Enum.EasingStyle, easingDirection: Enum.EasingDirection)
    local tweenInfo = TweenInfo.new(time, easingStyle, easingDirection)
    local tween = game:GetService("TweenService"):Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Function to get screen size for responsive design
function Util.getScreenSize(): Vector2
    return game:GetService("UserInputService").ViewportSize
end

-- Function to convert UDim2 offset to scale based on parent size
function Util.offsetToScale(ui: GuiObject, offset: UDim2): UDim2
    local parentSize = ui.Parent.AbsoluteSize
    return UDim2.new(
        offset.X.Scale + (offset.X.Offset / parentSize.X),
        0,
        offset.Y.Scale + (offset.Y.Offset / parentSize.Y),
        0
    )
end

-- Function to convert UDim2 scale to offset based on parent size
function Util.scaleToOffset(ui: GuiObject, scale: UDim2): UDim2
    local parentSize = ui.Parent.AbsoluteSize
    return UDim2.new(
        scale.X.Scale,
        scale.X.Scale * parentSize.X,
        scale.Y.Scale,
        scale.Y.Scale * parentSize.Y
    )
end

-- ========================================
-- THEME MODULE
-- ========================================
local Theme = {}

Theme.CurrentTheme = Config.DefaultTheme

Theme.Themes = {
    Dark = {
        Primary = Config.DefaultColors.Primary,
        Secondary = Config.DefaultColors.Secondary,
        Background = Config.DefaultColors.Background,
        Text = Config.DefaultColors.Text,
        Accent = Config.DefaultColors.Accent,
        Font = Config.DefaultFont,
        FontSize = Config.DefaultFontSize,
    },
    Light = {
        Primary = Color3.fromRGB(0, 120, 215), -- Lighter Blue
        Secondary = Color3.fromRGB(200, 200, 200), -- Light Gray
        Background = Color3.fromRGB(240, 240, 240), -- Very Light Gray
        Text = Color3.fromRGB(30, 30, 30), -- Dark Text
        Accent = Color3.fromRGB(255, 165, 0), -- Orange
        Font = Enum.Font.Gotham,
        FontSize = Config.DefaultFontSize,
    },
}

function Theme.setTheme(themeName: string)
    if Theme.Themes[themeName] then
        Theme.CurrentTheme = themeName
        print("Theme set to: " .. themeName)
    else
        warn("Theme '" .. themeName .. "' not found.")
    end
end

function Theme.getColors(): {
    Primary: Color3,
    Secondary: Color3,
    Background: Color3,
    Text: Color3,
    Accent: Color3,
    Font: Enum.Font,
    FontSize: number,
}
    return Theme.Themes[Theme.CurrentTheme]
end

-- ========================================
-- COMPONENT BASE CLASS
-- ========================================
local Component = {}
Component.__index = Component

function Component.new(instance: GuiObject, properties: { [string]: any }?)
    local self = setmetatable({}, Component)
    self.Instance = instance
    self.Properties = properties or {}
    self.Children = {}

    -- Apply initial properties
    if self.Properties then
        Util.setProperties(self.Instance, self.Properties)
    end

    -- Apply theme colors initially
    self:applyTheme()

    return self
end

function Component:addChild(childComponent: Component)
    table.insert(self.Children, childComponent)
    childComponent.Instance.Parent = self.Instance
end

function Component:applyTheme()
    local colors = Theme.getColors()
    -- This is a placeholder. Subclasses will override this to apply specific colors.
end

function Component:destroy()
    for _, child in ipairs(self.Children) do
        child:destroy()
    end
    self.Instance:Destroy()
    self.Children = {}
    self.Properties = {}
    setmetatable(self, nil)
end

-- ========================================
-- WINDOW CLASS
-- ========================================
local Window = {}
Window.__index = Window

function Window.new(options: {
    Title: string?,
    Icon: string?,
    Author: string?,
    Folder: string?,
    Size: UDim2?,
    Transparent: boolean?,
    Theme: string?,
    Resizable: boolean?,
    SideBarWidth: number?,
    Background: string?,
    BackgroundImageTransparency: number?,
    HideSearchBar: boolean?,
    ScrollBarEnabled: boolean?,
    User: {
        Enabled: boolean?,
        Anonymous: boolean?,
        Callback: (() -> ())?,
    }?,
})
    local self = setmetatable({}, Window)
    
    -- Set default values
    self.Title = options.Title or "ModernGUILib Window"
    self.Icon = options.Icon or ""
    self.Author = options.Author or "ModernGUILib"
    self.Folder = options.Folder or "ModernGUILib"
    self.Size = options.Size or UDim2.fromOffset(550, 350)
    self.Transparent = options.Transparent or false
    self.Theme = options.Theme or "Dark"
    self.Resizable = options.Resizable or true
    self.SideBarWidth = options.SideBarWidth or 200
    self.Background = options.Background or ""
    self.BackgroundImageTransparency = options.BackgroundImageTransparency or 0.42
    self.HideSearchBar = options.HideSearchBar or false
    self.ScrollBarEnabled = options.ScrollBarEnabled or true
    self.User = options.User or { Enabled = false, Anonymous = true, Callback = function() end }
    
    self.Tabs = {}
    self.CurrentTab = nil
    
    -- Set theme
    Theme.setTheme(self.Theme)
    
    -- Create main GUI
    self:_createMainGUI()
    
    return self
end

function Window:_createMainGUI()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main ScreenGui
    self.ScreenGui = Util.createUI("ScreenGui", PlayerGui, "ModernGUILib_" .. self.Folder)
    
    -- Main Window Frame
    self.MainFrame = Util.createUI("Frame", self.ScreenGui, "MainFrame")
    self.MainFrame.Size = self.Size
    self.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.BackgroundColor3 = Theme.getColors().Background
    
    -- Add corner rounding
    Util.createUI("UICorner", self.MainFrame, "Corner")
    
    -- Background image if provided
    if self.Background ~= "" then
        local bgImage = Util.createUI("ImageLabel", self.MainFrame, "BackgroundImage")
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.Position = UDim2.new(0, 0, 0, 0)
        bgImage.Image = self.Background
        bgImage.ImageTransparency = self.BackgroundImageTransparency
        bgImage.BackgroundTransparency = 1
        Util.createUI("UICorner", bgImage, "Corner")
    end
    
    -- Title Bar
    self.TitleBar = Util.createUI("Frame", self.MainFrame, "TitleBar")
    self.TitleBar.Size = UDim2.new(1, 0, 0, 40)
    self.TitleBar.Position = UDim2.new(0, 0, 0, 0)
    self.TitleBar.BackgroundColor3 = Theme.getColors().Secondary
    self.TitleBar.BorderSizePixel = 0
    
    -- Title bar corner rounding (top only)
    local titleCorner = Util.createUI("UICorner", self.TitleBar, "Corner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    
    -- Title Text
    self.TitleLabel = Util.createUI("TextLabel", self.TitleBar, "TitleLabel")
    self.TitleLabel.Size = UDim2.new(1, -100, 1, 0)
    self.TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    self.TitleLabel.BackgroundTransparency = 1
    self.TitleLabel.Text = self.Title
    self.TitleLabel.TextColor3 = Theme.getColors().Text
    self.TitleLabel.TextSize = 16
    self.TitleLabel.Font = Theme.getColors().Font
    self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    -- Close Button
    self.CloseButton = Util.createUI("TextButton", self.TitleBar, "CloseButton")
    self.CloseButton.Size = UDim2.new(0, 30, 0, 30)
    self.CloseButton.Position = UDim2.new(1, -35, 0.5, -15)
    self.CloseButton.AnchorPoint = Vector2.new(0, 0.5)
    self.CloseButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    self.CloseButton.Text = "X"
    self.CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.CloseButton.TextSize = 14
    self.CloseButton.Font = Enum.Font.GothamBold
    self.CloseButton.BorderSizePixel = 0
    Util.createUI("UICorner", self.CloseButton, "Corner")
    
    self.CloseButton.MouseButton1Click:Connect(function()
        self.ScreenGui:Destroy()
    end)
    
    -- Sidebar
    self.Sidebar = Util.createUI("Frame", self.MainFrame, "Sidebar")
    self.Sidebar.Size = UDim2.new(0, self.SideBarWidth, 1, -40)
    self.Sidebar.Position = UDim2.new(0, 0, 0, 40)
    self.Sidebar.BackgroundColor3 = Theme.getColors().Secondary
    self.Sidebar.BorderSizePixel = 0
    
    -- Sidebar scroll frame
    self.SidebarScroll = Util.createUI("ScrollingFrame", self.Sidebar, "SidebarScroll")
    self.SidebarScroll.Size = UDim2.new(1, 0, 1, 0)
    self.SidebarScroll.Position = UDim2.new(0, 0, 0, 0)
    self.SidebarScroll.BackgroundTransparency = 1
    self.SidebarScroll.BorderSizePixel = 0
    self.SidebarScroll.ScrollBarThickness = self.ScrollBarEnabled and 6 or 0
    self.SidebarScroll.ScrollBarImageColor3 = Theme.getColors().Primary
    
    -- Sidebar layout
    local sidebarLayout = Util.createUI("UIListLayout", self.SidebarScroll, "SidebarLayout")
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    sidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    sidebarLayout.Padding = UDim.new(0, 5)
    
    -- Content Area
    self.ContentArea = Util.createUI("Frame", self.MainFrame, "ContentArea")
    self.ContentArea.Size = UDim2.new(1, -self.SideBarWidth, 1, -40)
    self.ContentArea.Position = UDim2.new(0, self.SideBarWidth, 0, 40)
    self.ContentArea.BackgroundColor3 = Theme.getColors().Background
    self.ContentArea.BorderSizePixel = 0
    
    -- Make window draggable
    self:_makeDraggable()
end

function Window:_makeDraggable()
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

function Window:CreateTab(options: {
    Title: string,
    Icon: string?,
})
    local tab = {}
    tab.Title = options.Title
    tab.Icon = options.Icon or ""
    tab.Elements = {}
    
    -- Create tab button in sidebar
    local tabButton = Util.createUI("TextButton", self.SidebarScroll, "TabButton_" .. options.Title)
    tabButton.Size = UDim2.new(1, -10, 0, 40)
    tabButton.BackgroundColor3 = Theme.getColors().Background
    tabButton.Text = options.Title
    tabButton.TextColor3 = Theme.getColors().Text
    tabButton.TextSize = 14
    tabButton.Font = Theme.getColors().Font
    tabButton.BorderSizePixel = 0
    Util.createUI("UICorner", tabButton, "Corner")
    
    -- Create tab content frame
    local tabContent = Util.createUI("ScrollingFrame", self.ContentArea, "TabContent_" .. options.Title)
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.Position = UDim2.new(0, 0, 0, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.BorderSizePixel = 0
    tabContent.ScrollBarThickness = self.ScrollBarEnabled and 6 or 0
    tabContent.ScrollBarImageColor3 = Theme.getColors().Primary
    tabContent.Visible = false
    
    -- Tab content layout
    local contentLayout = Util.createUI("UIListLayout", tabContent, "ContentLayout")
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    contentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    contentLayout.Padding = UDim.new(0, 10)
    
    -- Add padding to content
    local contentPadding = Util.createUI("UIPadding", tabContent, "ContentPadding")
    contentPadding.PaddingTop = UDim.new(0, 10)
    contentPadding.PaddingBottom = UDim.new(0, 10)
    contentPadding.PaddingLeft = UDim.new(0, 10)
    contentPadding.PaddingRight = UDim.new(0, 10)
    
    tab.Button = tabButton
    tab.Content = tabContent
    
    -- Tab button click event
    tabButton.MouseButton1Click:Connect(function()
        self:_selectTab(tab)
    end)
    
    -- Hover effects for tab button
    tabButton.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            Util.tween(tabButton, { BackgroundColor3 = Theme.getColors().Primary:Lerp(Theme.getColors().Background, 0.7) }, Config.AnimationSpeed, Config.AnimationEasingStyle, Config.AnimationEasingDirection)
        end
    end)
    
    tabButton.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            Util.tween(tabButton, { BackgroundColor3 = Theme.getColors().Background }, Config.AnimationSpeed, Config.AnimationEasingStyle, Config.AnimationEasingDirection)
        end
    end)
    
    -- Add tab methods
    tab.CreateButton = function(options: {
        Title: string,
        Description: string?,
        Callback: (() -> ())?,
    })
        return self:_createButton(tab, options)
    end
    
    tab.CreateToggle = function(options: {
        Title: string,
        Description: string?,
        Default: boolean?,
        Callback: ((value: boolean) -> ())?,
    })
        return self:_createToggle(tab, options)
    end
    
    tab.CreateSlider = function(options: {
        Title: string,
        Description: string?,
        Default: number?,
        Min: number?,
        Max: number?,
        Callback: ((value: number) -> ())?,
    })
        return self:_createSlider(tab, options)
    end
    
    tab.CreateTextbox = function(options: {
        Title: string,
        Description: string?,
        Default: string?,
        PlaceholderText: string?,
        Callback: ((value: string) -> ())?,
    })
        return self:_createTextbox(tab, options)
    end
    
    tab.CreateDropdown = function(options: {
        Title: string,
        Description: string?,
        Options: {string},
        Default: string?,
        Callback: ((value: string) -> ())?,
    })
        return self:_createDropdown(tab, options)
    end
    
    table.insert(self.Tabs, tab)
    
    -- Select first tab automatically
    if #self.Tabs == 1 then
        self:_selectTab(tab)
    end
    
    return tab
end

function Window:_selectTab(tab)
    -- Hide all tabs
    for _, t in ipairs(self.Tabs) do
        t.Content.Visible = false
        t.Button.BackgroundColor3 = Theme.getColors().Background
    end
    
    -- Show selected tab
    tab.Content.Visible = true
    tab.Button.BackgroundColor3 = Theme.getColors().Primary
    self.CurrentTab = tab
end

function Window:_createButton(tab, options)
    local buttonFrame = Util.createUI("Frame", tab.Content, "ButtonFrame")
    buttonFrame.Size = UDim2.new(1, 0, 0, 60)
    buttonFrame.BackgroundColor3 = Theme.getColors().Secondary
    buttonFrame.BorderSizePixel = 0
    Util.createUI("UICorner", buttonFrame, "Corner")
    
    local titleLabel = Util.createUI("TextLabel", buttonFrame, "TitleLabel")
    titleLabel.Size = UDim2.new(1, -120, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = options.Title
    titleLabel.TextColor3 = Theme.getColors().Text
    titleLabel.TextSize = 14
    titleLabel.Font = Theme.getColors().Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    if options.Description then
        local descLabel = Util.createUI("TextLabel", buttonFrame, "DescLabel")
        descLabel.Size = UDim2.new(1, -120, 0, 15)
        descLabel.Position = UDim2.new(0, 10, 0, 30)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = options.Description
        descLabel.TextColor3 = Theme.getColors().Text:Lerp(Theme.getColors().Background, 0.3)
        descLabel.TextSize = 12
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
    
    local button = Util.createUI("TextButton", buttonFrame, "Button")
    button.Size = UDim2.new(0, 100, 0, 30)
    button.Position = UDim2.new(1, -110, 0.5, -15)
    button.AnchorPoint = Vector2.new(0, 0.5)
    button.BackgroundColor3 = Theme.getColors().Primary
    button.Text = "Click"
    button.TextColor3 = Theme.getColors().Text
    button.TextSize = 12
    button.Font = Theme.getColors().Font
    button.BorderSizePixel = 0
    Util.createUI("UICorner", button, "Corner")
    
    -- Button effects
    button.MouseEnter:Connect(function()
        Util.tween(button, { BackgroundColor3 = Theme.getColors().Primary:Lerp(Color3.new(1,1,1), 0.2) }, Config.AnimationSpeed, Config.AnimationEasingStyle, Config.AnimationEasingDirection)
    end)
    
    button.MouseLeave:Connect(function()
        Util.tween(button, { BackgroundColor3 = Theme.getColors().Primary }, Config.AnimationSpeed, Config.AnimationEasingStyle, Config.AnimationEasingDirection)
    end)
    
    button.MouseButton1Click:Connect(function()
        if options.Callback then
            options.Callback()
        end
    end)
    
    return {
        SetText = function(text: string)
            button.Text = text
        end,
        SetCallback = function(callback: () -> ())
            options.Callback = callback
        end,
    }
end

function Window:_createToggle(tab, options)
    local toggleFrame = Util.createUI("Frame", tab.Content, "ToggleFrame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 60)
    toggleFrame.BackgroundColor3 = Theme.getColors().Secondary
    toggleFrame.BorderSizePixel = 0
    Util.createUI("UICorner", toggleFrame, "Corner")
    
    local titleLabel = Util.createUI("TextLabel", toggleFrame, "TitleLabel")
    titleLabel.Size = UDim2.new(1, -80, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = options.Title
    titleLabel.TextColor3 = Theme.getColors().Text
    titleLabel.TextSize = 14
    titleLabel.Font = Theme.getColors().Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    if options.Description then
        local descLabel = Util.createUI("TextLabel", toggleFrame, "DescLabel")
        descLabel.Size = UDim2.new(1, -80, 0, 15)
        descLabel.Position = UDim2.new(0, 10, 0, 30)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = options.Description
        descLabel.TextColor3 = Theme.getColors().Text:Lerp(Theme.getColors().Background, 0.3)
        descLabel.TextSize = 12
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
    
    -- Toggle switch
    local toggleSwitch = Util.createUI("Frame", toggleFrame, "ToggleSwitch")
    toggleSwitch.Size = UDim2.new(0, 50, 0, 25)
    toggleSwitch.Position = UDim2.new(1, -60, 0.5, -12.5)
    toggleSwitch.AnchorPoint = Vector2.new(0, 0.5)
    toggleSwitch.BackgroundColor3 = options.Default and Theme.getColors().Primary or Theme.getColors().Background
    toggleSwitch.BorderSizePixel = 0
    Util.createUI("UICorner", toggleSwitch, "Corner")
    
    local toggleCircle = Util.createUI("Frame", toggleSwitch, "ToggleCircle")
    toggleCircle.Size = UDim2.new(0, 21, 0, 21)
    toggleCircle.Position = options.Default and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
    toggleCircle.AnchorPoint = Vector2.new(0, 0.5)
    toggleCircle.BackgroundColor3 = Theme.getColors().Text
    toggleCircle.BorderSizePixel = 0
    Util.createUI("UICorner", toggleCircle, "Corner")
    
    local currentValue = options.Default or false
    
    toggleSwitch.MouseButton1Click:Connect(function()
        currentValue = not currentValue
        
        local targetBgColor = currentValue and Theme.getColors().Primary or Theme.getColors().Background
        local targetPos = currentValue and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
        
        Util.tween(toggleSwitch, { BackgroundColor3 = targetBgColor }, Config.AnimationSpeed, Config.AnimationEasingStyle, Config.AnimationEasingDirection)
        Util.tween(toggleCircle, { Position = targetPos }, Config.AnimationSpeed, Config.AnimationEasingStyle, Config.AnimationEasingDirection)
        
        if options.Callback then
            options.Callback(currentValue)
        end
    end)
    
    return {
        SetValue = function(value: boolean)
            currentValue = value
            local targetBgColor = currentValue and Theme.getColors().Primary or Theme.getColors().Background
            local targetPos = currentValue and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
            
            toggleSwitch.BackgroundColor3 = targetBgColor
            toggleCircle.Position = targetPos
        end,
        GetValue = function(): boolean
            return currentValue
        end,
    }
end

function Window:_createSlider(tab, options)
    local sliderFrame = Util.createUI("Frame", tab.Content, "SliderFrame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 80)
    sliderFrame.BackgroundColor3 = Theme.getColors().Secondary
    sliderFrame.BorderSizePixel = 0
    Util.createUI("UICorner", sliderFrame, "Corner")
    
    local titleLabel = Util.createUI("TextLabel", sliderFrame, "TitleLabel")
    titleLabel.Size = UDim2.new(0.7, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = options.Title
    titleLabel.TextColor3 = Theme.getColors().Text
    titleLabel.TextSize = 14
    titleLabel.Font = Theme.getColors().Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    local valueLabel = Util.createUI("TextLabel", sliderFrame, "ValueLabel")
    valueLabel.Size = UDim2.new(0.3, -10, 0, 20)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 10)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(options.Default or options.Min or 0)
    valueLabel.TextColor3 = Theme.getColors().Primary
    valueLabel.TextSize = 14
    valueLabel.Font = Theme.getColors().Font
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    if options.Description then
        local descLabel = Util.createUI("TextLabel", sliderFrame, "DescLabel")
        descLabel.Size = UDim2.new(1, -20, 0, 15)
        descLabel.Position = UDim2.new(0, 10, 0, 30)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = options.Description
        descLabel.TextColor3 = Theme.getColors().Text:Lerp(Theme.getColors().Background, 0.3)
        descLabel.TextSize = 12
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
    
    -- Slider track
    local sliderTrack = Util.createUI("Frame", sliderFrame, "SliderTrack")
    sliderTrack.Size = UDim2.new(1, -20, 0, 4)
    sliderTrack.Position = UDim2.new(0, 10, 1, -20)
    sliderTrack.AnchorPoint = Vector2.new(0, 0.5)
    sliderTrack.BackgroundColor3 = Theme.getColors().Background
    sliderTrack.BorderSizePixel = 0
    Util.createUI("UICorner", sliderTrack, "Corner")
    
    -- Slider fill
    local sliderFill = Util.createUI("Frame", sliderTrack, "SliderFill")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = Theme.getColors().Primary
    sliderFill.BorderSizePixel = 0
    Util.createUI("UICorner", sliderFill, "Corner")
    
    -- Slider thumb
    local sliderThumb = Util.createUI("Frame", sliderTrack, "SliderThumb")
    sliderThumb.Size = UDim2.new(0, 16, 0, 16)
    sliderThumb.Position = UDim2.new(0, -8, 0.5, -8)
    sliderThumb.AnchorPoint = Vector2.new(0, 0.5)
    sliderThumb.BackgroundColor3 = Theme.getColors().Primary
    sliderThumb.BorderSizePixel = 0
    Util.createUI("UICorner", sliderThumb, "Corner")
    
    local minValue = options.Min or 0
    local maxValue = options.Max or 100
    local currentValue = options.Default or minValue
    
    local function updateSlider()
        local normalizedValue = (currentValue - minValue) / (maxValue - minValue)
        local fillWidth = normalizedValue
        local thumbPos = UDim2.new(normalizedValue, -8, 0.5, -8)
        
        sliderFill.Size = UDim2.new(fillWidth, 0, 1, 0)
        sliderThumb.Position = thumbPos
        valueLabel.Text = tostring(math.floor(currentValue + 0.5))
    end
    
    updateSlider()
    
    local isDragging = false
    
    sliderThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local trackSize = sliderTrack.AbsoluteSize.X
            local mousePos = input.Position.X - sliderTrack.AbsolutePosition.X
            local normalizedPos = math.clamp(mousePos / trackSize, 0, 1)
            
            currentValue = minValue + (maxValue - minValue) * normalizedPos
            updateSlider()
            
            if options.Callback then
                options.Callback(currentValue)
            end
        end
    end)
    
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    return {
        SetValue = function(value: number)
            currentValue = math.clamp(value, minValue, maxValue)
            updateSlider()
        end,
        GetValue = function(): number
            return currentValue
        end,
    }
end

function Window:_createTextbox(tab, options)
    local textboxFrame = Util.createUI("Frame", tab.Content, "TextboxFrame")
    textboxFrame.Size = UDim2.new(1, 0, 0, 60)
    textboxFrame.BackgroundColor3 = Theme.getColors().Secondary
    textboxFrame.BorderSizePixel = 0
    Util.createUI("UICorner", textboxFrame, "Corner")
    
    local titleLabel = Util.createUI("TextLabel", textboxFrame, "TitleLabel")
    titleLabel.Size = UDim2.new(0.4, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = options.Title
    titleLabel.TextColor3 = Theme.getColors().Text
    titleLabel.TextSize = 14
    titleLabel.Font = Theme.getColors().Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    if options.Description then
        local descLabel = Util.createUI("TextLabel", textboxFrame, "DescLabel")
        descLabel.Size = UDim2.new(0.4, 0, 0, 15)
        descLabel.Position = UDim2.new(0, 10, 0, 30)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = options.Description
        descLabel.TextColor3 = Theme.getColors().Text:Lerp(Theme.getColors().Background, 0.3)
        descLabel.TextSize = 12
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
    
    local textbox = Util.createUI("TextBox", textboxFrame, "Textbox")
    textbox.Size = UDim2.new(0.6, -20, 0, 30)
    textbox.Position = UDim2.new(0.4, 10, 0.5, -15)
    textbox.AnchorPoint = Vector2.new(0, 0.5)
    textbox.BackgroundColor3 = Theme.getColors().Background
    textbox.Text = options.Default or ""
    textbox.PlaceholderText = options.PlaceholderText or "Enter text..."
    textbox.TextColor3 = Theme.getColors().Text
    textbox.PlaceholderColor3 = Theme.getColors().Text:Lerp(Theme.getColors().Background, 0.5)
    textbox.TextSize = 12
    textbox.Font = Theme.getColors().Font
    textbox.BorderSizePixel = 0
    textbox.TextXAlignment = Enum.TextXAlignment.Left
    Util.createUI("UICorner", textbox, "Corner")
    
    textbox.FocusLost:Connect(function(enterPressed)
        if options.Callback then
            options.Callback(textbox.Text)
        end
    end)
    
    return {
        SetText = function(text: string)
            textbox.Text = text
        end,
        GetText = function(): string
            return textbox.Text
        end,
    }
end

function Window:_createDropdown(tab, options)
    local dropdownFrame = Util.createUI("Frame", tab.Content, "DropdownFrame")
    dropdownFrame.Size = UDim2.new(1, 0, 0, 60)
    dropdownFrame.BackgroundColor3 = Theme.getColors().Secondary
    dropdownFrame.BorderSizePixel = 0
    Util.createUI("UICorner", dropdownFrame, "Corner")
    
    local titleLabel = Util.createUI("TextLabel", dropdownFrame, "TitleLabel")
    titleLabel.Size = UDim2.new(0.4, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = options.Title
    titleLabel.TextColor3 = Theme.getColors().Text
    titleLabel.TextSize = 14
    titleLabel.Font = Theme.getColors().Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    if options.Description then
        local descLabel = Util.createUI("TextLabel", dropdownFrame, "DescLabel")
        descLabel.Size = UDim2.new(0.4, 0, 0, 15)
        descLabel.Position = UDim2.new(0, 10, 0, 30)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = options.Description
        descLabel.TextColor3 = Theme.getColors().Text:Lerp(Theme.getColors().Background, 0.3)
        descLabel.TextSize = 12
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
    
    local dropdown = Util.createUI("TextButton", dropdownFrame, "Dropdown")
    dropdown.Size = UDim2.new(0.6, -20, 0, 30)
    dropdown.Position = UDim2.new(0.4, 10, 0.5, -15)
    dropdown.AnchorPoint = Vector2.new(0, 0.5)
    dropdown.BackgroundColor3 = Theme.getColors().Background
    dropdown.Text = options.Default or (options.Options[1] or "Select...")
    dropdown.TextColor3 = Theme.getColors().Text
    dropdown.TextSize = 12
    dropdown.Font = Theme.getColors().Font
    dropdown.BorderSizePixel = 0
    dropdown.TextXAlignment = Enum.TextXAlignment.Left
    Util.createUI("UICorner", dropdown, "Corner")
    
    local arrow = Util.createUI("TextLabel", dropdown, "Arrow")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = Theme.getColors().Text
    arrow.TextSize = 10
    arrow.Font = Theme.getColors().Font
    arrow.TextXAlignment = Enum.TextXAlignment.Center
    arrow.TextYAlignment = Enum.TextYAlignment.Center
    
    local optionsFrame = Util.createUI("Frame", tab.Content, "OptionsFrame")
    optionsFrame.Size = UDim2.new(0.6, -20, 0, 0)
    optionsFrame.Position = UDim2.new(0.4, 10, 0, 0)
    optionsFrame.BackgroundColor3 = Theme.getColors().Background
    optionsFrame.BorderSizePixel = 0
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 10
    Util.createUI("UICorner", optionsFrame, "Corner")
    
    local optionsLayout = Util.createUI("UIListLayout", optionsFrame, "OptionsLayout")
    optionsLayout.FillDirection = Enum.FillDirection.Vertical
    optionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    optionsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    
    local currentValue = options.Default or options.Options[1] or ""
    local isOpen = false
    
    for _, optionText in ipairs(options.Options) do
        local optionButton = Util.createUI("TextButton", optionsFrame, "Option_" .. optionText)
        optionButton.Size = UDim2.new(1, 0, 0, 25)
        optionButton.BackgroundColor3 = Theme.getColors().Background
        optionButton.Text = optionText
        optionButton.TextColor3 = Theme.getColors().Text
        optionButton.TextSize = 12
        optionButton.Font = Theme.getColors().Font
        optionButton.BorderSizePixel = 0
        optionButton.TextXAlignment = Enum.TextXAlignment.Left
        
        optionButton.MouseEnter:Connect(function()
            optionButton.BackgroundColor3 = Theme.getColors().Primary:Lerp(Theme.getColors().Background, 0.7)
        end)
        
        optionButton.MouseLeave:Connect(function()
            optionButton.BackgroundColor3 = Theme.getColors().Background
        end)
        
        optionButton.MouseButton1Click:Connect(function()
            currentValue = optionText
            dropdown.Text = optionText
            
            -- Close dropdown
            isOpen = false
            optionsFrame.Visible = false
            arrow.Text = "▼"
            
            if options.Callback then
                options.Callback(optionText)
            end
        end)
    end
    
    dropdown.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        optionsFrame.Visible = isOpen
        arrow.Text = isOpen and "▲" or "▼"
        
        if isOpen then
            optionsFrame.Size = UDim2.new(0.6, -20, 0, #options.Options * 25)
            -- Position below the dropdown
            local dropdownPos = dropdown.AbsolutePosition
            local dropdownSize = dropdown.AbsoluteSize
            optionsFrame.Position = UDim2.new(0, dropdownPos.X - dropdownFrame.AbsolutePosition.X, 0, dropdownPos.Y + dropdownSize.Y - dropdownFrame.AbsolutePosition.Y + 5)
        end
    end)
    
    return {
        SetValue = function(value: string)
            if table.find(options.Options, value) then
                currentValue = value
                dropdown.Text = value
            end
        end,
        GetValue = function(): string
            return currentValue
        end,
        SetOptions = function(newOptions: {string})
            options.Options = newOptions
            -- Clear existing options
            for _, child in ipairs(optionsFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            -- Recreate options
            for _, optionText in ipairs(newOptions) do
                local optionButton = Util.createUI("TextButton", optionsFrame, "Option_" .. optionText)
                optionButton.Size = UDim2.new(1, 0, 0, 25)
                optionButton.BackgroundColor3 = Theme.getColors().Background
                optionButton.Text = optionText
                optionButton.TextColor3 = Theme.getColors().Text
                optionButton.TextSize = 12
                optionButton.Font = Theme.getColors().Font
                optionButton.BorderSizePixel = 0
                optionButton.TextXAlignment = Enum.TextXAlignment.Left
                
                optionButton.MouseButton1Click:Connect(function()
                    currentValue = optionText
                    dropdown.Text = optionText
                    isOpen = false
                    optionsFrame.Visible = false
                    arrow.Text = "▼"
                    
                    if options.Callback then
                        options.Callback(optionText)
                    end
                end)
            end
        end,
    }
end

-- ========================================
-- MAIN LIBRARY INTERFACE
-- ========================================
function ModernGUILib:CreateWindow(options)
    return Window.new(options)
end

function ModernGUILib:Init()
    print("ModernGUILib Initialized!")
end

-- Set theme function
ModernGUILib.SetTheme = Theme.setTheme
ModernGUILib.GetTheme = function()
    return Theme.CurrentTheme
end

return ModernGUILib


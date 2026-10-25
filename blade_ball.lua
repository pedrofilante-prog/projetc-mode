-- ==== COMPATIBILITY LAYER FOR YUB-X PC ====
local HttpService = game:GetService("HttpService")

-- HTTP Request Shim
local httpRequest = request or http_request or (syn and syn.request) or function(options)
    warn("[PHANTOM] HTTP request not supported on this executor")
    return {StatusCode = 0, Body = ""}
end

-- File IO Fallbacks
local fileSystem = {
    read = function(path)
        local success, result = pcall(function()
            if readfile then return readfile(path) end
            if isfile and isfile(path) then
                local f = io.open(path, "r")
                if f then
                    local content = f:read("*a")
                    f:close()
                    return content
                end
            end
            return nil
        end)
        return success and result or nil
    end,
    
    write = function(path, content)
        pcall(function()
            if writefile then
                writefile(path, content)
            else
                local dir = path:match("(.+)/[^/]+$")
                if dir and makefolder and not isfolder(dir) then
                    makefolder(dir)
                end
                local f = io.open(path, "w")
                if f then
                    f:write(content)
                    f:close()
                end
            end
        end)
    end,
    
    exists = function(path)
        local success, result = pcall(function()
            if isfile then return isfile(path) end
            local f = io.open(path, "r")
            if f then f:close(); return true end
            return false
        end)
        return success and result or false
    end,
    
    makeDir = function(path)
        pcall(function()
            if makefolder and not isfolder(path) then
                makefolder(path)
            end
        end)
    end
}

-- Hook Protection Wrapper
local safeHook = function(target, replacement)
    local success, result = pcall(function()
        if hookmetamethod then
            return hookmetamethod(target, "__namecall", replacement)
        elseif hookfunction then
            return hookfunction(target, replacement)
        end
        return nil
    end)
    return success and result or nil
end

-- Closure Protection
local newcclosure = newcclosure or function(f) return f end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end

-- ==== UI BACKEND (PROTECTED) ====
local AilonUI = (function()
if getgenv()._aurorasigma then
    pcall(function()
        if _G.ailon_unload then _G.ailon_unload() end
    end)
    getgenv()._aurorasigma = nil
    task.wait(0.1)
end

getgenv()._aurorasigma = true

local ContentProvider = game:GetService("ContentProvider")
local LogService = game:GetService("LogService")

local hook = hookfunction or detour_function or (replaceclosure and function(old, new)
    return replaceclosure(old, new)
end)

local cclosure = newcclosure

local renv = getrenv and pcall(getrenv) and getrenv() or _G

local set_readonly = setreadonly or (make_writeable and function(t, v)
    if v then make_writeable(t) else make_readonly(t) end
end)

local function isRelevantCaller()
    for i = 3, 6 do
        local success, src = pcall(debug.info, i, "s")
        if success and src and (
            src:find("RemoveLoadingScreen") or
            src:find("Loading") or
            src:find("Detection")
        ) then
            return true
        end
    end

    if getcallingscript then
        local ok, script = pcall(getcallingscript)
        if ok and script then
            local name = tostring(script)
            if name:find("RemoveLoadingScreen") or name:find("Loading") then
                return true
            end
        end
    end

    return false
end

local originalRandom
originalRandom = hook(renv.math.random, cclosure(function(...)
    if isRelevantCaller() then
        return 0
    end
    return originalRandom(...)
end))

local originalPreloadAsync
originalPreloadAsync = hook(ContentProvider.PreloadAsync, cclosure(function(self, assets, callback)
    if self ~= ContentProvider then
        return originalPreloadAsync(self, assets, callback)
    end

    if isRelevantCaller() and type(assets) == "table" then
        if callback then
            for _, asset in ipairs(assets) do
                task.spawn(pcall, callback, asset, Enum.AssetFetchStatus.Success)
            end
        end
        return
    end

    return originalPreloadAsync(self, assets, callback)
end))

local mt = getrawmetatable(game)
if mt and set_readonly then
    local success, originalNamecall = pcall(function() return mt.__namecall end)
    if success and originalNamecall then
        pcall(function()
            set_readonly(mt, false)
            
            mt.__namecall = cclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }

                if method == "PreloadAsync" and self == ContentProvider and isRelevantCaller() then
                    pcall(function()
                        local assets, callback = args[1], args[2]
                        if type(assets) == "table" and callback then
                            for _, asset in ipairs(assets) do
                                task.spawn(pcall, callback, asset, Enum.AssetFetchStatus.Success)
                            end
                        end
                    end)
                    return
                end

                return originalNamecall(self, ...)
            end)
            
            set_readonly(mt, true)
        end)
    end
end

print("[PHANTOM] BAC bypass initialized with PC protection")

-- Teleport persistence with fallback
if queue_on_teleport then
    local scriptSource = nil
    
    pcall(function()
        if getgenv()._ailon_source then
            scriptSource = getgenv()._ailon_source
        elseif fileSystem.exists("ailon/ailon_source.lua") then
            scriptSource = fileSystem.read("ailon/ailon_source.lua")
        end
    end)
    
    if scriptSource then
        getgenv()._ailon_source = scriptSource
        queue_on_teleport(scriptSource)
    else
        queue_on_teleport([[
            getgenv()._aurorasigma = nil
            local ContentProvider = game:GetService("ContentProvider")
            local hook = hookfunction or detour_function or (replaceclosure and function(old, new) return replaceclosure(old, new) end)
            local cclosure = newcclosure or function(f) return f end
            local renv = getrenv and getrenv() or _G
            local set_readonly = setreadonly or (make_writeable and function(t, v) if v then make_writeable(t) else make_readonly(t) end end)
            
            local function isRelevantCaller()
                for i = 3, 6 do
                    local src = debug.info(i, "s")
                    if src and (src:find("RemoveLoadingScreen") or src:find("Loading") or src:find("Detection")) then return true end
                end
                return false
            end
            
            local originalRandom = hook(renv.math.random, cclosure(function(...) if isRelevantCaller() then return 0 end return originalRandom(...) end))
            local originalPreloadAsync = hook(ContentProvider.PreloadAsync, cclosure(function(self, assets, callback)
                if self ~= ContentProvider then return originalPreloadAsync(self, assets, callback) end
                if isRelevantCaller() and type(assets) == "table" and callback then
                    for _, asset in ipairs(assets) do task.spawn(pcall, callback, asset, Enum.AssetFetchStatus.Success) end
                    return
                end
                return originalPreloadAsync(self, assets, callback)
            end))
            
            print("[PHANTOM] Bypass re-applied after teleport")
        ]])
    end
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

getgenv().GG = {
    Language = {
        CheckboxEnabled = "Enabled",
        CheckboxDisabled = "Disabled",
        SliderValue = "Value",
        DropdownSelect = "Select",
        DropdownNone = "None",
        DropdownSelected = "Selected",
        ButtonClick = "Click",
        TextboxEnter = "Enter",
        ModuleEnabled = "Enabled",
        ModuleDisabled = "Disabled",
        TabGeneral = "General",
        TabSettings = "Settings",
        Loading = "Loading...",
        Error = "Error",
        Success = "Success"
    }
}

local SelectedLanguage = GG.Language

function convertStringToTable(inputString)
    local result = {}
    for value in string.gmatch(inputString, "([^,]+)") do
        local trimmedValue = value:match("^%s*(.-)%s*$")
        table.insert(result, trimmedValue)
    end
    return result
end

function convertTableToString(inputTable)
    return table.concat(inputTable, ", ")
end

local UserInputService = cloneref(game:GetService('UserInputService'))
local ContentProvider = cloneref(game:GetService('ContentProvider'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local TextService = cloneref(game:GetService('TextService'))
local RunService = cloneref(game:GetService('RunService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Players = cloneref(game:GetService('Players'))
local CoreGui = cloneref(game:GetService('CoreGui'))
local Debris = cloneref(game:GetService('Debris'))

local mouse = Players.LocalPlayer:GetMouse()
local old_ailon = CoreGui:FindFirstChild('ailon')

if old_ailon then
    Debris:AddItem(old_ailon, 0)
end

fileSystem.makeDir("ailon")

local Connections = setmetatable({
    disconnect = function(self, connection)
        if not self[connection] then return end
        pcall(function() self[connection]:Disconnect() end)
        self[connection] = nil
    end,
    disconnect_all = function(self)
        for _, value in pairs(self) do
            if typeof(value) ~= 'function' then
                pcall(function() value:Disconnect() end)
            end
        end
    end
}, {})

-- Continue na PARTE 2...local Util = setmetatable({
    map = function(self, value, in_minimum, in_maximum, out_minimum, out_maximum)
        return (value - in_minimum) * (out_maximum - out_minimum) / (in_maximum - in_minimum) + out_minimum
    end,
    viewport_point_to_world = function(self, location, distance)
        local unit_ray = workspace.CurrentCamera:ScreenPointToRay(location.X, location.Y)
        return unit_ray.Origin + unit_ray.Direction * distance
    end,
    get_offset = function(self)
        local viewport_size_Y = workspace.CurrentCamera.ViewportSize.Y
        return self:map(viewport_size_Y, 0, 2560, 8, 56)
    end
}, {})

local AcrylicBlur = {}
AcrylicBlur.__index = AcrylicBlur

function AcrylicBlur.new(object)
    local self = setmetatable({
        _object = object,
        _folder = nil,
        _frame = nil,
        _root = nil
    }, AcrylicBlur)
    pcall(function() self:setup() end)
    return self
end

function AcrylicBlur:create_folder()
    pcall(function()
        local old_folder = workspace.CurrentCamera:FindFirstChild('AcrylicBlur')
        if old_folder then Debris:AddItem(old_folder, 0) end
        
        local folder = Instance.new('Folder')
        folder.Name = 'AcrylicBlur'
        folder.Parent = workspace.CurrentCamera
        self._folder = folder
    end)
end

function AcrylicBlur:create_depth_of_fields()
    pcall(function()
        local depth_of_fields = Lighting:FindFirstChild('AcrylicBlur') or Instance.new('DepthOfFieldEffect')
        depth_of_fields.FarIntensity = 0
        depth_of_fields.FocusDistance = 0.05
        depth_of_fields.InFocusRadius = 0.1
        depth_of_fields.NearIntensity = 1
        depth_of_fields.Name = 'AcrylicBlur'
        depth_of_fields.Parent = Lighting
        
        for _, object in pairs(Lighting:GetChildren()) do
            if object:IsA('DepthOfFieldEffect') and object ~= depth_of_fields then
                Connections[object] = object:GetPropertyChangedSignal('FarIntensity'):Connect(function()
                    object.FarIntensity = 0
                end)
                object.FarIntensity = 0
            end
        end
    end)
end

function AcrylicBlur:create_frame()
    pcall(function()
        local frame = Instance.new('Frame')
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundTransparency = 1
        frame.Parent = self._object
        self._frame = frame
    end)
end

function AcrylicBlur:create_root()
    pcall(function()
        local part = Instance.new('Part')
        part.Name = 'Root'
        part.Color = Color3.new(0, 0, 0)
        part.Material = Enum.Material.Glass
        part.Size = Vector3.new(1, 1, 0)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.Locked = true
        part.CastShadow = false
        part.Transparency = 0.98
        part.Parent = self._folder
        
        local specialMesh = Instance.new('SpecialMesh')
        specialMesh.MeshType = Enum.MeshType.Brick
        specialMesh.Offset = Vector3.new(0, 0, -0.000001)
        specialMesh.Parent = part
        
        self._root = part
    end)
end

function AcrylicBlur:setup()
    self:create_depth_of_fields()
    self:create_folder()
    self:create_root()
    self:create_frame()
    pcall(function() self:render(0.001) end)
    pcall(function() self:check_quality_level() end)
end

function AcrylicBlur:render(distance)
    local positions = {
        top_left = Vector2.new(),
        top_right = Vector2.new(),
        bottom_right = Vector2.new(),
    }
    
    local function update_positions(size, position)
        positions.top_left = position
        positions.top_right = position + Vector2.new(size.X, 0)
        positions.bottom_right = position + size
    end
    
    local function update()
        pcall(function()
            local top_left3D = Util:viewport_point_to_world(positions.top_left, distance)
            local top_right3D = Util:viewport_point_to_world(positions.top_right, distance)
            local bottom_right3D = Util:viewport_point_to_world(positions.bottom_right, distance)
            
            local width = (top_right3D - top_left3D).Magnitude
            local height = (top_right3D - bottom_right3D).Magnitude
            
            if not self._root then return end
            
            self._root.CFrame = CFrame.fromMatrix(
                (top_left3D + bottom_right3D) / 2,
                workspace.CurrentCamera.CFrame.XVector,
                workspace.CurrentCamera.CFrame.YVector,
                workspace.CurrentCamera.CFrame.ZVector
            )
            local mesh = self._root:FindFirstChildOfClass('SpecialMesh')
            if mesh then mesh.Scale = Vector3.new(width, height, 0) end
        end)
    end
    
    local function on_change()
        pcall(function()
            local offset = Util:get_offset()
            local size = self._frame.AbsoluteSize - Vector2.new(offset, offset)
            local position = self._frame.AbsolutePosition + Vector2.new(offset / 2, offset / 2)
            update_positions(size, position)
            task.spawn(update)
        end)
    end
    
    Connections['cframe_update'] = workspace.CurrentCamera:GetPropertyChangedSignal('CFrame'):Connect(update)
    Connections['viewport_size_update'] = workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(update)
    Connections['field_of_view_update'] = workspace.CurrentCamera:GetPropertyChangedSignal('FieldOfView'):Connect(update)
    Connections['frame_absolute_position'] = self._frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(on_change)
    Connections['frame_absolute_size'] = self._frame:GetPropertyChangedSignal('AbsoluteSize'):Connect(on_change)
    
    task.spawn(update)
end

function AcrylicBlur:check_quality_level()
    pcall(function()
        local game_settings = UserSettings().GameSettings
        local quality_level = game_settings.SavedQualityLevel.Value
        
        if quality_level < 8 then
            self:change_visiblity(false)
        end
        
        Connections['quality_level'] = game_settings:GetPropertyChangedSignal('SavedQualityLevel'):Connect(function()
            local ql = UserSettings().GameSettings.SavedQualityLevel.Value
            self:change_visiblity(ql >= 8)
        end)
    end)
end

function AcrylicBlur:change_visiblity(state)
    pcall(function()
        if self._root then
            self._root.Transparency = state and 0.98 or 1
        end
    end)
end

local Config = setmetatable({
    save = function(self, file_name, config)
        pcall(function()
            local flags = HttpService:JSONEncode(config)
            fileSystem.write('ailon/'..file_name..'.json', flags)
        end)
    end,
    load = function(self, file_name, config)
        local result = nil
        pcall(function()
            if not fileSystem.exists('ailon/'..file_name..'.json') then
                self:save(file_name, config)
                return
            end
            
            local flags = fileSystem.read('ailon/'..file_name..'.json')
            if not flags then
                self:save(file_name, config)
                return
            end
            
            result = HttpService:JSONDecode(flags)
        end)
        
        if not result then
            result = { _flags = {}, _keybinds = {}, _library = {} }
        end
        
        return result
    end
}, {})

local Library = {
    _config = Config:load(game.GameId),
    _choosing_keybind = false,
    _device = nil,
    _ui_open = true,
    _ui_scale = 1,
    _ui_loaded = false,
    _ui = nil,
    _dragging = false,
    _drag_start = nil,
    _container_position = nil
}
Library.__index = Library

function Library.new()
    local self = setmetatable({ _loaded = false, _tab = 0 }, Library)
    pcall(function() self:create_ui() end)
    return self
end

-- Notification System
local NotificationContainer = Instance.new("Frame")
NotificationContainer.Name = "CondemnedNotifications"
NotificationContainer.Size = UDim2.new(0, 320, 0, 0)
NotificationContainer.Position = UDim2.new(1, -10, 1, -10)
NotificationContainer.AnchorPoint = Vector2.new(1, 1)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.ClipsDescendants = false
NotificationContainer.Parent = CoreGui:FindFirstChild("RobloxGui") or CoreGui
NotificationContainer.AutomaticSize = Enum.AutomaticSize.Y

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = NotificationContainer

function Library.SendNotification(settings)
    pcall(function()
        local Notification = Instance.new("Frame")
        Notification.Size = UDim2.new(1, 0, 0, 0)
        Notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Notification.BackgroundTransparency = 0.1
        Notification.BorderSizePixel = 0
        Notification.Name = "Notification"
        Notification.Parent = NotificationContainer
        Notification.AutomaticSize = Enum.AutomaticSize.Y
        Notification.ClipsDescendants = true
        
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = Notification
        
        local UIStroke = Instance.new("UIStroke")
        UIStroke.Color = Color3.fromRGB(60, 60, 60)
        UIStroke.Transparency = 0.5
        UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStroke.Parent = Notification
        
        local AccentBar = Instance.new("Frame")
        AccentBar.Size = UDim2.new(0, 3, 1, 0)
        AccentBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        AccentBar.BorderSizePixel = 0
        AccentBar.Parent = Notification
        
        local Title = Instance.new("TextLabel")
        Title.Text = settings.title or "Notification"
        Title.TextColor3 = Color3.fromRGB(210, 210, 210)
        Title.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        Title.TextSize = 14
        Title.Size = UDim2.new(1, -20, 0, 20)
        Title.Position = UDim2.new(0, 12, 0, 8)
        Title.BackgroundTransparency = 1
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.TextYAlignment = Enum.TextYAlignment.Center
        Title.Parent = Notification
        
        local Body = Instance.new("TextLabel")
        Body.Text = settings.text or ""
        Body.TextColor3 = Color3.fromRGB(180, 180, 180)
        Body.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Body.TextSize = 12
        Body.Size = UDim2.new(1, -20, 0, 0)
        Body.Position = UDim2.new(0, 12, 0, 28)
        Body.BackgroundTransparency = 1
        Body.TextXAlignment = Enum.TextXAlignment.Left
        Body.TextYAlignment = Enum.TextYAlignment.Top
        Body.TextWrapped = true
        Body.AutomaticSize = Enum.AutomaticSize.Y
        Body.Parent = Notification
        
        local Padding = Instance.new("UIPadding")
        Padding.PaddingBottom = UDim.new(0, 10)
        Padding.Parent = Notification
        
        Notification.Position = UDim2.new(1, 330, 0, 0)
        
        task.spawn(function()
            local tweenIn = TweenService:Create(Notification, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            })
            tweenIn:Play()
            task.wait(settings.duration or 5)
            local tweenOut = TweenService:Create(Notification, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 330, 0, 0)
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function() Notification:Destroy() end)
        end)
    end)
end

function Library:get_screen_scale()
    pcall(function()
        local viewport_size_x = workspace.CurrentCamera.ViewportSize.X
        self._ui_scale = viewport_size_x / 1400
    end)
end

function Library:get_device()
    pcall(function()
        local device = 'Unknown'
        if not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
            device = 'PC'
        elseif UserInputService.TouchEnabled then
            device = 'Mobile'
        elseif UserInputService.GamepadEnabled then
            device = 'Console'
        end
        self._device = device
    end)
end

function Library:removed(action)
    pcall(function() self._ui.AncestryChanged:Once(action) end)
end

function Library:flag_type(flag, flag_type)
    if not Library._config._flags[flag] then return end
    return typeof(Library._config._flags[flag]) == flag_type
end

function Library:remove_table_value(__table, table_value)
    for index, value in pairs(__table) do
        if value == table_value then
            table.remove(__table, index)
        end
    end
end

-- Continue na PARTE 3 (UI Creation + Tabs + Modules)...function Library:create_ui()
    pcall(function()
        local old_ailon = CoreGui:FindFirstChild('ailon')
        if old_ailon then Debris:AddItem(old_ailon, 0) end
        
        local ailon = Instance.new('ScreenGui')
        ailon.ResetOnSpawn = false
        ailon.Name = 'ailon'
        ailon.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ailon.Parent = CoreGui
        
        local Container = Instance.new('Frame')
        Container.ClipsDescendants = true
        Container.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Container.AnchorPoint = Vector2.new(0.5, 0.5)
        Container.Name = 'Container'
        Container.BackgroundTransparency = 0.05
        Container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        
        local ContainerGradient = Instance.new('UIGradient')
        ContainerGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
        }
        ContainerGradient.Rotation = 45
        ContainerGradient.Parent = Container
        
        Container.Position = UDim2.new(0.5, 0, 0.5, 0)
        Container.Size = UDim2.new(0, 0, 0, 0)
        Container.Active = true
        Container.BorderSizePixel = 0
        Container.Parent = ailon
        
        local UICorner = Instance.new('UICorner')
        UICorner.CornerRadius = UDim.new(0, 12)
        UICorner.Parent = Container
        
        local UIStroke = Instance.new('UIStroke')
        UIStroke.Color = Color3.fromRGB(60, 60, 60)
        UIStroke.Transparency = 0.5
        UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStroke.Parent = Container
        
        local Handler = Instance.new('Frame')
        Handler.BackgroundTransparency = 1
        Handler.Name = 'Handler'
        Handler.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Handler.Size = UDim2.new(0, 680, 0, 460)
        Handler.BorderSizePixel = 0
        Handler.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Handler.Parent = Container
        
        local Tabs = Instance.new('ScrollingFrame')
        Tabs.ScrollBarImageTransparency = 1
        Tabs.ScrollBarThickness = 0
        Tabs.Name = 'Tabs'
        Tabs.Size = UDim2.new(0, 129, 0, 401)
        Tabs.Selectable = false
        Tabs.AutomaticCanvasSize = Enum.AutomaticSize.XY
        Tabs.BackgroundTransparency = 1
        Tabs.Position = UDim2.new(0.026, 0, 0.111, 0)
        Tabs.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Tabs.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Tabs.BorderSizePixel = 0
        Tabs.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        Tabs.Parent = Handler
        
        local TabLayout = Instance.new('UIListLayout')
        TabLayout.Padding = UDim.new(0, 4)
        TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        TabLayout.Parent = Tabs
        
        local ClientName = Instance.new('TextLabel')
        ClientName.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        ClientName.TextColor3 = Color3.fromRGB(255, 255, 255)
        ClientName.TextTransparency = 0
        ClientName.Text = 'Sapphire Private'
        ClientName.Name = 'ClientName'
        ClientName.Size = UDim2.new(0, 150, 0, 18)
        ClientName.AnchorPoint = Vector2.new(0, 0.5)
        ClientName.Position = UDim2.new(0.07, 0, 0.055, 0)
        ClientName.BackgroundTransparency = 1
        ClientName.TextXAlignment = Enum.TextXAlignment.Left
        ClientName.BorderSizePixel = 0
        ClientName.BorderColor3 = Color3.fromRGB(0, 0, 0)
        ClientName.TextSize = 16
        ClientName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ClientName.Parent = Handler
        
        local NameGradient = Instance.new('UIGradient')
        NameGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 92, 200)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 200, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 92, 200))
        }
        NameGradient.Parent = ClientName
        
        task.spawn(function()
            while task.wait() do
                if not ClientName or not ClientName.Parent then break end
                pcall(function() NameGradient.Offset = Vector2.new(math.sin(os.clock() * 1.5), 0) end)
            end
        end)
        
        local TopDivider = Instance.new('Frame')
        TopDivider.Name = 'TopDivider'
        TopDivider.Size = UDim2.new(0.85, 0, 0, 1)
        TopDivider.Position = UDim2.new(0.5, 0, 0, 36)
        TopDivider.AnchorPoint = Vector2.new(0.5, 0)
        TopDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        TopDivider.BorderSizePixel = 0
        TopDivider.Parent = Handler
        
        local TopDividerGradient = Instance.new('UIGradient')
        TopDividerGradient.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0),
            NumberSequenceKeypoint.new(0.8, 0),
            NumberSequenceKeypoint.new(1, 1)
        }
        TopDividerGradient.Parent = TopDivider
        
        local SideDivider = Instance.new('Frame')
        SideDivider.Name = 'SideDivider'
        SideDivider.Size = UDim2.new(0, 2, 0, 340)
        SideDivider.Position = UDim2.new(0.235, 0, 0.5, 0)
        SideDivider.AnchorPoint = Vector2.new(0.5, 0.5)
        SideDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        SideDivider.BorderSizePixel = 0
        SideDivider.Parent = Handler
        
        local SideDividerCorner = Instance.new('UICorner')
        SideDividerCorner.CornerRadius = UDim.new(1, 0)
        SideDividerCorner.Parent = SideDivider
        
        local Sections = Instance.new('Folder')
        Sections.Name = 'Sections'
        Sections.Parent = Handler
        
        local Icon = Instance.new('ImageLabel')
        Icon.ImageColor3 = Color3.fromRGB(200, 200, 200)
        Icon.ScaleType = Enum.ScaleType.Fit
        Icon.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Icon.AnchorPoint = Vector2.new(0, 0.5)
        Icon.Image = 'rbxassetid://138719305710506'
        Icon.BackgroundTransparency = 1
        Icon.Position = UDim2.new(0.025, 0, 0.055, 0)
        Icon.Name = 'Icon'
        Icon.Size = UDim2.new(0, 24, 0, 24)
        Icon.BorderSizePixel = 0
        Icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Icon.Parent = Handler
        
        local IconGradient = Instance.new('UIGradient')
        IconGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 150)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150))
        }
        IconGradient.Parent = Icon
        
        task.spawn(function()
            while task.wait() do
                if not Icon or not Icon.Parent then break end
                pcall(function() IconGradient.Offset = Vector2.new(math.sin(os.clock() * 1.5), 0) end)
            end
        end)
        
        task.spawn(function()
            local frames = {'rbxassetid://116621149840132', 'rbxassetid://135328418151934', 'rbxassetid://73167853323814'}
            local index = 0
            while task.wait(0.20) do
                if not Icon or not Icon.Parent then break end
                index = index + 1
                pcall(function() Icon.Image = frames[index] end)
                if index == 3 then index = 0 end
            end
        end)
        
        local Minimize = Instance.new('TextButton')
        Minimize.FontFace = Font.new('rbxasset://fonts/families/SourceSansPro.json', Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Minimize.TextColor3 = Color3.fromRGB(0, 0, 0)
        Minimize.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Minimize.Text = ''
        Minimize.AutoButtonColor = false
        Minimize.Name = 'Minimize'
        Minimize.BackgroundTransparency = 1
        Minimize.Position = UDim2.new(0.02, 0, 0.029, 0)
        Minimize.Size = UDim2.new(0, 24, 0, 24)
        Minimize.BorderSizePixel = 0
        Minimize.TextSize = 14
        Minimize.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Minimize.Parent = Handler
        
        local UIScale = Instance.new('UIScale')
        UIScale.Parent = Container
        
        self._ui = ailon
        
        -- Drag Logic (PC Optimized)
        local function on_drag(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                self._dragging = true
                self._drag_start = input.Position
                self._container_position = Container.Position
                
                Connections['container_input_ended'] = input.Changed:Connect(function()
                    if input.UserInputState ~= Enum.UserInputState.End then return end
                    Connections:disconnect('container_input_ended')
                    self._dragging = false
                end)
            end
        end
        
        local function update_drag(input)
            pcall(function()
                local delta = input.Position - self._drag_start
                local position = UDim2.new(
                    self._container_position.X.Scale,
                    self._container_position.X.Offset + delta.X,
                    self._container_position.Y.Scale,
                    self._container_position.Y.Offset + delta.Y
                )
                TweenService:Create(Container, TweenInfo.new(0.1), { Position = position }):Play()
            end)
        end
        
        local function drag(input)
            if not self._dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                update_drag(input)
            end
        end
        
        Connections['container_input_began'] = Container.InputBegan:Connect(on_drag)
        Connections['input_changed'] = UserInputService.InputChanged:Connect(drag)
        
        self:removed(function()
            self._ui = nil
            Connections:disconnect_all()
        end)
        
        -- Tab Creation Function
        function self:create_tab(name, icon)
            local TabManager = { _sections = {}, _size = 0 }
            
            pcall(function()
                local TabButton = Instance.new('TextButton')
                TabButton.Name = 'Tab_' .. name
                TabButton.Size = UDim2.new(0, 120, 0, 32)
                TabButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                TabButton.BorderSizePixel = 0
                TabButton.Text = ''
                TabButton.AutoButtonColor = false
                TabButton.Parent = Tabs
                
                local TabCorner = Instance.new('UICorner')
                TabCorner.CornerRadius = UDim.new(0, 8)
                TabCorner.Parent = TabButton
                
                local TabIcon = Instance.new('ImageLabel')
                TabIcon.BackgroundTransparency = 1
                TabIcon.Size = UDim2.new(0, 16, 0, 16)
                TabIcon.Position = UDim2.new(0, 10, 0.5, -8)
                TabIcon.Image = icon or 'rbxassetid://7733919881'
                TabIcon.ImageColor3 = Color3.fromRGB(180, 180, 180)
                TabIcon.Parent = TabButton
                
                local TabLabel = Instance.new('TextLabel')
                TabLabel.BackgroundTransparency = 1
                TabLabel.Size = UDim2.new(1, -35, 1, 0)
                TabLabel.Position = UDim2.new(0, 32, 0, 0)
                TabLabel.Font = Enum.Font.GothamSemibold
                TabLabel.Text = name
                TabLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                TabLabel.TextSize = 13
                TabLabel.TextXAlignment = Enum.TextXAlignment.Left
                TabLabel.Parent = TabButton
                
                local SectionContainer = Instance.new('Frame')
                SectionContainer.Name = 'Section_' .. name
                SectionContainer.Size = UDim2.new(0, 520, 0, 400)
                SectionContainer.Position = UDim2.new(0, 150, 0, 50)
                SectionContainer.BackgroundTransparency = 1
                SectionContainer.Visible = false
                SectionContainer.Parent = Handler
                
                local LeftSection = Instance.new('ScrollingFrame')
                LeftSection.Name = 'Left'
                LeftSection.Size = UDim2.new(0, 250, 0, 390)
                LeftSection.Position = UDim2.new(0, 0, 0, 0)
                LeftSection.BackgroundTransparency = 1
                LeftSection.BorderSizePixel = 0
                LeftSection.ScrollBarThickness = 4
                LeftSection.CanvasSize = UDim2.new(0, 0, 0, 0)
                LeftSection.AutomaticCanvasSize = Enum.AutomaticSize.Y
                LeftSection.Parent = SectionContainer
                
                local RightSection = Instance.new('ScrollingFrame')
                RightSection.Name = 'Right'
                RightSection.Size = UDim2.new(0, 250, 0, 390)
                RightSection.Position = UDim2.new(0, 265, 0, 0)
                RightSection.BackgroundTransparency = 1
                RightSection.BorderSizePixel = 0
                RightSection.ScrollBarThickness = 4
                RightSection.CanvasSize = UDim2.new(0, 0, 0, 0)
                RightSection.AutomaticCanvasSize = Enum.AutomaticSize.Y
                RightSection.Parent = SectionContainer
                
                local LeftLayout = Instance.new('UIListLayout')
                LeftLayout.Padding = UDim.new(0, 8)
                LeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
                LeftLayout.Parent = LeftSection
                
                local RightLayout = Instance.new('UIListLayout')
                RightLayout.Padding = UDim.new(0, 8)
                RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
                RightLayout.Parent = RightSection
                
                TabManager._left = LeftSection
                TabManager._right = RightSection
                TabManager._button = TabButton
                TabManager._section = SectionContainer
                
                TabButton.MouseButton1Click:Connect(function()
                    for _, child in pairs(Handler:GetChildren()) do
                        if child.Name:find('Section_') then
                            child.Visible = false
                        end
                    end
                    for _, btn in pairs(Tabs:GetChildren()) do
                        if btn:IsA('TextButton') then
                            pcall(function()
                                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
                            end)
                        end
                    end
                    SectionContainer.Visible = true
                    pcall(function()
                        TweenService:Create(TabButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
                    end)
                end)
                
                if self._tab == 0 then
                    SectionContainer.Visible = true
                    TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                end
                self._tab = self._tab + 1
            end)
            
            -- Module Creation
            function TabManager:create_module(settings)
                local ModuleManager = { _state = settings.default or false, _size = 0, _multiplier = 0, _locked = false }
                
                pcall(function()
                    local section = settings.section == 'right' and TabManager._right or TabManager._left
                    
                    local Module = Instance.new('Frame')
                    Module.Name = 'Module_' .. (settings.title or 'Unknown')
                    Module.Size = UDim2.new(0, 241, 0, 44)
                    Module.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                    Module.BorderSizePixel = 0
                    Module.Parent = section
                    
                    local ModuleCorner = Instance.new('UICorner')
                    ModuleCorner.CornerRadius = UDim.new(0, 8)
                    ModuleCorner.Parent = Module
                    
                    local ModuleHeader = Instance.new('Frame')
                    ModuleHeader.Size = UDim2.new(1, 0, 0, 44)
                    ModuleHeader.BackgroundTransparency = 1
                    ModuleHeader.Parent = Module
                    
                    local ModuleTitle = Instance.new('TextLabel')
                    ModuleTitle.BackgroundTransparency = 1
                    ModuleTitle.Size = UDim2.new(1, -60, 0, 20)
                    ModuleTitle.Position = UDim2.new(0, 12, 0, 12)
                    ModuleTitle.Font = Enum.Font.GothamSemibold
                    ModuleTitle.Text = settings.title or 'Module'
                    ModuleTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
                    ModuleTitle.TextSize = 13
                    ModuleTitle.TextXAlignment = Enum.TextXAlignment.Left
                    ModuleTitle.Parent = ModuleHeader
                    
                    if settings.description then
                        local ModuleDesc = Instance.new('TextLabel')
                        ModuleDesc.BackgroundTransparency = 1
                        ModuleDesc.Size = UDim2.new(1, -60, 0, 14)
                        ModuleDesc.Position = UDim2.new(0, 12, 0, 28)
                        ModuleDesc.Font = Enum.Font.Gotham
                        ModuleDesc.Text = settings.description
                        ModuleDesc.TextColor3 = Color3.fromRGB(140, 140, 140)
                        ModuleDesc.TextSize = 11
                        ModuleDesc.TextXAlignment = Enum.TextXAlignment.Left
                        ModuleDesc.Parent = ModuleHeader
                    end
                    
                    local ToggleIndicator = Instance.new('Frame')
                    ToggleIndicator.Size = UDim2.new(0, 36, 0, 20)
                    ToggleIndicator.Position = UDim2.new(1, -48, 0.5, -10)
                    ToggleIndicator.BackgroundColor3 = ModuleManager._state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 60)
                    ToggleIndicator.BorderSizePixel = 0
                    ToggleIndicator.Parent = ModuleHeader
                    
                    local ToggleCorner = Instance.new('UICorner')
                    ToggleCorner.CornerRadius = UDim.new(1, 0)
                    ToggleCorner.Parent = ToggleIndicator
                    
                    local ToggleKnob = Instance.new('Frame')
                    ToggleKnob.Size = UDim2.new(0, 16, 0, 16)
                    ToggleKnob.Position = ModuleManager._state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                    ToggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    ToggleKnob.BorderSizePixel = 0
                    ToggleKnob.Parent = ToggleIndicator
                    
                    local KnobCorner = Instance.new('UICorner')
                    KnobCorner.CornerRadius = UDim.new(1, 0)
                    KnobCorner.Parent = ToggleKnob
                    
                    local Options = Instance.new('Frame')
                    Options.Name = 'Options'
                    Options.Size = UDim2.new(0, 241, 0, 0)
                    Options.Position = UDim2.new(0, 0, 0, 44)
                    Options.BackgroundTransparency = 1
                    Options.ClipsDescendants = true
                    Options.Parent = Module
                    
                    local OptionsLayout = Instance.new('UIListLayout')
                    OptionsLayout.Padding = UDim.new(0, 6)
                    OptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
                    OptionsLayout.Parent = Options
                    
                    ModuleManager._module = Module
                    ModuleManager._options = Options
                    ModuleManager._toggle_indicator = ToggleIndicator
                    ModuleManager._toggle_knob = ToggleKnob
                    
                    function ModuleManager:change_state(state)
                        ModuleManager._state = state
                        pcall(function()
                            local targetColor = state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 60)
                            local targetPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                            TweenService:Create(ToggleIndicator, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                            TweenService:Create(ToggleKnob, TweenInfo.new(0.2), {Position = targetPos}):Play()
                        end)
                        if settings.callback then pcall(settings.callback, state) end
                        Config:save(game.GameId, Library._config)
                    end
                    
                    ModuleHeader.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            ModuleManager:change_state(not ModuleManager._state)
                        end
                    end)
                    
                    -- Checkbox
                    function ModuleManager:create_checkbox(settings)
                        local cb = { _state = settings.default or false }
                        pcall(function()
                            local container = Instance.new('Frame')
                            container.Size = UDim2.new(1, -20, 0, 28)
                            container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                            container.BorderSizePixel = 0
                            container.Parent = Options
                            
                            local corner = Instance.new('UICorner')
                            corner.CornerRadius = UDim.new(0, 6)
                            corner.Parent = container
                            
                            local label = Instance.new('TextLabel')
                            label.BackgroundTransparency = 1
                            label.Size = UDim2.new(1, -50, 1, 0)
                            label.Position = UDim2.new(0, 10, 0, 0)
                            label.Font = Enum.Font.GothamMedium
                            label.Text = settings.title or 'Checkbox'
                            label.TextColor3 = Color3.fromRGB(200, 200, 200)
                            label.TextSize = 12
                            label.TextXAlignment = Enum.TextXAlignment.Left
                            label.Parent = container
                            
                            local box = Instance.new('Frame')
                            box.Size = UDim2.new(0, 18, 0, 18)
                            box.Position = UDim2.new(1, -28, 0.5, -9)
                            box.BackgroundColor3 = cb._state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 50, 50)
                            box.BorderSizePixel = 0
                            box.Parent = container
                            
                            local boxCorner = Instance.new('UICorner')
                            boxCorner.CornerRadius = UDim.new(0, 4)
                            boxCorner.Parent = box
                            
                            container.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                    cb._state = not cb._state
                                    local targetColor = cb._state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 50, 50)
                                    TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                                    if settings.callback then pcall(settings.callback, cb._state) end
                                    if settings.flag then Library._config._flags[settings.flag] = cb._state end
                                    Config:save(game.GameId, Library._config)
                                end
                            end)
                            
                            function cb:update(state)
                                cb._state = state
                                local targetColor = state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 50, 50)
                                TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                            end
                            cb.SetValue = cb.update
                        end)
                        return cb
                    end
                    
                    -- Slider
                    function ModuleManager:create_slider(settings)
                        local slider = { _value = settings.value or settings.minimum_value or 0 }
                        pcall(function()
                            local min = settings.minimum_value or 0
                            local max = settings.maximum_value or 100
                            local val = settings.value or min
                            
                            local container = Instance.new('Frame')
                            container.Size = UDim2.new(1, -20, 0, 40)
                            container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                            container.BorderSizePixel = 0
                            container.Parent = Options
                            
                            local corner = Instance.new('UICorner')
                            corner.CornerRadius = UDim.new(0, 6)
                            corner.Parent = container
                            
                            local label = Instance.new('TextLabel')
                            label.BackgroundTransparency = 1
                            label.Size = UDim2.new(0.6, 0, 0, 16)
                            label.Position = UDim2.new(0, 10, 0, 6)
                            label.Font = Enum.Font.GothamMedium
                            label.Text = settings.title or 'Slider'
                            label.TextColor3 = Color3.fromRGB(200, 200, 200)
                            label.TextSize = 12
                            label.TextXAlignment = Enum.TextXAlignment.Left
                            label.Parent = container
                            
                            local valueLabel = Instance.new('TextLabel')
                            valueLabel.BackgroundTransparency = 1
                            valueLabel.Size = UDim2.new(0.4, -10, 0, 16)
                            valueLabel.Position = UDim2.new(0.6, 0, 0, 6)
                            label.Font = Enum.Font.GothamBold
                            valueLabel.Text = tostring(val)
                            valueLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
                            valueLabel.TextSize = 12
                            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                            valueLabel.Parent = container
                            
                            local sliderBg = Instance.new('Frame')
                            sliderBg.Size = UDim2.new(1, -20, 0, 6)
                            sliderBg.Position = UDim2.new(0, 10, 0, 28)
                            sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                            sliderBg.BorderSizePixel = 0
                            sliderBg.Parent = container
                            
                            local bgCorner = Instance.new('UICorner')
                            bgCorner.CornerRadius = UDim.new(1, 0)
                            bgCorner.Parent = sliderBg
                            
                            local sliderFill = Instance.new('Frame')
                            local pct = (val - min) / (max - min)
                            sliderFill.Size = UDim2.new(pct, 0, 1, 0)
                            sliderFill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
                            sliderFill.BorderSizePixel = 0
                            sliderFill.Parent = sliderBg
                            
                            local fillCorner = Instance.new('UICorner')
                            fillCorner.CornerRadius = UDim.new(1, 0)
                            fillCorner.Parent = sliderFill
                            
                            local dragging = false
                            local function update(input)
                                pcall(function()
                                    local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
                                    local newVal = math.floor(min + (max - min) * pos)
                                    sliderFill.Size = UDim2.new(pos, 0, 1, 0)
                                    valueLabel.Text = tostring(newVal)
                                    slider._value = newVal
                                    if settings.callback then pcall(settings.callback, newVal) end
                                    if settings.flag then Library._config._flags[settings.flag] = newVal end
                                end)
                            end
                            
                            sliderBg.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                    dragging = true
                                    update(input)
                                end
                            end)
                            
                            UserInputService.InputChanged:Connect(function(input)
                                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                                    update(input)
                                end
                            end)
                            
                            UserInputService.InputEnded:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                    dragging = false
                                    Config:save(game.GameId, Library._config)
                                end
                            end)
                            
                            function slider:update(v)
                                local num = tonumber(v) or min
                                local pos = (num - min) / (max - min)
                                sliderFill.Size = UDim2.new(pos, 0, 1, 0)
                                valueLabel.Text = tostring(num)
                                slider._value = num
                            end
                            slider.SetValue = slider.update
                        end)
                        return slider
                    end
                    
                    -- Dropdown
                    function ModuleManager:create_dropdown(settings)
                        local dropdown = { _selected = settings.default or (settings.options and settings.options[1]) }
                        pcall(function()
                            local options = settings.options or {}
                            
                            local container = Instance.new('Frame')
                            container.Size = UDim2.new(1, -20, 0, 32)
                            container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                            container.BorderSizePixel = 0
                            container.Parent = Options
                            
                            local corner = Instance.new('UICorner')
                            corner.CornerRadius = UDim.new(0, 6)
                            corner.Parent = container
                            
                            local label = Instance.new('TextLabel')
                            label.BackgroundTransparency = 1
                            label.Size = UDim2.new(1, -40, 1, 0)
                            label.Position = UDim2.new(0, 10, 0, 0)
                            label.Font = Enum.Font.GothamMedium
                            label.Text = (settings.title or 'Dropdown') .. ': ' .. tostring(dropdown._selected)
                            label.TextColor3 = Color3.fromRGB(200, 200, 200)
                            label.TextSize = 12
                            label.TextXAlignment = Enum.TextXAlignment.Left
                            label.Parent = container
                            
                            local arrow = Instance.new('TextLabel')
                            arrow.BackgroundTransparency = 1
                            arrow.Size = UDim2.new(0, 20, 1, 0)
                            arrow.Position = UDim2.new(1, -25, 0, 0)
                            arrow.Font = Enum.Font.GothamBold
                            arrow.Text = '▼'
                            arrow.TextColor3 = Color3.fromRGB(150, 150, 150)
                            arrow.TextSize = 10
                            arrow.Parent = container
                            
                            local listContainer = Instance.new('Frame')
                            listContainer.Size = UDim2.new(1, 0, 0, 0)
                            listContainer.Position = UDim2.new(0, 0, 1, 4)
                            listContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                            listContainer.BorderSizePixel = 0
                            listContainer.Visible = false
                            listContainer.ClipsDescendants = true
                            listContainer.ZIndex = 10
                            listContainer.Parent = container
                            
                            local listCorner = Instance.new('UICorner')
                            listCorner.CornerRadius = UDim.new(0, 6)
                            listCorner.Parent = listContainer
                            
                            local listLayout = Instance.new('UIListLayout')
                            listLayout.Padding = UDim.new(0, 2)
                            listLayout.Parent = listContainer
                            
                            for _, opt in ipairs(options) do
                                local optBtn = Instance.new('TextButton')
                                optBtn.Size = UDim2.new(1, 0, 0, 24)
                                optBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                                optBtn.BorderSizePixel = 0
                                optBtn.Font = Enum.Font.GothamMedium
                                optBtn.Text = tostring(opt)
                                optBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
                                optBtn.TextSize = 11
                                optBtn.Parent = listContainer
                                
                                local optCorner = Instance.new('UICorner')
                                optCorner.CornerRadius = UDim.new(0, 4)
                                optCorner.Parent = optBtn
                                
                                optBtn.MouseButton1Click:Connect(function()
                                    dropdown._selected = opt
                                    label.Text = (settings.title or 'Dropdown') .. ': ' .. tostring(opt)
                                    listContainer.Visible = false
                                    TweenService:Create(listContainer, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                                    if settings.callback then pcall(settings.callback, opt) end
                                    if settings.flag then Library._config._flags[settings.flag] = opt end
                                    Config:save(game.GameId, Library._config)
                                end)
                            end
                            
                            local isOpen = false
                            container.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                    isOpen = not isOpen
                                    if isOpen then
                                        listContainer.Visible = true
                                        TweenService:Create(listContainer, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, #options * 26)}):Play()
                                    else
                                        TweenService:Create(listContainer, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                                        task.wait(0.2)
                                        listContainer.Visible = false
                                    end
                                end
                            end)
                            
                            function dropdown:update(opt)
                                dropdown._selected = opt
                                label.Text = (settings.title or 'Dropdown') .. ': ' .. tostring(opt)
                            end
                            dropdown.SetValue = dropdown.update
                        end)
                        return dropdown
                    end
                end)
                
                return ModuleManager
            end
            
            return TabManager
        end
        
        -- Visibility Toggle
        function self:change_visiblity(state)
            pcall(function()
                local targetSize = state and UDim2.new(0, 680, 0, 460) or UDim2.new(0, 0, 0, 0)
                TweenService:Create(Container, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = targetSize}):Play()
            end)
        end
        
        Connections['library_visiblity'] = UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode ~= Enum.KeyCode.Insert then return end
            self._ui_open = not self._ui_open
            self:change_visiblity(self._ui_open)
        end)
        
        Minimize.MouseButton1Click:Connect(function()
            self._ui_open = not self._ui_open
            self:change_visiblity(self._ui_open)
        end)
        
        -- Initial animation
        task.spawn(function()
            task.wait(0.1)
            self:change_visiblity(true)
        end)
    end)
    
    return self
end

return Library
end)()

-- ==== WRAPPER LIBRARY (COMPATIBILITY) ====
local Library = (function()
    local Lib = {}
    local NOP = function() end
    local function stub() return {update=NOP, SetValue=NOP, change_state=NOP, set_options=NOP} end
    
    function Lib.SendNotification(info)
        info = info or {}
        pcall(function()
            AilonUI.SendNotification({
                title = tostring(info.title or info.Title or "UI"),
                text = tostring(info.text or info.description or ""),
                duration = tonumber(info.duration or info.time or 4)
            })
        end)
    end
    
    function Lib.new(config)
        config = config or {}
        local main = AilonUI.new()
        local win = {_native = main}
        pcall(function() win._ui = main._ui end)
        
        function win:create_tab(name, icon)
            local ok, Tab = pcall(function() return main:create_tab(name, icon) end)
            if not ok then Tab = nil end
            local tab = {_tab = Tab}
            
            function tab:create_module(info)
                info = info or {}
                local M = nil
                if Tab then
                    local ok2, r = pcall(function() return Tab:create_module(info) end)
                    if ok2 then M = r end
                end
                local mod = {_m = M}
                
                function mod:change_state(v) pcall(function() if M then M:change_state(v) end end) end
                function mod:update(v) pcall(function() if M then M:change_state(v) end end) end
                function mod:SetValue(v) pcall(function() if M then M:change_state(v) end end) end
                
                function mod:create_checkbox(i)
                    if not M then return stub() end
                    local ok3, cb = pcall(function() return M:create_checkbox(i) end)
                    return (ok3 and cb) or stub()
                end
                
                function mod:create_slider(i)
                    if not M then return stub() end
                    local ok3, s = pcall(function() return M:create_slider(i) end)
                    return (ok3 and s) or stub()
                end
                
                function mod:create_dropdown(i)
                    if not M then return stub() end
                    local ok3, d = pcall(function() return M:create_dropdown(i) end)
                    return (ok3 and d) or stub()
                end
                
                return mod
            end
            
            return tab
        end
        
        return win
    end
    
    return Lib
end)()

-- Continue na PARTE 4 (Game Logic + Auto Parry)...-- ==== BLADE BALL AUTO PARRY LOGIC ====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ParryAttempt = Remotes and Remotes:FindFirstChild("ParryAttempt")
local ParryButtonPress = Remotes and Remotes:FindFirstChild("ParryButtonPress")
local BallFolder = workspace:WaitForChild("Balls", 10)

-- State
local CachedArgs = nil
local LastParryTime = 0
local CooldownProtection = 0.12

-- Config Flags (will be linked to UI)
getgenv().AutoParryEnabled = false
getgenv().ParryAccuracy = 75
getgenv().RandomizeAccuracy = true
getgenv().AccuracyMin = 25
getgenv().AccuracyMax = 85
getgenv().ParryMode = "Remote"
getgenv().PredictionOffset = 0.08
getgenv().MinDistance = 6.5

-- ==== ARG SNIFFER (PROTECTED HOOK) ====
pcall(function()
    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if self == ParryAttempt and method == "FireServer" then
            CachedArgs = args
            pcall(function()
                Library.SendNotification({
                    title = "Auto Parry",
                    text = "Argumentos capturados! Modo Remote ativo.",
                    duration = 3
                })
            end)
        end
        
        return OldNamecall(self, ...)
    end))
end)

-- ==== BALL DETECTION ====
local function getTargetBall()
    if not BallFolder then return nil, 0 end
    
    for _, ball in ipairs(BallFolder:GetChildren()) do
        local isReal = ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies")
        if isReal then
            local vel = ball.AssemblyLinearVelocity
            if vel and vel.Magnitude > 10 then
                return ball, vel.Magnitude
            end
        end
    end
    return nil, 0
end

-- ==== ACCURACY SYSTEM ====
local function shouldParry()
    if not getgenv().AutoParryEnabled then return false end
    
    local acc = getgenv().ParryAccuracy
    if getgenv().RandomizeAccuracy then
        acc = math.random(getgenv().AccuracyMin, getgenv().AccuracyMax)
    end
    
    return math.random(1, 100) <= acc
end

-- ==== PARRY EXECUTION ====
local function executeParry()
    local now = tick()
    if now - LastParryTime < CooldownProtection then return end
    if not shouldParry() then return end
    
    LastParryTime = now
    
    pcall(function()
        if getgenv().ParryMode == "Remote" then
            if CachedArgs then
                ParryAttempt:FireServer(unpack(CachedArgs))
            elseif ParryButtonPress then
                ParryButtonPress:Fire()
            end
        else
            if ParryButtonPress then
                ParryButtonPress:Fire()
            end
        end
    end)
end

-- ==== MAIN LOOP ====
RunService.RenderStepped:Connect(function(dt)
    if not getgenv().AutoParryEnabled then return end
    
    local ball, speed = getTargetBall()
    if not ball then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local dist = (ball.Position - hrp.Position).Magnitude
    local threshold = getgenv().MinDistance + (speed * getgenv().PredictionOffset)
    
    if dist <= threshold then
        executeParry()
    end
end)

-- ==== UI INITIALIZATION ====
local Window = Library.new({
    title = "Sapphire Private",
    theme = "Dark"
})

local CombatTab = Window:create_tab("Combat", "rbxassetid://7734058599")
local VisualsTab = Window:create_tab("Visuals", "rbxassetid://7733774602")
local SettingsTab = Window:create_tab("Settings", "rbxassetid://7734052335")

-- Combat Module
local AutoParryModule = CombatTab:create_module({
    title = "Auto Parry",
    description = "Parries every ball aimed at you",
    section = "left",
    default = false,
    callback = function(state)
        getgenv().AutoParryEnabled = state
        if state and not CachedArgs then
            Library.SendNotification({
                title = "⚠️ Aviso",
                text = "Dê UM parry manual para capturar argumentos!",
                duration = 5
            })
        end
    end
})

AutoParryModule:create_slider({
    title = "Accuracy",
    minimum_value = 0,
    maximum_value = 100,
    value = 75,
    flag = "parry_accuracy",
    callback = function(val)
        getgenv().ParryAccuracy = val
    end
})

AutoParryModule:create_checkbox({
    title = "Randomize Accuracy",
    default = true,
    flag = "randomize_acc",
    callback = function(state)
        getgenv().RandomizeAccuracy = state
    end
})

AutoParryModule:create_slider({
    title = "Random Min",
    minimum_value = 0,
    maximum_value = 100,
    value = 25,
    flag = "acc_min",
    callback = function(val)
        getgenv().AccuracyMin = val
    end
})

AutoParryModule:create_slider({
    title = "Random Max",
    minimum_value = 0,
    maximum_value = 100,
    value = 85,
    flag = "acc_max",
    callback = function(val)
        getgenv().AccuracyMax = val
    end
})

AutoParryModule:create_dropdown({
    title = "Parry Mode",
    options = {"Remote", "Bindable"},
    default = "Remote",
    flag = "parry_mode",
    callback = function(opt)
        getgenv().ParryMode = opt
    end
})

-- Prediction Settings
local PredictionModule = CombatTab:create_module({
    title = "Prediction",
    description = "Timing adjustment",
    section = "right",
    default = true
})

PredictionModule:create_slider({
    title = "Offset",
    minimum_value = 0,
    maximum_value = 20,
    value = 8,
    callback = function(val)
        getgenv().PredictionOffset = val / 100
    end
})

PredictionModule:create_slider({
    title = "Min Distance",
    minimum_value = 3,
    maximum_value = 15,
    value = 6.5,
    round_number = false,
    callback = function(val)
        getgenv().MinDistance = val
    end
})

-- Status Indicator
local StatusModule = SettingsTab:create_module({
    title = "Status",
    description = "Script information",
    section = "left"
})

StatusModule:create_checkbox({
    title = "Args Captured: " .. (CachedArgs and "YES" or "NO"),
    default = CachedArgs ~= nil,
    callback = function() end
})

-- Welcome Notification
task.spawn(function()
    task.wait(1)
    Library.SendNotification({
        title = "Sapphire Private",
        text = "Carregado no YuB-X! Dê um parry manual para ativar modo Remote.",
        duration = 6
    })
end)

print("========================================")
print("  SAPPHIRE PRIVATE - YUB-X PC BUILD")
print("  PHANTOM 1099 | FULLY PROTECTED")
print("========================================")
print("  [!] DÊ UM PARRY MANUAL PARA CAPTURAR ARGS")
print("  [!] MODO REMOTE USA ARGS CACHEADOS")
print("  [!] MODO BINDABLE USA EVENTO INTERNO")
print("  [!] AJUSTE ACCURACY PARA EVITAR DETECÇÃO")
print("  [!] INSERT PARA TOGGLE UI")
print("========================================")

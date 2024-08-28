local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Statuslets"
obj.version = "2.3"
obj.author = "James Turnbull"
obj.homepage = "https://github.com/jamtur01/Statuslets.spoon"
obj.license = "MIT"

-- Constants
local REFRESH_INTERVAL = 300 -- 5 minutes
local DEFAULT_COLOR = hs.drawing.color.osx_yellow

-- Status indicators
local STATUS_INDICATORS = {
    GOOD = "●",
    WARNING = "◐",
    ERROR = "○"
}

-- Variables
obj.menubar = nil
obj.statusTimer = nil
obj.statusColors = {}
obj.cachedStatuses = {}

-- Helper functions
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function executeCommand(command)
    return trim(hs.execute(command, true))
end

local function getStatusIndicator(color)
    if color == hs.drawing.color.osx_green then
        return STATUS_INDICATORS.GOOD
    elseif color == hs.drawing.color.osx_yellow then
        return STATUS_INDICATORS.WARNING
    else
        return STATUS_INDICATORS.ERROR
    end
end

-- Status check functions
local function checkCPUUsage()
    local cpuUsage = hs.host.cpuUsage().overall.user
    return {
        color = cpuUsage < 75 and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = string.format("CPU Usage: %.2f%%", cpuUsage)
    }
end

local function checkMemoryUsage()
    local memoryInfo = executeCommand("vm_stat | grep 'Pages free:\\|Pages inactive:'")
    local freePages = 0
    for pages in memoryInfo:gmatch("%d+") do
        freePages = freePages + tonumber(pages)
    end
    if freePages > 0 then
        local freeMemory = freePages * 4096 / (1024 * 1024 * 1024)  -- Convert to GB
        return {
            color = freeMemory > 2 and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
            message = string.format("Free Memory: %.2f GB", freeMemory)
        }
    else
        return {
            color = hs.drawing.color.osx_yellow,
            message = "Memory info unavailable"
        }
    end
end

local function checkSystemUpdates()
    local updatesAvailable = executeCommand("softwareupdate -l | grep -q 'No new software available'") ~= ""
    return {
        color = not updatesAvailable and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = not updatesAvailable and "System Updates: Up-to-date" or "System Updates: Updates available"
    }
end

local function checkTimeMachineBackup()
    local backupSuccessful = executeCommand("tmutil latestbackup | grep -q 'Backup completed successfully'") ~= ""
    return {
        color = backupSuccessful and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = backupSuccessful and "Time Machine: Backup successful" or "Time Machine: Backup needed"
    }
end

local function checkNetworkTraffic()
    local highTraffic = executeCommand("netstat -ib | awk '{if ($7 > 0) print}' | grep -q '.'") ~= ""
    return {
        color = not highTraffic and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = not highTraffic and "Network Traffic: Normal" or "Network Traffic: High"
    }
end

local function checkUSBPowerDraw()
    local highPowerDraw = executeCommand("ioreg -p IOUSB -w0 | grep -q 'Current Required'") ~= ""
    return {
        color = not highPowerDraw and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = not highPowerDraw and "USB Power Draw: Normal" or "USB Power Draw: High"
    }
end

local function checkAvailableStorage()
    local output = executeCommand("df -h / | awk 'NR==2 {print $4}'")
    local available, unit = output:match("(%d+%.?%d*)([KMGT])")
    if available and unit then
        available = tonumber(available)
        local multiplier = {K = 1/1024/1024, M = 1/1024, G = 1, T = 1024}
        available = available * (multiplier[unit] or 1)
        return {
            color = available > 50 and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
            message = string.format("Available Storage: %.2f GB", available)
        }
    else
        return {
            color = hs.drawing.color.osx_yellow,
            message = "Storage info unavailable"
        }
    end
end

-- Core functions
function obj:createMenubarIcon()
    local statusText = hs.styledtext.new("")
    local statuses = {"cpu", "memory", "updates", "timemachine", "network", "usbpower", "storage"}
    
    for _, status in ipairs(statuses) do
        local color = obj.statusColors[status] or DEFAULT_COLOR
        local indicator = getStatusIndicator(color)
        statusText = statusText .. hs.styledtext.new(indicator, {color = color})
    end
    
    return statusText
end

function obj:checkStatus()
    return {
        cpu = checkCPUUsage(),
        memory = checkMemoryUsage(),
        updates = checkSystemUpdates(),
        timemachine = checkTimeMachineBackup(),
        network = checkNetworkTraffic(),
        usbpower = checkUSBPowerDraw(),
        storage = checkAvailableStorage()
    }
end

function obj:updateStatuses()
    local newStatuses = self:checkStatus()
    local hasChanged = false

    for key, newStatus in pairs(newStatuses) do
        local oldStatus = obj.cachedStatuses[key]
        if not oldStatus or oldStatus.color ~= newStatus.color or oldStatus.message ~= newStatus.message then
            hasChanged = true
            obj.statusColors[key] = newStatus.color
            obj.cachedStatuses[key] = newStatus
        end
    end

    if hasChanged then
        self:refreshMenubarIcon()
    end
end

function obj:generateMenu()
    local menuTable = {}
    
    for _, status in pairs(obj.cachedStatuses) do
        table.insert(menuTable, {
            title = status.message,
            disabled = true
        })
    end
    
    table.insert(menuTable, { title = "-" })
    table.insert(menuTable, {
        title = "Refresh Status",
        fn = function() self:updateStatuses() end
    })
    table.insert(menuTable, {
        title = "Quit Statuslets",
        fn = function() self:stop() hs.alert.show("Statuslets Stopped") end
    })
    
    return menuTable
end

function obj:start()
    if obj.menubar then
        obj.menubar:delete()
    end
    obj.menubar = hs.menubar.new()
    if obj.menubar then
        obj.menubar:setTitle("Init")
        obj.menubar:setMenu(function() return obj:generateMenu() end)
        self:updateStatuses()
        
        if obj.statusTimer then
            obj.statusTimer:stop()
        end
        obj.statusTimer = hs.timer.doEvery(REFRESH_INTERVAL, function() self:updateStatuses() end)
        
        print("Statuslets started successfully")
    else
        print("Failed to create menubar item")
    end
end

function obj:refreshMenubarIcon()
    local iconText = self:createMenubarIcon()
    obj.menubar:setTitle(iconText)
end

function obj:stop()
    if obj.statusTimer then
        obj.statusTimer:stop()
        obj.statusTimer = nil
    end
    if obj.menubar then
        obj.menubar:delete()
        obj.menubar = nil
    end
end

return obj
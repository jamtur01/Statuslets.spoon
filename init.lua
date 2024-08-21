local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Statuslets"
obj.version = "2.1"
obj.author = "James Turnbull"
obj.homepage = "https://github.com/jamtur01/Statuslets.spoon"
obj.license = "MIT"

-- Variables
obj.menubar = nil
obj.statusTimer = nil

-- Status Colors (default to yellow)
obj.statusColors = {
    cpu = hs.drawing.color.osx_yellow,
    memory = hs.drawing.color.osx_yellow,
    updates = hs.drawing.color.osx_yellow,
    timemachine = hs.drawing.color.osx_yellow,
    network = hs.drawing.color.osx_yellow,
    usbpower = hs.drawing.color.osx_yellow,
    storage = hs.drawing.color.osx_yellow
}

-- Cached statuses
obj.cachedStatuses = {}

function string.trim(s)
    return s:match( "^%s*(.-)%s*$" )
end

function obj:createMenubarIcon()
    local statusText = hs.styledtext.new("")
    local statuses = {"cpu", "memory", "updates", "timemachine", "network", "usbpower", "storage"}
    
    for _, status in ipairs(statuses) do
        local color = obj.statusColors[status]
        local dot = "●"  -- Default to full circle for good status
        if color == hs.drawing.color.osx_yellow then
            dot = "◐"  -- Half circle for warning
        elseif color ~= hs.drawing.color.osx_green then
            dot = "○"  -- Empty circle for error
        end
        statusText = statusText .. hs.styledtext.new(dot, {color = color})
    end
    
    return statusText
end

function obj:checkStatus()
    local statuses = {}

    -- CPU Usage Check
    local cpuUsage = hs.host.cpuUsage().overall
    statuses.cpu = {
        color = cpuUsage.user < 75 and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = string.format("CPU Usage: %.2f%%", cpuUsage.user)
    }

    -- Memory Usage Check
    local memoryInfo = hs.execute("vm_stat | grep 'Pages free:\\|Pages inactive:'", true)
    local freePages = 0
    for pages in memoryInfo:gmatch("%d+") do
        freePages = freePages + tonumber(pages)
    end
    if freePages > 0 then
        local freeMemory = freePages * 4096 / (1024 * 1024 * 1024)  -- Convert to GB
        statuses.memory = {
            color = freeMemory > 2 and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
            message = string.format("Free Memory: %.2f GB", freeMemory)
        }
    else
        statuses.memory = {
            color = hs.drawing.color.osx_yellow,
            message = "Memory info unavailable"
        }
    end

    -- System Updates Check
    local updatesOutput = hs.execute("softwareupdate -l | grep -q 'No new software available'", true)
    statuses.updates = {
        color = updatesOutput == "" and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = updatesOutput == "" and "System Updates: Up-to-date" or "System Updates: Updates available"
    }

    -- Time Machine Backup Check
    local tmOutput = hs.execute("tmutil latestbackup | grep -q 'Backup completed successfully'", true)
    statuses.timemachine = {
        color = tmOutput == "" and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = tmOutput == "" and "Time Machine: Backup successful" or "Time Machine: Backup needed"
    }

    -- Network Traffic Check
    local networkOutput = hs.execute("netstat -ib | awk '{if ($7 > 0) print}' | grep -q '.'", true)
    statuses.network = {
        color = networkOutput == "" and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = networkOutput == "" and "Network Traffic: Normal" or "Network Traffic: High"
    }

    -- USB Power Draw Check
    local usbPowerOutput = hs.execute("ioreg -p IOUSB -w0 | grep -q 'Current Required'", true)
    statuses.usbpower = {
        color = usbPowerOutput == "" and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
        message = usbPowerOutput == "" and "USB Power Draw: Normal" or "USB Power Draw: High"
    }

    -- Available Storage Check
    local function getAvailableStorage()
        local output = hs.execute("df -h / | awk 'NR==2 {print $4}'")
        local available, unit = output:match("(%d+%.?%d*)([KMGT])")
        if available and unit then
            available = tonumber(available)
            local multiplier = {K = 1/1024/1024, M = 1/1024, G = 1, T = 1024}
            available = available * (multiplier[unit] or 1)
            return available
        else
            return nil
        end
    end

    local availableSpace = getAvailableStorage()
    if availableSpace then
        statuses.storage = {
            color = availableSpace > 50 and hs.drawing.color.osx_green or hs.drawing.color.osx_red,
            message = string.format("Available Storage: %.2f GB", availableSpace)
        }
    else
        statuses.storage = {
            color = hs.drawing.color.osx_yellow,
            message = "Storage info unavailable"
        }
    end

    return statuses
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
    
    for key, status in pairs(obj.cachedStatuses) do
        table.insert(menuTable, {
            title = status.message,
            disabled = true
        })
    end
    
    -- Separator
    table.insert(menuTable, { title = "-" })
    
    -- Refresh option
    table.insert(menuTable, {
        title = "Refresh Status",
        fn = function() self:updateStatuses() end
    })
    
    -- Quit option
    table.insert(menuTable, {
        title = "Quit Statuslets",
        fn = function() obj:stop() hs.alert.show("Statuslets Stopped") end
    })
    
    return menuTable
end

function obj:start()
    print("Starting Statuslets...")
    if obj.menubar then
        print("Deleting existing menubar item")
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
        obj.statusTimer = hs.timer.doEvery(300, function() self:updateStatuses() end)
        
        print("Statuslets started successfully")
    else
        print("Failed to create menubar item")
    end
end

function obj:refreshMenubarIcon()
    local iconText = self:createMenubarIcon()
    
    if obj.menubar:setTitle(iconText) then
        print("Menubar title updated successfully")
    else
        print("Failed to update menubar title")
    end
end

-- Stop Function
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
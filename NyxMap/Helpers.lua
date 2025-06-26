local Helpers = {}

function Helpers.CountAll(_table)
    local loop
    loop = function(tab)
        local tempCount = 0
        for _, value in tab do
            tempCount += 1
            if typeof(value) == "table" then
                tempCount += loop(value)
            end
        end
        return tempCount
    end

    local count = loop(_table)
    return count
end

function Helpers.Count(_table)
    local count = 0
    for _, _ in _table do
        count += 1
    end
    return count
end

return Helpers
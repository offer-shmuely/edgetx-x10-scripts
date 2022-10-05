local M =  {}

function M.log(s)
    print("LogViewer: " .. s)
end
function M.log1(fmt, val1)
    M.log(string.format(fmt, val1))
end
function M.log2(fmt, val1, val2)
    M.log(string.format(fmt, val1, val2))
end
function M.log3(fmt, val1, val2, val3)
    M.log(string.format(fmt, val1, val2, val3))
end


return M

-- LÖVE harness configuration (real LÖVE 11.x runtime, simulated Balatro state)
function love.conf(t)
    t.identity = 'bsc_harness'
    t.window.title = 'Balatro Strategic Copilot - harness'
    t.window.width = 1600
    t.window.height = 900
    t.console = false
end

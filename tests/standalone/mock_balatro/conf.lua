-- SIMULATED Balatro conf.lua (not the real game), for tests/standalone/run_love_standalone.sh.
function love.conf(t)
    t.title = 'Balatro (simulation)'
    t.window.width = 1280
    t.window.height = 720
    -- scenario "append": a game asking LÖVE to search its save folder LAST (the autonomous mode
    -- cannot work then; this checks that nothing breaks)
    if os.getenv('BSC_SCENARIO') == 'append' then t.appendidentity = true end
end

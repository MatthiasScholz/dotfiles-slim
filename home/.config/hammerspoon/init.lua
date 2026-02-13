hs.loadSpoon('Hyper')
-- unusedd hs.loadSpoon('HyperModal')
-- TODO configure HyperModal

-- Init Hyper Key
Hyper = spoon.Hyper
Hyper:bindHotKeys({hyperKey = {{}, 'F19'}})

-- Configure Application Key Bindings
--  bundleID, global, local
Bindings = {
  {'com.apple.finder', 'f', nil},
  -- not needed {'com.raycast.macos', nil, {'c', 'space', ';'}},
  {'md.obsidian', 'g', nil},
}
hs.fnutils.each(Bindings, function(bindingTable)
  local bundleID, globalBind, localBinds = table.unpack(bindingTable)
  if globalBind then
    Hyper:bind({}, globalBind, function() hs.application.launchOrFocusByBundleID(bundleID) end)
  end
  if localBinds then
    hs.fnutils.each(localBinds, function(key)
      Hyper:bindPassThrough(key, bundleID)
    end)
  end
end)

-- Configure Higher Customized Bindings
-- Obsidian Shortcuts
Hyper:bind({}, 't', function()
  hs.urlevent.openURL("obsidian://open?vault=tw&file=DASHBOARD")
  Hyper:exit()
end)
Hyper:bind({}, 'n', nil, function()
  hs.urlevent.openURL("obsidian://adv-uri?vault=tw&commandid=quickadd:runQuickAdd")
end)

-- Jump to ms teams or zoom
-- UNUSED: Z_count = 0
Hyper:bind({}, 'z', nil, function()
  -- start a timer
  -- if not pressed again then
  if hs.application.find('us.zoom.xos') then
    hs.application.launchOrFocusByBundleID('us.zoom.xos')
  elseif hs.application.find('com.microsoft.teams2') then
    hs.application.launchOrFocusByBundleID('com.microsoft.teams2')
    local call = hs.settings.get("call")
    call:focus()
  end
end)

-- Examples to open an url
Hyper:bind({}, 'p', nil, function()
  hs.urlevent.openURL("https://gemini.google.com")
end)


-- TODO Check use case
-- provide the ability to override config per computer
if (hs.fs.displayName('./localConfig.lua')) then
  require('localConfig')
end


-- Helper for Hyper Groups
local chooseFromGroup = function(choice)
  local name = hs.application.nameForBundleID(choice.bundleID)

  hs.notify.new(nil)
  :title("Switching ✦-" .. choice.key .. " to " .. name)
  :contentImage(hs.image.imageFromAppBundle(choice.bundleID))
  :send()

  hs.settings.set("hyperGroup." .. choice.key, choice.bundleID)
  hs.application.launchOrFocusByBundleID(choice.bundleID)
end

-- Open selection window for a HyperGroup
-- Requires using "option" key in combination with the Hyper key
-- and the defined HyperGroup specific key
local hyperGroup = function(key, group)
  Hyper:bind({}, key, nil, function()
    hs.application.launchOrFocusByBundleID(hs.settings.get("hyperGroup." .. key))
  end)
  -- FIXME not compatible with my custom keyboard setup
  Hyper:bind({'option'}, key, nil, function()
    print("Setting options…")
    local choices = {}
    hs.fnutils.each(group, function(bundleID)
      table.insert(choices, {
        text = hs.application.nameForBundleID(bundleID),
        image = hs.image.imageFromAppBundle(bundleID),
        bundleID = bundleID,
        key = key
      })
    end)

    if #choices == 1 then
      chooseFromGroup(choices[1])
    else
      hs.chooser.new(chooseFromGroup)
      :placeholderText("Choose an application for hyper+" .. key .. ":")
      :choices(choices)
      :show()
    end
  end)
end

hyperGroup('b', {
  'com.Vivaldi',
  'com.google.Chrome',
})

hyperGroup('c', {
  -- TODO Add Google Chat
  'com.microsoft.teams2',
  -- Slack
  -- UNUSED 'com.tinyspeck.slackmacgap',
  'com.hnc.Discord'
})

-- TODO Add functionality to open a window chooser modal with filter query
--      like switch.sh which currently uses yabai and manual configuration of a shortcut
Hyper:bind({}, 'w', nil, function()
  local wc = hs.chooser.new(function(choice)

   end)

  -- TODO declare windows variable
   wc
     :placeholderText("Open windows")
     :searchSubText(true)
     :choices(windows)
     :show()
end)


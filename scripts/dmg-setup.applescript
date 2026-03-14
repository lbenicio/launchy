-- DMG window layout script for Launchy.
-- Run after `hdiutil attach` mounts the writable staging DMG.
-- Sets icon positions, window bounds, and background image (if present).

tell application "Finder"
    tell disk "Launchy"
        open
        update without registering applications
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 960, 460}

        set opts to icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128

        -- Position the application icon on the left, Applications alias on the right
        set position of item "Launchy.app" of container window to {160, 185}
        set position of item "Applications" of container window to {400, 185}

        -- Apply background image when it was copied into .background/
        try
            set background picture of opts to file ".background:background.png"
        end try

        update without registering applications
        close
    end tell
end tell

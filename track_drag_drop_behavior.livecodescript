script "DataView Track Drag and Drop Behavior"
local sControlsA
local sDispatchMessages = "true"


command dvRegisterControlForDragMessages pValue
  put empty into sControlsA[the long id of pValue]
  put true into sDispatchMessages
end dvRegisterControlForDragMessages


command dvResetViewsAffectedDuringDragOperation
  local tControl

  repeat for each key tControl in sControlsA
    set the dvTrackDragReorder of tControl to false
  end repeat

  put false into sDispatchMessages
  put empty into sControlsA
end dvResetViewsAffectedDuringDragOperation


command dvFreezeMouseRelatedDragMessagesPriorToCleanup
  put false into sDispatchMessages
end dvFreezeMouseRelatedDragMessagesPriorToCleanup


on dragDrop
  _doDragDrop

  pass dragDrop
end dragDrop

/* On web/mobile the drag drop will result in a mouseRelease event due to the
 * mouse up being off the original target */
 on mouseRelease
  if the platform is "web" or the environment is "mobile" then
    _doDragDrop
    _doDragEnd
  end if

  pass mouseRelease
end mouseRelease

private command _doDragDrop
  repeat for each key tControl in sControlsA
    if tControl is in the long id of the target then
      dispatch "dvDragDrop" to tControl
      exit repeat
    end if
  end repeat
end _doDragDrop

/**
Summary: Restore pre-drag state after drag operation is complete.

Description: After the drag is finished we need to reset any DataViews that
were part of the drag operation.
*/
on dragEnd
  _doDragEnd

  pass dragEnd
end dragEnd

/* On web/mobile a mouseUp is dropping on the original mouse target so a non-envent */
 on mouseUp
  if the platform is "web" or the environment is "mobile" then
    _doDragEnd
  end if

  pass mouseUp
end mouseUp

private command _doDragEnd
  local tControl
  repeat for each key tControl in sControlsA
    set the visible of image "dvDragImage" of tControl to false
    dispatch "dvDragEnd" to tControl
  end repeat
end _doDragEnd

on dragMove pMouseH,pMouseV
  _doDragMove pMouseH, pMouseV, the long id of the target

  pass dragMove
end dragMove

on mouseMove pMouseH, pMouseV
  if the platform is "web" or the environment is "mobile" then
    local tControl
    repeat for each key tControl in sControlsA
      if there is an image "dvDragImage" of tControl then
        /* Show the image with an offset so users can see the indicator */
        show image "dvDragImage" of tControl \
          at item 1 of the loc of tControl, \
            pMouseV + the height of image "dvDragImage" of tControl div 3
      end if
    end repeat

    _doDragMove pMouseH, pMouseV, the long id of the mouseControl
  end if

  pass mouseMove
end mouseMove

private command _doDragMove pMouseH, pMouseV, pTarget
  if not sDispatchMessages then
    exit _doDragMove
  end if

  local tControl
  repeat for each key tControl in sControlsA
    dispatch "dvDragMove" to tControl with pMouseH, pMouseV, pTarget
  end repeat
end _doDragMove

on dragLeave
  _doDragLeave

  pass dragLeave
end dragLeave

on mouseLeave
  if the platform is "web" or the environment is "mobile" then
    _doDragLeave
  end if

  pass mouseLeave
end mouseLeave

private command _doDragLeave
  if not sDispatchMessages then
    exit _doDragLeave
  end if

  local tControl
  repeat for each key tControl in sControlsA
    dispatch "dvDragLeave" to tControl
  end repeat
end _doDragLeave

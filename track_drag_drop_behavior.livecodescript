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
  repeat for each key tControl in sControlsA
    if tControl is in the long id of the target then
      dispatch "dvDragDrop" to tControl
      exit repeat
    end if
  end repeat

  pass dragDrop
end dragDrop


/**
Summary: Restore pre-drag state after drag operation is complete.

Description: After the drag is finished we need to reset any DataViews that
were part of the drag operation.
*/
on dragEnd
  local tControl
  local tFoundAMatch = "false"

  repeat for each key tControl in sControlsA
    dispatch "dvDragEnd" to tControl
  end repeat

  pass dragEnd
end dragEnd


on dragMove pMouseH,pMouseV
  if not sDispatchMessages then pass dragMove

  local tControl

  repeat for each key tControl in sControlsA
    dispatch "dvDragMove" to tControl with pMouseH, pMouseV, the long id of the target
  end repeat

  pass dragMove
end dragMove


on dragLeave
  if not sDispatchMessages then pass dragLeave

  local tControl

  repeat for each key tControl in sControlsA
    dispatch "dvDragLeave" to tControl
  end repeat

  pass dragLeave
end dragLeave

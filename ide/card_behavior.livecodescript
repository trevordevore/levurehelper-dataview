script "Create DataView Dialog Card Behavior"
on saveStackRequest
  _resetUI
  pass saveStackRequest
end saveStackRequest


on preOpenCard
  local tDialogA

  set the enabled of group "BehaviorControls" to false
  set the enabled of group "CreateRowTemplateControls" to false

  put the dialogData into tDialogA
  if tDialogA["show create row template"] is not empty and tDialogA["show create row template"] is false then
    set the visible of field "CreateRowTemplate" to false
    set the visible of group "CreateRowTemplateControls" to false
  end if

  if tDialogA["default row template styles"] is empty then
    put "default" into tDialogA["default row template styles"]
  end if
  set the text of field "RowTemplateStyles" to tDialogA["default row template styles"]

  _positionControlsAndResizeStack
end preOpenCard


on closeCard
  _resetUI
end closeCard


on mouseUp pBtnNum
  if pBtnNum is 1 then
    switch the short name of the target
      case "CreateDeveloperBehavior"
        set the enabled of group "BehaviorControls" to the hilite of the target
        break
      case "CreateRowTemplate"
        set the enabled of group "CreateRowTemplateControls" to the hilite of the target
        break
    end switch
  end if
end mouseUp


private command _positionControlsAndResizeStack
  local tTop

  if the visible of button "CreateRowTemplate" then
    put the bottom of field "RowTemplateStyles" into tTop
  end if

  set the top of button "CreateDeveloperBehavior" to tTop + 20
  set the top of field "LblBehaviorTip" to the bottom of button "CreateDeveloperBehavior" + 4
  _resizeFieldToFitTextHeight the long id of field "LblBehaviorTip"
  set the top of group "BehaviorControls" to the bottom of field "LblBehaviorTip" + 4

  set the top of group "DialogButtons" to the bottom of group "BehaviorControls" + 30

  local tRect
  put the rect of the owner of me into tRect
  put item 2 of tRect + the bottom of group "DialogButtons" + 30 into item 4 of tRect
  set the rect of the owner of me to tRect
end _positionControlsAndResizeStack


private command _resetUI
  set the text of field "Name" to empty
  set the hilite of button "CreateRowTemplate" to false
  set the text of field "RowTemplateStyles" to "default"
  set the hilite of button "CreateDeveloperBehavior" to false
  set the text of field "BehaviorName" to empty
  set the text of field "BehaviorFilename" to empty
  set the enabled of group "BehaviorControls" to true
end _resetUI


on uiClickedCreate
  local tPropsA, tError

  put word 1 to -1 of field "Name" into tPropsA["name"]

  put the hilite of button "CreateRowTemplate" into tPropsA["create row template"]
  if tPropsA["create row template"] then
    put word 1 to -1 of field "RowTemplateStyles" into tPropsA["row template styles"]
  end if

  if the hilite of button "CreateDeveloperBehavior" then
    put word 1 to -1 of field "BehaviorName" into tPropsA["behavior name"]
    put word 1 to -1 of field "BehaviorFilename" into tPropsA["behavior filename"]
    replace "/" with empty in tPropsA["behavior filename"]
  end if

  if tPropsA["name"] is empty then
    put "Please enter a name." into tError
  else if the hilite of button "CreateDeveloperBehavior" then
    if tPropsA["behavior name"] is empty then
      put "Please enter a behavior name." into tError
    else if tPropsA["behavior filename"] is empty then
      put "Please enter a behavior filename." into tError
    end if
  end if

  if tError is empty then
    set the dialogData to tPropsA
    close this stack
  else
    answer error tError
  end if
end uiClickedCreate


on uiClickedCancel
  set the dialogData to "cancel"
  close this stack
end uiClickedCancel


command uiUpdateSuggestedBehaviorNames
  if the text of field "Name" is not empty then
    set the text of field "BehaviorName" to the text of field "Name" && "Behavior"
    set the text of field "BehaviorFilename" to \
          _makeFilenameFromControlName(the text of field "Name") & ".livecodescript"
  end if
end uiUpdateSuggestedBehaviorNames


private function _makeFilenameFromControlName pControlName
  replace space with "_" in pControlName
  put tolower(pControlName) into pControlName
  return pControlName
end _makeFilenameFromControlName


private command _resizeFieldToFitTextHeight pField
  local tRect

  put the rect of pField into tRect
  put item 2 of tRect + the formattedHeight of pField into item 4 of tRect
  set the rect of pField to tRect
end _resizeFieldToFitTextHeight

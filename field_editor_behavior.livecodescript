script "DataView Field Editor Behavior"
constant kKeyNumsThatScroll = "65308,65309,65310,65311"

local sFormattedHeight

--on escapeKey
--  _CloseFieldEditor false, param(0)
--end escapeKey


on openField
  put the formattedHeight of me into sFormattedHeight
end openField


on closeField
  delete local sFormattedHeight
  _CloseFieldEditor true, param(0)
end closeField


on exitField
  delete local sFormattedHeight
  _CloseFieldEditor true, param(0)
end exitField


on returnInField
  if the autotab of me then
    _CloseFieldEditor true, param(0)
  else
    pass returnInField
  end if
end returnInField


on enterInField
  if the autotab of me then
    _CloseFieldEditor true, param(0)
  else
    pass enterInField
  end if
end enterInField


on tabKey
  if the autotab of me then
    _CloseFieldEditorAndOpenNext param(0)
  else
    pass tabkey
  end if
end tabKey

local sScrollingIntoView

on rawKeyDown pKey
  ## scroll into view if not in view
    set the wholematches to true
  if sScrollingIntoView is not true and pKey is not among the items of kKeyNumsThatScroll then
    put true into sScrollingIntoView
    if not the visible of the dvRowControl of me or (the selectedLoc is a point and the selectedLoc is not within the viewProp["content window rect"] of the dvControl of me) then
      ScrollSelectionIntoView
    end if
    put false into sScrollingIntoView
  end if

  pass rawKeyDown
end rawKeyDown


on selectionChanged
   ## don't pass as selectionChanged is reserved for group
   ## developer can override behavior to process selectionChanged
end selectionChanged


/**
* |brief Sent when field content is updated by user.
*
* We are interested in whether or not the height of the field equals the content height.
* If it is not then resize.
*/
on textChanged
  if the formattedHeight of me is not sFormattedHeight then
    ResizeToFitContent
    put the formattedHeight of me into sFormattedHeight
  end if
end textChanged


on TextChangedByScript pAction
  ResizeToFitContent
end TextChangedByScript


command ResizeToFitContent
  local theFormattedHeight, thePadding
  local theWidth, theTempHeight, theSelectedChunk
  local theRow

  if there is not a (the long id of me) then exit ResizeToFitContent ## in case underlying control is deleted
  _cancelMessage "ResizeToFitContent" ## throttle

  lock screen

  put _getSelectedChunk() into theSelectedChunk

  ## Resize the row which will resize the editor
  put the dvRow of the dvRowControl of me into theRow
  FlagRowForResize theRow
  RenderVisibleRows

  if theSelectedChunk is not empty then
    try
      select theSelectedChunk ## this throws errors when resizing after a delete
    catch e
    end try
  end if

  # 2015-12-21: Added so we could move objects along with the DataView.
  dispatch "DataViewDidUpdateView" to the dvControl of me

  unlock screen
end ResizeToFitContent


/**
Summary: Returns a fully qualified reference to the selectedChunk.

Description:
The selectedChunk returns a short field reference (e.g. field 2). This is not
sufficient for referencing the selectedChunk when the selectedField is not
on the same stack as the defaultStack.

Returns: Reference to selectedChunk
*/
function _getSelectedChunk
  local tSelChunk, tSelField

  put the selectedChunk into tSelChunk
  if tSelChunk is not empty then
    put the long id of the selectedField into tSelField
    put tSelField into word -2 to -1 of tSelChunk
  end if

  return tSelChunk
end _getSelectedChunk


command _cancelMessage pMsg
  local tMessage, tMessages

  repeat until (comma & pMsg & comma) is not in the pendingMessages
    put the pendingMessages into tMessages
    filter tMessages with "*," & pMsg & ",*"
    repeat for each line tMessage in tMessages
      cancel item 1 of tMessage
    end repeat
  end repeat
end _cancelMessage

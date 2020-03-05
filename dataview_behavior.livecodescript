script "DataView Behavior"
constant kLockUpdatesSetting = "true" # use for testing whether or not lockupdates makes a difference.

constant kFieldEditorName = "dvFieldEditor"

constant kAlternatingRowModValue = 0 -- 0 to have first color be first, 1 to have first color be alternating color
constant kDefaultDimmedHiliteColor = "212,212,212"
constant kRowColor = "255,255,255"
constant kAlternateRowColor = "230,237,247"
constant kKeyNumsThatScroll = "65308,65309,65310,65311"

constant kSBWidthWin = 17
constant kSBWidthMac = 15
constant kSBWidthLinux = 16

constant kDefaultForNonCachedVariableHeightRows = 50

local sInit
local sWorkingGroupRect
local sViewPropsA
local sSystemA -- stores system specific settings
local sLastTargetedRow
local sScrollerID
local sPendingMsgsA
local sFieldEditor ## place holder until I decide what to do with editing.
local sNumRowsTempCache ## Caches row count during single event
local sTouchA # for swiping
local sMouseDownA # dvMouseDownBefore handler stores data in this variable that dvMouseDownAfter handler uses.
local sDropStructure
local sUseEventsForScroll


/**
Summary: Print out diagnostic information about the internal data structures.

Returns: Diagnostic text
*/
command __InspectInternally
  local tText

  put "control height cache:" && _getTotalCachedHeight() & cr & \
        "content height:" && the viewProp["content height"] of me & cr & \
        "sViewProps:" & cr & printArray(sViewPropsA,,true) into tText

  return tText
end __InspectInternally


/**
Summary: Possible entry point for initializing internal data structures.

Description:
Note that this message will not be called if a DataView is created
by script.
*/
before preopenControl
  if the target is not me then exit preopenControl
  _init
end preopenControl


/**
Summary: Possible entry point for initializing internal data structures.

*/
before newGroup
  if the target is not me then exit newGroup
  _init
end newGroup


/**
Summary: Cleans up the mobile scrollbar.
*/
after closeControl
  if the environment is "mobile" then
    if sScrollerID is among the lines of mobileControls() then
      mobileControlDelete sScrollerID
      put empty into sScrollerID
    end if
  end if
end closeControl


/**
Summary: Resizes the DataView to fit the new rect.

*/
on resizeControl
  if the target is not me then pass resizeControl
  ResizeToFit
  pass resizeControl
end resizeControl


/**
Summary: Implements changing selection when arrow keys are pressed.
*/
on arrowKey pDirection
  if word 1 of the target is "field" and not the locktext of the target then pass arrowkey
  dvArrowKey pDirection
  pass arrowkey
end arrowKey


/**
Summary: Implements scroll wheel scrolling for the control.

Parameters:
pKeyNum: See LiveCode docs.

Returns: empty
*/
on rawKeyDown pKeyNum
  local tCanScroll

  /*
  Immediate exit:
    1. No scrollbar (content isn't tall enough to scroll)
    2. Editable field is target and either:
        A. pKeyNum isn't interesting for scrolling purposes
        B. The field is the focusedObject and it has a scrollbar
  */
  put the visible of scrollbar "dvVScrollbar" of me \
        or the viewProp["scroll when vScrollbar is hidden"] of me into tCanScroll

  if not tCanScroll then
    pass rawKeyDown
  else if word 1 of the target is "field" AND not the locktext of the target then
    set the wholeMatches to true

    if pKeyNum is not among the items of kKeyNumsThatScroll then
      pass rawkeyDown
    else if the long id of the target is the focusedObject AND the vscrollbar of the target then
      # If field has focus then scroll actions should be handled by field
      pass rawKeyDown
    end if
  end if

  -- 65308 - Mouse wheel down
  -- 65309 - Mouse wheel up
  -- 65310 - Mouse wheel right
  -- 65311 - Mouse wheel left
  -- 65365 - page up
  -- 65366 - page down
  -- 65360 - home
  -- 65367 - end

  ## Note: Messages are locked when setting thumbpostion and we call scrolling code directly.
  ##          This is done so that scrolling works when scrollbars are hidden.
  local tAvailHeight, tScroll, tRowHeight

  switch pKeyNum
    case "65360"
      ## home
      set the viewProp["vscroll"] of me to 0
      break
    case "65367"
      ## end
      set the viewProp["vscroll"] of me to the endValue of scrollbar "dvVScrollbar" of me
      break
    case "65365"
      ## scroll page up
      set the viewProp["vscroll"] of me to the thumbPosition of scrollbar "dvVScrollbar" of me - \
            the pageIncrement of scrollbar "dvVScrollbar" of me
      break
    case "65366"
      ## scroll page down
      set the viewProp["vscroll"] of me to the thumbPosition of scrollbar "dvVScrollbar" of me + \
            the pageIncrement of scrollbar "dvVScrollbar" of me
      break
    case "65309"    # scroll up
      ## mouse wheel up

      ## If a field editor is open then it must be closed first
      if the viewProp["cache"] of me is "none" and the viewProp["field editor is open"] of me then
        DeleteFieldEditor true, "close control"
      else
        if sUseEventsForScroll then
          put the viewProp["row height"] of me into tRowHeight
          if tRowHeight <= 0 then
            # This calculation provides an acceptable scroll speed for variabl row height in testing
            put the viewProp["content window height"] of me into tAvailHeight
            put round(tAvailHeight * .03) into tRowHeight
          end if

          set the viewProp["vscroll"] of me to \
                round(the thumbPosition of scrollbar "dvVScrollbar" of me) - item 2 of macCurrentEventScrollValues(tRowHeight)
        else
          put the viewProp["content window height"] of me into tAvailHeight
          put round(tAvailHeight * .1) into tScroll
          set the viewProp["vscroll"] of me to round(the thumbPosition of scrollbar "dvVScrollbar" of me) - tScroll
        end if
      end if
      break
    case "65308"    # scroll down
      ## mouse wheel down

      ## If a field editor is open then it must be closed first
      if the viewProp["cache"] of me is "none" and the viewProp["field editor is open"] of me then
        DeleteFieldEditor true, "close control"
      else
        if sUseEventsForScroll then
          put the viewProp["row height"] of me into tRowHeight
          if tRowHeight <= 0 then
            # This calculation provides an acceptable scroll speed for variabl row height in testing
            put the viewProp["content window height"] of me into tAvailHeight
            put round(tAvailHeight * .03) into tRowHeight
          end if

          set the viewProp["vscroll"] of me to \
                round(the thumbPosition of scrollbar "dvVScrollbar" of me) - item 2 of macCurrentEventScrollValues(tRowHeight)
        else
          put the viewProp["content window height"] of me into tAvailHeight
          put round(tAvailHeight * .1) into tScroll
          set the viewProp["vscroll"] of me to round(the thumbPosition of scrollbar "dvVScrollbar" of me) + tScroll
        end if
      end if
      break
    case "65310"
      ## mouse wheel right
      -- nothing
    case "65311"
      ## mouse wheel left
      -- nothing
    default
      pass rawKeyDown
  end SWITCH
end rawKeyDown


/**
Summary: Prcoesses the message for the scrollbars.

*/
on scrollbarDrag pValue
  if the short name of the target is "dvVScrollbar" then
    if pValue is not the viewProp["vscroll"] of me then
      lock messages
      _setVScroll pValue ## in case messages are locked
      unlock messages
    end if
  end if
end scrollbarDrag


/**
Summary: Called by mobile scrollbars.

*/
on scrollerDidScroll pOffsetX, pOffsetY
  -- Set the scroll values of the group based on feedback from the scroller
  -- notice that we can just use the values directly and because out-of-bounds
  -- scrolling is enabled for the group, the bounce effect needs no extra
  -- code.
  _setVScroll pOffsetY
end scrollerDidScroll


on mouseDown pMouseBtnNum
  if the environment is not "mobile" then
    # For more complicated dataview behavior the developer may
    # want to call dvMouseDownBefore manually.
    if the viewProp["process mousedown"] of me is not false then
      dvMouseDown pMouseBtnNum
    end if
  end if
  pass mousedown
end mouseDown


on mouseUp pMouseBtnNum
  if the environment is not "mobile" then
    dvMouseUp pMouseBtnNum
  end if
  pass mouseUp
end mouseUp


on mouseRelease pMouseBtnNum
  if the environment is not "mobile" then
    dvMouseRelease pMouseBtnNum
  end if
  pass mouseRelease
end mouseRelease


/**
Summary: Implementation of `MouseEnterControl`/`MouseLeaveControl` and `MouseEnterDataView/MouseLeaveControl` messages.

Description:
As of LiveCode 9.5 there is no support for `mouseEnter`/`mouseLeave` messages that
are sent to a group. The DataView synthesizes the `MouseEnterControl`/`MouseLeaveControl`
messages to overcome this shortcoming.

`mouseEnter` handles both `MouseEnterControl` and `MouseLeaveControl` messages while the mouse
moves around inside of the DataView. `mouseLeave` sends the `MouseLeaveControl` when the mouse
leaves the DataView.
*/
local sCurrentMouseRowControlId
local sMouseWithinDataView


before mouseEnter
  local tControlId

  /*
  Observed behavior:
  Take a row control that has an icon which is shown on MouseEnterRowControl and
  hidden on MouseLeaveRowControl. While visible, the user can click on it to show a
  popup menu. If the user moves the mouse around to other controls in the row control
  while the popup menu is visible, and then dismisses the menu while the mouse is outside
  of the DataView (by click or using escape key), an endless loop of mouseLeave/mouseEnter
  messages will be generated while the icon is being shown/hidden repeatedly.

  I understand why mouseLeave is sent to the control. It is unclear why mouseEnter would
  be sent again as the mouse isn't over the control. That appears to be a bug.

  This check ensures that this endless loop doesn't occur.
  */
  if the mouseLoc is not within the rect of me then
    exit mouseEnter
  end if

  if not sMouseWithinDataView then
    put true into sMouseWithinDataView
    dispatch "MouseEnterDataView" to me
  end if

  put the dvRowControl of the target into tControlId
  if tControlId is empty then
    put the dvPaddingControl of the target into tControlId
  end if

  if tControlId is not empty then
    put the short id of tControlId into tControlId

    if tControlId is not sCurrentMouseRowControlId then
      if sCurrentMouseRowControlId is not empty and there is a control id sCurrentMouseRowControlId then
        dispatch "MouseLeaveControl" to control id sCurrentMouseRowControlId
      end if

      put tControlId into sCurrentMouseRowControlId
      dispatch "MouseEnterControl" to control id sCurrentMouseRowControlId
    end if
  else
    if there is a control id sCurrentMouseRowControlId then
      put sCurrentMouseRowControlId into tControlId
      put empty into sCurrentMouseRowControlId
      dispatch "MouseLeaveControl" to control id tControlId
    end if
  end if
end mouseEnter


/**
Summary: Ensures that `the mouseLoc` does not return a negative y value.

Description:
During testing it was observed that `the mouseLoc` in `after mouseUp` would
return a negative value for the y coordinate unless the DataView also defined
the `on mouseUp` handler. The root cause has not been found but this fixes
the problem.

Returns: nothing
*/
on mouseEnter
  pass mouseEnter
end mouseEnter


/**
Summary: mouseLeave is only necessary for sending messages when the mouse leaves the DataView as a whole.

Returns: nothing
*/
after mouseLeave
  # During this message the mouseLoc will be outside of the rect in most cases.
  # It is possible that a control slightly overlaps the DataView, however, which
  # is why there is a check for a matching dvControl as well.
  if the mouseLoc is not within the rect of me or \
        the mousecontrol is empty or the dvControl of the mousecontrol is not the dvControl of me then
    if sCurrentMouseRowControlId is not empty then
      local tControlId

      put sCurrentMouseRowControlId into tControlId
      put empty into sCurrentMouseRowControlId
      if there is a control id tControlId then
        dispatch "MouseLeaveControl" to control id tControlId
      end if
    end if

    put false into sMouseWithinDataView
    dispatch "MouseLeaveDataView" to me
  end if
end mouseLeave


/**
Summary: Ensures that `the mouseLoc` does not return a negative y value.

Description:
During testing it was observed that `the mouseLoc` in `after mouseLeave` would
return a negative value for the y coordinate unless the DataView also defined
the `on mouseLeave` handler. The root cause has not been found but this fixes
the problem.

Returns: nothing
*/
on mouseLeave
  pass mouseLeave
end mouseLeave


on touchStart pID
  local theIndex, theControl, theRow

  put the mouseLoc into sTouchA[pId]["start loc"]

  ## figure out the index clicked on
  put empty into theIndex
  if the mouseControl is not empty then
    put the dvRowControl of the mouseControl into theControl
  end if
  if theControl is not empty then
    put the dvRow of theControl into theRow
  end if

  ## Bring focus into control. Do this before any possible exit points.
  if theRow is not empty then
    ## Clicked on a control. Bring focus into control but away from scrollbar.
    if the long ID of me is not in the long ID of the focusedObject or word 1 of the target is "scrollbar" or \
          (sViewPropsA["fld_editor"]["control"] is not empty and the long id of control id sViewPropsA["fld_editor"]["control"] is the long ID of the focusedObject) then
      focus on graphic "dvBackground" of me
    end if
  else
    ## clicked in space but no on list control
    focus on graphic "dvBackground" of me
  end if

  if the viewProp["autohilite"] of me is false then return empty

  ## Now do what we need to do
  if theRow is not empty then
    put sViewPropsA["hilited rows"] into sViewPropsA["previously hilited rows"]
    put theRow into sViewPropsA["hilited rows"]
    _hiliteRowsInVisibleControls
  end if

  ## If the selection hasn't changed then at least update the hilites as they
  ## may be grayed out. If one day we can get a true focusIn message for the group
  ## as a whle then the 'else' condition can be removed.
  --   if theSelectionChanged then _selectionChanged thePreviouslyHilitedRows
  --   else _hiliteRowsInVisibleControls
  pass touchStart
end touchStart


on touchEnd pID
  local thePreviouslyHilitedRows

  # When the touch end remove the ID from the array tracking all our touches
  if sTouchA[pID] is an array then
    ## no swipe
    delete variable sTouchA[pId]
  end if

  put sViewPropsA["previously hilited rows"] into thePreviouslyHilitedRows
  put empty into sViewPropsA["previously hilited rows"]
  if sViewPropsA["hilited rows"] is not empty then
    _selectionChanged thePreviouslyHilitedRows
  end if
  pass touchEnd
end touchEnd


/**
Summary: Sent in cases where user touches row, holds but then starts scrolling.

*/
on touchRelease
  set the dvHilitedRows of me to empty
  pass touchRelease
end touchRelease


/**
Summary: Determines whether a left or right swipe has occurred on the data view.

*/
on touchMove pId, pX, pY
  ## Swipe is with one finger
  if sTouchA[pID] is an array and the number of lines of the keys of sTouchA is 1 then
    local theDeltaX, theDeltaY

    put item 1 of sTouchA[pID]["start loc"] - pX into theDeltaX
    put abs(item 2 of sTouchA[pID]["start loc"] - pY) into theDeltaY
    if theDeltaY < 50 then
      if abs(theDeltaX) > 30 then
        if theDeltaX < 0 then
          dispatch "swipeRight"
        else
          dispatch "swipeLeft"
        end if
        delete variable sTouchA[pID]
      end if
    end if
  end if
  pass touchMove
end touchMove


/**
Summary: Deletes all controls, resets the vscroll and clears internal storage.

Returns: empty
*/
command ResetView
  local i, msgsAreLocked

  put the lockMessages into msgsAreLocked
  lock screen
  lock messages

  _init

  # Cleanup rows, sending messages
  repeat for each key theKey in sViewPropsA["controls"]["cache"]
    if there is not a control id sViewPropsA["controls"]["cache"][theKey]["control"] then next repeat

    dispatch "CleanupAfterControl" to control id sViewPropsA["controls"]["cache"][theKey]["control"]
    delete control id sViewPropsA["controls"]["cache"][theKey]["control"]
  end repeat

  # This will clean up any stragglers
  repeat with i = the number of groups of group "dvList" of me down to 1
    delete group i of group "dvList" of me
  end repeat
  repeat with i = 1 to the number of controls of group "dvList" of me
    delete control 1 of group "dvList" of me
  end repeat

  if there is a group "dvTopPaddingContent" of me then
    delete group "dvTopPaddingContent" of me
  end if

  set the viewProp["vscroll"] of me to 0
  set the viewProp["first working row"] of me to 0
  set the viewProp["last working row"] of me to 0
  set the thumbposition of scrollbar "dvVScrollbar" of me to 0

  put empty into sViewPropsA

  set the viewProp["content height"] of me to 0
  _autoHideScrollbars
  _configureScrollbars
  unlock screen

  set the lockMessages to msgsAreLocked

  return empty
end ResetView


/**
Summary: Renders the data in the view using the current vscroll. The 'hilited rows' property will be reset.

Description:
All controls will be updated with latest data. If caching is on this means all controls get new data.
Any controls which have not yet been cached will be cached during this call. No controls will be recreated.

Returns: empty
*/
command RenderView
  put empty into sViewPropsA["hilited rows"]
  put empty into sViewPropsA["running actions"]
  _renderView
  return the result
end RenderView


/**
Summary: Refresh the view by making sure the proper data is mapped to the proper row.

Description:
The purpose of this handler is to ensure that the proper data is mapped to the proper row
in the view. It can be called after reordering rows, deleting rows, adding rows, etc.

If caching is on then the cache keys for each row will be updated, clearing controls as
necessary, and any new controls will be initialized/displayed.

If caching is off then the normal draw routines are called.

Returns: empty
*/
command RefreshViewRows
  _renderView false
  return the result
end RefreshViewRows


/**
Summary: Refreshes the data in the specified rows and renders them.

Parameters:
pRows: A comma-delimited list of rows to render.

Description:
If a row does not have a control associated with it then nothing will happen.

Returns: empty
*/
command RenderRows pRows
  local tRowCount, theRow, theIndex
  local theDataA, theControlId, theStyle, theTopLeft
  local updateTheScrollbars = "false"
  local msgsAreLocked, theRowWidth, theCacheKey

  put the viewProp["content width"] of me into theRowWidth

  put the lockMessages into msgsAreLocked
  unlock messages
  lock screen

  set the lockUpdates of group "dvList" of me to kLockUpdatesSetting

  put the viewProp["number of rows"] of me into tRowCount

  ## Update existing rows
  repeat for each item theRow in pRows
    if theRow < 1 or theRow > tRowCount then next repeat

    # Reset data array each time through loop
    put empty into theDataA

    dispatch "DataForRow" to me with theRow, theDataA, theStyle ## style is ignored for a refresh (dispatch forces target)

    put _dispatchCacheKeyForRow(theRow) into theCacheKey # don't use cached key
    put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into theControlId

    if theControlId is not empty then
      if the dvTemplateStyle of control id theControlId is not theStyle then
        # Control isn't valid for row type. Move back into cache and get a new control
        put the topleft of control id theControlId into theTopLeft

        _cleanupControl theCacheKey, theRow, theControlId, true

        _setupRowControl theRow, empty, true
        put the result into theControlId
        set the topleft of control id theControlId to theTopLeft
      else
        # Reset data array each time through loop
        put empty into theStyle

        ## Since we are rendering from scratch dvControlHasBeenRendered should return false during the next two messages
        lock messages
        set the dvDataCache of control id theControlId to empty
        set the dvHiliteState of control id theControlId to empty
        unlock messages

        ## Implemented by instance of behavior

        dispatch "FillInData" to control id theControlId with theDataA, theRow

        lock messages
        set the dvDataCache of control id theControlId to NULL
        unlock messages
      end if

      _dispatchLayoutControl theControlId, theRow, theRowWidth, true
      put true into updateTheScrollbars
    else if the viewProp["cache"] of me is "none" and not the viewProp["fixed row height"] of me then
      ## Control isn't visible on screen. NULL the height so it's new height is taken into account next time it is rendered.
      if sViewPropsA["controls"]["control height cache"][theRow] is not NULL then
        put true into updateTheScrollbars
        put NULL into sViewPropsA["controls"]["control height cache"][theRow]
      end if
    end if
  end repeat

  set the lockUpdates of group "dvList" of me to false

  if updateTheScrollbars then
    ## Update everything
    _calculateContentHeight
    lock messages
    _configureScrollbars ## note that messages are locked so no scrollbar drag is sent
    unlock messages
    RenderVisibleRows

    # Allow developer to move objects along with the DataView.
    dispatch "DataViewDidUpdateView" to me
  end if

  unlock screen
  set the lockMessages to msgsAreLocked

  return empty
end RenderRows


/**
Summary: Renders all visible controls based on current properties.

Returns: `true` if the `content height` changed while drawing.
*/
command RenderVisibleRows
  local theDataA, theStyle
  local theStartRow, theEndRow, theStartRowYOffset
  local theRowWidth, theOrigContentHeight
  local msgsAreLocked

  ## Throttle
  if sViewPropsA["running actions"]["vscroll"] then
    put true into sViewPropsA["running actions"]["resend vscroll"]
    return empty
  end if

  put true into sViewPropsA["running actions"]["vscroll"]

  put the lockMessages into msgsAreLocked
  unlock messages

  _getRangeOfRowsToDisplay theStartRow, theEndRow, theStartRowYOffset  ## can alter content height

  put the viewProp["content height"] of me into theOrigContentHeight
  put the viewProp["content width"] of me into theRowWidth

  ## Update the pool of available controls
  ## and reset list of rows in use
  _updateControlCacheForActiveRange theStartRow, theEndRow

  set the viewProp["first working row"] of me to theStartRow # in case developer wants to access
  set the viewProp["last working row"] of me to theEndRow

  lock screen

  local forceFillInData = "true"

  if theStartRow > 0 then
    local theTopLeft, tControlId

    put the topleft of group "dvListMask" of me into theTopLeft
    subtract theStartRowYOffset from item 2 of theTopLeft

    set the lockUpdates of group "dvList" of me to kLockUpdatesSetting
    repeat with theRow = theStartRow to theEndRow
      ## Controls
      ## "available"
      ## "cache"
      ## "rows in use"

      ## Is there a cached control for this row?
      put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(theRow)]["control"] into tControlId

      ## No control? Get data and get one.
      if tControlId is empty then
        _setupRowControl theRow, empty, forceFillInData
        put the result into tControlId
        if tControlId is empty then exit repeat

        set the topleft of control id tControlId to theTopLeft
        # Don't update height. We only get here if caching is off. Heights have already been determined previously.
        _dispatchLayoutControl tControlId, theRow, theRowWidth, false
      else
        _prepareRowForDisplay theRow, tControlId, theRowWidth, theTopLeft
      end if

      if not the visible of control id tControlId then
        # Send message to control telling it that it is being displayed
        dispatch "ShowControl" to control id tControlId
        set the visible of control id tControlId to true
      end if

      if theRow is among the items of sViewPropsA["hilited rows"] then
        _hiliteControl tControlId, true
      else
        _hiliteControl tControlId, false
      end if

      put the bottom of control id tControlId into item 2 of theTopLeft

      # relayer row control so that tabbing through controls works as expected.
      lock messages
      relayer control id tControlId to front of group "dvList" of me
      unlock messages
    end repeat
  end if ## startrow > 0

  # Scroll top padding content
  if there is a group "dvTopPaddingContent" of me then
    put the short id of group "dvTopPaddingContent" of me into tControlId
    if theStartRow is 0 then
      if not the visible of control id tControlId then
        set the visible of control id tControlId to true
      end if
      set topleft of control id tControlId to the topleft of group "dvList" of me
    else if theStartRow is 1 and theStartRowYOffset < 0 then
      if not the visible of control id tControlId then
        set the visible of control id tControlId to true
      end if
      set the bottomleft of control id tControlId to \
            the topleft of control id sViewPropsA["controls"]["cache"][_getCacheKeyForRow(1)]["control"]
    else if the visible of control id tControlId then
      set the visible of control id tControlId to false
    end if
  end if

  set the lockUpdates of group "dvList" of me to false

  if the viewProp["content height"] of me is not theOrigContentHeight then
    _configureScrollbars
  end if

  unlock screen

  set the lockMessages to msgsAreLocked

  put false into sViewPropsA["running actions"]["vscroll"]

  if sViewPropsA["running actions"]["resend vscroll"] then
    if the keys of the dragData is empty then
      send "RenderVisibleRows" to me in 0 milliseconds
    end if
    put false into sViewPropsA["running actions"]["resend vscroll"]
  end if

  return the viewProp["content height"] of me is not theOrigContentHeight
end RenderVisibleRows


/**
Summary: Resizes the specified row controls. Useful for cached controls that can be resized by the user.

Parameters:
pRows: The rows to resize.

Returns: empty
*/
command ResizeRows pRows
  local theRow

  repeat for each item theRow in pRows
    FlagRowForResize theRow
  end repeat

  lock screen
  RenderVisibleRows

  # 2015-12-21: Added so we could move objects along with the DataView.
  dispatch "DataViewDidUpdateView" to me
  unlock screen

  return empty
end ResizeRows


/**
Summary: Removes the specified row from the view. Use when data is removed from the model.

Parameters:
pRows: The rows to delete.
pRefreshView: Pass in false to prevent the view being refreshed.

Description:
This handler is most useful when caching is turned on.

Returns: empty
*/
command DeleteRows pRows, pRefreshView
  local theRow, theCacheKey, theItemNo
  local msgsAreLocked

  put pRefreshView is not false into pRefreshView

  put the lockMessages into msgsAreLocked
  lock screen

  set the wholeMatches to true

  ## Go backwards so as not to mess up index offsets 11-08-2012: Not sure if this is still relevant
  sort items of pRows descending numeric

  ## Move control back into cache of available controls
  repeat for each item theRow in pRows
    _deleteRowControlFromCache theRow
  end repeat

  _ensureIntegrityOfSelectedRows

  ## Redraw everything. Note that RefreshViewRows won't reload data in cached controls, just refresh the view.
  if pRefreshView then
    RefreshViewRows
  end if
  set the lockMessages to msgsAreLocked

  unlock screen

  return empty
end DeleteRows


/**
Summary: Removes a row control from the cache. The view is not refreshed afterwards.

Parameters:
pRow: The row to remove.

Description:
Use this handler to remove controls from the cache as part of a larger handler that
will also handle refreshing the view.

Returns: nothing
*/
command DeleteRowControlFromCache pRow
  _deleteRowControlFromCache pRow
  return empty
end DeleteRowControlFromCache


private command _deleteRowControlFromCache pRow
  local tCacheKey, tItemNo

  put _getCacheKeyForRow(pRow) into tCacheKey
  if sViewPropsA["controls"]["cache"][tCacheKey] is an array then
    _cleanupControl tCacheKey, pRow, sViewPropsA["controls"]["cache"][tCacheKey]["control"], true
  end if

  # Remove from rows in use
  put itemOffset(pRow, sViewPropsA["controls"]["rows in use"]) into tItemNo
  if tItemNo > 0 then
    delete item tItemNo of sViewPropsA["controls"]["rows in use"]
  end if

  return empty
end _deleteRowControlFromCache


/**
Summary: Resizes the DataView rows to fit the current rect.

Returns: empty
*/
command ResizeToFit
  put _workingGroupRect(the long id of me) into sWorkingGroupRect

  ## Throttle just in case developer tries to call this from different timers
  if sViewPropsA["running actions"]["resize to fit"] then
    put true into sViewPropsA["running actions"]["resend resize to fit"]
    return empty
  end if

  put true into sViewPropsA["running actions"]["resize to fit"]

  local screenIsLocked

  put the lockScreen into screenIsLocked
  if not screenIsLocked then lock screen

  local theVScrollPercent, theLockLoc, msgsAreLocked, theMasterRect
  local theErrorToRethrow

  put sWorkingGroupRect into theMasterRect
  put the viewProp["vscroll percent"] of me into theVScrollPercent

  put the lockLoc of me into theLockLoc
  set the lockLoc of me to true
  put the lockMessages into msgsAreLocked
  lock messages

  set the rect of graphic "dvBackground" of me to theMasterRect
  if there is a button "dvEventCatcher" of me then
    set the rect of button "dvEventCatcher" of me to theMasterRect
  end if
  add the borderWidth of me to item 1 of theMasterRect
  add the borderWidth of me to item 2 of theMasterRect
  subtract the borderWidth of me from item 3 of theMasterRect
  subtract the borderWidth of me from item 4 of theMasterRect

  set the rect of scrollbar "dvVScrollbar" of me to \
        item 3 of theMasterRect - the width of scrollbar "dvVScrollbar" of me, \
        item 2 of theMasterRect, item 3 of theMasterRect, item 4 of theMasterRect - max(0, the viewProp["scrollbar corner offset"] of me)

  set the topleft of group "dvListMask" of me to item 1 of theMasterRect + max(0, the viewProp["content left padding"] of me), \
        item 2 of theMasterRect
  set the topleft of group "dvList" of me to the topleft of group "dvListMask" of me
  set the visible of scrollbar "dvVScrollbar" of me to the environment is not "mobile" \
        AND the viewProp["content height"] of me > _getContentWindowHeight()
  _resizeSupportingControls

  set the lockLoc of me to theLockLoc
  unlock messages

  try
    _resetHiliteStateInCachedControls
    _resizeRowControlsAsNeeded

    lock messages
    _configureScrollbars
    unlock messages
    RenderVisibleRows

    # if content height changed then true is returned. Fix scrollbars.
    if the result then
      lock messages
      _configureScrollbars
      unlock messages
    end if

    if sScrollerID is not empty then
      mobileControlSet sScrollerID, "rect", the rect of me
    end if
  catch e
    put e into theErrorToRethrow
  end try

  unlock messages

  # 2015-12-21: Added so we could move objects along with the DataView.
  dispatch "DataViewDidUpdateView" to me

  if not screenIsLocked then unlock screen
  set the lockMessages to msgsAreLocked

  put false into sViewPropsA["running actions"]["resize to fit"]

  if theErrorToRethrow is not empty then throw theErrorToRethrow

  if sViewPropsA["running actions"]["resend resize to fit"] then
    send "ResizeToFit" to me in 0 seconds
    put false into sViewPropsA["running actions"]["resend resize to fit"]
  end if

  return empty
end ResizeToFit


/**
Summary: Selects all rows in the view.

Returns: empty
*/
command SelectAll
  if the selectedField is not empty and (not the listBehavior of the selectedField or (listBehavior of the selectedField and multiplehilites of the selectedfield)) then
    select text of the selectedField
    dispatch "selectionChanged" to the selectedField
  else
    local theRows, thePreviouslyHilitedIndexes, theOrigValue
    local theSelectionWasChanged

    put sViewPropsA["hilited rows"] into thePreviouslyHilitedIndexes

    put the viewProp["scroll selections into view"] of me is not false into theOrigValue
    set the viewProp["scroll selections into view"] of me to false

    repeat with i = 1 to the viewProp["number of rows"] of me
      put i & "," after theRows
    end repeat

    lock screen
    set the dvHilitedRows of me to theRows
    put the result into theSelectionWasChanged

    set the viewProp["scroll selections into view"] of me to theOrigValue

    put 1 into sLastTargetedRow ## default to this

    if theSelectionWasChanged then
      _selectionChanged thePreviouslyHilitedIndexes
    end if
    unlock screen
  end if

  return empty
end SelectAll


/**
Summary: Scrolls the row to the top or bottom of the view.

Parameters:
pRow The row to scroll.
pPlacement: `top` or `bottom`.
*/
command ScrollRowTo pRow, pPlacement
  _scrollRow pRow, pPlacement, true
  return the result
end ScrollRowTo


/**
Summary: Scrolls the specified row into view.

Parameters:
pRow Row to scroll into view.
pPlacement: Optional parameter specifying whether row should be displayed at `top` or `bottom` of view.

Returns: Error message
*/
command ScrollRowIntoView pRow, pPlacement
  _scrollRow pRow, pPlacement, false
  return the result
end ScrollRowIntoView


/**
Summary: Scrolls the specified rectangle into view. You can provide a padding for the top/bottom so that rect has spacing between top/bottom of view.

Parameters:
pRect: The rectangle to scroll into view.
pPadding: A rectangle specifying the padding to use. Only item 2 and 4 are used at this time.

Returns: empty
*/
command ScrollRectIntoView pRect, pPadding
  local theItemNo
  local theMaskRect
  local theScrollToOffset, theVScroll, theCurrentVScroll

  if pPadding is an integer then
    put pPadding & comma & pPadding & comma & pPadding into item 2 of pPadding
  else if pPadding is not a rect then
    put 0,0,0,0 into pPadding
  end if

  ## Mask rect is rect of this group with vscroll taken into account
  put the viewProp["content window rect"] of me into theMaskRect
  put the viewProp["vscroll"] of me into theCurrentVScroll

  ## left,right are ignored right now
  add item 1 of pPadding to item 1 of theMaskRect
  add item 2 of pPadding to item 2 of theMaskRect
  subtract item 3 of pPadding from item 3 of theMaskRect
  subtract item 4 of pPadding from item 4 of theMaskRect

  ## If mask height is less than rect height than we focus on top of pRect.
  ## Otherwise we focus on bottom of pRect.
  if item 4 of theMaskRect - item 2 of theMaskRect < item 4 of pRect - item 2 of pRect then
    put 2 into theItemNo
    put item 4 of theMaskRect - item 2 of theMaskRect into theScrollToOffset
  else
    put 4 into theItemNo
    put 0 into theScrollToOffset
  end if

  if _rectIsAtLeastAsTallAsMask(pRect, theMaskRect) then
    if _rectCoversMask(pRect, theMaskRect) then
      ## Rect covers entire visible area. Do nothing.
    else
      ## If rect top or bottom is visible then do nothing. Otherwise scroll top in.
      if _topIsVisible(pRect, theMaskRect) or _bottomIsVisible(pRect, theMaskRect) then
        ## Nothing
      else
        ## Scroll up to top of control
        put theCurrentVScroll - abs(item 2 of theMaskRect - item 2 of pRect) into theVScroll
      end if
    end if
  else if _topIsClipped(pRect, theMaskRect) then
    ## Scroll up to top of control
    put theCurrentVScroll - abs(item 2 of theMaskRect - item 2 of pRect) into theVScroll

  else if _bottomIsClipped(pRect, theMaskRect) then
    ## scroll down to bottom of control
    put theCurrentVScroll - (item 4 of theMaskRect - item theItemNo of pRect) into theVScroll
    add theScrollToOffset to theVScroll

  else if _topAndBottomAreClipped(pRect, theMaskRect) then
    if item 2 of pRect >= item 4 of theMaskRect then
      ## scroll down so bottom to bottom of control
      put theCurrentVScroll - (item 4 of theMaskRect - item theItemNo of pRect) into theVScroll
      add theScrollToOffset to theVScroll
    else
      ## scroll up to top of control
      put theCurrentVScroll - abs(item 2 of theMaskRect - item 2 of pRect) into theVScroll
    end if
  end if

  if theVScroll is not empty then
    if the viewProp["animate selections"] of me then
      _startScrollAnimation theVScroll
    else
      local msgsAreLocked

      _cancelAnimation
      put the lockMessages into msgsAreLocked
      lock messages
      set the thumbPosition of scrollbar "dvVScrollbar" of me to theVScroll
      set the lockMessages to msgsAreLocked
      _setVScrollForPlatform theVScroll
    end if
  end if

  return empty
end ScrollRectIntoView


/**
Summary: Scrolls the text selection into view.

Returns: empty
*/
command ScrollSelectionIntoView
  if not sViewPropsA["is animating"] then
    local theRect

    put the selectedLoc into theRect

    if theRect is a point then ## selectedfield bugs can get you here
      local theRowControl

      ## Reconfigure selectedLoc for position of row control in view
      put the dvRowControl of the selectedField into theRowControl
      if theRowControl is not empty then
        local theActualRowRect, theRowControlRect, theMargins, theAnimSetting

        put the rect of theRowControl into theActualRowRect
        put the dvRectOfRow[the dvRow of theRowControl] of me into theRowControlRect
        if theRowControlRect is a rect then
          ## Add in the difference in positions to the selectedLoc value
          add (item 1 of theRowControlRect - item 1 of theActualRowRect) to item 1 of theRect
          add (item 2 of theRowControlRect - item 2 of theActualRowRect) to item 2 of theRect

          put item 1 of theRect into item 3 of theRect
          put item 2 of theRect + the effective textHeight of the selectedField into item 4 of theRect

          ## Add margin
          put 0,20,0,20 into theMargins

          put the viewProp["animate selections"] of me into theAnimSetting
          set the viewProp["animate selections"] of me to false
          ScrollRectIntoView theRect, theMargins
          set the viewProp["animate selections"] of me to theAnimSetting
        end if
      end if
    end if
  end if
end ScrollSelectionIntoView


/**
Summary: Flags the control for a row as needing to be resized the next time it is drawn.

Parameters:
pRow: The row to flag.

Description:
Flagging a row to be resized can be useful when working with cached controls
and you want to mark rows as needed to be resized the next time they
are scrolled into view.

Returns: empty
*/
command FlagRowForResize pRow
  local tCacheKey

  put _getCacheKeyForRow(pRow) into tCacheKey
  if sViewPropsA["controls"]["cache"][tCacheKey] is an array then
    put true into sViewPropsA["controls"]["cache"][tCacheKey]["resize"]
  end if
  return empty
end FlagRowForResize


/**
Summary: Returns properties for the DataView.

Parameters:
pProp: The property to get.

Description:
Table of properties:

| Name | Description |
|:---- |:----------- |
| `number of rows` | The number of rows in the DataView. Dispatches the `NumberOfRows` function. |
| `cache` |  |
| `opaque` |  |
| `background color` |  |
| `vscroll` |  |
| `vscroll percent` |  |
| `drop indicator template` |  |
| `row style templates` |  |
| `content width` |  |
| `content window height` |  |
| `content window rect` |  |
| `field editor is open` |  |
| `field editor` |  |
| `field editor name` |  |
| `field editor content has changed` |  |

| `effective scrollbar width` |  |
| `scrollbar is visible` |  |
| `first selected row` |  |
| `first working row` |  |
| `last working row` |  |

Returns: Mixed
*/
getProp viewProp [pProp]
  switch pProp
    case "number of rows"
      ## Can we cache this so we don't make so many calls?
      ## Cache when rendering view. Update if row added or deleted.
      local tValue
      put sNumRowsTempCache into tValue
      if tValue is empty then
        dispatch function "NumberOfRows"
        if it is "handled" then
          put the result into tValue
        end if
      end if
      put max(0,tValue) into tValue
      return tValue
      break

    case "opaque"
      return the visible of graphic "dvBackground" of me

    case "background color"
      return the backgroundColor of graphic "dvBackground" of me

    case "vscroll percent"
      return _getVScrollPercent()
      break

    case "content width"
      return the width of group "dvList" of me
      break

    case "content window width"
      return the width of group "dvListMask" of me

    case "content window height"
      return _getContentWindowHeight()
      break

    case "content window rect"
      return the rect of group "dvListMask" of me
      break

    case "field editor is open"
      return sViewPropsA["fld_editor"]["control"] is not empty \
            and there is a control id sViewPropsA["fld_editor"]["control"] \
            and not sViewPropsA["fld_editor"]["closing"]
      break

    case "field editor"
      if sViewPropsA["fld_editor"]["control"] is not empty and there is a control id sViewPropsA["fld_editor"]["control"] then
        return the long id of control id sViewPropsA["fld_editor"]["control"]
      else
        return empty
      end if
      break

    case "field editor name"
      return kFieldEditorName
      break

    case "field editor content has changed"
      if sViewPropsA["fld_editor"]["control"] is not empty and there is a control id sViewPropsA["fld_editor"]["control"] then
        set the caseSensitive to true
        return the effective styledText of control id sViewPropsA["fld_editor"]["control"] \
              is not the dvOriginalStyledText of control id sViewPropsA["fld_editor"]["control"]
      end if
      break

    case "effective scrollbar width"
      return the width of scrollbar "dvVScrollbar" of me
      break

    case "scrollbar is visible"
      return the visible of scrollbar "dvVScrollbar" of me
      break

    case "first selected row"
      if sViewPropsA[pProp] is empty then
        return item 1 of sViewPropsA["hilited rows"] # in case prop isn't set but rows are selected
      else
        return sViewPropsA[pProp]
      end if
      break

    default
      return the viewProp[pProp] of me
  end switch
end viewProp


/**
Summary: Sets properties on the DataView.

Parameters:
pProp: The property to set.
pValue: The value to set the property to.

Description:
Table of properties that can be set:

| Name | Description |
|:---- |:----------- |
| `cache` | `none`, `lazy`, or `eager` |
| `opaque` |  |
| `background color` |  |
| `vscroll` |  |
| `vscroll percent` |  |
| `scrollbar width` |  |
| `content left padding` |  |
| `content right padding` |  |
| `content top padding` |  |
| `content bottom padding` |  |
| `drop indicator template` |  |
| `row style templates` |  |
| `top padding template` |  |
| `hilite color` |  |

Returns: nothing
*/
setProp viewProp [pProp] pValue
  ## Cleansing
  switch pProp
    case "cache"
      if pValue is not among the items of "eager,lazy,none" then
        put "none" into pValue
      end if
      break
  end switch

  ## Set
  switch pProp
    case "opaque"
      set the visible of graphic "dvBackground" of me to pValue is true
      break
    case "background color"
      set the backgroundColor of graphic "dvBackground" of me to pValue
      break
    case "vscroll"
      _setVScrollForPlatform pValue
      break
    case "vscroll percent"
      _SetVScrollPercent pValue
      break
    case "hscroll"

      break
    case "scrollbar width"
      if pValue is not the viewProp[pProp] of me then
        set the viewProp[pProp] of me to pValue
        lock screen
        _setScrollbarWidth pValue
        _resizeSupportingControls
        # Only resize controls if scrollbar overlaps content area.
        if pValue > the viewProp["content right padding"] of me then
          beep
          _resizeRowControlsAsNeeded
        end if
        unlock screen
      end if
      break
    case "content left padding"
    case "content right padding"
    case "content top padding"
    case "content bottom padding"
      if pValue is not a number then
        put 0 into pValue
      end if
      set the viewProp[pProp] of me to pValue
      ResizeToFit
      break
    case "content width"
      if pValue is empty then
        put the width of group "dvListMask" of me into pValue
      end if
      lock screen
      local tRect
      put the rect of group "dvList" of me into tRect
      put item 1 of tRect + pValue into item 3 of tRect
      set the rect of group "dvList" of me to tRect
      set the hscrollbar of group "dvListMask" of me to the width of group "dvList" of me > the width of group "dvListMask" of me
      if not the hscrollbar of group "dvListMask" of me then set the hscroll of group "dvListMask" of me to 0
      _resizeRowControlsAsNeeded
      unlock screen
      break
    case "drop indicator template"
      if pValue is not empty then
        put _customControlReference(pValue) into pValue
      end if
      set the viewProp[pProp] of me to pValue
      break
    case "row style templates"
      if pValue is an array then
        repeat for each key theKey in pValue
          if pValue[theKey] is not empty then
            put _customControlReference(pValue[theKey]) into pValue[theKey]
          end if
        end repeat
      else
        if pValue is not empty then put _customControlReference(pValue) into pValue
        put pValue into pValue["default"]
      end if
      set the viewProp[pProp] of me to pValue
      break
    case "top padding template"
      if pValue is not empty then
        put _customControlReference(pValue) into pValue
      end if
      set the viewProp[pProp] of me to pValue
      _insertPaddingControl
      break
    default
      set the viewProp[pProp] of me to pValue
      break
  end switch

  ## Redraw as needed
  switch pProp
    case "hilite color"
      _hiliteRowsInVisibleControls
      break
  end switch

  return empty
end viewProp


/**
Summary: Defines the arrow key behavior for the control.

Parameters:
pDirection: The direction of the arrowkey that was pressed.

Description:
This handler is called from the arrowkey message. If you need to override
the arrowKey message in the behavior instance then you can call his handler explicitly
in order to get the default arrow key behavior.

Returns: empty
*/
command dvArrowKey pDirection
  ## Look for cases where we pass arrowkey
  if word 1 of the target is "field" and not the locktext of the target then exit dvArrowKey
  if the viewProp["autohilite"] of me is false then exit dvArrowKey

  local theSelectionChanged, thePreviouslyHilitedRows
  local theNewRow, theRowCount, restoreTheseRows

  ## Don't let queue of key repeats build up or list might keep scrolling after user releases arrow key
  ## Mac needs 'autokey'. Windows needs 'keyDown'.
  get flushEvents("autokey")
  get flushEvents("keyDown")

  put false into theSelectionChanged

  lock screen

  set the wholeMatches to true

  if sViewPropsA["hilited rows"] is not empty then
    put sViewPropsA["hilited rows"] into thePreviouslyHilitedRows
    put thePreviouslyHilitedRows into restoreTheseRows
  end if

  if sViewPropsA["hilited rows"] is not empty then
    local theItemNo

    switch pDirection
      case "up"
        if _isThisModifierSetActive("shift") and the viewProp["multiple lines"] of me then
          if item 1 of sViewPropsA["hilited rows"] > 1 then
            put max(1, _nextSelectableRow(item 1 of sViewPropsA["hilited rows"], "up")) into theNewRow
            put itemOffset(theNewRow, thePreviouslyHilitedRows) into theItemNo
            if theItemNo is 0 then
              put theNewRow into sLastTargetedRow

              put comma & theNewRow after thePreviouslyHilitedRows
              _setHilitedRows thePreviouslyHilitedRows
              put true into theSelectionChanged
            end if
          end if
        else if _isThisModifierSetActive("") then ## other modifiers should not select
          put max(1, _nextSelectableRow(item 1 of sViewPropsA["hilited rows"], "up")) into theNewRow
          if sViewPropsA["hilited rows"] is not theNewRow then
            if item 1 of sViewPropsA["hilited rows"] > 1 then
              put theNewRow into sLastTargetedRow

              _setHilitedRows theNewRow
              put true into theSelectionChanged
            else if item 1 of sViewPropsA["hilited rows"] is 1 then
              ## Case for multiple selections going all the way to top
              put item 1 of sViewPropsA["hilited rows"] into sLastTargetedRow

              _setHilitedRows item 1 of sViewPropsA["hilited rows"]
              put true into theSelectionChanged
            end if
          end if
        end if
        break

      case "down"
        put the viewProp["number of rows"] of me into theRowCount

        if _isThisModifierSetActive("shift") and the viewProp["multiple lines"] of me then
          if item -1 of sViewPropsA["hilited rows"] is not empty and item -1 of sViewPropsA["hilited rows"] < theRowCount then
            put _nextSelectableRow(item -1 of sViewPropsA["hilited rows"], "down") into theNewRow
            put itemOffset(theNewRow, thePreviouslyHilitedRows) into theItemNo
            if theItemNo is 0 then
              put theNewRow into sLastTargetedRow

              put comma & theNewRow after thePreviouslyHilitedRows
              _setHilitedRows thePreviouslyHilitedRows
              put true into theSelectionChanged
            end if
          end if
        else if _isThisModifierSetActive("") then ## other modifiers should not select
          put _nextSelectableRow(item 1 of sViewPropsA["hilited rows"], "down") into theNewRow
          if theNewRow is not sViewPropsA["hilited rows"] then # did row change?
            if item 1 of sViewPropsA["hilited rows"] > 0 and item 1 of sViewPropsA["hilited rows"] < theRowCount then
              put theNewRow into sLastTargetedRow

              _setHilitedRows theNewRow
              put true into theSelectionChanged
            else if item 1 of sViewPropsA["hilited rows"] is theRowCount then
              put theRowCount into sLastTargetedRow
              subtract 1 from theNewRow

              ## Case for multiple selections going all the way to bottom
              _setHilitedRows theRowCount
              put true into theSelectionChanged
            end if
          end if
        end if
        break
    end switch

  else if the viewProp["number of rows"] of me > 0 then
    put _nextSelectableRow(0, "down") into theNewRow
    if theNewRow > 0 then
      _setHilitedRows theNewRow
      put true into theSelectionChanged
    end if
  end if

  if theSelectionChanged then
    # If the arrow key is moving the selection (and not adding to it)
    # then update the "first selected row"
    if the number of items of sViewPropsA["hilited rows"] is 1 then
      put sViewPropsA["hilited rows"] into sViewPropsA["first selected row"]
    end if

    _selectionChanged thePreviouslyHilitedRows
  end if

  unlock screen

  return false
end dvArrowKey


/**
Summary: Developers who override mousedown can use this call.

*/
command dvMouseDown pMouseBtnNum
  dvMouseDownBefore pMouseBtnNum
  dvMouseDownAfter pMouseBtnNum
end dvMouseDown


/**
Summary: Selects rows in the view prior to the developer mouseDown being processed.

*/
command dvMouseDownBefore pMouseBtnNum
  # If user is holding down command or option then mouseDown is sent to an editable field.
  if word 1 of the target is "field" and not the lockText of the target then exit dvMouseDownBefore

  local theRow, theIndex, theControl, canSelectTarget

  ## figure out the row clicked on
  put empty into theIndex
  put the dvRowControl of the target into theControl
  put the dvCanSelect of the target is not false into canSelectTarget
  if theControl is not empty then
    put the dvRow of theControl into theRow
  end if

  put theRow into sLastTargetedRow

  ## Bring focus into control. Do this before any possible exit points.
  if theRow is not empty then
    ## Click on a row control. If focus isn't in the dvListMask itself then focus on background.
    ## This accounts for clicks on the scrollbar (which shouldn't have focus) and when focus is in the
    # dvTopPaddingContent group but should be removed.
    if the long ID of group "dvList" is not in the long ID of the focusedObject \
          or (sViewPropsA["fld_editor"]["control"] is not empty and the long id of control id sViewPropsA["fld_editor"]["control"] is the long ID of the focusedObject) then
      focus on graphic "dvBackground" of me
    end if
  else
    ## clicked in space but not on list control
    focus on graphic "dvBackground" of me
  end if

  if the viewProp["autohilite"] of me is false then return empty
  ## Allow for rows that can't be clicked.
  ## Send message to target so developer can determine whether or not to select
  ## based on what was clicked on.
  if theControl is not empty AND not canSelectTarget then return empty

  put false into sMouseDownA["selection changed"]

  lock screen
  set the wholeMatches to true

  ## No do what we need to do
  if theRow is not empty then
    local theHilitedRows, theItemNo

    put sViewPropsA["hilited rows"] into theHilitedRows
    put sViewPropsA["hilited rows"] into sMouseDownA["previously hilited rows"]

    if pMouseBtnNum is 1 then
      if _isThisModifierSetActive("command") and the viewProp["multiple lines"] of me then
        ## Add or remove hilite
        put itemOffset(theRow, theHilitedRows) into theItemNo
        if theItemNo > 0 then
          delete item theItemNo of theHilitedRows
        else
          put theRow into item (the number of items of theHilitedRows + 1) of theHilitedRows
          ScrollRowIntoView theRow
        end if
        sort items of theHilitedRows numeric ascending

        ## At this point we want to hilite controls but not scroll them
        put theHilitedRows into sViewPropsA["hilited rows"]
        _hiliteRowsInVisibleControls
        put true into sMouseDownA["selection changed"]

        ## Update reference for shift clicking
        if theHilitedRows is empty then
          put empty into sViewPropsA["first selected row"]
        else if the number of items of theHilitedRows is 1 then
          put theRow into sViewPropsA["first selected row"]
        end if

      else if _isThisModifierSetActive("shift") and the viewProp["multiple lines"] of me then
        if sViewPropsA["first selected row"] is empty then
          ## If no first row has been logged then index becomes first index
          put theRow into sViewPropsA["first selected row"]
        end if

        ## Generate list of hilited rows
        put empty into theHilitedRows
        repeat with i = min(theRow, sViewPropsA["first selected row"]) to \
              max(theRow, sViewPropsA["first selected row"])
          put i & "," after theHilitedRows
        end repeat
        delete the last char of theHilitedRows

        sort items of theHilitedRows numeric ascending

        # Is selection list changing?
        if sMouseDownA["previously hilited rows"] is not theHilitedRows then
          put theHilitedRows into sViewPropsA["hilited rows"]
          _hiliteRowsInVisibleControls
          put true into sMouseDownA["selection changed"]
        end if

      else
        ## If clicking on a selected control then delay deselecting until mouseUp.
        ## This allows for drag/drop of multi controls.
        ## Only applies if no modifier is down or option is down as option can be used for dragging.
        if the viewProp["multiple lines"] of me and theRow is among the items of sViewPropsA["hilited rows"] AND ( _isThisModifierSetActive("") OR _isThisModifierSetActive("option-control") ) then
          put true into sViewPropsA["deselect on mouseUp"]
        else
          # We only need to select if control isn't already the selected row
          if theRow is not sViewPropsA["hilited rows"] then
            if the viewProp["select on mouseUp"] of me then
              put theControl into sViewPropsA["select on mouseUp"]
            else
              # Select in after handler
              put theControl into sMouseDownA["select control"]
            end if
          end if
        end if
      end if

    else if pMouseBtnNum is 3 then
      ## right-click only changes selection if clicking on index that isn't highlighted
      ## OR there is more than one row selected and "multiple lines" is turned off
      if theRow is not among the items of theHilitedRows \
            or (the number of items of theHilitedRows > 1 and not the viewProp["multiple lines"] of me) then
        ## Same behavior as mouseclick 1
        ## single click always inserts index into first index var
        put theRow into sViewPropsA["first selected row"]

        put theRow into sViewPropsA["hilited rows"]
        _hiliteRowsInVisibleControls

        # This is the only place we send selection changed prior to the developer getting the message
        # as the selection needs to occur prior to showing contextual menus.
        unlock screen
        _selectionChanged sMouseDownA["previously hilited rows"]
        put empty into sMouseDownA
      else
        unlock screen
        put empty into sMouseDownA
      end if
    end if
  end if

  return empty
end dvMouseDownBefore


/**
Summary: Sends the selection changed message or updates hilited rows after developer mouseDown is processed.

*/
command dvMouseDownAfter pMouseBtnNum
  if the keys of sMouseDownA is empty then exit dvMouseDownAfter

  unlock screen # Now we unlock after before handler and developer handler have finished executing.

  if sMouseDownA["select control"] is not empty then
    if there is a sMouseDownA["select control"] then
      _selectControl sMouseDownA["select control"]
    end if
  else if sMouseDownA["selection changed"] then
    _selectionChanged sMouseDownA["previously hilited rows"]
  else
    ## If the selection hasn't changed then at least update the hilites as they
    ## may be grayed out. If one day we can get a true focusIn message for the group
    ## as a whole then the 'else' condition can be removed.
    _hiliteRowsInVisibleControls
  end if
  put empty into sMouseDownA
  return empty
end dvMouseDownAfter


/**
Summary: Handles special cases where selection occurs on `mouseUp`.

*/
command dvMouseUp pMouseBtnNum
  if sViewPropsA["deselect on mouseUp"] then
    _selectControl
    put false into sViewPropsA["deselect on mouseUp"]

  else if sViewPropsA["select on mouseUp"] is not empty then
    local theControl

    # Control should handle selections in mouseUp rather than mouseDown. Usually done when drag/drop needs to happen before loading of data.
    put sViewPropsA["select on mouseUp"] into theControl
    put empty into sViewPropsA["select on mouseUp"]
    _selectControl theControl
  end if
  return empty
end dvMouseUp


/**
Summary: Handles special cases where selection occurs on `mouseUp`.

*/
on dvMouseRelease pMouseBtnNum
  put false into sViewPropsA["deselect on mouseUp"]
  return empty
end dvMouseRelease


--> Drag and Drop

/**
Summary: Sets the dragImage to a snapshot of a row.

Parameters:
pRows: The row(s) to use as the dragImage.

Returns: Error message
*/
setprop dvDragImageRow pRows
  local tControlId

  put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(item 1 of pRows)]["control"] into tControlId
  if tControlId is not empty then
    _createDragImageFromControl tControlId
    return empty
  else
    return "row control not found"
  end if
end dvDragImageRow


/**
Summary: Begins a drag-reorder operation.

Parameters:
pBoolean: True to start the operation, false to stop.

Returns: Error
*/
setprop dvTrackDragReorder pBoolean
  if pBoolean is not sDropStructure["tracking"] then
    if pBoolean then
      local theDropIndicatorGroup, theContentRect, theRect

      ## Set right away
      ## This handler will be called from dragMove most likely. This message
      ## can be fired numerous times and we want getProp dvTrackDragReorder to return true immediately.
      put true into sDropStructure["tracking"]

      DeleteFieldEditor true, "enterInField" ## close and save

      put the viewProp["drop indicator template"] of me into theDropIndicatorGroup
      if theDropIndicatorGroup is empty then
        put the long id of group "Default Drop Indicator" of stack "DataViewControlTemplate" into theDropIndicatorGroup
      end if

      put the viewProp["content window rect"] of me into theContentRect

      lock screen
      lock messages

      if there is a group 1 of group "dvDropIndicator" of me then
        delete group 1 of group "dvDropIndicator" of me
      end if

      copy theDropIndicatorGroup to group "dvDropIndicator" of me
      put it into theDropIndicatorGroup
      set the visible of group "dvDropIndicator" of me to false
      set the topLeft of theDropIndicatorGroup to item 1 to 2 of theContentRect
      put the rect of theDropIndicatorGroup into theRect
      put item 3 of theContentRect into item 3 of theRect
      unlock messages
      unlock screen
      set the rect of theDropIndicatorGroup to theRect # this will trigger resizeControl

      put the rect of theDropIndicatorGroup into sDropStructure["default drop indicator rect"]
      insert script of stack "DataView Track Drag and Drop Behavior" into front

      dvRegisterControlForDragMessages the long id of me

      ## initialize index mouse is over
      dvDragMove the mouseH, the mouseV
    else
      set the visible of group "dvDropIndicator" of me to false
      put empty into sDropStructure

      if there is a group 1 of group "dvDropIndicator" of me then
        delete group 1 of group "dvDropIndicator" of me
      end if

      if there is a image "dvDragImage" of me then
        delete image "dvDragImage" of me
      end if

      put false into sDropStructure["tracking"]
      put empty into sViewPropsA["select on mouseUp"] # this is set in dvMouseDownBefore. dvMouseUp won't be sent if a drag starts, however.
    end if
  end if

  return empty
end dvTrackDragReorder


/**
Summary: Returns a boolean value indicating whether or not drag reordering is being tracked.

Returns: Boolean
*/
getProp dvTrackDragReorder
  return sDropStructure["tracking"]
end dvTrackDragReorder


/**
Summary: Implementation of dragEnd for the view. Called from the frontscript.

Description:
Defined using `before` so that instance implementation doesn't need to worry about
passing the message.

*/
before dvDragEnd
  # Any data grid that had dvTrackDragReorder turned on during this drag event must be cleaned up.
  # Checking for presence of frontscript is necessary in situations where the user dragged content over
  # multiple DataViews during the drag operation. The frontscript only needs to be removed once.
  if the long id of stack "DataView Track Drag and Drop Behavior" is among the lines of the frontscripts then
    dvResetViewsAffectedDuringDragOperation
    remove script of stack "DataView Track Drag and Drop Behavior" from front
  end if
end dvDragEnd


/**
Summary: Implementation of dragLeave. Called from frontscript.

Description:
Check if mouse is outside of control on dragLeave. When mouse leaves window we
don't want drag indicator showing.

*/
command dvDragLeave
  if the mouseH,the mouseV is not within the viewProp["content window rect"] of me then
    _setDropIndicatorVisibility false
  end if
end dvDragLeave


/**
Summary: Implementation of dragDrop for the view. Called from the frontscript.

Description:
When dragDrop is triggered this handler will notify the view by dispatching
`AcceptRowDrop` along with the following parameters:

1. pDraggingInfoA: Array with an `action` (dragAction) key. Additional keys may have been added by the `ValidateRowDrop` command.
2. pRow: The row that the drop occurred on.
3. pDropOperation: The drop operation. `on` or `above`.

*/
on dvDragDrop
  local processTheDrop, tDropStructure

  ## Cache before we clean up
  if the dragAction is "move" AND sDropStructure["drop row"] is empty then put false into processTheDrop
  else put the dragAction is not "none" into processTheDrop  ## This works better as it takes into account dropping data onto empty view from other source.
  put sDropStructure into tDropStructure

  ## If some other control displays a dialog during dragDrop, dragMove will still be sent
  ## if the mouse moves within the dialog. We don't want to process those any longer at this point.
  dvFreezeMouseRelatedDragMessagesPriorToCleanup

  if processTheDrop then
    dispatch "AcceptRowDrop" with tDropStructure["info"], tDropStructure["drop row"], tDropStructure["drop operation"]
  end if
end dvDragDrop


/**
Summary: Implementation of dragMove for the view. Called from the frontscript.

Parameters:
pMouseH: The mouse x location as passed to dragMove.
pMouseV: The mouse y location as passed to dragMove.
pDragMoveTarget: The long id of the targte of

Description:
During dragMove this handler will calculate a proposed drop row and drop operation
based on the position of the mouse. It will then dispatch `ValidateRowDrop` to the
view and pass the following parameters:

1. pDraggingInfoA: Array with `action` (dragAction), `mouseH`, and `mouseV` keys. The `mouseH` and `mouseV` keys are the same parameters passed to `dragMove`.
2. pProposedRow: The proposed row that the drop should occur on based on the mouse vertical position.
3. pProposedDropOperation: The proposed drop operation based on the mouse vertical position. `on` or `above`.

The `ValidateRowDrop` handler can accept any of the above parameters by reference (parameter name prefixed with @)
and modify them. Modifying the proposed row and drop operation can be done if needed in order to redirect a drop.

If the drop should not occur over the proposed row then return `false` from `ValidateRowDrop`.

*/
on dvDragMove pMouseH, pMouseV, pDragMoveTarget

  ## Make sure data view control will accept drop
  if the dragSource contains the long ID of me and (the mouseControl is not empty and the long id of the mouseControl contains the long ID of me) then
    set the dragAction to "move"
  end if

  put empty into sDropStructure["drop row"]
  put empty into sDropStructure["drop operation"]

  try
    local msgsAreLocked
    local tViewRect
    local showDropIndicator = false

    put the lockMessages into msgsAreLocked

    put the viewProp["content window rect"] of me into tViewRect

    lock screen

    # Make sure that this DataView is the actual target of the message. If the user drags over multiple DataViews
    # during a drag session then this instance will get the message even if it isn't the target.
    if the mouseControl is not empty and the dvControl of the long id of the mousecontrol is the long id of me then
      local tTargetControlId

      put the dvRowControl of the mouseControl into tTargetControlId

      if tTargetControlId is not empty then
        put the short id of tTargetControlId into tTargetControlId
      else
        if pMouseV <= (item 2 of tViewRect + the viewProp["content top padding"] of me + 1) then
          # top padding area. Use first control.
          put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(item 1 of sViewPropsA["controls"]["rows in use"])]["control"] into tTargetControlId
        else
          ## Assume we are below the last control
          put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(item -1 of sViewPropsA["controls"]["rows in use"])]["control"] into tTargetControlId
        end if
      end if

      if tTargetControlId is not empty then
        # If closer to middle then operation = "on"
        # If closer to top then operation = "above"
        # If closer to bottom then + 1 and operation = "above"
        local tProposedDropOperation, tProposedRow, tOrigProposedRow
        local tControlRect, tTop, tBottom, tHeight
        local tDropIndicatorOffset

        put the dvRow of control id tTargetControlId into tProposedRow

        put tProposedRow into tOrigProposedRow

        put the rect of control id tTargetControlId into tControlRect
        put item 2 of tControlRect into tTop
        put item 4 of tControlRect into tBottom
        put tBottom - tTop into tHeight

        if pMouseV < (tTop + (tHeight/2)) then
          put "above" into tProposedDropOperation
        else if pMouseV > (tBottom - (tHeight/2)) then
          put "above" into tProposedDropOperation
          add 1 to tProposedRow
        else
          put "on" into tProposedDropOperation
        end if
      else
        put 1 into tProposedRow
        put 1 into tOrigProposedRow
        put "on" into tProposedDropOperation
        put item 2 of tViewRect + the viewProp["content top padding"] of me into tTop
        put tTop into tBottom
      end if

      put the dragAction into sDropStructure["info"]["action"]
      put pMouseH into sDropStructure["info"]["mouseH"]
      put pMouseV into sDropStructure["info"]["mouseV"]

      dispatch "ValidateRowDrop" to me with sDropStructure["info"], tProposedRow, tProposedDropOperation
      if the result is not false then
        local tX, tY

        put the dragAction into sDropStructure["info"]["action"]
        put tProposedRow into sDropStructure["drop row"]
        put tProposedDropOperation into sDropStructure["drop operation"]
        put true into showDropIndicator

        # Proposed row
        if tProposedRow is not tOrigProposedRow then
          put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(tProposedRow)]["control"] into tTargetControlId
          if tTargetControlId is not empty then
            put the rect of control id tTargetControlId into tControlRect
            put item 2 of tControlRect into tTop
            put item 4 of tControlRect into tBottom
          end if
        end if

        if tProposedDropOperation is "above" then
          put tTop into tY
        else
          put tBottom into tY
        end if

        put (item 4 of sDropStructure["default drop indicator rect"] \
              - item 2 of sDropStructure["default drop indicator rect"]) \
              / 2 div 1 into tDropIndicatorOffset ## div 1 = floor

        lock messages
        put item 1 of sDropStructure["default drop indicator rect"] into tX
        put min(item 4 of tViewRect, max(item 2 of tViewRect + tDropIndicatorOffset, tY)) into tY ## don't let outside of the List group
        put tY - tDropIndicatorOffset into tY
        set the topLeft of group "dvDropIndicator" of me to tX, tY
        unlock messages
        dispatch "PositionDropIndicator" to group 1 of group "dvDropIndicator" of me with pDragMoveTarget, sDropStructure["info"], sDropStructure["drop row"], sDropStructure["drop operation"]
        put the dragAction into sDropStructure["info"]["action"]
      else
        set the dragAction to "none"
      end if

      # No longer valid outside of this message
      delete variable sDropStructure["info"]["mouseH"]
      delete variable sDropStructure["info"]["mouseV"]
    end if

    _setDropIndicatorVisibility showDropIndicator

    set the lockMessages to msgsAreLocked
    unlock screen

  catch e
    put param(0) && "error:" && e
  end try
end dvDragMove


/**
Summary: Returns the long id of the DataView control.

*/
getProp dvControl
  return the long id of me
end dvControl


/**
Summary: Can be used to focus on or remove focus from the DataView.

Parameters:
pBoolean: `true` to focus on DataView. `false` to focus on nothing.

*/
setProp dvFocus pBoolean
  if pBoolean then
    if the long id of me is not in the long id of the focusedObject then
      focus on graphic "dvBackground" of me
    end if
  else
    focus on nothing
  end if
end dvFocus


/**
Summary: Returns whether or not a row control is currently selected.

Returns: boolean
*/
getProp dvHilite
  local theControl
  put the dvRowControl of the target into theControl
  return the dvRow of theControl is among the items of the dvHilitedRows of me
end dvHilite


/**
Summary: Alias to dvHilitedRows.

Returns: List of hilited rows.
*/
getprop dvHilitedRow
  return sViewPropsA["hilited rows"]
end dvHilitedRow


/**
Summary: Returns a list of rows that are hilited in the control.

Returns: List of hilited rows.
*/
getprop dvHilitedRows
  return sViewPropsA["hilited rows"]
end dvHilitedRows


/**
Summary: Alias to dvHilitedRows.

Parameters:
pRows: Row(s) to hilite.
pForceScroll: Will scroll the rows into view, regardless of whether or not the highlighted rows changed (unless the "scroll selections into view" property is false).

Returns: Boolean value specifying whether or not the selected rows changed.
*/
setprop dvHilitedRow[pForceScroll] pRows
  local theRowsChanged

  # This property is only set by outsiders or internal methods
  # that should update the first selected row.
  put item 1 of pRows into sViewPropsA["first selected row"]

  _setHilitedRows pRows
  put the result into theRowsChanged

  if not theRowsChanged AND pForceScroll then
    ScrollRowIntoView item 1 of pRows, the viewProp["scroll into view anchor"] of me
  end if

  return theRowsChanged
end dvHilitedRow


/**
Summary: Sets the list of rows that are hilited in the control.

Parameters:
pRows: List of rows to hilite.
pForceScroll: Will scroll the rows into view, regardless of whether or not the highlighted rows changed (unless the "scroll selections into view" property is false).

Returns: Boolean value specifying whether or not the selected rows changed.
*/
setprop dvHilitedRows[pForceScroll] pRows
  set the dvHilitedRow[pForceScroll] of me to pRows
  return the result
end dvHilitedRows


/**
Summary: Returns the control associated with a row.

Description:
This may return empty if the row is not visible and caching is not turned on.

Returns: Control reference
*/
getProp dvControlOfRow [pRow]
  if sViewPropsA["controls"]["cache"][_getCacheKeyForRow(pRow)]["control"] is not empty then
    return the long id of control id sViewPropsA["controls"]["cache"][_getCacheKeyForRow(pRow)]["control"]
  else
    return empty
  end if
end dvControlOfRow


getProp dvRowIsDirty[pRow]
  local tControlId

  put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(pRow)]["control"] into tControlId
  if there is a control id tControlId then
    local tValue

    lock messages
    put the dvIsDirty of control id tControlId into tValue
    unlock messages
    return tValue
  else
    return false
  end if
end dvRowIsDirty


setProp dvRowIsDirty[pRow] pIsDirty
  local tControlId

  put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(pRow)]["control"] into tControlId
  if there is a control id tControlId then
    lock messages
    set the dvIsDirty of control id tControlId to pIsDirty is true
    unlock messages
  end if
end dvRowIsDirty


/**
Summary: Marks all controls in the cache as dirty.

Description:
If a control is in the cache but not associated with a row then it is not
possible to mark it as dirty. This handler will mark all controls in the cache
as dirty.

Returns: nothing
*/
command MarkAllControlsAsDirty
  local tCacheKey, tControlId

  lock messages
  repeat for each key tCacheKey in sViewPropsA["controls"]["cache"]
    put sViewPropsA["controls"]["cache"][tCacheKey]["control"] into tControlId
    if tControlId is not empty then
      set the dvIsDirty of control id tControlId to true
    end if
  end repeat
  unlock messages

  return empty
end MarkAllControlsAsDirty


/**
Summary: Returns whether or not a row has been rendered. It it hasn't been rendered then it is a ghost control.

Description:
This property is useful when caching is set to "lazy".

Returns: Boolean
*/
getProp dvControlHasBeenRendered
  if the dvRowControl of the target is not empty then
    return the dvDataCache of the dvRowControl of the target is NULL
  else
    pass dvControlHasBeenRendered
  end if
end dvControlHasBeenRendered


/**
Summary: Returns all controls in the data view cache.

Description:
Returns a list of all controls that have been created for the rows in the DataView.
If `cache` is `none` this this list will only contains controls for rows that are visible.
If `cache` is `lazy` or `eager` then it will be a list of control for all rows in the
DataView.

Note that if `cache` is `lazy` then it is possible that not all controls have been
rendered yet. You can use the `dvControlHasBeenRendered` property to check whether
or not the control has been rendered.

Returns: CR delimited list of controls
*/
getProp dvRowControls
  local tControls

  repeat for each key theKey in sViewPropsA["controls"]["cache"]
    put the long id of control id sViewPropsA["controls"]["cache"][theKey]["control"] & cr after tControls
  end repeat
  delete the last char of tControls

  return tControls
end dvRowControls


/**
Summary: Padding control property. Dont allow controls outside of this DataView to return return a value for this property.

Returns: empty
*/
getProp dvPaddingControl
  return empty
end dvPaddingControl


/**
Summary: Row control property. Dont allow controls outside of this DataView to return return a value for this property.

Returns: empty
*/
getProp dvRowControl
  return empty
end dvRowControl


/**
Summary: Row control property. Dont allow controls outside of this DataView to return return a value for this property.

Returns: empty
*/
getProp dvHilite
  return empty
end dvHilite


/**
Summary: Row control property. Dont allow controls outside of this DataView to return return a value for this property.

Returns: empty
*/
setProp dvHilite pValue
  # nothing
end dvHilite


/**
Summary: Tells you whether or not the last mouse click was within the content area of the control.

Returns: Boolean
*/
getprop dvClickedWithinContentArea
  local theClickLoc

  ## Note that LiveCode doesn't report scrollbars as mousecontrol if thumb is not
  ## showing. Hence the checks for visibility and click not within of vertical scrollbar
  ## (dvlist overlaps with rect of vertical scrollbar)
  put the clickLoc into theClickLoc
  return theClickLoc is within the viewProp["content window rect"] of me \
        and (not the visible of scrollbar "dvVScrollbar" of me \
        or (the visible of scrollbar "dvVScrollbar" of me and theClickLoc is not within the rect of scrollbar "dvVScrollbar" of me))
end dvClickedWithinContentArea


/**
Summary: Returns the last row clicked on (or targeted in the case of arrowkeys or select all).

Returns: Integer
*/
getprop dvClickRow
  return sLastTargetedRow
end dvClickRow


/**
Summary: Returns the rect of a row in the view. The rect is relative ot the card.

Parameters:
pRow The row to get the rect for.

Returns: Rect
*/
getProp dvRectOfRow[pRow]
  local theRect, theVScroll

  if pRow is an integer then
    put _relativeRectOfRow(pRow) into theRect

    ## Adjust for vscroll
    put the viewProp["vscroll"] of me into theVScroll
    subtract theVScroll from item 2 of theRect
    subtract theVScroll from item 4 of theRect

    ## Now adjust for position of view on card
    add the top of group "dvListMask" of me to item 2 of theRect
    add the top of group "dvListMask" of me to item 4 of theRect
  end if

  return theRect
end dvRectOfRow


/**
Summary: Initializes the DataView.

Description:
Initializes properties the first time the control is used. Note that the mobile scroller
will be initialized everytime, regardless of whether or not `sInit` is `true`. That is because
the mobile scroller needs to be cleaned up in `closeControl` but then recreated when the control
is used again. There is no guaranteed entry point (messages could be locked)
so `_init` is called from multiple places.

If the control has already been initialized then return value is `true`.
Otherwise it is `false`.

Returns: Boolean
*/
private command _init
  # Rect can change without the resizeControl being notified (e.g. setting the topleft)
  # Update the model so that the rect is always up to date when rendering.
  put _workingGroupRect(the long id of me) into sWorkingGroupRect

  if sInit then
    _initMobileScroller
    return true
  end if

  put true into sInit

  set the opaque of me to false
  set the showname of me to false
  set the hscrollbar of me to false
  set the vscrollbar of me to false
  set the dropShadow of me to empty
  set the innerShadow of me to empty
  set the outerGlow of me to empty
  set the innerGlow of me to empty
  set the colorOverlay of me to empty

  if the buildnumber >= 15500 then // 9.5dp-1
    set the layermode of me to "container"
    set the layermode of control "dvBackground" of me to "dynamic"
    set the layermode of group "dvListMask" of me to "container"
    set the layermode of group "dvList" of me to "container"
    set the layermode of group "dvDropIndicator" of me to "dynamic"
    set the layerMode of control "dvVScrollbar" of me to "dynamic"
  end if

  switch the platform
    case "Win32"
      if "registryRead" is among the items of the securityPermissions then
        local theValue

        put queryRegistry("HKEY_CURRENT_USER\Control Panel\Colors\HilightText") into sSystemA["hilited text color"]
        if sSystemA["hilited text color"] is not empty then
          replace space with comma in sSystemA["hilited text color"]
        end if
        put queryRegistry("HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics\ScrollWidth") into theValue
        if theValue is an integer then
          put abs(theValue/15) into sSystemA["scrollbarWidth"]
        end if
      end if

      break
  end switch

  # Initialize all templates
  # Note: this occurs every time an instance of a data view is opened.
  local theTemplatesA

  put the viewProp["row style templates"] of me into theTemplatesA
  repeat for each key theKey in theTemplatesA
    if there is a theTemplatesA[theKey] then
      dispatch "InitializeTemplate" to theTemplatesA[theKey]
    end if
  end repeat

  _setScrollbarWidth
  _initMobileScroller
  put "community.livecode.trevordevore.macosscrollwheel" is among the lines of the loadedExtensions \
        into sUseEventsForScroll

  return false
end _init


/**
Summary: Creates a mobile scroller on mobile platforms.

Returns: nothing
*/
private command _initMobileScroller
  if the environment is "mobile" and \
        (sScrollerID is empty or sScrollerID is not among the lines of mobileControls()) then
    set the visible of scrollbar "dvVScrollbar" of me to false
    _createMobileScroller
  end if
end _initMobileScroller


/**
Summary: Looks for the next row in the view that can be selected.

Parameters:
pStartingRow: The row to start searching from. The first searched row will be +1 or -1 from this row.
pDirection: "up" searches -1, "down" searchs + 1. This mimics arrows keys in the list.

Description:
This handler checks the `dvCanSelect` property of row controls until it finds
one that is not `false`.

Returns: Row
*/
private function _nextSelectableRow pStartingRow, pDirection
  local i, theAnimSetting

  switch pDirection
    case "down"
      repeat with i = pStartingRow + 1 to the viewProp["number of rows"] of me
        if there is not a the dvControlOfRow[i] of me then
          put the viewProp["animate selections"] of me into theAnimSetting
          set the viewProp["animate selections"] of me to false
          _scrollRow i
          set the viewProp["animate selections"] of me to theAnimSetting
        end if

        if the dvCanSelect of (the dvControlOfRow[i] of me) is not false then
          return i
        end if
      end repeat
      break
    case "up"
      repeat with i = pStartingRow - 1 down to 1
        if there is not a the dvControlOfRow[i] of me then
          put the viewProp["animate selections"] of me into theAnimSetting
          set the viewProp["animate selections"] of me to false
          _scrollRow i
          set the viewProp["animate selections"] of me to theAnimSetting
        end if

        if the dvCanSelect of (the dvControlOfRow[i] of me) is not false then
          return i
        end if
      end repeat
      break
  end switch

  return pStartingRow
end _nextSelectableRow


/**
Summary: Dispatchs the selectedRowChanged message to the behavior instance.

Parameters:
pPreviouslyHilitedRows The list of rows that were hilited prior to the selection changing.

*/
private command _selectionChanged pPreviouslyHilitedRows
  dispatch "selectedRowChanged" with sViewPropsA["hilited rows"], pPreviouslyHilitedRows
  return empty
end _selectionChanged


/**
Summary: Selects a control, stores it as the first one clicked on and brings focus into view.

Parameters:
pControl Reference to control clicked on. It empty then default is dvRowControl.

Returns: empty
*/
private command _selectControl pControl
  local theRow
  local thePreviouslyHilitedRows

  if pControl is empty then put the dvRowControl of the target into pControl
  if pControl is not empty then
    put the dvRow of pControl into theRow
    put sViewPropsA["hilited rows"] into thePreviouslyHilitedRows

    ## single click always inserts index into first index var
    put theRow into sViewPropsA["first selected row"]
    _setHilitedRows theRow

    ## Clicked on a control
    if the long ID of me is not in the long ID of the focusedObject then
      focus on graphic "dvBackground" of me
    end if

    _selectionChanged thePreviouslyHilitedRows
  end if

  return empty
end _selectControl


/**
Summary: Sets the list of hilited rows for the control, hilites the controls and scrolls the first one into view.

Parameters:
pRows List of rows to hilite.

Returns: Boolean value indicating whether or not hilited row changed.
*/
private command _setHilitedRows pRows
  local theRows, theTotalRows, theRow
  local theReturnValue

  ## Standardize order
  sort items of pRows numeric ascending

  lock screen

  ## cleanse input
  put the viewProp["number of rows"] of me into theTotalRows
  if theTotalRows > 0 then
    repeat for each item theProspectiveRow in pRows
      if theProspectiveRow > 0 then
        put max(1, min(theProspectiveRow, theTotalRows)) into theRow
        if theRow is not among the items of theRows then
          put theRow & "," after theRows
        end if
      end if
    end repeat
    delete the last char of theRows
  end if

  put theRows is not sViewPropsA["hilited rows"] into theReturnValue

  ## Only scroll into view if not already the highlighted row
  put theRows into sViewPropsA["hilited rows"]
  if the viewProp["scroll selections into view"] of me is not false and theReturnValue then
    if item 1 of sViewPropsA["hilited rows"] is an integer then
      ScrollRowIntoView item 1 of sViewPropsA["hilited rows"], the viewProp["scroll into view anchor"] of me
    end if
  end if

  _hiliteRowsInVisibleControls

  unlock screen

  return theReturnValue
end _setHilitedRows


/**
Summary: Returns the rect of a row in relative space

Parameters:
pRow The row to get the rect for.

Returns: Rect
*/
private function _relativeRectOfRow pRow
  local theRect

  local theContentHeight, theControlHeight, theRowWidth, theIndex
  local updateViewHeight = "false"

  put 0 into item 1 of theRect
  put the viewProp["content width"] of me into item 3 of theRect
  put item 1 of _workingTopAndBottomContentCoordinates() into theContentHeight

  ## Determine top and bottom of control
  if the viewProp["fixed row height"] of me then
    put theContentHeight + ((pRow - 1) * the viewProp["row height"] of me) into item 2 of theRect
    put theContentHeight + (pRow * the viewProp["row height"] of me) into item 4 of theRect

  else if the viewProp["cache"] of me is "none" then

    put item 3 of theRect into theRowWidth

    ## Random sized controls
    repeat with theRow = 1 to the viewProp["number of rows"] of me
      if sViewPropsA["controls"]["control height cache"][theRow] is NULL then
        put kDefaultForNonCachedVariableHeightRows into theControlHeight
      else
        put sViewPropsA["controls"]["control height cache"][theRow] into theControlHeight
      end if

      add theControlHeight to theContentHeight

      if pRow is theRow then
        put theContentHeight - theControlHeight  into item 2 of theRect
        put theContentHeight into item 4 of theRect
        exit repeat
      end if
    end repeat

  else
    local theCacheKey

    put item 3 of theRect into theRowWidth

    ## Random sized controls
    repeat with theRow = 1 to the viewProp["number of rows"] of me
      ## Control must be resized if it hasn't loaded yet.
      put _getCacheKeyForRow(theRow) into theCacheKey
      _prepareRowForDisplay theRow, sViewPropsA["controls"]["cache"][theCacheKey]["control"], theRowWidth
      if not updateViewHeight then put the result into updateViewHeight

      add sViewPropsA["controls"]["cache"][theCacheKey]["height"] to theContentHeight

      if pRow is theRow then
        put theContentHeight - sViewPropsA["controls"]["cache"][theCacheKey]["height"] into item 2 of theRect
        put theContentHeight into item 4 of theRect

        if updateViewHeight then
          _configureScrollbars
        end if

        exit repeat
      end if
    end repeat
  end if

  return theRect
end _relativeRectOfRow


/**
Summary: Returns the topleft of a control relative to another control.

Parameters:
pObj: The target object.
pRelativeToObj: Returned topleft point will be relative to this object.

Returns: point
*/
private function _relativeTopLeft pObj, pRelativeToObj
  local tAnchorTopLeft, tTopLeft

  put the topleft of pRelativeToObj into tAnchorTopLeft
  put the topleft of pObj into tTopLeft
  return item 1 of tTopLeft - item 1 of tAnchorTopLeft & "," & \
        item 2 of tTopLeft - item 2 of tAnchorTopLeft
end _relativeTopLeft


/**
Summary: Scrolls a row into view.

Parameters:
pRow: The row to scroll.
pPlacement: empty, `top` or `bottom`.
pForceScroll: Pass in true along with `pPlacement` to force a row to top or bottom.

Returns: Error
*/
private command _scrollRow pRow, pPlacement, pForceScroll
  local theError, theMaskHeight, theOffset, theMaskRect, controlIsTallerThanMask
  local theRect, theTopOfControl, theBottomOfControl
  local theNewVScroll

  if pRow is not an integer then return "invalid row" --throw "invalid row passed to" && param(0)
  put pForceScroll is true into pForceScroll

  ## Work off of a 0 based rect, not actual position on card
  put the viewProp["content window height"] of me into theMaskHeight
  put round(the thumbPosition of scrollbar "dvVScrollbar" of me) into theOffset -- round needed for engine bug
  put "0," & theOffset & ",0," & theMaskHeight + theOffset into theMaskRect

  if theError is empty then
    # repeat as the heights of rows may change as we scroll them into view.
    # This will change the rect of the row we are targeting.
    # Note that this only applies when caching is off and fixed row height is false.
    lock screen

    repeat forever
      put _relativeRectOfRow(pRow) into theRect

      put item 2 of theRect into theTopOfControl
      put item 4 of theRect into theBottomOfControl

      put item 4 of theRect - item 2 of theRect >= item 4 of theMaskRect - item 2 of theMaskRect into controlIsTallerThanMask

      ## If row is off the top then scroll to top of group
      ## else if row is off the bottom then scroll to the bottom

      ## We lock messages so no scrollbarDrag message is sent. scrollbarDrag may use a slight delay when
      ## drawing so that fast scrolling doesn't cue up redraws. We bypass the message
      ## and call _ScrollListV directly so that screen is updated immediately regardless of how
      ## scrollbarDrag is finally implemented.

      -- ======================
      local scrollTheList = "false"

      # If control is at least as tall as mask then match up top or bottom, depending on which is visible.
      if (theTopOfControl <= item 2 of theMaskRect AND theBottomOfControl >= item 4 of theMaskRect) \
            OR (theTopOfControl >= item 2 of theMaskRect AND theBottomOfControl <= item 4 of theMaskRect) then
        # nothing, entire row is already visible
      else if controlIsTallerThanMask then
        # If bottom is in view then scroll to bottom.
        # Otherwise scroll to top.
        if theBottomOfControl >= item 2 of theMaskRect AND theBottomOfControl <= item 4 of theMaskRect then
          put theBottomOfControl - theMaskHeight into theNewVScroll
          put true into scrollTheList
        else
          put theTopOfControl into theNewVScroll
          put true into scrollTheList
        end if
      else
        ## control is off the top of view OR top edge is clipped off
        if theBottomOfControl <= item 2 of theMaskRect or theTopOfControl < item 2 of theMaskRect then
          put theTopOfControl into theNewVScroll
          put true into scrollTheList
        else
          ## control is off the bottom of view or bottom edge is clipped off
          put theBottomOfControl - theMaskHeight into theNewVScroll
          put true into scrollTheList
        end if
      end if

      if scrollTheList OR pForceScroll then
        # Force vscroll if value is passed in.
        if pPlacement is "top" then
          put theTopOfControl into theNewVScroll
        else if pPlacement is "bottom" then
          put theBottomOfControl - theMaskHeight into theNewVScroll
        end if

        if the viewProp["animate selections"] of me and sPendingMsgsA["UpdateScrollAnimation"] is empty then
          unlock screen
          _startScrollAnimation theNewVScroll
          exit repeat
        else
          local msgsAreLocked

          _cancelAnimation
          put the lockMessages into msgsAreLocked
          lock messages
          set the thumbPosition of scrollbar "dvVScrollbar" of me to theNewVScroll
          set the lockMessages to msgsAreLocked

          _setVScrollForPlatform theNewVScroll

          # Use bottom to determine if control has made it into place. The bottom
          # is what will change if control is resized.
          if item 4 of _relativeRectOfRow(pRow) is item 4 of theRect then
            unlock screen
            exit repeat
          else
            # Loop through again, calculating a new rect.
            # Note that this only applies when caching is off and row height is not fixed.
            --                  put "repeating..." && _relativeRectOfRow(pRow) && "::" && theRect & cr after msg
            --                  wait 10 milliseconds
          end if
        end if

      else
        unlock screen
        exit repeat
      end if

    end repeat # ensure row gets into view.
  end if

  return theError
end _scrollRow


private function _topIsVisible pRect, pMaskRect
  return item 2 of pRect < item 4 of pMaskRect and item 2 of pRect > item 2 of pMaskRect
end _topIsVisible


private function _bottomIsVisible pRect, pMaskRect
  return item 4 of pRect > item 2 of pMaskRect and item 4 of pRect < item 4 of pMaskRect
end _bottomIsVisible


private function _rectIsAtLeastAsTallAsMask pRect, pMaskRect
  return item 4 of pRect - item 2 of pRect >= item 4 of pMaskRect - item 2 of pMaskRect
end _rectIsAtLeastAsTallAsMask


private function _rectCoversMask pRect, pMaskRect
  return _rectIsAtLeastAsTallAsMask(pRect, pMaskRect) and \
        item 2 of pRect <= item 2 of pMaskRect and \
        item 4 of pRect >= item 4 of pMaskRect
end _rectCoversMask


private function _topIsClipped pRect, pMaskRect
  return item 4 of pRect > item 2 of pMaskRect and item 2 of pRect < item 2 of pMaskRect
end _topIsClipped


private function _bottomIsClipped pRect, pMaskRect
  return item 2 of pRect < item 4 of pMaskRect and item 4 of pRect > item 4 of pMaskRect
end _bottomIsClipped

private function _topAndBottomAreClipped pRect, pMaskRect
  return item 2 of pRect >= item 4 of pMaskRect or item 4 of pRect <= item 2 of pMaskRect
end _topAndBottomAreClipped


/**
Summary: Loops through the visible controls ("rows in use") and turns highlighting on/off as appropriate.

Returns: empty
*/
private command _hiliteRowsInVisibleControls
  local msgsAreLocked, tRow, tBoolean, tControlId

  lock screen
  put the lockMessages into msgsAreLocked
  set the lockMessages to false
  set the wholeMatches to true

  repeat for each item tRow in sViewPropsA["controls"]["rows in use"]
    put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(tRow)]["control"] into tControlId

    if tControlId is not empty then
      put tRow is among the items of sViewPropsA["hilited rows"] into tBoolean
      _hiliteControl tControlId, tBoolean
    end if
  end repeat

  set the lockMessages to msgsAreLocked
  unlock screen

  return empty
end _hiliteRowsInVisibleControls


/**
Summary: Turns the hilite for a control on/off.

Parameters:
pControlId: Id of control.
pBoolean: Whether or not to turn hilite on.

Returns: empty
*/
private command _hiliteControl pControlId, pBoolean
  local tRow, tColor
  local msgsAreLocked, tIsHilited

  put the lockMessages into msgsAreLocked

  lock messages
  put the dvHiliteState of control id pControlId into tIsHilited
  if tIsHilited is not pBoolean then
    # Store as prop of control
    set the dvHiliteState of control id pControlId to pBoolean
  end if
  unlock messages

  if tIsHilited is not pBoolean then
    if there is a control "Background" of control id pControlId then
      if pBoolean then
        put _getHiliteColor() into tColor
      else
        set the wholeMatches to true
        put the dvRow of control id pControlId into tRow
        if tRow mod 2 is kAlternatingRowModValue then
          put _getEffectiveColor("alternate row color") into tColor
        else
          put _getEffectiveColor("row color") into tColor
        end if
      end if

      if the backgroundColor of control "Background" of control id pControlId is not tColor then
        set the backgroundColor of control "Background" of control id pControlId to tColor
      end if
    else
      if pBoolean then
        put _getHiliteColor() into tColor
      else
        put _getEffectiveColor("row color") into tColor
      end if
    end if

    set the dvHilite [tColor] of control id pControlId to pBoolean
  end if

  set the lockMessages to msgsAreLocked

  return empty
end _hiliteControl


private command _resetHiliteSettingOnControl pControlId
  local msgsAreLocked
  put the lockmessages into msgsAreLocked
  lock messages
  set the dvHiliteState of control id pControlId to empty
  set the lockmessages to msgsAreLocked
end _resetHiliteSettingOnControl


private function _getHiliteColor
  local theColor

  --   put the long id of me & cr & the long id of the focusedObject & cr & the executioncontexts
  if the long ID of me is not in the long ID of the focusedObject and the viewProp["dim on focusOut"] of me is not false then
    put _getEffectiveColor("dimmed hilite color") into theColor
    put the viewProp["dimmed hilite color"] of me into theColor
    if theColor is empty then
      put kDefaultDimmedHiliteColor into theColor
    end if
  else
    put the viewProp["hilite color"] of me into theColor
    if theColor is empty then
      put the hiliteColor into theColor
    end if
  end if
  return theColor
end _getHiliteColor


private function _getEffectiveColor pProperty
  local msgsAreLocked, theColor, theHiliteColor, theAvg

  put the lockMessages into msgsAreLocked
  lock messages
  put the viewProp[pProperty] of me into theColor
  set the lockMessages to msgsAreLocked

  if theColor is not a color then
    switch pProperty
      case "row color"
        return kRowColor
        break
      case "alternate row color"
        if the viewProp["alternate row colors"] of me then
          return kAlternateRowColor
        else
          return _getEffectiveColor("row color")
        end if
        break
      case "dimmed hilite color"
        return kDefaultDimmedHiliteColor
        break
      case "hilite color"
        return the hiliteColor
        break
      case "hilited text color"
        if sViewPropsA["system"]["hilited text color"] is a color \
              and not (the long ID of me is not in the long ID of the focusedObject \
              and the viewProp["dim on focusOut"] of me is not false) then
          return sViewPropsA["system"]["hilited text color"]
        else
          -- Check the RGB values of the hiliteColor; add them
          -- up and average them - if the result >128 then show black text, and if it's
          -- <=128 then show white text. (Thanks Ken)
          put _getHiliteColor("hilite color") into theHiliteColor
          if the number of items of theHiliteColor is not 3 then put _colorToRGB(theHiliteColor) into theHiliteColor
          put item 1 of theHiliteColor + item 2 of theHiliteColor + item 3 of theHiliteColor into theAvg
          put round(theAvg / 3) into theAvg
          if theAvg > 128 then return "0,0,0"
          else return "255,255,255"
        end if
        break
    end switch
  else
    return theColor
  end if
end _getEffectiveColor


private function _colorToRGB pColor
  if pColor is a color then
    if the number of items of pColor is not 3 then
      local theGraphic, theOrigColor

      lock screen
      put the long ID of graphic "dvBackground" of me into theGraphic
      put the backColor of theGraphic into theOrigColor
      set the backColor of theGraphic to pColor
      set the backpixel of theGraphic to the effective backpixel of theGraphic
      put the backColor of theGraphic into pColor
      set the backColor of theGraphic to theOrigColor
      unlock screen
    end if
  end if

  return pColor
end _colorToRGB



/**
Summary: Tells you whether the provided list of modifier keys are depressed.

Parameters:
pModifiers: List of keys to check. Any combination of `shift`, `option`, `command`, `control` or `option-control`.

Description:
`option-control` will check for option on macos and control on other platforms.
Use this for copy operations.

Returns: true/false
*/
private function _isThisModifierSetActive pModifiers
  local theState

  replace "alt" with "option" in pModifiers

  set the wholeMatches to true

  put the optionKey into theState
  if "option" is among the items of pModifiers or ("option-control" is among the items of pModifiers and the platform is "macos") then
    if theState is "up" then
      return false
    end if
  else if theState is "down" then
    return false
  end if

  put the shiftKey into theState
  if "shift" is among the items of pModifiers then
    if theState is "up" then
      return false
    end if
  else if theState is "down" then
    return false
  end if

  if the platform is "macos" then
    put the commandKey into theState
    if "command" is among the items of pModifiers then
      if theState is "up" then
        return false
      end if
    else if theState is "down" then
      return false
    end if

    put the controlKey into theState
    if "control" is among the items of pModifiers then
      if theState is "up" then
        return false
      end if
    else if theState is "down" then
      return false
    end if
  else
    put the commandKey into theState
    if "command" is among the items of pModifiers or "control" is among the items of pModifiers or "option-control" is among the items of pModifiers then
      if theState is "up" then
        return false
      end if
    else if theState is "down" then
      return false
    end if
  end if

  return true
end _isThisModifierSetActive


private function _getContentWindowHeight
  return item 4 of sWorkingGroupRect - item 2 of sWorkingGroupRect
end _getContentWindowHeight


/**
Summary: Internal helper which renders the data in the view using the current vscroll.

Parameters:
pRefreshDataInCachedControls If false and caching is on then cached controls will not have data updated. Only non-existent controls will be added to the cache. This can speed things up when refreshing due to row order changing.

Returns: empty
*/
private command _renderView pRefreshDataInCachedControls
  local msgsAreLocked, theFocusedObject, tSelChunk

  ## Throttle
  if sViewPropsA["running actions"]["render"] then
    put true into sViewPropsA["running actions"]["resend render"]
    put pRefreshDataInCachedControls into sViewPropsA["running actions"]["resend render param"]
    return empty
  end if
  put true into sViewPropsA["running actions"]["render"]

  put pRefreshDataInCachedControls is not false into pRefreshDataInCachedControls

  # Make sure control is initialized and reset the view if it hasn't been.
  _init
  if not the result then
    ResetView
  end if

  lock screen

  put the lockMessages into msgsAreLocked
  if the long id of me is in the focusedObject then
    put the focusedObject into theFocusedObject
    if word 1 of theFocusedObject is "field" then
      put the selectedChunk into tSelChunk
      # Create a reference that won't break as controls are relayered
      put "control id" && the short id of theFocusedObject into word -2 to -1 of tSelChunk
    end if
    lock messages
    focus on nothing
  end if
  unlock messages

  # Make sure field editor doesn't disappear
  if sViewPropsA["fld_editor"]["control"] is not empty then
    put the dvRowCacheKey of control id sViewPropsA["fld_editor"]["control"] into sViewPropsA["fld_editor"]["relinkToCacheKey"]
    put _relativeTopLeft(the long id of control id sViewPropsA["fld_editor"]["control"], \
            the dvRowControl of control id sViewPropsA["fld_editor"]["control"]) into sViewPropsA["fld_editor"]["topleft"]
    relayer control id sViewPropsA["fld_editor"]["control"] to back of group "dvListMask" of me
  end if

  put the viewProp["number of rows"] of me into sNumRowsTempCache

  ## Cache controls based on settings
  if the viewProp["cache"] of me is among the items of "eager,lazy" then
    _updateControlCacheForActiveRange 0, 0 # This cleans up the current rows in use
    _syncCacheKeyToRowMappings false
    _cacheControls pRefreshDataInCachedControls # This caches the controls, creating as needed, and associating them with a row.
  else if not the viewProp["fixed row height"] of me then
    _updateControlCacheForActiveRange 0, 0
    _initializeHeightsForVariableSizedRows
  else
    _updateControlCacheForActiveRange 0, 0
  end if

  _insertPaddingControl

  ## Start from scratch
  put empty into sViewPropsA["controls"]["rows in use"]

  ## Resize all controls right away if "eager"
  # TODO: [Optimization] When resizing for the first time we should look for auto hide scrollbars.
  #       Once height gets above view height then turn scrollbars on (if need be) and start sizing over).
  if the viewProp["cache"] of me is "eager" then
    _resizeControls
  end if

  _calculateContentHeight

  local theVscroll

  ## Make sure vscroll is in bounds
  put max(0, min(the viewProp["vscroll"] of me, the viewProp["content height"] of me - _getContentWindowHeight())) into theVscroll

  lock messages
  set the viewProp["vscroll"] of me to theVscroll
  unlock messages

  RenderVisibleRows

  lock messages

  # If edit field wasn't linked to new row control then silently delete.
  if sViewPropsA["fld_editor"]["relinkToCacheKey"] is not empty and there is a field kFieldEditorName of group "dvListMask" of me then
    delete field kFieldEditorName of group "dvListMask" of me
    delete variable sViewPropsA["fld_editor"]
    put empty into tSelChunk
  end if

  _configureScrollbars ## It is possible that this call is redundant as RenderVisibleRows may call it. No big deal though.

  # If focus was in data view prior to start then refocus now if it still exists.
  if theFocusedObject is not empty then
    if there is a theFocusedObject then
      if tSelChunk is not empty then
        select tSelChunk
      else
        focus on theFocusedObject
      end if
    else
      focus on graphic "dvBackground" of me
    end if
  end if

  unlock messages

  # 2015-12-21: Added so we could move objects along with the DataView.
  dispatch "DataViewDidUpdateView" to me

  unlock screen

  put empty into sNumRowsTempCache

  set the lockMessages to msgsAreLocked

  put false into sViewPropsA["running actions"]["render"]

  if sViewPropsA["running actions"]["resend render"] then
    get sViewPropsA["running actions"]["resend render param"]
    send "__runRenderViewAgain it" to me in 0 milliseconds
    put false into sViewPropsA["running actions"]["resend render"]
    put empty into sViewPropsA["running actions"]["resend render param"]
  end if

  return empty
end _renderView


command __runRenderViewAgain pRefreshDataInCachedControls
  _renderView pRefreshDataInCachedControls
end __runRenderViewAgain


/**
Summary: Fills in starting values for heights for all rows when row heights are not fixed and caching is not on.

Description:
Currently each row is seeded with a NULL value. This helps us determine which ones have
been sized and which ones haven't.
*/
private command _initializeHeightsForVariableSizedRows
  local theRow

  dispatch function "HeightsForRows" to me
  if it is "handled" then
    # developer should have returned an array with keys for each row. The value is height of row.
    put the result into sViewPropsA["controls"]["control height cache"]
    if sViewPropsA["controls"]["control height cache"] is not an array then
      # If not an array then 0 rows or developer handled but didn't return a valid value.
      # Fill in with NULL below.
      put empty into it
    end if
  end if

  if it is not "handled" then
    repeat with theRow = 1 to the viewProp["number of rows"] of me
      put NULL into sViewPropsA["controls"]["control height cache"][theRow]
    end repeat
  end if

  return empty
end _initializeHeightsForVariableSizedRows


/**
Summary: Handles cleanup of a control based on cache setting.
*/
private command _cleanupControl pCacheKey, pRow, pControlId, pDeleteInTime
  if the viewProp["cache"] of me is not among the items of "eager,lazy" then
    _moveControlIntoUnusedCachePool pCacheKey, pRow # this sends cleanup message
  else
    # Send message to control telling it to clean up after itself
    if there is a control id pControlId then
      dispatch "CleanupAfterControl" to control id pControlId

      lock messages
      if the long id of control id pControlId is in the focusedObject then
        focus on graphic "dvBackground" of me ## engine doesn't like the focused control in a group being deleted
      end if

      if not pDeleteInTime then
        delete control id pControlId
      else
        set the visible of control id pControlId to false
        send "__deleteRowControl pControlId" to me in 0 seconds
      end if
      unlock messages
    end if

    delete local sViewPropsA["controls"]["row cache keys"][pRow] # break link between row and cache key
    delete local sViewPropsA["controls"]["cache"][pCacheKey]
  end if

  return empty
end _cleanupControl


command __deleteRowControl pControlId
  local msgsAreLocked

  put the lockmessages into msgsAreLocked
  lock messages
  if there is a control id pControlId then delete control id  pControlId
  set the lockmessages to msgsAreLocked
end __deleteRowControl


/**
Summary: Makes sure that the "hilited rows" and "first selected row" are in bounds for how many rows are in view.

Description:
This is useful after internal operations which might remove rows from the view.
*/
private command _ensureIntegrityOfSelectedRows
  local theRowCount

  # Make sure hilited rows don't extend beyong what is left.
  put the viewProp["number of rows"] of me into theRowCount
  repeat with i = the number of items of sViewPropsA["hilited rows"] down to 1
    if item i of sViewPropsA["hilited rows"] > theRowCount then
      delete item i of sViewPropsA["hilited rows"]
    end if
  end repeat

  if sViewPropsA["first selected row"] is not empty \
        AND sViewPropsA["first selected row"] is not among the items of sViewPropsA["hilited rows"] then
    put item 1 of sViewPropsA["hilited rows"] into sViewPropsA["first selected row"]
  end if

  return empty
end _ensureIntegrityOfSelectedRows


/**
Summary: Moves the control for an index back into the list of available controls.

Parameters:
pCacheKey: The cache key of the control to move back to to the cache of available controls.
pRow: Pass in the row to dissassociate the row with the the cache key.

Returns: empty
*/
private command _moveControlIntoUnusedCachePool pCacheKey, pRow
  local tControlId, theItemNo, removeFromCache

  put sViewPropsA["controls"]["cache"][pCacheKey]["control"] into tControlId
  if there is a control id tControlId then
    _hideRowControl tControlId

    # Send message to control telling it to clean up after itself
    dispatch "CleanupAfterControl" to control id tControlId

    ## Move back into pool of available controls
    if the viewProp["cache"] of me is "none" then
      put empty into sViewPropsA["controls"]["available"][tControlId]
    end if

    # Reset the dvHiliteState of the control so that dvHilite is initialized next time control is used.
    _resetHiliteSettingOnControl tControlId
  end if

  delete local sViewPropsA["controls"]["cache"][pCacheKey]
  if pRow is an integer then
    delete local sViewPropsA["controls"]["row cache keys"][pRow] # break link
  end if

  return empty
end _moveControlIntoUnusedCachePool


private command _hideRowControl pControlId
  dispatch "HideControl" to control id pControlId
  set the visible of control id pControlId to false
end _hideRowControl


/**
Summary: Sets the values for scrollbars based on the content in the control.

Description:
This handler will maintain the current thumbposition of the scrollbar value.

Returns: empty
*/
private command _configureScrollbars
  local msgsAreLocked, theWindowHeight
  local theEndValue, thePageIncrement
  local theVScroll

  put _getContentWindowHeight() into theWindowHeight
  put max(theWindowHeight, the viewProp["content height"] of me) into theEndValue

  if the endValue of scrollbar "dvVScrollbar" of me is not theEndValue or theWindowHeight is not the thumbsize of scrollbar "dvVScrollbar" of me then
    ## If messages are not locked then scrollbarDrag is sent when group height is increased.
    put the lockMessages into msgsAreLocked
    lock messages

    lock screen

    # 2013-02-21: Switched to using vscroll. It was possible for this handler
    # to be called without the thumbposition being in right place. We probably shouldn't
    # be using the UI anyway. Use the model data.
    put the viewProp["vscroll"] of me into theVScroll
    --      put the thumbposition of scrollbar "dvVScrollbar" of me into theVScroll

    ## Setting thumbsize 2nd is important because engine limits thumbsize based on endValue
    set the thumbposition of scrollbar "dvVScrollbar" of me to 0
    set the endValue of scrollbar "dvVScrollbar" of me to theEndValue
    set the thumbsize of scrollbar "dvVScrollbar" of me to theWindowHeight

    put theWindowHeight into thePageIncrement
    --   if the viewProp["fixed row height"] of me and the viewProp["row height"] of me is an integer then subtract the viewProp["row height"] of me from thePageIncrement
    --   else subtract 16 from thePageIncrement ## Why 16? Why not.
    set the pageIncrement of scrollbar "dvVScrollbar" of me to thePageIncrement

    if the viewProp["fixed row height"] of me and the viewProp["row height"] of me is an integer then
      set the lineIncrement of scrollbar "dvVScrollbar" of me to the viewProp["row height"] of me
    else
      # TODO: Should this value be the average of the current content height?
      set the lineIncrement of scrollbar "dvVScrollbar" of me to round(thePageIncrement / 16)
    end if

    ## Make sure this syncs with new value. Just don't broadcast it.
    put min(theVScroll, theEndValue - theWindowHeight) into theVScroll
    set the viewProp["vscroll"] of me to theVScroll

    set the lockMessages to msgsAreLocked
    ## Whether or not message is sent is dependent on current message lock
    set the thumbposition of scrollbar "dvVScrollbar" of me to theVScroll

    unlock screen

    _setMobileScrollerContentRect
  end if

  return empty
end _configureScrollbars


private command _setVScrollForPlatform pValue
  if sScrollerID is not empty then
    mobileControlSet sScrollerID, "vScroll", pValue
  else
    _setVScroll pValue
  end if

  return empty
end _setVScrollForPlatform


private command _setVScroll pValue
  local msgsAreLocked, refocusOnMe, theOrigThumb
  local refocusOnFieldEditor = "false"

  ## Should we enable this for Lion as well?
  if the environment is not "mobile" then
    put max(0, min(pValue, the viewProp["content height"] of me - _getContentWindowHeight())) into pValue
  end if

  put the lockMessages into msgsAreLocked

  lock messages
  if pValue is the viewProp["vscroll"] of me then
    set the lockMessages to msgsAreLocked
    exit _setVScroll
  end if

  ## First set the vscroll and draw
  put the long id of me is in the focusedObject into refocusOnMe
  unlock messages
  if refocusOnMe and the viewProp["field editor is open"] of me then
    put true into refocusOnFieldEditor
  end if

  lock screen

  ## If an editor is present and focused then we don't want to close it when focus leaves.
  if refocusOnFieldEditor then
    lock messages
    focus on nothing
  end if

  lock messages
  set the viewProp["vscroll"] of me to pValue
  unlock messages

  # If nothing has breen drawn yet then don't do anything.
  if sViewPropsA["controls"]["row cache keys"] is an array then
    put the thumbsize of scrollbar "dvVScrollbar" of me into theOrigThumb
    RenderVisibleRows
    if the result then # content height changed
      # adjust value and call again
      put pValue + (the thumbsize of scrollbar "dvVScrollbar" of me - theOrigThumb) into pValue
      set the lockMessages to msgsAreLocked
      _setVScroll pValue
      exit _setVScroll
    end if
  end if

  lock messages
  set the thumbposition of scrollbar "dvVScrollbar" of me to pValue
  unlock messages

  if refocusOnFieldEditor and there is a control id sViewPropsA["fld_editor"]["control"] then
    ## Bring focus back to the field editor but don't send any messages
    lock messages
    focus on control id sViewPropsA["fld_editor"]["control"]
  else if refocusOnMe then
    set the dvFocus of me to true ## We like to keep focus
  end if

  unlock messages

  # 2015-12-21: Added so we could move objects along with the DataView.
  dispatch "DataViewDidUpdateView" to me

  unlock screen
  set the lockMessages to msgsAreLocked
end _setVScroll


/**
Summary: Returns the percentage of the vscroll thumb.

Returns: percentage.
*/
private function _getVScrollPercent
  local theWorkingEndValue

  put the endValue of scrollbar "dvVScrollbar" of me - the thumbSize of scrollbar "dvVScrollbar" of me into theWorkingEndValue
  if theWorkingEndValue > 0 then
    return round(the thumbPosition of scrollbar "dvVScrollbar" of me) / theWorkingEndValue
  else
    return 0
  end if
end _getVScrollPercent


/**
Summary: Returns the percentage of the vscroll thumb.

Parameters:
pPercent The percentage to set the vscroll to.

Returns: percentage.
*/
private command _setVScrollPercent pPercent
  local theWorkingEndValue
  put the endValue of scrollbar "dvVScrollbar" of me - the thumbSize of scrollbar "dvVScrollbar" of me into theWorkingEndValue
  _setVScrollForPlatform round(theWorkingEndValue * pPercent)
end _setVScrollPercent


/**
Summary: Returns the cache key in sViewPropsA["controls"]["cache"] for a given row.

Parameters:
pRow: The row to get the key for.
pRefreshKey: If true then a fresh key will be retrieved for the row. Otherwise an internal cache may be used.

Returns: Key or empty if no control is cached for the specified row.
*/
private function _getCacheKeyForRow pRow, pRefreshKey
  if pRow is not an integer then
    return empty
  else
    local theCacheKey

    put pRefreshKey is true into pRefreshKey

    if not pRefreshKey then
      put sViewPropsA["controls"]["row cache keys"][pRow] into theCacheKey
    end if

    if theCacheKey is empty then
      put _dispatchCacheKeyForRow(pRow) into theCacheKey
    end if

    if theCacheKey is among the keys of sViewPropsA["controls"]["cache"] then
      put theCacheKey into sViewPropsA["controls"]["row cache keys"][pRow]
      return theCacheKey
    else
      return empty
    end if
  end if
end _getCacheKeyForRow


/**
Summary: Syncs up cache keys and the corresponding control with rows. Only applies if caching is on.

Parameters:
pRemoveStaleCacheKeys: If true then stale caches will be removed. Default is false.

Description:
Refreshes the mapping between rows and the corresponding cache key. This will ask the
data source for the cache keys for all rows and then update the mapping between rows and
cache keys.

If pRemoveStaleCacheKeys is true then any cache keys that are mapped to a control but which
no longer are associated with a row will be cleared out, along with the associated control.

Returns: empty
*/
private command _syncCacheKeyToRowMappings pRemoveStaleCacheKeys
  local refreshKeys

  set the wholematches to true

  put the viewProp["cache"] of me is among the items of "eager,lazy" into refreshKeys
  put pRemoveStaleCacheKeys is true into pRemoveStaleCacheKeys

  if refreshKeys then
    local theRow, theControl, theCacheKeys, theCacheKey

    # Make a list of cache keys, one per line
    repeat with theRow = 1 to the viewProp["number of rows"] of me
      put _dispatchCacheKeyForRow(theRow) & cr after theCacheKeys
    end repeat
    delete the last char of theCacheKeys

    # look for stale keys
    if pRemoveStaleCacheKeys then
      local tCacheKey

      repeat for each key theRow in sViewPropsA["controls"]["row cache keys"]
        # Check for match between old row cache key and new row cache key
        if line theRow of theCacheKeys is not sViewPropsA["controls"]["row cache keys"][theRow] then

          # Now check if cache key is in new list at all
          if sViewPropsA["controls"]["row cache keys"][theRow] is not among the lines of theCacheKeys then

            # Nope. Clean out the cache key entry.
            put sViewPropsA["controls"]["row cache keys"][theRow] into tCacheKey
            _cleanupControl tCacheKey, theRow, sViewPropsA["controls"]["cache"][tCacheKey]["control"], true
          end if
        end if
      end repeat
    end if

    # Update cache keys
    delete local sViewPropsA["controls"]["row cache keys"]

    put 0 into theRow
    repeat for each line theCacheKey in theCacheKeys
      add 1 to theRow
      put theCacheKey into sViewPropsA["controls"]["row cache keys"][theRow]
    end repeat
  end if

  return empty
end _syncCacheKeyToRowMappings


/**
Summary: Looks to see if a control needs to be filled in with data (ghost controls) or resized and then peforms necessary actions.

Parameters:
pRow: The row number of the control.
pRowControlId: The id of the row control.
pRowWidth: The width to assign to the row if it must be resized.
pTopLeft: Optional point to set the topleft of the control to.

Returns: Boolean. True if control was updated. False otherwise.
*/
private command _prepareRowForDisplay pRow, pRowControlId, pRowWidth, pTopLeft
  local controlWasUpdated = "false"
  local msgsAreLocked, tRowCacheKey

  ## Always update
  put the lockMessages into msgsAreLocked
  lock messages
  if pTopLeft is a point then set the topleft of control id pRowControlId to pTopLeft
  set the dvRow of control id pRowControlId to pRow
  put _getCacheKeyForRow(pRow) into tRowCacheKey

  if the dvDataCache of control id pRowControlId is not NULL then
    local theDataA

    ## Ghost control
    put the dvDataCache of control id pRowControlId into theDataA
    unlock messages
    dispatch "FillInData" to control id pRowControlId with theDataA, pRow

    lock messages
    set the dvDataCache of control id pRowControlId to NULL
    _restoreEditorFieldToControl tRowCacheKey, pRowControlId
    unlock messages

    _dispatchLayoutControl pRowControlId, pRow, pRowWidth, true
    put true into controlWasUpdated
  else
    if the dvIsDirty of control id pRowControlId then
      unlock messages
      _setupRowControl pRow, pRowControlId, true
    else
      _restoreEditorFieldToControl tRowCacheKey, pRowControlId
    end if

    ## Regular control
    if sViewPropsA["controls"]["cache"][tRowCacheKey]["resize"] or the dvIsDirty of control id pRowControlId then
      unlock messages
      _dispatchLayoutControl pRowControlId, pRow, pRowWidth, true
      put true into controlWasUpdated
    end if

    lock messages
    set the dvIsDirty of control id pRowControlId to false
    unlock messages
  end if

  set the lockMessages to msgsAreLocked

  return controlWasUpdated
end _prepareRowForDisplay


/**
Summary: Returns the combined height of cached controls.

Description:
If a control has not been cachdd yet then kDefaultForNonCachedVariableHeightRows is used for the height.

Returns: integer
*/
private function _getTotalCachedHeight
  local tTotal, tKey

  repeat for each key tKey in sViewPropsA["controls"]["control height cache"]
    if sViewPropsA["controls"]["control height cache"][tKey] is NULL then add kDefaultForNonCachedVariableHeightRows to tTotal
    else add sViewPropsA["controls"]["control height cache"][tKey] to tTotal
  end repeat

  return tTotal
end _getTotalCachedHeight


/**
Summary: Determines the "content height" based on current properties and data.

Returns: empty
*/
private command _calculateContentHeight pRefreshHeight
  local msgsAreLocked
  local theContentHeight = 0

  put the lockMessages into msgsAreLocked
  set the lockMessages to false

  if the viewProp["fixed row height"] of me then
    set the viewProp["content height"] of me to (the viewProp["number of rows"] of me * max(0, the viewProp["row height"] of me)) \
          + the viewProp["content top padding"] of me + the viewProp["content bottom padding"] of me

  else if the viewProp["cache"] of me is "none" then
    repeat with theRow = 1 to the viewProp["number of rows"] of me
      if sViewPropsA["controls"]["control height cache"][theRow] is NULL then
        add kDefaultForNonCachedVariableHeightRows to theContentHeight
      else
        add sViewPropsA["controls"]["control height cache"][theRow] to theContentHeight
      end if
    end repeat
    set the viewProp["content height"] of me to theContentHeight \
          + the viewProp["content top padding"] of me + the viewProp["content bottom padding"] of me

  else # caching is on and not fixed height
    _storeContentHeightForCachedControls
  end if

  ## Auto-hide
  _autoHideScrollbars

  set the lockMessages to msgsAreLocked

  return empty
end _calculateContentHeight


private command _storeContentHeightForCachedControls
  local theRow, theContentHeight="0"

  repeat with theRow = 1 to the viewProp["number of rows"] of me
    add sViewPropsA["controls"]["cache"][_getCacheKeyForRow(theRow)]["height"] to theContentHeight
  end repeat
  set the viewProp["content height"] of me to theContentHeight \
        + the viewProp["content top padding"] of me + the viewProp["content bottom padding"] of me
end _storeContentHeightForCachedControls


/**
Summary: Hides/shows the scrollbars as appropriate.

*/
private command _autoHideScrollbars
  local msgsAreLocked

  put the lockMessages into msgsAreLocked
  set the lockMessages to false

  ## Auto-hide
  if the viewProp["autohide scrollbars"] of me AND the environment is not "mobile" then
    local tRight

    if the viewProp["content height"] of me <= _getContentWindowHeight() then
      ## hide
      if the visible of scrollbar "dvVScrollbar" of me then
        set the visible of scrollbar "dvVScrollbar" of me to false
        put the right of group "dvList" of me into tRight
        _resizeSupportingControls

        # "content right padding" may place content in location where showing
        # the scrollbar doesn't affect how content is drawn.
        if tRight is not the right of group "dvList" of me then
          _resizeRowControlsAsNeeded
        end if
      end if
    else
      ## show
      if not the visible of scrollbar "dvVScrollbar" of me then
        set the visible of scrollbar "dvVScrollbar" of me to true
        put the right of group "dvList" of me into tRight
        _resizeSupportingControls

        if tRight is not the right of group "dvList" of me then
          _resizeRowControlsAsNeeded
        end if
      end if
    end if
  end if

  set the lockMessages to msgsAreLocked

  return empty
end _autoHideScrollbars


/**
Summary: Inserts controls into the padding areas of the DataView.

Returns: nothing
*/
private command _insertPaddingControl
  local msgsAreLocked, tControl

  if there is not a group "dvTopPaddingContent" of me then
    put the lockMessages into msgsAreLocked
    lock messages

    put the viewProp["top padding template"] of me into tControl
    if there is a tControl then

      copy tControl to group "dvListMask" of me
      set the name of it to "dvTopPaddingContent"
      relayer it after group "dvList" of me
      unlock messages
      dispatch "FillInData" to it

      _resizePaddingControl
    end if

    set the lockMessages to msgsAreLocked
  end if
end _insertPaddingControl


/**
Summary: Caches controls for all rows in the view.

Parameters:
pRefreshDataInCachedControls: If true and caching is on then cached controls will not have data updated. Only non-existent controls will be added to the cache. This can speed things up when refreshing due to row order changing.

Description:
How controls are cached is dependent on the 'cache' setting.
If 'cache' is set to `eager` then all rows are cached with FillInData being sent to them.
If 'cache' is set to `lazy` then a ghost control is cached meaning
that no FillInData message is sent.

Returns: empty
*/
private command _cacheControls pRefreshDataInCachedControls
  local theRowCount, theRow
  local msgsAreLocked, tControlId

  put pRefreshDataInCachedControls is not false into pRefreshDataInCachedControls
  put the lockMessages into msgsAreLocked

  unlock messages
  put the viewProp["number of rows"] of me into theRowCount

  lock messages

  ## Create row controls
  repeat with theRow = 1 to theRowCount
    ## Is there a cached control for this row?
    put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(theRow)]["control"] into tControlId

    # Get out early if not updating data
    if not pRefreshDataInCachedControls AND tControlId is not empty then
      # control may have a text editor open
      _hideRowControl tControlId
      next repeat
    end if

    ## If tControlId is not empty then it will be refreshed with latest data.
    ## If it is empty then a control will be provided.
    _setupRowControl theRow, tControlId
    put the result into tControlId

    if tControlId is not empty then
      _hideRowControl tControlId
    end if
  end repeat

  set the lockMessages to msgsAreLocked

  return empty
end _cacheControls


/**
Summary: Sets up a control for a row. Data will be filled in or cached with control based on 'cache' property.

Parameters:
pRow: Row to set up control for.
pRowControlId: If id is passed in then control used as the row control and data within it is updated. Otherwise one is provided. Passing it in is used when refreshing cached controls with new data.
pForceFillInData: Pass in true to force FillInData to be sent, even if lazy caching is set. Used if you are definitly about to display the row.

Returns: Control reference
*/
private command _setupRowControl pRow, pRowControlId, pForceFillInData
  local theDataA
  local theStyle, cacheTheControl

  ## Implemented by instance of behavior
  dispatch "DataForRow" to me with pRow, theDataA, theStyle

  if theStyle is empty then put "default" into theStyle

  # Is style of row changing?
  if pRowControlId is not empty and the dvTemplateStyle of control id pRowControlId is not theStyle then
    _cleanupControl _getCacheKeyForRow(pRow), pRow, pRowControlId, true
    put empty into pRowControlId
  end if

  put pRowControlId is empty into cacheTheControl

  if pRowControlId is empty then
    put _getControlIdOfStyle(theStyle) into pRowControlId
  end if

  if pRowControlId is not empty then
    if cacheTheControl then
      _cacheRowControl pRow, pRowControlId
    end if

    ## If fixed row height then lock it in
    if the viewProp["fixed row height"] of me then
      set the height of control id pRowControlId to the viewProp["row height"] of me
    end if

    ## Lock the size
    set the lockLoc of control id pRowControlId to true

    local msgsAreLocked
    put the lockMessages into msgsAreLocked
    lock messages
    set the dvRow of control id pRowControlId to pRow
    set the dvTemplateStyle of control id pRowControlId to theStyle
    _resetHiliteSettingOnControl pRowControlId
    unlock messages

    if the viewProp["cache"] of me is not "lazy" OR pForceFillInData then
      dispatch "FillInData" to control id pRowControlId with theDataA, pRow
      lock messages
      set the dvDataCache of control id pRowControlId to NULL
    else ## "lazy"
      ## Just create a "ghost" control.
      ## Store data with control. It will be loaded in later as needed
      lock messages
      set the dvDataCache of control id pRowControlId to theDataA
    end if

    _restoreEditorFieldToControl _getCacheKeyForRow(pRow), pRowControlId

    set the lockMessages to msgsAreLocked
  end if

  return pRowControlId
end _setupRowControl


/**
Summary: Restores the editor field to the proper row control. Used when refreshing view.

Parameters:
pRowCacheKey: The cache key of the the row template.
pParentControlId: The id of the row template that will become the parent of the editor field.

Returns: nothing
*/
private command _restoreEditorFieldToControl pRowCacheKey, pParentControlId
  if pRowCacheKey is not empty and sViewPropsA["fld_editor"]["relinkToCacheKey"] is pRowCacheKey then
    relayer control id sViewPropsA["fld_editor"]["control"] to front of control id pParentControlId
    set the topleft of control id sViewPropsA["fld_editor"]["control"] to \
          the left of control id pParentControlId + item 1 of sViewPropsA["fld_editor"]["topleft"], \
          the top of control id pParentControlId + item 2 of sViewPropsA["fld_editor"]["topleft"]
    delete variable sViewPropsA["fld_editor"]["topleft"]
    delete variable sViewPropsA["fld_editor"]["relinkToCacheKey"]
  end if
end _restoreEditorFieldToControl


/**
Summary: Resets the dvHiliteState property of all cached controls.

Description:
When resizing the DataGrid dvHilite should be called again. Resetting the
custom property ensures that it will.

Returns: nothing
*/
private command _resetHiliteStateInCachedControls
  local tIndex

  repeat for each key tIndex in sViewPropsA["controls"]["cache"]
    set the dvHiliteState of control id sViewPropsA["controls"]["cache"][tIndex]["control"] to empty
  end repeat

  return empty
end _resetHiliteStateInCachedControls


/**
Summary: Resizes (or marks as needing resizing) all controls after the list area is resized.

Returns: empty
*/
private command _resizeRowControlsAsNeeded
  switch the viewProp["cache"] of me
    case "eager"
      _resizeControls
      _storeContentHeightForCachedControls
      break
    case "lazy"
    default
      local tIndex

      ## Mark them all as dirty
      repeat for each key tIndex in sViewPropsA["controls"]["cache"]
        put true into sViewPropsA["controls"]["cache"][tIndex]["resize"]
      end repeat
      break
  end switch

  return empty
end _resizeRowControlsAsNeeded


/**
Summary: Resizes the list controls. Use this handler to resize necessary controls after showing/hiding scrollbars.

Returns: empty
*/
private command _resizeSupportingControls
  local tRect

  put sWorkingGroupRect into tRect

  add max(0, the viewProp["content left padding"] of me) to item 1 of tRect
  subtract max(0, the viewProp["content right padding"] of me) from item 3 of tRect

  # Account for scrollbar if content height exceeds working group height
  if the environment is not "mobile" and the viewProp["content height"] of me > (item 4 of tRect - item 2 of tRect) then
    put min(the left of scrollbar "dvVScrollbar" of me, item 3 of tRect) into item 3 of tRect
  end if

  set the rect of group "dvListMask" of me to tRect
  set the rect of group "dvList" of me to tRect

  if there is a group "dvTopPaddingContent" of me then
    _resizePaddingControl
  end if

  return empty
end _resizeSupportingControls


private command _resizePaddingControl
  local tPaddingRect
  put the rect of group "dvTopPaddingContent" of me into tPaddingRect
  put item 3 of sWorkingGroupRect into item 3 of tPaddingRect

  # This control should get the `resizeControl` message.
  unlock messages
  set the rect of group "dvTopPaddingContent" of me to tPaddingRect
  lock messages
end _resizePaddingControl


/**
Summary: Resizes controls by adjusting their width and calling LayoutControl.

Parameters:
pStartRow First row in range of rows to resize. Default is 1.
pEndrow: Last row in range of rows to resize. Default is number of rows.

Returns: empty
*/
private command _resizeControls pStartRow, pEndRow
  if sViewPropsA["controls"]["cache"] is an array then
    local msgsAreLocked, theWidth, tControlId, theRow

    put the lockMessages into msgsAreLocked
    unlock messages

    if pStartRow is not an integer then put 1 into pStartRow
    if pEndRow is not a integer then put the viewProp["number of rows"] of me into pEndRow

    put the viewProp["content width"] of me into theWidth

    repeat with theRow = pStartRow to pEndRow
      put sViewPropsA["controls"]["cache"][_getCacheKeyForRow(theRow)]["control"] into tControlId
      _dispatchLayoutControl tControlId, theRow, theWidth
    end repeat

    set the lockMessages to msgsAreLocked
  end if

  return empty
end _resizeControls


/**
Summary: Resizes the width of a control and sends the LayoutControl message. The control will maintain it's current topleft position.

Parameters:
pRowControlId: The id of the control to send the message to.
pRow: The row of the control.
pWidth: The width to set pRowControl to.
pUpdateContentHeight: Pass in true to update the `content height` after calling `LayoutControl`. This is only applicable if `fixed row height` is false.

Description:
The LayoutControl handler is responsible for setting the proper height of the row control.

Returns: empty
*/
private command _dispatchLayoutControl pRowControlId, pRow, pWidth, pUpdateContentHeight
  local theRect, theVScroll, theIndex, theCacheKey, theResult
  local theHeight, msgsAreLocked

  if the viewProp["fixed row height"] of me then put false into pUpdateContentHeight

  put the lockMessages into msgsAreLocked
  lock messages
  put the rect of control id pRowControlId into theRect
  put item 1 of theRect + pWidth into item 3 of theRect
  set the rect of control id pRowControlId to theRect
  unlock messages

  put _getCacheKeyForRow(pRow) into theCacheKey

  set the lockUpdates of control id pRowControlId to kLockUpdatesSetting
  dispatch "LayoutControl" to control id pRowControlId with theRect, pRow
  put the result into theResult
  put false into sViewPropsA["controls"]["cache"][theCacheKey]["resize"]
  set the lockUpdates of control id pRowControlId to false

  if not the viewProp["fixed row height"] of me AND theResult is not "do not resize" then
    ## When we set up control we locked the height. We need to update the height now.
    local tBorderWidth = 0
    if the showBorder of control id pRowControlId then
      put the borderWidth of control id pRowControlId into tBorderWidth
    end if

    put the rect of control id pRowControlId into theRect
    put item 2 of theRect + the formattedHeight of control id pRowControlId - tBorderWidth into item 4 of theRect
    set the rect of control id pRowControlId to theRect
    put item 4 of theRect - item 2 of theRect into theHeight
  else
    put the height of control id pRowControlId into theHeight
  end if

  if pUpdateContentHeight then
    ## subtract existing height before adding new height
    if sViewPropsA["controls"]["control height cache"][pRow] is an integer then
      set the viewProp["content height"] of me to the viewProp["content height"] of me - max(0, sViewPropsA["controls"]["control height cache"][pRow])
    else if sViewPropsA["controls"]["cache"][theCacheKey]["height"] is an integer then
      set the viewProp["content height"] of me to the viewProp["content height"] of me - max(0, sViewPropsA["controls"]["cache"][theCacheKey]["height"])
    end if
  end if

  put theHeight into sViewPropsA["controls"]["cache"][theCacheKey]["height"]

  # if caching is not on and no fixed row height then store height in lookup table
  if "control height cache" is among the keys of sViewPropsA["controls"] then
    put sViewPropsA["controls"]["cache"][theCacheKey]["height"] \
          into sViewPropsA["controls"]["control height cache"][pRow]
  end if

  if pUpdateContentHeight then
    set the viewProp["content height"] of me to the viewProp["content height"] of me + sViewPropsA["controls"]["cache"][theCacheKey]["height"]
  end if

  set the lockMessages to msgsAreLocked

  return empty
end _dispatchLayoutControl


/**
Summary: Dispatches the `CacheKeyForRow` message. If unhandled then the row number is returned.

Parameters:
pRow: The row to get the cache key for.

Returns: Cache key
*/
private function _dispatchCacheKeyForRow pRow
  local theCacheKey

  # TODO: is this reliable? What if user renders view again? Will the cache update?
  # I don't think so.

  # This must be handled for views that can rearrange rows.
  dispatch function "CacheKeyForRow" with pRow
  if it is "handled" then
    put the result into theCacheKey
    if theCacheKey is empty then
      return pRow
    else
      return theCacheKey
    end if
  else
    # This is fine for views that never change order.
    return pRow
  end if
end _dispatchCacheKeyForRow


/**
Summary: Stores a control in the cache for a row, removing the control from the pool of available controls.

Parameters:
pRow: The row to cache the control for.
pControlId: The id of the control to cache.

Returns: empty
*/
private command _cacheRowControl pRow, pControlId
  local i, theCacheKey, theOffsetRow

  set the wholeMatches to true

  put _dispatchCacheKeyForRow(pRow) into theCacheKey

  if pControlId is among the keys of sViewPropsA["controls"]["available"] then
    delete local sViewPropsA["controls"]["available"][pControlId]
    if the keys of sViewPropsA["controls"]["available"] is empty then
      delete local sViewPropsA["controls"]["available"]
    end if
  end if

  ## Store control in cache
  put pControlId into sViewPropsA["controls"]["cache"][theCacheKey]["control"]
  put true into sViewPropsA["controls"]["cache"][theCacheKey]["resize"]
  put the height of control id pControlId into sViewPropsA["controls"]["cache"][theCacheKey]["height"]

  # if caching is not on and no fixed row height then store height in lookup table
  if "control height cache" is among the keys of sViewPropsA["controls"] then
    put sViewPropsA["controls"]["cache"][theCacheKey]["height"] \
          into sViewPropsA["controls"]["control height cache"][pRow]
  end if

  return empty
end _cacheRowControl


/*
Summary: Returns the working top/bottom that will show content. Padding has been taken out.

Returns: top x, bottom x
*/
private function _workingTopAndBottomContentCoordinates
  local theWindowHeight, theTopPadding, theBottomPadding

  put _getContentWindowHeight() into theWindowHeight
  put max(0, the viewProp["content top padding"] of me) into theTopPadding
  put max(0, the viewProp["content bottom padding"] of me) into theBottomPadding

  return min( theTopPadding, theWindowHeight - 1) & "," & \
        the viewProp["content height"] of me - min(theBottomPadding, theWindowHeight - 1)
end _workingTopAndBottomContentCoordinates


/**
Summary: Determines the range of rows to show based on the current vscroll setting.

Parameters:
@rStartRow: Output contains the row to start on.
@rEndRow: Output contains the row to end on.
@rStartRowYOffset: Output contains the y offset for the first row from the top of the container group. <= 0.

Description:
If `fixed row height` is false then controls will be resized in this handler.

Returns: empty
*/
private command _getRangeOfRowsToDisplay @rStartRow, @rEndRow, @rStartRowYOffset
  local theRowCount, theVScroll, theAdditionalHeight
  local theContentHeight, theRowWidth, recalculateHeight, theIndex

  put the viewProp["number of rows"] of me into theRowCount

  if theRowCount < 1 then
    put 0 into rStartRow
    put 0 into rEndRow
    put 0 into rStartRowYOffset
    return empty
  end if

  -- vscroll / (outside world content - window height) = percentage
  -- vscroll = 23
  -- row height = 10
  -- window height = 100
  -- outside world height = 240

  if the viewProp["fixed row height"] of me then
    local theNumberOfVisibleRows

    -- vscroll div row height = rStartRow
    -- vscroll mod row height = rStartRowYOffset
    -- rStartRow + (window height / row height) = rEndRow
    -- if rStartRowYOffset < 0 then add 1 to rEndRow
    put the viewProp["vscroll"] of me into theVScroll ## may be negative if "bouncing" is supported
    --         put max(0, the viewProp["vscroll"] of me) into theVSCroll
    if theVSCroll < 0 then put abs(theVSCroll) into theAdditionalHeight

    put max(0, theVSCroll - item 1 of _workingTopAndBottomContentCoordinates()) div the viewProp["row height"] of me + 1 into rStartRow

    if theVScroll < item 1 of _workingTopAndBottomContentCoordinates() then
      put -(item 1 of _workingTopAndBottomContentCoordinates() - theVScroll) into rStartRowYOffset
      put (the viewProp["content window height"] of me + rStartRowYOffset + theAdditionalHeight) div the viewProp["row height"] of me into theNumberOfVisibleRows
      if the viewProp["content window height"] of me mod the viewProp["row height"] of me > 0 then
        add 1 to theNumberOfVisibleRows
      end if
    else
      put (theVSCroll - item 1 of _workingTopAndBottomContentCoordinates()) mod the viewProp["row height"] of me into rStartRowYOffset
      put (the viewProp["content window height"] of me + rStartRowYOffset + theAdditionalHeight) div the viewProp["row height"] of me into theNumberOfVisibleRows
      if the viewProp["content window height"] of me mod the viewProp["row height"] of me > 0 then
        add 1 to theNumberOfVisibleRows
      end if
    end if

    ## Make sure we have enough controls to scroll
    put min(theRowCount, rStartRow + theNumberOfVisibleRows) into rEndRow
    if rStartRowYOffset < 0 then
      add 1 to rEndRow
    end if

    put min(rEndRow, the viewProp["number of rows"] of me) into rEndRow

  else if the viewProp["cache"] of me is "none" then # not fixed height but not cached
    local theContentWindowHeight, theTopOfLastControl, theControlHeight

    put the viewProp["content window height"] of me into theContentWindowHeight

    ## The outer repeat loop is in case the height changes while trying to figure out the rows
    ## to display. If it does then we start everything over and recalculate.
    repeat forever
      put the viewProp["content width"] of me into theRowWidth ## this can change if scrollbar is shown/hidden!!!
      put empty into rStartRow
      put empty into rEndRow
      put empty into recalculateHeight
      put empty into theTopOfLastControl
      put item 1 of _workingTopAndBottomContentCoordinates() into theContentHeight
      put empty into rStartRowYOffset
      put the viewProp["vscroll"] of me into theVSCroll

      repeat with theRow = 1 to theRowCount
        -- rStartRow = last control that is <= vscroll
        -- rEndRow = control right after control that exceeds content window height
        -- rStartRowYOffset = vscroll - top of rStartRow

        put theContentHeight into theTopOfLastControl

        # We use the default height if none has been set,
        # unless the start row has been determined. In that case
        # we size the control and get actual height.
        put sViewPropsA["controls"]["control height cache"][theRow] into theControlHeight

        # NOTE: This code won't run again if 'recalculate the height' is true.

        if theControlHeight is NULL then
          if rStartRow is not empty OR (rStartRow is empty AND theContentHeight+kDefaultForNonCachedVariableHeightRows > theVScroll) then
            # PrepareRow will resize and adjust "content height". Will subtract current height so make sure it is added in.
            if sViewPropsA["controls"]["control height cache"][theRow] is NULL then
              set the viewProp["content height"] of me to the viewProp["content height"] of me - kDefaultForNonCachedVariableHeightRows
            else
              set the viewProp["content height"] of me to the viewProp["content height"] of me - sViewPropsA["controls"]["control height cache"][theRow]
            end if
            _setupRowControl theRow
            set the viewProp["content height"] of me to the viewProp["content height"] of me + sViewPropsA["controls"]["control height cache"][theRow]

            # Need to resize before we recalculate height
            _prepareRowForDisplay theRow, sViewPropsA["controls"]["cache"][_getCacheKeyForRow(theRow)]["control"], theRowWidth
            if recalculateHeight is empty and the result is true then put true into recalculateHeight

            put sViewPropsA["controls"]["control height cache"][theRow] into theControlHeight
          else
            put kDefaultForNonCachedVariableHeightRows into theControlHeight
          end if
        end if

        add theControlHeight to theContentHeight

        if rStartRow is empty then
          ## First fill in the starting row
          if theContentHeight > theVScroll then
            put theRow into rStartRow
            put theVScroll - theTopOfLastControl into rStartRowYOffset
            put 0 into theContentHeight -- reset as rest of controls must be as tall as content window so first control can scroll off.
          end if
        else
          if theContentHeight >= theContentWindowHeight then
            put theRow into rEndRow
            exit repeat
          end if
        end if
      end repeat ## loop through rows

      ## If height has to be recalculated then run the operation again
      if recalculateHeight then
        _calculateContentHeight
        set the lockMessages to true
        _configureScrollbars
        set the lockMessages to false
      else
        exit repeat
      end if
    end repeat

  else
    local theCacheKey

    --      put the milliseconds into theStartTime
    # It is expected that controls have been cached at this point.

    put the viewProp["content window height"] of me into theContentWindowHeight

    ## The outer repeat loop is in case the height changes while trying to figure out the rows
    ## to display. If it does then we start everything over and recalculate.
    repeat forever
      put the viewProp["content width"] of me into theRowWidth ## this can change if scrollbar is shown/hidden!!!
      put empty into rStartRow
      put empty into rEndRow
      put empty into recalculateHeight
      put empty into theTopOfLastControl
      put empty into rStartRowYOffset
      --         put max(0, the viewProp["vscroll"] of me) into theVSCroll # removed for ios "bounce" effect.
      put the viewProp["vscroll"] of me into theVSCroll
      put item 1 of _workingTopAndBottomContentCoordinates() into theContentHeight

      ## Efficiency Notes:
      ## This takes longer and longer as you scroll to the bottom of the view.
      ## Thoughts on optimization:
      ## What about moving _PreparRowForDisplay out of this command. Any row
      ## prepration should be done prior to calling this so that it can be throttled.
      ## Rows would only be resized as they were scrolled into view.
      ## To optimize we need to not set the "resize" flag for all controls in ResizeToFit.
      ## Rather we set the flag on all visible controls. Set flag on all controls AFTER we
      ## determine which rows to display.

      repeat with theRow = 1 to theRowCount
        -- rStartRow = last control that is <= vscroll
        -- rEndRow = control right after control that exceeds content window height
        -- rStartRowYOffset = vscroll - top of rStartRow

        put theContentHeight into theTopOfLastControl
        put _getCacheKeyForRow(theRow) into theCacheKey
        if theCacheKey is empty then exit repeat ## caching hasn't occured yet. Maybe ResizeToFit was called before initializing and developer passed in bad row count?

        ## Take into account ghost or controls that need to be resized
        _prepareRowForDisplay theRow, sViewPropsA["controls"]["cache"][theCacheKey]["control"], theRowWidth
        if recalculateHeight is empty and the result is true then put true into recalculateHeight

        put sViewPropsA["controls"]["cache"][theCacheKey]["height"] into theControlHeight
        add theControlHeight to theContentHeight

        if rStartRow is empty then
          ## First fill in the starting row
          if theContentHeight > theVScroll then
            put theRow into rStartRow
            put theVScroll - theTopOfLastControl into rStartRowYOffset
            put 0 into theContentHeight -- reset as rest of controls must be as tall as content window so first control can scroll off.
          end if
        else
          if theContentHeight >= theContentWindowHeight then
            put theRow into rEndRow
            exit repeat
          end if
        end if
      end repeat ## loop through rows

      ## If height has to be recalculated then run the operation again
      if recalculateHeight then
        _calculateContentHeight
        set the lockMessages to true
        _configureScrollbars
        set the lockMessages to false
      else
        exit repeat
      end if
    end repeat

    --      put the short name of me && "timer:" && the milliseconds - theStartTime & cr after fld "log"
  end if

  if theRowCount > 0 then
    if rStartRow is empty then
      put 1 into rStartRow # a good starting number
    end if
    if rEndRow is empty then
      put theRowCount into rEndRow
    end if
  end if

  return empty
end _getRangeOfRowsToDisplay


/**
Summary: Syncs the list of active controls based on a new start and end row.

Parameters:
pStartRow: The first row that should not be removed from the cache.
pEndRow: The last row that should not be removed from the cache.

Description:
If `cache` is `none` then two checks are performed against controls that are
actively in use (`sViewPropsA["controls"]["row cache keys"]`):

1. Is row control is associated with still part of new active range?
2. If still in range does it's `type` match the `type` of the row it will now be associated with?

If the answer to either condition is `false` then controls are moved out
of the active list of controls and into `sViewPropsA["controls"]["available"]`.

If `cache` is turned on then any controls outside of the new active range are
hidden.

`rows in use` will be updated after this handler finishes running.

Returns: empty
*/
private command _updateControlCacheForActiveRange pStartRow, pEndRow
  local theCacheSetting, theCacheKey, theCacheKeys, theRow, tControlId
  local theRowIndexA

  set the wholeMatches to true

  put the viewProp["cache"] of me into theCacheSetting

  # Make a list of cache keys for row range, one per line
  if pStartRow > 0 then
    repeat with theRow = pStartRow to pEndRow
      put _dispatchCacheKeyForRow(theRow) & cr after theCacheKeys
    end repeat
    delete the last char of theCacheKeys
  end if

  local theOffset = 0
  if pStartRow > 0 then put pStartRow - 1 into theOffset

  # Behavior when caching is on is different than when it is not on.
  if the viewProp["cache"] of me is "none" then
    local theEffectiveRow

    # Move through all rows currently in the cache.
    # If outside range then move into bin.
    # If inside range then check if cache key for row matches. If not move out of service.
    repeat for each key theRow in sViewPropsA["controls"]["row cache keys"]
      put sViewPropsA["controls"]["row cache keys"][theRow] into theCacheKey

      # Out of range
      if theRow < pStartRow or theRow > pEndRow then

        _moveControlIntoUnusedCachePool theCacheKey, theRow

      else

        # Check for match between old row cache key and new row cache key
        put theRow - theOffset into theEffectiveRow
        if line theEffectiveRow of theCacheKeys is not sViewPropsA["controls"]["row cache keys"][theRow] then
          _moveControlIntoUnusedCachePool theCacheKey, theRow
        end if

      end if
    end repeat

  else # caching is on

    # Hide any controls that are visible that are no longer in range.
    repeat for each item theRow in sViewPropsA["controls"]["rows in use"]
      put sViewPropsA["controls"]["row cache keys"][theRow] into theCacheKey

      # Out of range
      if theRow < pStartRow or theRow > pEndRow then

        put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into tControlId

        try
          if the visible of control id tControlId then
            _hideRowControl tControlId
          end if
        catch e
          put param(0) & cr & e
        end try

      end if
    end repeat
  end if

  ## Rebuild `rows in use` using new range
  put empty into sViewPropsA["controls"]["rows in use"]
  if pStartRow > 0 then
    repeat with theRow = pStartRow to pEndRow
      put theRow & "," after sViewPropsA["controls"]["rows in use"]
    end repeat
    delete the last char of sViewPropsA["controls"]["rows in use"]
  end if

  return empty
end _updateControlCacheForActiveRange


/**
Summary: Returns a control of the given style.

Parameters:
pStyle: The style of the control to return.

Description:
If a control with a matching style exists in the "available" list then it will be returned.
Otherwise a new control will be created.

Returns: Control reference.
*/
private function _getControlIdOfStyle pStyle
  local tControlId

  put _findAvailableControlOfStyle(pStyle) into tControlId

  if tControlId is empty then
    local theTemplatesA, theTemplate

    put the viewProp["row style templates"] of me into theTemplatesA
    put theTemplatesA[pStyle] into theTemplate
    if there is not a theTemplate then
      throw "DataView Error:" && quote & pStyle & quote && "does not have a valid template defined. Template:" && quote & theTemplate & quote
    else
      local msgsAreLocked
      put the lockMessages into msgsAreLocked
      lock messages
      copy theTemplate to group "dvList" of me
      put the short id of it into tControlId
      if the buildnumber >= 15500 then // 9.5dp-1
        set the opaque of control id tControlId to false
        set the showborder of control id tControlId to false
        set the showname of control id tControlId to false
        set the hscrollbar of control id tControlId to false
        set the vscrollbar of control id tControlId to false
        set the dropShadow of control id tControlId to empty
        set the innerShadow of control id tControlId to empty
        set the outerGlow of control id tControlId to empty
        set the innerGlow of control id tControlId to empty
        set the colorOverlay of control id tControlId to empty

        set the layermode of control id tControlId to "dynamic"
      end if

      ## Make sure a style is set
      set the dvTemplateStyle of control id tControlId to pStyle
      set the topleft of control id tControlId to the topleft of group "dvList" of me

      set the lockMessages to msgsAreLocked
    end if
  end if

  return tControlId
end _getControlIdOfStyle


/**
Summary: Locates a row control that matches pStyle and is not "active" (i.e. is not currently in use).

Parameters:
pStyle: The found control will have this style.

Returns: control reference or empty
*/
private function _findAvailableControlOfStyle pStyle
  local tControlId

  repeat for each key tControlId in sViewPropsA["controls"]["available"]
    try ## in case control doesn't exist
      if the dvTemplateStyle of control id tControlId is pStyle then
        return tControlId
      end if
    catch e
    end try
  end repeat
  return empty
end _findAvailableControlOfStyle


/*
Summary: Creates a portable control reference.

Parameters:
pControl: Long id of a control.

Description:
All group referneces are removed, the main stack is removed if on a substack
and the stack name is shortened.

Returns: Control reference
*/
private function _customControlReference pControl
  -----
  local theFirstCharToDelete
  local theLastCharToDelete
  local theOffset
  local theStack
  -----
  put the long ID of pControl into pControl
  ## Get id without hierarchy
  if word 1 of pControl is not among the items of "card,stack" then
    local theStackOffset, theSecondStackOffset

    ## Strip any nested refs
    if pControl contains "of group id" then
      put length(word 1 to 4 of pControl) + 1 into theFirstCharToDelete
      put offset(" card id", pControl) - 1 into theLastCharToDelete
      delete char theFirstCharToDelete to theLastCharToDelete of pControl
    end if

    put offset(" of stack ", pControl) into theStackOffset
    put offset(" of stack ", pControl, theStackOffset) into theSecondStackOffset
    if theSecondStackOffset > 0 then
      ## Strip mainstack ref if substack.
      ## We want user to move stacks around.
      add theSecondStackOffset to theStackOffset
      delete char theStackOffset to -1 of pControl
    else
      ## Shorten stack name
      put char (theStackOffset + 4) to -1 of pControl into theStack
      put the short name of theStack into theStack  # get stack short name
      put quote & theStack & quote into char (theStackOffset + 10) to -1 of pControl
    end if
  end if

  return pControl
end _customControlReference


/**
Summary: Creates a mobile scrollbar.

Returns: empty
*/
private command _createMobileScroller
  if sScrollerID is empty OR sScrollerID is not among the lines of mobileControls() then
    -- Create the scroller and store its id
    mobileControlCreate "scroller"
    put the result into sScrollerID

    -- The 'rect' is the region of the card it should cover
    mobileControlSet sScrollerID, "rect", the rect of me
    -- The 'visible' determines if the scroller is displayed
    mobileControlSet sScrollerID, "visible", "true"

    if the environment is "mobile" then
      -- The 'canBounce' determines whether the standard iOS 'bouncing' occurs
      -- at extremities of scrolling
      mobileControlSet sScrollerID, "canBounce", "true"
      -- The 'canCancelTouches' determines whether contorl can cancel touch messages if it
      -- is determined a scroll gesture is occuring.
      mobileControlSet sScrollerID, "canCancelTouches", "true"
      -- The 'delayTouches' affects touch messages. Waits until it is determined whether or not
      -- touch is a scroll gesture.
      mobileControlSet sScrollerID, "delayTouches", "true"
      -- The 'pagingEnabled' determines whether scrolling only happens in multiples
      -- of the width/height
      mobileControlSet sScrollerID, "pagingEnabled", "false"
      -- The 'canScrollToTop' determines whether touching the status bar scrolls
      -- the scroller to the top
      mobileControlSet sScrollerID, "canScrollToTop", "false"
      -- Initialize to whatever the current vscroll of the view is
      mobileControlSet sScrollerID, "vScroll", the viewProp["vscroll"] of me
    end if
  end if

  -- The 'contentRect' is the region the scroller scrolls over
  _setMobileScrollerContentRect

  return empty
end _createMobileScroller


/**
Summary: Sets the content rect for the mobile scroller.

Returns: empty
*/
private command _setMobileScrollerContentRect
  if the environment is "mobile" and sScrollerID is not empty then
    mobileControlSet sScrollerID, "contentRect", (0, 0, the width of me, the viewProp["content height"] of me)
  end if

  return empty
end _setMobileScrollerContentRect


/**
Summary: Sets the scrollbar width.

Description:
If user has set a specific width it is used. Otherwise a platform
appropriate value is used.

Returns: empty
*/
private command _setScrollbarWidth pWidth
  lock screen
  if pWidth is not an integer then
    if the viewProp["scrollbar width"] of me is an integer then
      put the viewProp["scrollbar width"] of me into pWidth
    else
      if sSystemA["scrollbarWidth"] is an integer then
        put sSystemA["scrollbarWidth"] into pWidth
      else
        if the platform is "MacOS" then
          put kSBWidthMac into pWidth
        else if the platform is "win32" then
          put kSBWidthWin into pWidth
        else
          put kSBWidthLinux into pWidth
        end if
      end if
    end if
  end if

  local theRectV

  put the rect of scrollbar "dvVScrollbar" of me into theRectV
  put item 3 of theRectV - pWidth into item 1 of theRectV

  set the rect of scrollbar "dvVScrollbar" of me to theRectV
  unlock screen

  return empty
end _setScrollbarWidth


--> Animation


constant kFrameLength = 10
constant kAnimationLength = 300

private command _startScrollAnimation pScrollTo
  _cancelAnimation

  local rightNow, scrollFrom

  put true into sViewPropsA["is animating"]
  put the milliseconds into rightNow
  put round(the thumbPosition of scrollbar "dvVScrollbar" of me) into scrollFrom

  _scheduleScrollAnimation scrollFrom, pScrollTo, rightNow, "ease in out", rightNow, rightNow + kAnimationLength
end _startScrollAnimation


private command _cancelAnimation
  put false into sViewPropsA["is animating"]
  cancel sPendingMsgsA["UpdateScrollAnimation"]
  put empty into sPendingMsgsA["UpdateScrollAnimation"]
end _cancelAnimation


private command _scheduleScrollAnimation pScrollFrom, pScrollTo, pLastTime, pPhase, pPhaseStart, pPhaseEnd
  if not sViewPropsA["is animating"] then return empty

  local rightNow, theNextTime

  put the milliseconds into rightNow
  ## Synchronize to the system clock.
  put (rightNow - (rightNow mod kFrameLength)) + kFrameLength into theNextTime

  send "__updateScrollAnimation pScrollFrom, pScrollTo, pLastTime, pPhase, pPhaseStart, pPhaseEnd" to me in theNextTime - rightNow milliseconds
  put the result into sPendingMsgsA["UpdateScrollAnimation"]
end _scheduleScrollAnimation


command __updateScrollAnimation pScrollFrom, pScrollTo, pLastTime, pPhase, pPhaseStart, pPhaseEnd
  put empty into sPendingMsgsA["UpdateScrollAnimation"]
  if not sViewPropsA["is animating"] then return empty

  local theControl, rightNow, theExponent
  local msgsAreLocked, theValue

  put the milliseconds into rightNow

  put 2 into theExponent

  switch pPhase
    case "ease in"
      put round(aeEaseIn(pScrollFrom, pScrollTo, kAnimationLength, pLastTime - pPhaseStart, theExponent)) into theValue
      break
    case "ease in out"
    case "ease in and out"
      put round(aeEaseInOUt(pScrollFrom, pScrollTo, kAnimationLength, pLastTime - pPhaseStart, theExponent)) into theValue
      break
    case "ease out"
    default
      put round(aeEaseOut(pScrollFrom, pScrollTo, kAnimationLength, pLastTime - pPhaseStart, theExponent)) into theValue
  end switch

  lock screen

  put the long ID of the focusedObject into theControl
  put the lockMessages into msgsAreLocked

  if not msgsAreLocked then lock messages
  set the thumbPosition of scrollbar "dvVScrollbar" of me to theValue
  if not msgsAreLocked then unlock messages

  _setVScrollForPlatform theValue

  ## Make sure focus stays with us
  if the long ID of me is in theControl and (there is not a theControl or the long ID of me is not in the long ID of the focusedobject) then
    focus on graphic "dvBackground" of me
  end if

  unlock screen

  ## Schedule next animation
  if pScrollFrom > pScrollTo then
    if theValue > pScrollTo then
      _scheduleScrollAnimation pScrollFrom, pScrollTo, rightNow, pPhase, pPhaseStart, pPhaseEnd
    else
      put false into sViewPropsA["is animating"]
    end if
  else
    if theValue < pScrollTo then
      _scheduleScrollAnimation pScrollFrom, pScrollTo, rightNow, pPhase, pPhaseStart, pPhaseEnd
    else
      put false into sViewPropsA["is animating"]
    end if
  end if

  return empty
end __updateScrollAnimation


private command _setDropIndicatorVisibility pBoolean
  if not pBoolean AND the visible of group "dvDropIndicator" of me then
    set the visible of group "dvDropIndicator" of me to false
    dispatch "HideDropIndicator" to group 1 of group "dvDropIndicator" of me
  else if pBoolean and not the visible of group "dvDropIndicator" of me then
    set the visible of group "dvDropIndicator" of me to true
    dispatch "ShowDropIndicator" to group 1 of group "dvDropIndicator" of me
  end if

  return empty
end _setDropIndicatorVisibility


/**
Summary: Scrolls the view based on the position of the mouse. Used during drag/drop operations.

Parameters:
pMouseH: The X mouse position.
pMouseV: The Y mouse position.

Returns: empty
*/
private command _listGroupDragReorderAutoScroll pMouseH, pMouseV
  local theMaskRect

  put the viewProp["content window rect"] of me into theMaskRect

  ## Check that mouse is within vertical space of group
  if pMouseH > item 1 of theMaskRect and pMouseH < item 3 of theMaskRect then
    local theWindowHeight, theScroll, theHotZone, theDiff

    put item 4 of theMaskRect - item 2 of theMaskRect into theWindowHeight
    put round(theWindowHeight * .1) into theScroll

    ## Decide the zone where auto scrolling will occur
    if the viewProp["fixed row height"] of me then
      put round(the viewProp["row height"] of me  / 2) into theHotZone
    else
      put 20 into theHotZone ## 20 is arbitrary number
    end if

    ## First check for above
    put item 2 of theMaskRect - pMouseV into theDiff

    if theDiff > 0 and theDiff <= theHotZone then
      put theDiff * -1 into theDiff
      --         put (theHotZone + theDiff) * -1 into theDiff ## These speed up scrolling too much
    else
      put pMouseV - item 4 of theMaskRect into theDiff

      if theDiff > 0 and theDiff <= theHotZone then
        --            put theHotZone - theDiff into theDiff
      else
        put 0 into theDiff
      end if
    end if

    if abs(theDiff) > 0 and abs(theDiff) <= theHotZone then
      local theCurrentVScroll

      ## Mouse is in a hot zone; auto scroll if value not changing.
      put min( round((theDiff * 5 / 100 * theScroll)), the endValue of scrollbar "dvVScrollbar" of me) into theScroll

      put the viewProp["vscroll"] of me into theCurrentVScroll
      put theCurrentVScroll + theScroll into theScroll

      if theCurrentVScroll is not theScroll then
        _setVScrollForPlatform theScroll
      end if
    end if
  end if

  return empty
end _listGroupDragReorderAutoScroll


/**
Summary: Sets the dragImage (and associated properties) using an image created from a control.

Parameters:
pControlId: Id of control to use as the dragImage.

Returns: empty
*/
private command _createDragImageFromControl pControlId
  local tImageOffset, isHilited

  lock screen

  local msgsAreLocked

  put the lockMessages into msgsAreLocked

  if there is not a image "dvDragImage" of me then
    lock messages
    reset the templateImage
    create image "dvDragImage" in group "dvListMask" of me
    set the visible of it to false
  end if

  unlock messages

  put the dvHilite of control id pControlId into isHilited
  set the dvHilite of control id pControlId to false

  # Set here so that implementor can modify it
  put the clickH - the left of control id pControlId & comma & \
        the clickV - the top of control id pControlId into tImageOffset
  set the dragImageOffset to tImageOffset

  dispatch "PreDragImageSnapshot" to control id pControlId
  dispatch "CreateDragImageSnapshot" to control id pControlId with the short id of image "dvDragImage" of me
  if it is not "handled" then
    export snapshot from rect (the rect of control id pControlId) of control id pControlId \
          to image "dvDragImage" of me as PNG
  end if
  dispatch "PostDragImageSnapshot" to control id pControlId

  set the dvHilite of control id pControlId to isHilited

  set the dragImage to the ID of image "dvDragImage" of me

  set the lockMessages to msgsAreLocked
  unlock screen

  return empty
end _createDragImageFromControl


/**
Summary: Returns the rect where you can draw content in a group without making scrollbars appear.

Parameters:
pGroup A reference to a group control.

Returns: Rect
*/
private function _workingGroupRect pGroup
  local theRect, theWidth

  put the rect of pGroup into theRect
  add the leftMargin of pGroup to item 1 of theRect
  add the topMargin of pGroup to item 2 of theRect
  subtract the rightMargin of pGroup from item 3 of theRect
  subtract the bottomMargin of pGroup from item 4 of theRect
  if the environment is not "mobile" then
    if the hScrollbar of pGroup then subtract the scrollbarWidth of pGroup from item 4 of theRect
    if the vScrollbar of pGroup then subtract the scrollbarWidth of pGroup from item 3 of theRect
  end if
  if the showBorder of pGroup then
    put the borderWidth of pGroup into theWidth
    add theWidth to item 1 of theRect
    add theWidth to item 2 of theRect
    subtract theWidth from item 3 of theRect
    subtract theWidth from item 4 of theRect
  end if
  return theRect
end _workingGroupRect


/**
Summary: Returns the card containing this behavior.

Returns: Card reference
*/
private function _behaviorCard
  local theCard, theCharNo

  put the long id of this me into theCard

  put offset(" of card", theCard) into theCharNo
  if theCharNo > 0 then
    delete char 1 to (theCharNo + 3) of theCard
  else
    put offset(" of stack", theCard) into theCharNo
    if theCharNo > 0 then
      delete char 1 to (theCharNo + 3) of theCard
    end if
  end if

  return theCard
end _behaviorCard


/**
Summary: Returns the stack reference of a control.

Parameters:
pControl: A reference to a control.

Returns: A reference to the control stack.
*/
private function _stackOf pControl
  local theCharNo

  put the long ID of pControl into pControl ## force the long id

  if word 1 of pControl is not "stack" then
    put offset(" of stack ", pControl) into theCharNo
    if theCharNo > 0 then
      delete char 1 to (theCharNo + 3) of pControl
    else
      put empty into pControl
    end if
  end if
  return pControl
end _stackOf


--> Field Editing

/**
Summary: When "true" is passed in then any open field editors will NOT be closed when they normally would.

Parameters:
pStackRef: A reference to the stack that is being suspended.
pBoolean: `true` suspends normal field editor closing behavior. `false` restores normal behavior.

Description:
Use when a stack is suspended so that a field editor stays open.
Note that this message is processed in the actual behavior button rather than in an instance of the data grid.

Returns: empty
*/
command SuspendFieldEditorClosing pStackRef, pBoolean
  local theKeyExists

  put the long id of pStackRef into pStackRef
  if the short name of pStackRef begins with "rev" then return empty

  put pStackRef is among the keys of sViewPropsA["suspended stacks"] into theKeyExists

  if pBoolean then
    if not theKeyExists then
      put empty into sViewPropsA["suspended stacks"][pStackRef]
    end if
  else
    if theKeyExists then
      delete variable sViewPropsA["suspended stacks"][pStackRef]
    end if
  end if

  --   loggerLogMsg param(0) && the milliseconds & cr & the keys of sViewPropsA["suspended stacks"] & cr

  return empty
end SuspendFieldEditorClosing


/**
Summary: Returns whether or not a stack is suspended

Description:
Only call on the behavior button, not an instance of the data view. Otherwise the script local
won't have the proper value.

Returns: Boolean
*/
getProp uStackIsSuspended [pStackRef]
  put the long id of pStackRef into pStackRef
  return pStackRef is among the keys of sViewPropsA["suspended stacks"]
end uStackIsSuspended


/**
Summary: Returns whether or not a field editor should close. Called from an instance of the data view.

Parameters:
pClosingTriggeredBy: The event triggering the close. If exitField or closeField then stack check is performed.

Returns: Boolean
*/
private function _shouldFieldEditorClose pClosingTriggeredBy
  local theTargetStack, theBehaviorStack, theStackIsSuspended, msgsAreLocked

  # If focus is leaving a field then only close if stack is not suspended.
  if pClosingTriggeredBy is among the items of "exitField,closeField" then
    put _stackOf(the long id of me) into theTargetStack
    put _stackOf(_behaviorCard()) into theBehaviorStack
    put the lockMessages into msgsAreLocked
    set the lockMessages to false
    put the uStackIsSuspended[theTargetStack] of stack (the short name of this me) into theStackIsSuspended
    set the lockMessages to msgsAreLocked

    return not theStackIsSuspended
  else
    return true
  end if
end _shouldFieldEditorClose


/**
Summary: Scrolls the row into view and dispatches the EditKey message to it.

Parameters:
pKey: The key to edit.
pRow: The row to edit.

Description:
It is up to the control to implement the EditKey handler. Normally it will call `EditFieldText` for
the field that edits the targeted key.

Returns: Error message
*/
command EditKeyOfRow pKey, pRow
  local theCacheKey

  lock screen
  ScrollRowIntoView pRow
  put _getCacheKeyForRow(pRow) into theCacheKey

  if sViewPropsA["controls"]["cache"][theCacheKey]["control"] is not empty then
    dispatch "EditKey" to control id sViewPropsA["controls"]["cache"][theCacheKey]["control"] with pKey
    unlock screen
    return empty
  else
    unlock screen
    return "no control exists for row"
  end if
end EditKeyOfRow


/**
Summary: Opens an editing field for the target field. This allows the user to edit the value for a key.

Parameters:
pField: A reference to the field that will be edited. The editor will appear over the top of this field.
pKey: The key that the field is associated with.

Returns: empty
*/
command CreateFieldEditorForField pField, pKey
  local msgsAreLocked, theClickLine, theRow
  local theClickField, theClickChunk
  local theMargins, theBorderWidth
  local tRowControl, theScrollSetting, theAnimSetting
  local thisStackHasFocus

  ## Cache where the person clicked as this data will change if
  ## OpenInlineEditor changes position of the target
  if the clickField is not empty then put the long ID of the clickField into theClickField
  else put empty into theClickField
  put the clickCharChunk into theClickChunk
  put the clickLine into theClickLine

  lock screen
  put the lockMessages into msgsAreLocked
  unlock messages
  ## bring focus into control clicked on so other controls get exit/focusOut message
  put the short name of _stackOf(the long id of me) is line 1 of the openStacks into thisStackHasFocus
  if thisStackHasFocus then
    if the traversalon of pField then
      focus on pField
    else
      focus on graphic "dvBackground" of me
    end if
  end if

  ## Make sure normal behavior is active. Can get out of sync if suspend/resumeStack messages are not synced.
  ## Have seen this happen when running AppleScripts that open other applications.
  ## Send message to behavior button as that is where script locals are stored.
  dispatch "SuspendFieldEditorClosing" to stack (the short name of this me) with _stackOf(the long id of me), false

  put the dvRowControl of pField into tRowControl
  put the dvRow of tRowControl into theRow
  lock messages

  if thisStackHasFocus then
    focus on graphic "dvBackground" of me
  end if

  ## Cleanup if necessary
  if there is a field kFieldEditorName of group "dvListMask" of me then
    delete field kFieldEditorName of group "dvListMask" of me
  end if

  reset the templatefield

  put the margins of pField into theMargins
  if the number of items of theMargins is 1 then
    repeat with i = 1 to 3
      put "," & item 1 of theMargins after theMargins
    end repeat
  end if
  put the borderWidth of pField into theBorderWidth

  set the autoTab of the templatefield to the autoTab of pField
  set the dontWrap of the templatefield to the dontWrap of pField
  set the tabStops of the templatefield to the tabStops of pField
  set the margins of the templatefield to theMargins
  set the borderWidth of the templatefield to theBorderWidth
  set the foregroundColor of the templatefield to the foregroundColor of pField
  set the textAlign of the templatefield to the effective textAlign of pField
  set the textFont of the templatefield to the effective textFont of pField
  set the textSize of the templatefield to the effective textSize of pField
  set the textHeight of the templatefield to the textHeight of pField
  set the textStyle of the templatefield to the effective textStyle of pField
  set the fixedLineHeight of the templatefield to the fixedLineHeight of pField
  set the textColor of the templateField to the textColor of pField
  set the opaque of the templatefield to true
  set the backgroundColor of the templateField to the backgroundColor of pField
  set the threeD of the templatefield to true

  unlock messages

  ## make sure the row control is the hilited one and in view
  if theRow is not sViewPropsA["hilited rows"] then
    put the viewProp["scroll selections into view"] of me into theScrollSetting
    put the viewProp["animate selections"] of me into theAnimSetting
    set the viewProp["scroll selections into view"] of me to true
    if not the visible of tRowControl then
      set the viewProp["animate selections"] of me to false ## don't animate to unseen controls
    end if
    set the dvHilitedRows of me to theRow
    set the viewProp["scroll selections into view"] of me to theScrollSetting
    set the viewProp["animate selections"] of me to theAnimSetting

    # If control can't be selected then unset hilited rows
    if not the dvCanSelect of tRowControl then
      put empty into sViewPropsA["hilited rows"]
    end if
  end if

  lock messages

  create field kFieldEditorName in tRowControl
  put the short id of it into sViewPropsA["fld_editor"]["control"]

  set the behavior of control id sViewPropsA["fld_editor"]["control"] to the long ID of stack "DataView Field Editor Behavior"

  set the rect of control id sViewPropsA["fld_editor"]["control"] to the rect of pField

  set the dvIsFieldEditor of control id sViewPropsA["fld_editor"]["control"] to true
  set the uIsFieldEditor of control id sViewPropsA["fld_editor"]["control"] to true ## property name for generic field editor
  set the dvTargetField of control id sViewPropsA["fld_editor"]["control"] to pField
  set the uTargetField of control id sViewPropsA["fld_editor"]["control"] to pField ## property name for generic field editor
  set the dvTargetKey of control id sViewPropsA["fld_editor"]["control"] to pKey
  set the dvScrollInPadding of control id sViewPropsA["fld_editor"]["control"] to 0,10,0,10
  set the dvRowCacheKey of control id sViewPropsA["fld_editor"]["control"] to _getCacheKeyForRow(theRow)

  unlock messages

  ## Shout our existence out to the world
  _populateFieldEditor pField

  lock messages
  set the dvOriginalStyledText of control id sViewPropsA["fld_editor"]["control"] to the effective styledText of control id sViewPropsA["fld_editor"]["control"]

  ## Bug when editing right|center-aligned text that is wider than field.
  if the textAlign of control id sViewPropsA["fld_editor"]["control"] is not "left" \
        and the formattedWidth of control id sViewPropsA["fld_editor"]["control"] >= the width of control id sViewPropsA["fld_editor"]["control"] then
    set the textAlign of control id sViewPropsA["fld_editor"]["control"] to "left"
  end if
  unlock messages

  local theFrontScriptButton

  ## Inserted once, never removed
  put the long id of stack "DataView Field Editor Frontscript" into theFrontScriptButton

  if theFrontScriptButton is not among the lines of the frontScripts then
    insert script of theFrontScriptButton into front
  end if

  ## 2016-03-18: If the developer selected something in the editor already then don't do anything.
  ## Deprecated behavior: User can set dvSelectAll in preOpenFieldEditor
  local tDeveloperFocusedOnField

  put the selectedField is not empty and \
        the long id of the selectedfield is the long id of control id sViewPropsA["fld_editor"]["control"] into tDeveloperFocusedOnField
  if tDeveloperFocusedOnField then
  else
    if the dvSelectAll of control id sViewPropsA["fld_editor"]["control"] then
      select char 1 to -1 of control id sViewPropsA["fld_editor"]["control"]
    else
      if theClickField is not empty and theClickField is the long ID of pField then
        if theClickChunk is not empty then
          select after char (word 2 of theClickChunk) of control id sViewPropsA["fld_editor"]["control"]
        else if theClickLine is not empty then
          select after line (word 2 of theClickLine) of control id sViewPropsA["fld_editor"]["control"]
        else
          select after char -1 of control id sViewPropsA["fld_editor"]["control"]
        end if
      else
        select after char -1 of control id sViewPropsA["fld_editor"]["control"]
      end if
    end if
  end if

  if thisStackHasFocus then
    focus on control id sViewPropsA["fld_editor"]["control"]
  end if

  ## All of the scrolling around and unfocusing of controls will leave
  ## the row the field editor is in dimmed out. Explicitly highlight the
  ## row again.
  if the dvCanSelect of tRowControl is not false then
    _hiliteControl the short id of the dvRowControl of control id sViewPropsA["fld_editor"]["control"], true
  end if

  if not tDeveloperFocusedOnField then
    dispatch "selectionChanged" to control id sViewPropsA["fld_editor"]["control"]
  end if

  reset the templatefield
  set the lockMessages to msgsAreLocked
  unlock screen

  return empty
end CreateFieldEditorForField


/**
Summary: Refreshes the editor field content.

Returns: empty
*/
command RefreshFieldEditorContent
  if sViewPropsA["fld_editor"]["control"] is not empty and there is a control id sViewPropsA["fld_editor"]["control"] then
    _populateFieldEditor the dvTargetField of control id sViewPropsA["fld_editor"]["control"]
  end if
  return empty
end RefreshFieldEditorContent


/**
Summary: Populates editor field with content.

Returns: empty
*/
private command _populateFieldEditor pField
  local theRowControl, theRowRect

  ## Shout our existence out to the world
  try
    dispatch "PreOpenFieldEditor" to pField with the long id of control id sViewPropsA["fld_editor"]["control"]
    if it is not "handled" then
      set the styledText of control id sViewPropsA["fld_editor"]["control"] to the styledText of pField
    end if

    ## Determine the rect that needs to be scrolled into view
    if the viewProp["scroll selections into view"] of me then
      put the dvRowControl of pField into theRowControl
      put the dvRectOfRow[the dvRow of theRowControl] of me into theRowRect
      add (the top of control id sViewPropsA["fld_editor"]["control"] - the top of theRowControl) to item 2 of theRowRect
      subtract (the bottom of theRowControl - the bottom of control id sViewPropsA["fld_editor"]["control"]) from item 4 of theRowRect

      ## Developer can set uPadding of field
      ScrollRectIntoView theRowRect, the dvScrollInPadding of control id sViewPropsA["fld_editor"]["control"]
    end if
  catch e
    lock messages
    delete control id sViewPropsA["fld_editor"]["control"]
    put empty into sViewPropsA["fld_editor"]
    unlock messages

    throw e
  end try

  return empty
end _populateFieldEditor



/**
Summary: Closes the field editor, optionally saving contents.

Parameters:
pSaveContents: Boolean value specifying whether or not to send messages to save changes.
pClosingTriggeredBy: The system message that triggered the closing.

Description:
This is called from the field editor behaviors.

Returns: empty
*/
command _CloseFieldEditor pSaveContents, pClosingTriggeredBy
  ## Don't process if field editor is not open
  ## OR it is already being closed (most likely e.g. escapekey triggers closing and then closeField tries to close as well)
  if sViewPropsA["fld_editor"]["control"] is not empty and \
        there is a control id sViewPropsA["fld_editor"]["control"] and \
        not sViewPropsA["fld_editor"]["closing"] then
    if _shouldFieldEditorClose(pClosingTriggeredBy) then
      put pSaveContents is not false into pSaveContents
      DeleteFieldEditor pSaveContents, pClosingTriggeredBy
    end if
  end if
  return empty
end _CloseFieldEditor


/**
Summary: Removes focus from the editor and sends messages to open the next field editor.

Parameters:
pClosingTriggeredBy: The system message that triggered the closing.

Description:
This is called from the field editor behaviors.

Returns: empty
*/
command _CloseFieldEditorAndOpenNext pClosingTriggeredBy
  if _shouldFieldEditorClose(pClosingTriggeredBy) then
    send "DeleteFieldEditorAndOpenNext pClosingTriggeredBy" to me in 0 seconds
  end if
  return empty
end _CloseFieldEditorAndOpenNext


/**
Summary: A helper function that determines if a field editor is open for a field of a particular name.

Parameters:
pRowObject: The row object that is asking the question.
pFieldName: Name of field that might have a field editor open for it.

Description:
This can be called from a row template.

Returns: Boolean
*/
function FieldEditorIsOpen pRowObject, pFieldName
  local fieldEditorIsOpen

  put the viewProp["field editor is open"] of me \
        and the dvRowControl of the viewProp["field editor"] of me is the dvRowControl of pRowObject into fieldEditorIsOpen

  if fieldEditorIsOpen AND pFieldName is not empty then
    return the dvTargetKey of the viewProp["field editor"] of me is pFieldName
  else
    return fieldEditorIsOpen
  end if
end FieldEditorIsOpen


/**
Summary: Deletes the field editor, optionally sending messages to save changes made in editor.

Parameters:
pSaveContents: Set to true to dispatch message signaling that editor content should be saved.
pClosingTriggeredBy: The system message that triggered the closing.

Returns: Empty or `cancel`
*/
command DeleteFieldEditor pSaveContents, pClosingTriggeredBy
  local theFocusedObject, msgsAreLocked, contentHasChanged
  local theField, theRow, theKey
  local theEditor, theError

  --   beep

  if pClosingTriggeredBy is empty then put "unknown" into pClosingTriggeredBy
  put the lockMessages into msgsAreLocked

  ## Make sure control still exists.
  if sViewPropsA["fld_editor"]["control"] is empty or there is not a control id sViewPropsA["fld_editor"]["control"] then
    ## The pointer is invalid. Now ensure that actual control is missing.
    if there is a field kFieldEditorName of group "dvListMask" of me then
      lock messages
      delete field kFieldEditorName of group "dvListMask" of me
      set the lockMessages to msgsAreLocked
    end if

    return empty
  end if

  put pSaveContents is not false into pSaveContents

  unlock messages

  put the long id of control id sViewPropsA["fld_editor"]["control"] into theEditor
  put the dvTargetField of theEditor into theField

  lock screen

  ## So that "field editor is open" returns false
  put true into sViewPropsA["fld_editor"]["closing"]

  if there is a theField then
    if pSaveContents then
      put the dvRow of the dvRowControl of theEditor into theRow
      put the dvTargetKey of theEditor into theKey ## might be an array index

      set the caseSensitive to true
      put the effective styledText of theEditor is not the dvOriginalStyledText of theEditor into contentHasChanged
      set the caseSensitive to false

      if contentHasChanged then
        dispatch "CloseFieldEditor" to theField with theEditor, theRow, theKey, pClosingTriggeredBy
      else
        dispatch "ExitFieldEditor" to theField with theEditor, theRow, theKey, pClosingTriggeredBy
      end if
    else
      dispatch "ExitFieldEditor" to theField with theEditor, theRow, theKey, pClosingTriggeredBy
    end if

    ## Developer can return false if the field should not be closed
    if the result is false then
      put "cancel" into theError
    end if
  end if

  if theError is empty then
    if there is a theEditor then # Saw error message where this had disappeared. Possibly in CloseFieldEditor...
      put the long id of the focusedObject into theFocusedObject
      if theEditor is theFocusedObject then focus on nothing ## so closeField/exitField are called
      hide theEditor

      lock messages

      if theEditor is theFocusedObject then
        focus on graphic "dvBackground" of me ## Engine doesn't like deleting focused control in groups
      else
        ## Just let it be. Developer may have set focus in Close/ExitFieldEditor
        --         focus on nothing
      end if

      unlock messages

      if there is a theEditor then
        -- delete theEditor
        --            send "_deleteFieldEditor theEditor" to me in 0 seconds ## field itself likely triggered message so don't delete until afterwards
        _deleteFieldEditor theEditor # this handler now keeps trying to delete
      end if

      ## If user displayed an answer dialog in any callbacks we end
      ## up with unbalanced focusOut/In messages. This causes hilites
      ## to stay grey. Force update.
      _hiliteRowsInVisibleControls

      ## Reset internals
      delete variable sViewPropsA["fld_editor"]
    end if
  end if

  if sViewPropsA["fld_editor"] is an array then
    put false into sViewPropsA["fld_editor"]["closing"]
  end if

  set the lockMessages to msgsAreLocked
  unlock screen

  return theError
end DeleteFieldEditor


command _deleteFieldEditor pField
  if there is a pField then
    try
      delete pField
    catch e
      --         put param(0) && the milliseconds & cr & e
      # Script still executing? Try again.
      send "_deleteFieldEditor pField" to me in 10 milliseconds
    end try
  end if
end _deleteFieldEditor


/**
Summary: Deletes the field editor and sends message to view telling it to open next editing field.

Parameters:
pClosingTriggeredBy: The system message that triggered the closing.
pDirection: Pass in a value to force "next" or "previous".

Description:
The field editor will be closed with changes saved. The `OpenNextFieldEditor` message will then be
sent to view so the developer can open another field for editing.
Optionally sending messages to save changes made in editor. `OpenNextFieldEditor` has three parameters:

| Name | Description |
|:---- |:----------- |
| `pRow` | The row that was just edited. |
| `pKey` | The key that was just edited. |
| `pDirection` | `next` or `previous` |

Returns: Empty or "cancel"
*/
command DeleteFieldEditorAndOpenNext pClosingTriggeredBy, pDirection
  local msgsAreLocked, shiftKeyIsDown
  local theRow, theKey, theDirection, theControl
  local theError

  put the lockMessages into msgsAreLocked

  ## Make sure editor exists
  if sViewPropsA["fld_editor"]["control"] is empty or there is not a control id sViewPropsA["fld_editor"]["control"] then
    ## The pointer is invalid. Now ensure that actual control is missing.
    if there is a field kFieldEditorName of group "dvListMask" of me then
      lock messages
      delete field kFieldEditorName of group "dvListMask" of me
      set the lockMessages to msgsAreLocked
    end if

    return empty
  end if

  unlock messages

  lock screen

  put _isThisModifierSetActive("shift") into shiftKeyIsDown

  ## Get info before field might be deleted
  put the dvRow of the dvRowControl of control id sViewPropsA["fld_editor"]["control"] into theRow
  put the dvTargetKey of control id sViewPropsA["fld_editor"]["control"] into theKey

  DeleteFieldEditor true, pClosingTriggeredBy
  put the result into theError

  if theError is empty then
    if pDirection is not among the items of "next,previous" then
      if shiftKeyIsDown then put "previous" into pDirection
      else put "next" into pDirection
    end if

    ## If this isn't done in time then the exitfield/closefield message that
    ## is currently being triggered will delete the new control that is created.
    --      dispatch "OpenNextFieldEditor" with theRow, theKey, theDirection
    send "OpenNextFieldEditor theRow, theKey, pDirection, pClosingTriggeredBy" to me in 0 seconds
  end if

  unlock screen
  set the lockMessages to msgsAreLocked

  return theError
end DeleteFieldEditorAndOpenNext


local sControlsBeingAnimated = ""
local sDeleteAnimationLayer = "false"


/**
Summary: Reveals rows by animating them.

Parameters:
pRows:
pShowOrHide:

Description:
It is unknow how well this code works (if at all). Needs testing.

*/
private command AnimateRows pRows, pShowOrHide
  local theRow, theRowControl
  local theYOffset, theStartingY
  local thePrevRowControl, theDestLoc

  put empty into sControlsBeingAnimated

  sort items of pRows ascending numeric

  # 1) Determine starting Y. This will be the row above item 1 of pRows or
  #    the top of the view.
  #
  # 2) Determine any visible rows that appear after pRows
  #
  # 3) Group pRows and rows from (2) and put at the back of the group "dvList" of me
  #
  # 4) Position the group so that the last item of pRows is at starting Y position

  # [1]
  if pShowOrHide is "show" then
    put the dvControlOfRow[item 1 of pRows - 1] of me into thePrevRowControl
    if thePrevRowControl is not empty then
      put the bottom of thePrevRowControl into theStartingY
    else
      put the top of group "dvList" of me into theStartingY
    end if
  end if

  lock messages
  create group "dvAnimationLayer" in group "dvList" of me
  relayer group "dvAnimationLayer" of group "dvList" of me to back of group "dvList" of me
  unlock messages

  repeat for each item theRow in pRows
    put the dvControlOfRow[theRow] of me into theRowControl
    if theRowControl is not empty then
      lock messages
      relayer theRowControl to front of group "dvAnimationLayer" of group "dvList" of me
      unlock messages
      put theRowControl & cr after sControlsBeingAnimated

      # We are going to move the animation layer group up the height of all rows being shown
      add the height of theRowControl to theYOffset
    end if
  end repeat

  # [2] and [3]
  repeat with i = item 2 of pRows + 1 to the viewProp["number of rows"] of me
    put the dvControlOfRow[i] of me into theRowControl
    if theRowControl is not empty then
      lock messages
      relayer theRowControl to front of group "dvAnimationLayer" of group "dvList" of me
      unlock messages
      put theRowControl & cr after sControlsBeingAnimated
    else
      exit repeat
    end if
  end repeat

  delete the last char of sControlsBeingAnimated

  put the loc of group "dvAnimationLayer" of group "dvList" of me into theDestLoc
  if pShowOrHide is "hide" then
    subtract theYOffset from item 2 of theDestLoc
  end if

  # [4]
  if pShowOrHide is "show" then
    lock messages
    set the top of group "dvAnimationLayer" of group "dvList" of me to theStartingY - theYOffset
    unlock messages
  end if

  aeMoveTo the long id of group "dvAnimationLayer" of group "dvList" of me, theDestLoc, 1000, "out"

  return empty
end AnimateRows


# When animation is done then get rid of animation layer.
command aeMoveDone
  if there is a group "dvAnimationLayer" of group "dvList" of me then
    put true into sDeleteAnimationLayer
  end if
end aeMoveDone

# animationEngine sends this AFTER aeMoveDone.
command aeExitFrame
  if sDeleteAnimationLayer then
    lock messages
    repeat for each line theControl in sControlsBeingAnimated
      relayer theControl to front of group "dvList" of me
    end repeat
    delete group "dvAnimationLayer" of group "dvList" of me
    unlock messages
    put false into sDeleteAnimationLayer
    put empty into sControlsBeingAnimated
  end if
end aeExitFrame

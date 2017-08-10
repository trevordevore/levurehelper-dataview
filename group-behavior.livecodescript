script "DataView Group Behavior"
local sLastTargetedRow

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
local sViewPropsA
local sSystemA -- stores system specific settings
local sScrollerID
local sPendingMsgsA
local sFieldEditor ## place holder until I decide what to do with editing.


private function _GetTotalCachedHeight
  local theTotal

  repeat for each key theKey in sViewPropsA["controls"]["control height cache"]
    if sViewPropsA["controls"]["control height cache"][theKey] is NULL then add kDefaultForNonCachedVariableHeightRows to theTotal
    else add sViewPropsA["controls"]["control height cache"][theKey] to theTotal
  end repeat
  return theTotal
end _GetTotalCachedHeight


command InspectInternally
  local theTotal, theText

  repeat for each key theKey in sViewPropsA["controls"]["control height cache"]
    if sViewPropsA["controls"]["control height cache"][theKey] is NULL then add kDefaultForNonCachedVariableHeightRows to theTotal
    else add sViewPropsA["controls"]["control height cache"][theKey] to theTotal
  end repeat

  put "control height cache:" && theTotal & cr & \
        "content height:" && the viewProp["content height"] of me & cr & \
        "sViewProps:" & cr & printArray(sViewPropsA,,true) into theText

  --   breakpoint

  return theText
end InspectInternally


on preopenControl
  _Init

  ## mobile
  if the environment is "mobile" then
    set the visible of scrollbar "dvVScrollbar" of me to false
    _CreateMobileScroller
  end if
end preopenControl


on closeControl
  if the environment is "mobile" then
    if sScrollerID is among the lines of mobileControls() then
      mobileControlDelete sScrollerID
      put empty into sScrollerID
    end if
  end if
end closeControl


private command _Init
  if sInit then return empty
  put true into sInit

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

  _SetScrollbarWidth
  set the viewProp["opaque"] of me to the opaque of me

  ResetView

  # Initialize all templates
  # Note: this occurs every time an instance of a data view is opened.
  local theTemplatesA

  put the viewProp["row style templates"] of me into theTemplatesA
  repeat for each key theKey in theTemplatesA
    if there is a theTemplatesA[theKey] then
      dispatch "InitializeTemplate" to theTemplatesA[theKey]
    end if
  end repeat
end _Init


private command _CreateMobileScroller
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
    end if
  end if

  -- The 'contentRect' is the region the scroller scrolls over
  _SetMobileScrollerContentRect
end _CreateMobileScroller


private command _SetMobileScrollerContentRect
  if the environment is "mobile" and sScrollerID is not empty then
    mobileControlSet sScrollerID, "contentRect", (0, 0, the width of me, the viewProp["content height"] of me)
  end if
end _SetMobileScrollerContentRect


command _SetScrollbarWidth pWidth
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
end _SetScrollbarWidth


on resizeControl
  if the target is not me then pass resizeControl
  ResizeToFit
  pass resizeControl
end resizeControl


command ResizeToFit
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

  put _WorkingGroupRect(the long id of me) into theMasterRect
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

  set the topleft of group "dvListMask" of me to Item 1 to 2 of theMasterRect
  set the topleft of group "dvList" of me to Item 1 to 2 of theMasterRect
  set the visible of scrollbar "dvVScrollbar" of me to sScrollerID is empty AND the viewProp["content height"] of me > _GetContentWindowHeight()
  _ResizeListControls

  set the lockLoc of me to theLockLoc
  unlock messages

  try
    _TellControlsToResize

    lock messages
    _ConfigureScrollbars
    unlock messages
    RenderVisibleRows

    # if content height changed then true is returned. Fix scrollbars.
    if the result then
      lock messages
      _ConfigureScrollbars
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
* \brief Resizes (or marks as needing resizing) all controls after the list area is resized.
*
* \return empty
*/
private command _TellControlsToResize
  switch the viewProp["cache"] of me
    case "eager"
      _ResizeControls
      _StoreContentHeightForCachedControls
      break
    case "lazy"
    default
      local theIndex

      ## Mark them all as dirty
      repeat for each key theIndex in sViewPropsA["controls"]["cache"]
        put true into sViewPropsA["controls"]["cache"][theIndex]["resize"]
      end repeat
      break
  end switch
end _TellControlsToResize


/**
* \brief Resizes the list controls. Use this handler to resize necessary controls after showing/hiding scrollbars.
*
* \return empty
*/
private command _ResizeListControls
  local theRect

  put _WorkingGroupRect(the long id of me) into theRect

  if the visible of scrollbar "dvVScrollbar" of me then
    put the left of scrollbar "dvVScrollbar" of me into item 3 of theRect
  end if

  set the rect of group "dvListMask" of me to theRect
  set the rect of group "dvList" of me to theRect
end _ResizeListControls


/**
* \brief Implements changing selection when arrow keys are pressed.
*
* \param pDirection See LiveCode docs.
*
*/
on arrowKey pDirection
  if word 1 of the target is "field" and not the locktext of the target then pass arrowkey
  dvArrowKey pDirection
  pass arrowkey
end arrowKey


/**
* \brief Defines the arrow key behavior for the control.
*
* \param pDirection The direction of the arrowkey that was pressed.
*
* This handler is called from the arrowkey message. If the developer needs to override
* the arrowKey message in the behavior instance then they can call his handler explicitly
* in order to get the default arrow key behavior.
*
* \return empty
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
        if _IsThisModifierSetActive("shift") and the viewProp["multiple lines"] of me then
          if item 1 of sViewPropsA["hilited rows"] > 1 then
            put max(1, _NextSelectableRow(item 1 of sViewPropsA["hilited rows"], "up")) into theNewRow
            put itemOffset(theNewRow, thePreviouslyHilitedRows) into theItemNo
            if theItemNo is 0 then
              put theNewRow into sLastTargetedRow

              put comma & theNewRow after thePreviouslyHilitedRows
              _SetHilitedRows thePreviouslyHilitedRows
              put true into theSelectionChanged
            end if
          end if
        else if _IsThisModifierSetActive("") then ## other modifiers should not select
          put max(1, _NextSelectableRow(item 1 of sViewPropsA["hilited rows"], "up")) into theNewRow
          if sViewPropsA["hilited rows"] is not theNewRow then
            if item 1 of sViewPropsA["hilited rows"] > 1 then
              put theNewRow into sLastTargetedRow

              _SetHilitedRows theNewRow
              put true into theSelectionChanged
            else if item 1 of sViewPropsA["hilited rows"] is 1 then
              ## Case for multiple selections going all the way to top
              put item 1 of sViewPropsA["hilited rows"] into sLastTargetedRow

              _SetHilitedRows item 1 of sViewPropsA["hilited rows"]
              put true into theSelectionChanged
            end if
          end if
        end if
        break

      case "down"
        put the viewProp["number of rows"] of me into theRowCount

        if _IsThisModifierSetActive("shift") and the viewProp["multiple lines"] of me then
          if item -1 of sViewPropsA["hilited rows"] is not empty and item -1 of sViewPropsA["hilited rows"] < theRowCount then
            put _NextSelectableRow(item -1 of sViewPropsA["hilited rows"], "down") into theNewRow
            put itemOffset(theNewRow, thePreviouslyHilitedRows) into theItemNo
            if theItemNo is 0 then
              put theNewRow into sLastTargetedRow

              put comma & theNewRow after thePreviouslyHilitedRows
              _SetHilitedRows thePreviouslyHilitedRows
              put true into theSelectionChanged
            end if
          end if
        else if _IsThisModifierSetActive("") then ## other modifiers should not select
          put _NextSelectableRow(item 1 of sViewPropsA["hilited rows"], "down") into theNewRow
          if theNewRow is not sViewPropsA["hilited rows"] then # did row change?
            if item 1 of sViewPropsA["hilited rows"] > 0 and item 1 of sViewPropsA["hilited rows"] < theRowCount then
              put theNewRow into sLastTargetedRow

              _SetHilitedRows theNewRow
              put true into theSelectionChanged
            else if item 1 of sViewPropsA["hilited rows"] is theRowCount then
              put theRowCount into sLastTargetedRow
              subtract 1 from theNewRow

              ## Case for multiple selections going all the way to bottom
              _SetHilitedRows theRowCount
              put true into theSelectionChanged
            end if
          end if
        end if
        break
    end switch

  else if the viewProp["number of rows"] of me > 0 then
    put _NextSelectableRow(0, "down") into theNewRow
    if theNewRow > 0 then
      _SetHilitedRows theNewRow
      put true into theSelectionChanged
    end if
  end if

  if theSelectionChanged then
    # If the arrow key is moving the selection (and not adding to it)
    # then update the "first selected row"
    if the number of items of sViewPropsA["hilited rows"] is 1 then
      put sViewPropsA["hilited rows"] into sViewPropsA["first selected row"]
    end if

    _SelectionChanged thePreviouslyHilitedRows
  end if

  unlock screen

  return false
end dvArrowKey


/**
* \brief Looks for the next row in the view that can be selected.
*
* \param pStartingRow The row to start searching from. The first searched row will be +1 or -1 from this row.
* \param pDirection "up" searches -1, "down" searchs + 1. This mimics arrows keys in the list.
*
* \return Row
*/
private function _NextSelectableRow pStartingRow, pDirection
  local i, theAnimSetting

  switch pDirection
    case "down"
      repeat with i = pStartingRow + 1 to the viewProp["number of rows"] of me
        if there is not a the dvControlOfRow[i] of me then
          put the viewProp["animate selections"] of me into theAnimSetting
          set the viewProp["animate selections"] of me to false
          _ScrollRow i
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
          _ScrollRow i
          set the viewProp["animate selections"] of me to theAnimSetting
        end if

        if the dvCanSelect of (the dvControlOfRow[i] of me) is not false then
          return i
        end if
      end repeat
      break
  end switch

  return pStartingRow
end _NextSelectableRow


/**
* \brief Flags the control for a row as needing to be resized the next time it is drawn.
*
* \param pRow The row to flag.
*
* \return empty
*/
command FlagRowForResize pRow
  local theCacheKey

  put _GetCacheKeyForRow(pRow) into theCacheKey
  if sViewPropsA["controls"]["cache"][theCacheKey] is an array then
    put true into sViewPropsA["controls"]["cache"][theCacheKey]["resize"]
  end if
  return empty
end FlagRowForResize


/**
* |brief Toggles the exanded state of a row.
*
* \param @pDataSetA The data set containing the tree.
* \param pRow The row to toggle.
* \param pLevelsDown How many levels to toggle. Empty or 0 only toggles pRow. -1 toggles all. Positive number affects that many levels down.
* \param pExpandedState Pass in a true/false to force a setting.
*
* \package Tree
*
* \return The row number of the element.
*/
command TreeToggleRow @pDataSetA, pRow, pLevelsDown, pExpandedState
  local theSelElementKeys, theElementKey
  local theCurrentLevel, theChildNodes, theItemNo
  local i

  set the wholematches to true

  # store selected elements
  put sViewPropsA["hilited rows"] into theSelElementKeys
  repeat with i = 1 to the number of items of theSelElementKeys
    put item (item i of theSelElementKeys) of pDataSetA["visible object keys"] into item i of theSelElementKeys
  end repeat

  if pLevelsDown is empty then
    put 0 into pLevelsDown
  else if pLevelsDown < 0 then
    put -1 into pLevelsDown
  end if

  # Make sure node is visible
  put item pRow of pDataSetA["visible object keys"] into theElementKey
  _ShowNode pDataSetA, theElementKey

  --   # Are we showing or hiding?
  --   local showOrHide

  --   if pDataSetA["objects"][theElementKey]["expanded"] then put "hide" into showOrHide
  --   else put "show" into showOrHide

  # Toggle

  _SetExpandedState pDataSetA, pRow, pExpandedState

  # Affect children
  if pLevelsDown is not 0 then
    put 0 into theCurrentLevel
    _SetNodeAncestorExpandedState pDataSetA, theElementKey, pDataSetA["objects"][theElementKey]["expanded"], pLevelsDown, theCurrentLevel
  end if

  --   if showOrHide is "hide" then
  --      AnimateRows theChildNodes, showOrHide
  --   else
  --      AnimateRows theChildNodes, showOrHide
  --   end if
  lock screen

  --   put the milliseconds into theStart

  RenderView

  --   put "time:" && the milliseconds - theStart

  put TreeDescendantNodesOfRow(pDataSetA, pRow, true) into theChildNodes
  if theChildNodes is not empty then
    local theLastRow

    put itemOffset(the last item of theChildNodes, pDataSetA["visible object keys"]) into theLastRow
    ScrollRowIntoView theLastRow, "bottom"
  end if

  # Now make sure pRow is visible
  ScrollRowIntoView pRow, "top" # scroll to top if not in view

  # update selected rows
  # rows may no longer be available because they are contracted
  if theSelElementKeys is not empty then
    repeat with i = the number of items of theSelElementKeys down to 1
      put itemOffset(item i of theSelElementKeys, pDataSetA["visible object keys"]) into theItemNo
      if theItemNo > 0 then
        put theItemNo into item i of theSelElementKeys
      else
        delete item i of theSelElementKeys
      end if
    end repeat

    # If there are no rows left to be selected then select row that was toggled
    if theSelElementKeys is empty then put pRow into theSelElementKeys
    put theSelElementKeys into sViewPropsA["hilited rows"]
    _SetHilitedRows theSelElementKeys
  end if

  unlock screen

  return itemOffset(theElementKey, pDataSetA["visible object keys"])
end TreeToggleRow


/**
* \brief Attempts to render tree and keep some sensical scroll state.
*
*/
private command _RenderAfterAlteringVisibleTreeNodes @pDataSetA, pRow
  local theVScroll, theChildNodes

  --   put the viewProp["vscroll"] of me into theVScroll
  RenderView
  --   set the viewProp["vscroll"] of me to theVScroll
  # If children are off bottom then scroll to bottom
  put TreeDescendantNodesOfRow(pDataSetA, pRow, true) into theChildNodes
  if theChildNodes is not empty then
    local theLastRow

    put itemOffset(the last item of theChildNodes, pDataSetA["visible object keys"]) into theLastRow
    ScrollRowIntoView theLastRow, "bottom"
  end if

  return empty
end _RenderAfterAlteringVisibleTreeNodes


/**
* \brief Sets the expanded state for a node.
*
* \param @pDataSetA The data set containing the tree.
* \param pRow The row to expand/contract.
* \param pBoolean The value to assign to the expanded state. Leave empty to toggle.
*
* \return empty
*/
private command _SetExpandedState @pDataSetA, pRow, pBoolean
  local theChildElementKeys, theChildElementKey, theElementKey, theItemCount

  put item pRow of pDataSetA["visible object keys"] into theElementKey

  if pBoolean is empty then put not pDataSetA["objects"][theElementKey]["expanded"] into pBoolean
  else put pBoolean is true into pBoolean

  # Make sure it has a boolean value
  if pDataSetA["objects"][theElementKey]["expanded"] is empty then put false into pDataSetA["objects"][theElementKey]["expanded"]

  if pDataSetA["objects"][theElementKey]["expanded"] is not pBoolean then
    if not pDataSetA["objects"][theElementKey]["is leaf"] then
      if pDataSetA["objects"][theElementKey]["children"] is not empty then
        if not pBoolean then
          put _NumberOfVisibleAncestors(pDataSetA, "objects", theElementKey) into theItemCount
          delete item (pRow + 1) to (pRow + theItemCount) of pDataSetA["visible object keys"]
          put false into pDataSetA["objects"][theElementKey]["expanded"]
          --            put "hide" into theAction
        else
          put true into pDataSetA["objects"][theElementKey]["expanded"]
          put _DescendantElements(pDataSetA, "objects", theElementKey, true) into theChildElementKeys

          # make sure we don't add children to visible object keys twice
          set the wholematches to true
          local theRow
          put pRow into theRow
          repeat for each item theChildElementKey in theChildElementKeys
            if theChildElementKey is not among the items of pDataSetA["visible object keys"] then
              put "," & theChildElementKey after item theRow of pDataSetA["visible object keys"]
              add 1 to theRow
            end if
          end repeat
          --            put "show" into theAction
        end if
      end if
    end if
  end if

  return empty
end _SetExpandedState


/**
* |brief Expands any tree nodes necessary so that the node can be seen. The selected row(s) will be maintained.
*
* \param @pDataSetA The data set containing the tree.
* \param pElementKey The key in the data set that should be shown.
*
* \package Tree
*
* \return The row number of the element.
*/
command TreeShowNode @pDataSetA, pElementKey
  local theSelElementKeys, theRow, i

  # store selected elements
  put sViewPropsA["hilited rows"] into theSelElementKeys
  put item 1 of theSelElementKeys into theRow
  repeat with i = 1 to the number of items of theSelElementKeys
    put item (item i of theSelElementKeys) of pDataSetA["visible object keys"] into item i of theSelElementKeys
  end repeat

  _ShowNode pDataSetA, pElementKey

  lock screen
  RenderView

  # update selected rows
  # rows may no longer be available because they are contracted
  if theSelElementKeys is not empty then
    local theItemNo

    set the wholematches to true
    repeat with i = the number of items of theSelElementKeys down to 1
      put itemOffset(item i of theSelElementKeys, pDataSetA["visible object keys"]) into theItemNo
      if theItemNo > 0 then
        put theItemNo into item i of theSelElementKeys
      else
        delete item i of theSelElementKeys
      end if
    end repeat

    # If there are no rows left to be selected then select row that was toggled
    if theSelElementKeys is empty then put itemOffset(pElementKey, pDataSetA["visible object keys"]) into theSelElementKeys
    put theSelElementKeys into sViewPropsA["hilited rows"]
    _SetHilitedRows theSelElementKeys
  end if

  # Now make sure shown row is visible
  ScrollRowIntoView itemOffset(pElementKey, pDataSetA["visible object keys"])

  unlock screen

  set the wholematches to true
  return itemOffset(pElementKey, pDataSetA["visible object keys"])
end TreeShowNode


/**
* |brief Expands any tree nodes necessary so that the node can be seen.
*
* \param @pDataSetA The data set containing the tree.
* \param pElementKey The key in the data set that should be shown.
*
* \package Tree
*
* \return empty
*/
private command _ShowNode @pDataSetA, pElementKey
  local theParentKey, theKeys

  # Build list from root parent down to pElementKey and then work through it.
  # We need this in order to expand a row.
  put pDataSetA["objects"][pElementKey]["parent"] into theParentKey

  repeat until theParentKey is empty
    put theParentKey & "," after theKeys
    put pDataSetA["objects"][theParentKey]["parent"] into theParentKey
  end repeat
  delete the last char of theKeys

  local theKey, theRowNo
  set the wholematches to true

  repeat with i = the number of items of theKeys down to 1
    put item i of theKeys into theKey
    if not pDataSetA["objects"][theKey]["expanded"] then
      put itemOffset(theKey, pDataSetA["visible object keys"]) into theRowNo
      if theRowNo > 0 then
        _SetExpandedState pDataSetA, theRowNo, true
      end if
    end if
  end repeat

  return empty
end _ShowNode


/**
* \brief Returns the node keys of the ancestors of a row.
*
* \param @pDataSetA The data set containing the tree.
* \param pRow The row to get ancestor nodes for.
*
* \package Tree
*
* \return List
*/
function TreeAncestorNodesOfRow @pDataSetA, pRow
  local theElementKey
  put item pRow of pDataSetA["visible object keys"] into theElementKey
  return _AncestorElements(pDataSetA, "objects", theElementKey)
end TreeAncestorNodesOfRow


/**
* \brief Returns the node keys of the ancestors of a node.
*
* \param @pDataSetA The data set containing the tree.
* \param pNodeKey The node key to get ancestor nodes for.
*
* \package Tree
*
* \return List
*/
function TreeAncestorNodesOfNode @pDataSetA, pNodeKey
  return _AncestorElements(pDataSetA, "objects", pNodeKey)
end TreeAncestorNodesOfNode


/**
* \brief Returns the node keys of the descendants of a row.
*
* \param @pDataSetA The data set containing the tree.
* \param pRow The row to get ancestor nodes for.
* \param pOnlyVisible Pass in true to only return the visible descendant elements of pElementKey. Default is false.
*
* \package Tree
*
* \return List
*/
function TreeDescendantNodesOfRow @pDataSetA, pRow, pOnlyVisible
  local theElementKey
  put item pRow of pDataSetA["visible object keys"] into theElementKey
  return _DescendantElements(pDataSetA, "objects", theElementKey, pOnlyVisible)
end TreeDescendantNodesOfRow


/**
* \brief Returns the node keys of the descendants of a node.
*
* \param @pDataSetA The data set containing the tree.
* \param pNodeKey The node key to get ancestor nodes for.
* \param pOnlyVisible Pass in true to only return the visible descendant elements of pElementKey. Default is false.
*
* \package Tree
*
* \return List
*/
function TreeDescendantNodesOfNode @pDataSetA, pNodeKey, pOnlyVisible
  return _DescendantElements(pDataSetA, "objects", pNodeKey, pOnlyVisible)
end TreeDescendantNodesOfNode


/**
* \brief Recursive helper command for expanding nodes.
*
* \param @pDataSetA The data set containing the tree.
* \param pElementKey The key in the data set that should be expanded.
* \param pExpandedState True or false.
* \param pLevelsDown The number of levels down to expand. Leave empty to expand all children.
* \param @pCurrentLevel The current level that is being expanded. When this matches pLevelsDown or the last child is expanded then recursion stops.
*
* \return empty
*/
command _SetNodeAncestorExpandedState @pDataSetA, pElementKey, pExpandedState, pLevelsDown, @pCurrentLevel
  local theCurrentLevel, theChildrenKeys, theKey, theRowNo

  put pExpandedState is true into pExpandedState

  add 1 to theCurrentLevel
  put pCurrentLevel into theCurrentLevel

  put pDataSetA["objects"][pElementKey]["children"] into theChildrenKeys

  set the wholematches to true

  repeat for each item theKey in theChildrenKeys
    if pDataSetA["objects"][theKey]["expanded"] is not pExpandedState then
      put itemOffset(theKey, pDataSetA["visible object keys"]) into theRowNo
      if theRowNo > 0 then
        # Make call which deals with visible toggling
        _SetExpandedState pDataSetA, theRowNo, pExpandedState
      else
        put pExpandedState into pDataSetA["objects"][theKey]["expanded"]
      end if
    end if

    if theCurrentLevel is not pLevelsDown then
      _SetNodeAncestorExpandedState pDataSetA, theKey, pExpandedState, pLevelsDown, pCurrentLevel
      put theCurrentLevel into pCurrentLevel # reset for next child in loop.
    end if
  end repeat

  return empty
end _SetNodeAncestorExpandedState


/**
* |brief Returns a list of nodes that are descendants of a node.
*
* \param @pTreeA The tree structure.
* \param pNodesKey The name of the nodes key.
* \param pParentNodeId The parent node id.
* \param pOnlyVisible Only get the visible ancestor ids.
*
* \package Tree
*
* \return List
*/
private function _DescendantElements @pTreeA, pNodesKey, pParentNodeId, pOnlyVisible
  local theIds, theChildId, theChildIds

  put pOnlyVisible is true into pOnlyVisible

  if not pOnlyVisible OR (pOnlyVisible AND pTreeA[pNodesKey][pParentNodeId]["expanded"]) then
    repeat for each item theChildId in pTreeA[pNodesKey][pParentNodeId]["children"]
      put theChildId into item (the number of items of theIds + 1) of theIds

      put _DescendantElements(pTreeA, pNodesKey, theChildId, pOnlyVisible) into theChildIds
      if theChildIds is not empty then
        put theChildIds into item (the number of items of theIds + 1) of theIds
      end if
    end repeat
  end if

  return theIds
end _DescendantElements


/**
* |brief Returns a list of nodes that are ancestors of a node.
*
* \param @pTreeA The tree structure.
* \param pNodesKey The name of the nodes key.
* \param pChildNodeId The child node id to get the ancestors for.
*
* \package Tree
*
* \return List
*/
private function _AncestorElements @pTreeA, pNodesKey, pChildNodeId
  local theIds, theAncestorIds

  if pTreeA[pNodesKey][pChildNodeId]["parent"] is not empty then
    put pTreeA[pNodesKey][pChildNodeId]["parent"] into theIds
    put _AncestorElements(pTreeA, pNodesKey, pTreeA[pNodesKey][pChildNodeId]["parent"]) into theAncestorIds
    if theAncestorIds is not empty then
      put "," & theAncestorIds after theIds
    end if
  end if

  return theIds
end _AncestorElements


/**
* |brief Returns the number of visible ancestor nodes of a node.
*
* \param @pTreeA The tree structure.
* \param pNodesKey The name of the nodes key.
* \param pParentNodeId The parent node id.
*
* \package Tree
*
* \return Integer
*/
private function _NumberOfVisibleAncestors @pTreeA, pNodesKey, pParentNodeId
  local theItemCount, theChildId

  if pTreeA[pNodesKey][pParentNodeId]["expanded"] then
    put the number of items of pTreeA[pNodesKey][pParentNodeId]["children"] into theItemCount

    repeat for each item theChildId in pTreeA[pNodesKey][pParentNodeId]["children"]
      add _NumberOfVisibleAncestors(pTreeA, pNodesKey, theChildId) to theItemCount
    end repeat
  end if

  return max(theItemCount, 0)
end _NumberOfVisibleAncestors


/**
* \brief Locates an element in the tree (representation of a row). The element may or may not be a visible row.
*
* \param @pDataSetA The data set to search.
* \param pKey The name of the key to use to locate the row.
* \param pValue The value to find.
*
* You can pass in multiple key/value pairs as parameters in order to match multiple keys.
*
* \package Tree
*
* \return Array with "key", "row" and "visible" keys. ""key" is the key of the element found under the object key in the view data set. "key" will be empty if not found.
*/
function TreeFindElement @pDataSetA, pKey, pValue
  local i, foundAMatch, theElementKey, theFilterA
  local theObjectsKey, theRowsKey

  ## Create a lookup array
  if pKey is not an array then
    repeat with i = 2 to the paramCount
      put param(i+1) into theFilterA[param(i)]
      add 1 to i
    end repeat
  else
    put pKey into theFilterA
  end if

  put "objects" into theObjectsKey
  put "visible object keys" into theRowsKey

  # Find match
  repeat with i = 1 to the number of elements of pDataSetA[theObjectsKey]
    put true into foundAMatch

    repeat for each key theKey in theFilterA
      if pDataSetA[theObjectsKey][i][theKey] is not theFilterA[theKey] then
        put false into foundAMatch
        next repeat
      end if
    end repeat

    if foundAMatch then
      put i into theElementKey
      exit repeat
    end if
  end repeat

  # Fill in return value
  local theA
  put theElementKey into theA["key"]
  put true into theA["visible"]
  put empty into theA["row"]

  if theElementKey is not empty then
    set the wholematches to true
    put itemoffset(theElementKey, pDataSetA[theRowsKey]) into theA["row"]
    put theA["row"] > 0 into theA["visible"]
  end if

  return theA
end TreeFindElement


/**
* \brief Returns the order of a row in relation to its immediate siblings.
*
* \param @pDataSetA A reference to the view data set.
* \param pRow The row to focus on. Must be visible.
*
* \package Tree
*
* \return Position. Empty if no parent.
*/
function TreeRowPositionRelativeToParent @pDataSetA, pRow
  local theId, theParentId, thePosition
  local theObjectsKey, theRowsKey

  put "objects" into theObjectsKey
  put "visible object keys" into theRowsKey

  set the wholeMatches to true

  # Find position relative to parent.
  put item pRow of pDataSetA[theRowsKey] into theId
  put pDataSetA[theObjectsKey][theId]["parent"] into theParentId

  if theParentId > 0 then
    return itemOffset(theId, pDataSetA[theObjectsKey][theParentId]["children"])
  else
    local theRow

    ## At root level
    repeat for each item theId in pDataSetA[theRowsKey]
      add 1 to theRow
      if pDataSetA[theObjectsKey][theId]["parent"] < 1 then
        add 1 to thePosition
      end if
      if theRow is pRow then
        return thePosition
      end if
    end repeat
  end if

  return empty
end TreeRowPositionRelativeToParent


/**
* \brief Returns the tree level of a row.
*
* \param @pDataSetA A reference to the view data set.
* \param pElementKey The key of the element to determine the level of.
*
* \package Tree
*
* \return Integer
*/
function TreeLevelOfElement @pDataSetA, pElementKey
  local theLevel = "1"

  repeat until pDataSetA["objects"][pElementKey]["parent"] < 1
    add 1 to theLevel
    put pDataSetA["objects"][pElementKey]["parent"] into pElementKey
  end repeat

  return theLevel
end TreeLevelOfElement


/**
* \brief Returns whether or not a row control is highlighted.
*
* \return boolean
*/
getProp dvHilite
  local theControl
  put the dvRowControl of the target into theControl
  return the dvRow of theControl is among the items of the dvHilitedRows of me
end dvHilite


/**
* \brief Alias to dvHilitedRows.
*
* \return List of hilited rows.
*/
getprop dvHilitedRow
  return sViewPropsA["hilited rows"]
end dvHilitedRow


/**
* \brief Returns a list of rows that are hilited in the control.
*
* \return List of hilited rows.
*/
getprop dvHilitedRows
  return sViewPropsA["hilited rows"]
end dvHilitedRows


/**
* \brief Alias to dvHilitedRows.
*
* \param pRow Row to hilite.
* \param pForceScroll Will scroll the rows into view, regardless of whether or not the highlighted rows changed (unless the "scroll selections into view" property is false).
*
* \return Error message
*/
setprop dvHilitedRow[pForceScroll] pRows
  local theRowsChanged

  # This property is only set by outsiders or internal methods
  # that should update the first selected row.
  put item 1 of pRows into sViewPropsA["first selected row"]

  _SetHilitedRows pRows
  put the result into theRowsChanged

  if not theRowsChanged AND pForceScroll then
    ScrollRowIntoView item 1 of pRows, the viewProp["scroll into view anchor"] of me
  end if

  return theRowsChanged
end dvHilitedRow


/**
* \brief Sets the list of rows that are hilited in the control.
*
* \param pRows List of rows to hilite.
* \param pForceScroll Will scroll the rows into view, regardless of whether or not the highlighted rows changed (unless the "scroll selections into view" property is false).
*
* \return Error message
*/
setprop dvHilitedRows[pForceScroll] pRows
  set the dvHilitedRow[pForceScroll] of me to pRows
  return the result
end dvHilitedRows


/**
* Returns the controls associated with a row.
*
* This may return empty if the row is not visible and caching is not turned on.
*
* \return Control reference
*/
getProp dvControlOfRow [pRow]
  return sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(pRow)]["control"]
end dvControlOfRow


/**
* \brief Returns whether or not a row has been rendered. It it hasn't been rendered then it is a ghost control.
*
* This property is useful when caching is set to "lazy".
*/
getProp dvControlHasBeenRendered
  if the dvRowControl of the target is not empty then
    return the dvDataCache of the dvRowControl of the target is NULL
  else
    pass dvControlHasBeenRendered
  end if
end dvControlHasBeenRendered


/**
* \brief Returns all controls in the data view cache.
*
* \return CR delimited list of controls
*/
getProp dvRowControls
  local theControls

  repeat for each key theKey in sViewPropsA["controls"]["cache"]
    put sViewPropsA["controls"]["cache"][theKey]["control"] & cr after theControls
  end repeat
  delete the last char of theControls

  return theControls
end dvRowControls


/**
* \brief Dispatchs the selectionChanged message to the behavior instance.
*
* \param pPreviouslyHilitedRows The list of rows that were hilited prior to the selection changing.
*
* return empty
*/
private command _SelectionChanged pPreviouslyHilitedRows
  dispatch "selectionChanged" with sViewPropsA["hilited rows"], pPreviouslyHilitedRows
  return empty
end _SelectionChanged


/**
* \brief Selects a control, stores it as the first one clicked on and brings focus into view.
*
* \param pControl Reference to control clicked on. It empty then default is dvRowControl.
*
* \return empty
*/
private command _SelectControl pControl
  -----
  local theRow
  local thePreviouslyHilitedRows
  -----
  if pControl is empty then put the dvRowControl of the target into pControl
  if pControl is not empty then
    put the dvRow of pControl into theRow
    put sViewPropsA["hilited rows"] into thePreviouslyHilitedRows

    ## single click always inserts index into first index var
    put theRow into sViewPropsA["first selected row"]
    _SetHilitedRows theRow

    ## Clicked on a control
    if the long ID of me is not in the long ID of the focusedObject then
      focus on graphic "dvBackground" of me
    end if

    _SelectionChanged thePreviouslyHilitedRows
  end if

  return empty
end _SelectControl


/**
* \brief Sets the list of hilited rows for the control, hilites the controls and scrolls the first one into view.
*
* \param pRows List of rows to hilite.
*
* \return Boolean value indicating whether or not hilited row changed.
*/
private command _SetHilitedRows pRows
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

  _HiliteRowsInVisibleControls

  unlock screen

  return theReturnValue
end _SetHilitedRows


/**
* \brief Tells you whether or not the last mouse click was within the content area of the control.
*
* \return Boolean
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
* \brief Returns the last row clicked on (or targeted in the case of arrowkeys or select all).
*
* \return Integer
*/
getprop dvClickRow
  return sLastTargetedRow
end dvClickRow


/**
* \brief Selects all rows in the view.
*
* \return empty
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
      _SelectionChanged thePreviouslyHilitedIndexes
    end if
    unlock screen
  end if

  return empty
end SelectAll


/**
* \brief Returns the rect of a row in the view. The rect is relative ot the card.
*
* \param pRow The row to get the rect for.
*
* \return Rect
*/
getProp dvRectOfRow[pRow]
  local theRect, theVScroll

  if pRow is an integer then
    put _RelativeRectOfRow(pRow) into theRect

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
* |brief Returns the rect of a row in relative space
*
* \param pRow The row to get the rect for.
*
* \return Rect
*/
private function _RelativeRectOfRow pRow
  local theRect

  local theContentHeight, theControlHeight, theRowWidth, theIndex
  local updateViewHeight = "false"

  put 0 into item 1 of theRect
  put the viewProp["content width"] of me into item 3 of theRect
  put item 1 of _WorkingTopAndBottomContentCoordinates() into theContentHeight

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
      put _GetCacheKeyForRow(theRow) into theCacheKey
      _PrepareRowForDisplay theRow, sViewPropsA["controls"]["cache"][theCacheKey]["control"], theRowWidth
      if not updateViewHeight then put the result into updateViewHeight

      add sViewPropsA["controls"]["cache"][theCacheKey]["height"] to theContentHeight

      if pRow is theRow then
        put theContentHeight - sViewPropsA["controls"]["cache"][theCacheKey]["height"] into item 2 of theRect
        put theContentHeight into item 4 of theRect

        if updateViewHeight then
          _ConfigureScrollbars
        end if

        exit repeat
      end if
    end repeat
  end if

  return theRect
end _RelativeRectOfRow


/**
* \brief Scrolls the row to the top or bottom of the view.
*
* \param pRow The row to scroll.
* \param pPlacement Top or bottom.
*
*/
command ScrollRowTo pRow, pPlacement
  _ScrollRow pRow, pPlacement, true
  return the result
end ScrollRowTo


/**
* \brief Scrolls the specified row into view.
*
* \param pRow Row to scroll into view.
* \param pPlacement Optional parameter specifying whether row should be displayed at top or bottom of view. "top" or "bottom".
*
* \return Error message
*/
command ScrollRowIntoView pRow, pPlacement
  _ScrollRow pRow, pPlacement, false
  return the result
end ScrollRowIntoView


/**
* \brief Scrolls a row into view.
*
* \param pRow The row to scroll.
* \param [pPlacement] empty, "top" or "bottom".
* \param [pForceScroll] Pass in true along with pPlacement to force a row to top or bottom.
*
* \return Error
*/
private command _ScrollRow pRow, pPlacement, pForceScroll
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
      put _RelativeRectOfRow(pRow) into theRect

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
          StartScrollAnimation theNewVScroll
          exit repeat
        else
          local msgsAreLocked

          CancelAnimation
          put the lockMessages into msgsAreLocked
          lock messages
          set the thumbPosition of scrollbar "dvVScrollbar" of me to theNewVScroll
          set the lockMessages to msgsAreLocked
          _SetVScroll theNewVScroll

          # Use bottom to determine if control has made it into place. The bottom
          # is what will change if control is resized.
          if item 4 of _RelativeRectOfRow(pRow) is item 4 of theRect then
            unlock screen
            exit repeat
          else
            # Loop through again, calculating a new rect.
            # Note that this only applies when caching is off and row height is not fixed.
            --                  put "repeating..." && _RelativeRectOfRow(pRow) && "::" && theRect & cr after msg
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
end _ScrollRow


/**
* \brief Scrolls the specified rectangle into view. You can provide a padding for the top/bottom so that rect has spacing between top/bottom of view.
*
* \param pRect The rectangle to scroll into view.
* \param pPadding A rectangle specifying the padding to use. Only item 2 and 4 are used at this time.
*
* \return empty
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

  if _RectIsAtLeastAsTallAsMask(pRect, theMaskRect) then
    if _RectCoversMask(pRect, theMaskRect) then
      ## Rect covers entire visible area. Do nothing.
    else
      ## If rect top or bottom is visible then do nothing. Otherwise scroll top in.
      if _TopIsVisible(pRect, theMaskRect) or _BottomIsVisible(pRect, theMaskRect) then
        ## Nothing
      else
        ## Scroll up to top of control
        put theCurrentVScroll - abs(item 2 of theMaskRect - item 2 of pRect) into theVScroll
      end if
    end if
  else if _TopIsClipped(pRect, theMaskRect) then
    ## Scroll up to top of control
    put theCurrentVScroll - abs(item 2 of theMaskRect - item 2 of pRect) into theVScroll

  else if _BottomIsClipped(pRect, theMaskRect) then
    ## scroll down to bottom of control
    put theCurrentVScroll - (item 4 of theMaskRect - item theItemNo of pRect) into theVScroll
    add theScrollToOffset to theVScroll

  else if _TopAndBottomAreClipped(pRect, theMaskRect) then
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
      StartScrollAnimation theVScroll
    else
      local msgsAreLocked

      CancelAnimation
      put the lockMessages into msgsAreLocked
      lock messages
      set the thumbPosition of scrollbar "dvVScrollbar" of me to theVScroll
      set the lockMessages to msgsAreLocked
      _SetVScroll theVScroll
    end if
  end if

  return empty
end ScrollRectIntoView


/**
* |brief Scrolls the text selection into view.
*
* \return empty
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


private function _TopIsVisible pRect, pMaskRect
  return item 2 of pRect < item 4 of pMaskRect and item 2 of pRect > item 2 of pMaskRect
end _TopIsVisible


private function _BottomIsVisible pRect, pMaskRect
  return item 4 of pRect > item 2 of pMaskRect and item 4 of pRect < item 4 of pMaskRect
end _BottomIsVisible


private function _RectIsAtLeastAsTallAsMask pRect, pMaskRect
  return item 4 of pRect - item 2 of pRect >= item 4 of pMaskRect - item 2 of pMaskRect
end _RectIsAtLeastAsTallAsMask


private function _RectCoversMask pRect, pMaskRect
  return _RectIsAtLeastAsTallAsMask(pRect, pMaskRect) and \
        item 2 of pRect <= item 2 of pMaskRect and \
        item 4 of pRect >= item 4 of pMaskRect
end _RectCoversMask


private function _TopIsClipped pRect, pMaskRect
  return item 4 of pRect > item 2 of pMaskRect and item 2 of pRect < item 2 of pMaskRect
end _TopIsClipped


private function _BottomIsClipped pRect, pMaskRect
  return item 2 of pRect < item 4 of pMaskRect and item 4 of pRect > item 4 of pMaskRect
end _BottomIsClipped

private function _TopAndBottomAreClipped pRect, pMaskRect
  return item 2 of pRect >= item 4 of pMaskRect or item 4 of pRect <= item 2 of pMaskRect
end _TopAndBottomAreClipped


/**
* \brief Loops through the visible controls ("rows in use") and turns highlighting on/off as appropriate.
*
* \return empty
*/
private command _HiliteRowsInVisibleControls
  local msgsAreLocked, theBoolean

  lock screen
  put the lockMessages into msgsAreLocked
  set the lockMessages to false
  set the wholeMatches to true
  repeat for each item theRow in sViewPropsA["controls"]["rows in use"]
    put theRow is among the items of sViewPropsA["hilited rows"] into theBoolean
    _HiliteControl sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(theRow)]["control"], theBoolean
  end repeat
  set the lockMessages to msgsAreLocked
  unlock screen

  return empty
end _HiliteRowsInVisibleControls


/**
* \brief Turns the hilite for a control on/off.
*
* \param pControl Control reference.
* \param pBoolean Whether or not to turn hilite on.
*
* \return empty
*/
private command _HiliteControl pControl, pBoolean
  local theRow, theColor

  if there is a control "Background" of pControl then
    if pBoolean then
      set the backgroundColor of control "Background" of pControl to _GetHiliteColor()
    else
      set the wholeMatches to true
      put the dvRow of pControl into theRow
      if theRow mod 2 is kAlternatingRowModValue then
        set the backgroundColor of control "Background" of pControl to _GetEffectiveColor("alternate row color")
      else
        set the backgroundColor of control "Background" of pControl to _GetEffectiveColor("row color")
      end if
    end if

    put the backgroundColor of control "Background" of pControl into theColor
  else
    if pBoolean then
      put _GetHiliteColor() into theColor
    else
      put _GetEffectiveColor("row color") into theColor
    end if
  end if

  local msgsAreLocked

  put the lockMessages into msgsAreLocked
  unlock messages
  set the dvHilite [theColor] of pControl to pBoolean
  set the lockMessages to msgsAreLocked

  return empty
end _HiliteControl


private function _GetHiliteColor
  local theColor

  --   put the long id of me & cr & the long id of the focusedObject & cr & the executioncontexts
  if the long ID of me is not in the long ID of the focusedObject and the viewProp["dim on focusOut"] of me is not false then
    put _GetEffectiveColor("dimmed hilite color") into theColor
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
end _GetHiliteColor


private function _GetEffectiveColor pProperty
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
          return _GetEffectiveColor("row color")
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
          put _GetHiliteColor("hilite color") into theHiliteColor
          if the number of items of theHiliteColor is not 3 then put _ColorToRGB(theHiliteColor) into theHiliteColor
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
end _GetEffectiveColor


private function _ColorToRGB pColor
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
end _ColorToRGB


private function _IsThisModifierSetActive pModifiers
  local theState

  replace "alt" with "option" in pModifiers

  set the wholeMatches to true

  put the optionKey into theState
  if "option" is among the items of pModifiers then
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

  if the platform is "MacOS" then
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
    if "command" is among the items of pModifiers or "control" is among the items of pModifiers then
      if theState is "up" then
        return false
      end if
    else if theState is "down" then
      return false
    end if
  end if

  return true
end _IsThisModifierSetActive


/**
* \brief Implements scroll wheel scrolling for the control.
*
* pKeyNum See LiveCode docs.
*
* \return empty
*/
on rawKeyDown pKeyNum
  ## exit immediately if an editable field is the target and action isn't scroll wheel.
  set the wholeMatches to true
  if word 1 of the target is "field" AND not the locktext of the target then
    if pKeyNum is not among the items of kKeyNumsThatScroll then
      pass rawkeyDown
    else if the long id of the target is the focusedObject AND the vscrollbar of the target then
      # If field has focus then scroll actions should be hanndled by field
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
  local theAvailHeight, theScroll

  switch pKeyNum
    case "65360"
      ## home
      if the visible of scrollbar "dvVScrollbar" of me or the viewProp["scroll when vScrollbar is hidden"] of me then
        set the viewProp["vscroll"] of me to 0
      end if
      break
    case "65367"
      ## end
      if the visible of scrollbar "dvVScrollbar" of me or the viewProp["scroll when vScrollbar is hidden"] of me then
        set the viewProp["vscroll"] of me to the endValue of scrollbar "dvVScrollbar" of me
      end if
      break
    case "65365"
      ## scroll page up
      if the visible of scrollbar "dvVScrollbar" of me or the viewProp["scroll when vScrollbar is hidden"] of me then
        set the viewProp["vscroll"] of me to the thumbPosition of scrollbar "dvVScrollbar" of me - \
              the pageIncrement of scrollbar "dvVScrollbar" of me
      end if
      break
    case "65366"
      ## scroll page down
      if the visible of scrollbar "dvVScrollbar" of me or the viewProp["scroll when vScrollbar is hidden"] of me then
        set the viewProp["vscroll"] of me to the thumbPosition of scrollbar "dvVScrollbar" of me + \
              the pageIncrement of scrollbar "dvVScrollbar" of me
      end if
      break
    case "65309"    # scroll up
      ## mouse wheel up

      ## If a field editor is open then it must be closed first
      if the viewProp["cache"] of me is "none" and the viewProp["field editor is open"] of me then --sViewPropsA["field editor"]["control"] is not empty and there is a sViewPropsA["field editor"]["control"] then
        DeleteFieldEditor true, "close control"
      else
        if the visible of scrollbar "dvVScrollbar" of me or the viewProp["scroll when vScrollbar is hidden"] of me then
          put the viewProp["content window height"] of me into theAvailHeight
          put round(theAvailHeight * .1) into theScroll
          set the viewProp["vscroll"] of me to round(the thumbPosition of scrollbar "dvVScrollbar" of me) - theScroll
        end if
      end if
      break
    case "65308"    # scroll down
      ## mouse wheel down

      ## If a field editor is open then it must be closed first
      if the viewProp["cache"] of me is "none" and the viewProp["field editor is open"] of me then --sViewPropsA["field editor"]["control"] is not empty and there is a sViewPropsA["field editor"]["control"] then
        DeleteFieldEditor true, "close control"
      else
        if the visible of scrollbar "dvVScrollbar" of me or the viewProp["scroll when vScrollbar is hidden"] of me then
          put the viewProp["content window height"] of me into theAvailHeight
          put round(theAvailHeight * .1) into theScroll
          set the viewProp["vscroll"] of me to round(the thumbPosition of scrollbar "dvVScrollbar" of me) + theScroll
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


--after mouseDown pMouseBtnNum
--   if the environment is not "mobile" then
--      # For more complicated dataview behavior the developer may
--      # want to call dvMouseDownAfter manually.
--      if the viewProp["process mousedown"] of me is not false then
--         dvMouseDownAfter pMouseBtnNum
--      end if
--   end if
--   pass mousedown
--end mouseDown


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


local sTouchA # for swiping

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
          (sViewPropsA["field editor"]["control"] is not empty and sViewPropsA["field editor"]["control"] is the long ID of the focusedObject) then
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
    _HiliteRowsInVisibleControls
  end if

  ## If the selection hasn't changed then at least update the hilites as they
  ## may be grayed out. If one day we can get a true focusIn message for the group
  ## as a whle then the 'else' condition can be removed.
  --   if theSelectionChanged then _SelectionChanged thePreviouslyHilitedRows
  --   else _HiliteRowsInVisibleControls
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
    _SelectionChanged thePreviouslyHilitedRows
  end if
end touchEnd


/**
* \brief Sent in cases where user touches row, holds but then starts scrolling.
*
*/
on touchRelease
  set the dvHilitedRows of me to empty
end touchRelease


/**
* |brief Determines whether a left or right swipe has occurred on the data view.
*
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


local sMouseDownA # before handler stores data in this variable that after handler uses.


/**
* \brief Developers who override mousedown can use this call.
*
*/
command dvMouseDown pMouseBtnNum
  dvMouseDownBefore pMouseBtnNum
  dvMouseDownAfter pMouseBtnNum
end dvMouseDown


/**
* \brief Selects rows in the view prior to the developer mouseDown being processed.
*
*/
command dvMouseDownBefore pMouseBtnNum
  # If user is holding down command or option then mouseDown is sent to an editable field.
  if word 1 of the target is "field" and not the lockText of the target then exit dvMouseDownBefore

  local theRow, theIndex, theControl

  ## figure out the row clicked on
  put empty into theIndex
  put the dvRowControl of the target into theControl
  if theControl is not empty then
    put the dvRow of theControl into theRow
  end if

  put theRow into sLastTargetedRow

  ## Bring focus into control. Do this before any possible exit points.
  if theRow is not empty then
    ## Clicked on a control. Bring focus into control but away from scrollbar.
    if the long ID of me is not in the long ID of the focusedObject or word 1 of the target is "scrollbar" or \
          (sViewPropsA["field editor"]["control"] is not empty and sViewPropsA["field editor"]["control"] is the long ID of the focusedObject) then
      focus on graphic "dvBackground" of me
    end if
  else
    ## clicked in space but no on list control
    focus on graphic "dvBackground" of me
  end if

  if the viewProp["autohilite"] of me is false then return empty
  ## Allow for rows that can't be clicked.
  ## Send message to target so developer can determine whether or not to select
  ## based on what was clicked on.
  if theControl is not empty AND the dvCanSelect of the target is false then return empty

  put false into sMouseDownA["selection changed"]

  lock screen
  set the wholeMatches to true

  ## No do what we need to do
  if theRow is not empty then
    local theHilitedRows, theItemNo

    put sViewPropsA["hilited rows"] into theHilitedRows
    put sViewPropsA["hilited rows"] into sMouseDownA["previously hilited rows"]

    if pMouseBtnNum is 1 then
      if _IsThisModifierSetActive("command") and the viewProp["multiple lines"] of me then
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
        _HiliteRowsInVisibleControls
        put true into sMouseDownA["selection changed"]

        ## Update reference for shift clicking
        if theHilitedRows is empty then
          put empty into sViewPropsA["first selected row"]
        else if the number of items of theHilitedRows is 1 then
          put theRow into sViewPropsA["first selected row"]
        end if

      else if _IsThisModifierSetActive("shift") and the viewProp["multiple lines"] of me then
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
        _HiliteRowsInVisibleControls
        put true into sMouseDownA["selection changed"]
      end if

    else
      ## If clicking on a selected control then delay deselecting until mouseUp.
      ## This allows for drag/drop of multi controls.
      ## Only applies if no modifier is down or option is down as option can be used for dragging.
      if the viewProp["multiple lines"] of me and theRow is among the items of sViewPropsA["hilited rows"] AND ( _IsThisModifierSetActive("") OR _IsThisModifierSetActive("option") ) then
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
      _HiliteRowsInVisibleControls

      # This is the only place we send selection changed prior to the developer getting the message
      # as the selection needs to occur prior to showing contextual menus.
      unlock screen
      _SelectionChanged sMouseDownA["previously hilited rows"]
      put empty into sMouseDownA
    else
      put empty into sMouseDownA
    end if
  end if
end if

return empty
end dvMouseDownBefore


/**
* \brief Sends the selection changed message or updates hilited rows after developer mouseDown is processed.
*
*/
command dvMouseDownAfter pMouseBtnNum
  if the keys of sMouseDownA is empty then exit dvMouseDownAfter

  unlock screen # Now we unlock after before handler and developer handler have finished executing.

  if sMouseDownA["select control"] is not empty then
    if there is a sMouseDownA["select control"] then
      _SelectControl sMouseDownA["select control"]
    end if
  else if sMouseDownA["selection changed"] then
    _SelectionChanged sMouseDownA["previously hilited rows"]
  else
    ## If the selection hasn't changed then at least update the hilites as they
    ## may be grayed out. If one day we can get a true focusIn message for the group
    ## as a whole then the 'else' condition can be removed.
    _HiliteRowsInVisibleControls
  end if
  put empty into sMouseDownA
  return empty
end dvMouseDownAfter


command dvMouseUp pMouseBtnNum
  if sViewPropsA["deselect on mouseUp"] then
    _SelectControl
    put false into sViewPropsA["deselect on mouseUp"]

  else if sViewPropsA["select on mouseUp"] is not empty then
    local theControl

    # Control should handle selections in mouseUp rather than mouseDown. Usually done when drag/drop needs to happen before loading of data.
    put sViewPropsA["select on mouseUp"] into theControl
    put empty into sViewPropsA["select on mouseUp"]
    _SelectControl theControl
  end if
  return empty
end dvMouseUp


on dvMouseRelease pMouseBtnNum
  put false into sViewPropsA["deselect on mouseUp"]
  return empty
end dvMouseRelease


getProp dvControl
  return the long id of me
end dvControl


setProp dvFocus pBoolean
  if pBoolean then
    if the long id of me is not in the long id of the focusedObject then
      focus on graphic "dvBackground" of me
    end if
  else
    focus on nothing
  end if
end dvFocus


getProp viewProp [pProp]
  switch pProp
    case "number of rows"
      ## Can we cache this so we don't make so many calls?
      ## Cache when rendering view. Update if row added or deleted.
      local theValue
      dispatch function "NumberOfRows"
      if it is "handled" then put the result into theValue
      put max(0,theValue) into theValue
      break

    case "opaque"
      return the visible of graphic "dvBackground" of me

    case "background color"
      return the backgroundColor of graphic "dvBackground" of me

    case "vscroll percent"
      return _GetVScrollPercent()
      break

    case "content width"
      return the width of group "dvListMask" of me
      break

    case "content window height"
      return _GetContentWindowHeight()
      break

    case "content window rect"
      return the rect of group "dvListMask" of me
      break

    case "field editor is open"
      return there is a sViewPropsA["field editor"]["control"] and not sViewPropsA["field editor"]["closing"]
      break

    case "field editor"
      if there is a sViewPropsA["field editor"]["control"] then
        return sViewPropsA["field editor"]["control"]
      else
        return empty
      end if
      break

    case "field editor name"
      return kFieldEditorName
      break

    case "field editor content has changed"
      local theEditor

      put sViewPropsA["field editor"]["control"] into theEditor
      if there is a theEditor then
        set the caseSensitive to true
        return the styledText of theEditor is not the dvOriginalStyledText of theEditor
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
      if the environment is "mobile" then
        mobileControlSet sScrollerID, "vScroll", pValue
      else
        _SetVScroll pValue
      end if
      break
    case "vscroll percent"
      _SetVScrollPercent pValue
      break
    case "hscroll"

      break
    case "drop indicator template"
      if pValue is not empty then
        put _CustomControlReference(pValue) into pValue
      end if
      set the viewProp[pProp] of me to pValue
      break
    case "row style templates"
      if pValue is an array then
        repeat for each key theKey in pValue
          if pValue[theKey] is not empty then
            put _CustomControlReference(pValue[theKey]) into pValue[theKey]
          end if
        end repeat
      else
        if pValue is not empty then put _CustomControlReference(pValue) into pValue
        put pValue into pValue["default"]
      end if
      set the viewProp[pProp] of me to pValue
      break
    default
      set the viewProp[pProp] of me to pValue
      break
  end switch

  ## Redraw as needed
  switch pProp
    case "hilite color"
      _HiliteRowsInVisibleControls
      break
  end switch

  return empty
end viewProp


private function _GetContentWindowHeight
  return the height of group "dvListMask" of me
end _GetContentWindowHeight


/**
* \brief Renders the data in the view using the current vscroll. The 'hilited rows' property will be reset.
*
* All controls will be updated with latest data. If caching is on this means all controls get new data.
* Any controls which have not yet been cached will be cached during this call. No controls will be recreated.
*
* \return empty
*/
command RenderView
  put empty into sViewPropsA["hilited rows"]
  put empty into sViewPropsA["running actions"]
  _RenderView
  return the result
end RenderView


/**
* \brief Internal helper which renders the data in the view using the current vscroll.
*
* \param pRefreshDataInCachedControls If false and caching is on then cached controls will not have data updated. Only non-existent controls will be added to the cache. This can speed things up when refreshing due to row order changing.
*
* All controls will be updated with latest data. If caching is on this means all controls get new data.
* Any controls which have not yet been cached will be cached during this call. No controls will be recreated.
*
* \return empty
*/
private command _RenderView pRefreshDataInCachedControls
  local msgsAreLocked, theFocusedObject, theSelChunk

  ## Throttle
  if sViewPropsA["running actions"]["render"] then
    put true into sViewPropsA["running actions"]["resend render"]
    put pRefreshDataInCachedControls into sViewPropsA["running actions"]["resend render param"]
    return empty
  end if
  put true into sViewPropsA["running actions"]["render"]

  put pRefreshDataInCachedControls is not false into pRefreshDataInCachedControls

  _Init

  lock screen

  put the lockMessages into msgsAreLocked
  if the long id of me is in the focusedObject then
    put the focusedObject into theFocusedObject
    if word 1 of theFocusedObject is "field" then
      put the selectedChunk into theSelChunk
    end if
    lock messages
    focus on nothing
  end if
  unlock messages

  --   ## If not fixed row height then it requires caching.
  --   if not the viewProp["fixed row height"] of me AND the viewProp["cache"] of me is not among the items of "eager,lazy" then
  --      set the viewProp["cache"] of me to "lazy"
  --   end if

  ## Cache controls based on settings
  if the viewProp["cache"] of me is among the items of "eager,lazy" then
    _UpdateControlCache 0, 0 # This cleans up the current rows in use
    _RefreshRowCacheKeys # This remaps data cache keys to the appropriate row.
    _CacheControls pRefreshDataInCachedControls # This caches the controls, creating as needed, and associating them with a row.
  else if not the viewProp["fixed row height"] of me then
    _UpdateControlCache 0, 0
    _InitializeHeightsForVariableSizedRows
  else
    _UpdateControlCache 0, 0
  end if

  ## Start from scratch
  put empty into sViewPropsA["controls"]["rows in use"]

  ## Resize all controls right away if "eager"
  # TODO: [Optimization] When resizing for the first time we should look for auto hide scrollbars.
  #       Once height gets above view height then turn scrollbars on (if need be) and start sizing over).
  if the viewProp["cache"] of me is "eager" then
    _ResizeControls
  end if

  _CalculateContentHeight

  local theVscroll

  ## Make sure vscroll is in bounds
  put max(0, min(the viewProp["vscroll"] of me, the viewProp["content height"] of me - _GetContentWindowHeight())) into theVscroll

  lock messages
  set the viewProp["vscroll"] of me to theVscroll
  unlock messages

  RenderVisibleRows

  lock messages

  _ConfigureScrollbars ## It is possible that this call is redundant as RenderVisibleRows may call it. No big deal though.

  # If focus was in data view prior to start then refocus now if it still exists.
  if theFocusedObject is not empty then
    if there is a theFocusedObject then
      if theSelChunk is not empty then
        select theSelChunk
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

  set the lockMessages to msgsAreLocked

  put false into sViewPropsA["running actions"]["render"]

  if sViewPropsA["running actions"]["resend render"] then
    get sViewPropsA["running actions"]["resend render param"]
    send "RunRenderViewAgain it" to me in 0 milliseconds
    put false into sViewPropsA["running actions"]["resend render"]
    put empty into sViewPropsA["running actions"]["resend render param"]
  end if

  return empty
end _RenderView


command RunRenderViewAgain pRefreshDataInCachedControls
  _RenderView pRefreshDataInCachedControls
end RunRenderViewAgain


/**
* \brief Fills in starting values for heights for all rows when row heights are not fixed and caching is not on.
*
* Currently each row is seeded with a NULL value. This helps us determine which ones have
* been sized and which ones haven't.
*/
private command _InitializeHeightsForVariableSizedRows
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
end _InitializeHeightsForVariableSizedRows


/**
* \brief Refresh the view by making sure the proper data is mapped to the proper row.
*
* The purpose of this handler is to ensure that the proper data is mapped to the proper row
* in the view. It can be called after reordering rows, deleting rows, adding rows, etc.
*
* If caching is on then the cache keys for each row will be updated, clearing controls as necessary, and any new controls will be initialized/displayed.
*
* If caching is off then the normal draw routines are called.
*
* \return empty
*/
command RefreshViewRows
  _RenderView false
  return the result
end RefreshViewRows


/**
* \brief Refreshes the data in the specified rows.
*
* \param pRows
*
* If a row does not have a control associated with it then nothing will happen.
*
* \return empty
*/
command RenderRows pRows
  local theRow, theIndex
  local theDataA, theControl, theStyle
  local updateTheScrollbars = "false"
  local msgsAreLocked, theRowWidth, theCacheKey

  put the viewProp["content width"] of me into theRowWidth

  put the lockMessages into msgsAreLocked
  unlock messages
  lock screen

  set the lockUpdates of group "dvList" of me to kLockUpdatesSetting

  ## Update existing rows
  repeat for each item theRow in pRows
    put _DispatchCacheKeyForRow(theRow) into theCacheKey # don't use cached key
    put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into theControl

    if theControl is not empty then
      # Reset data array each time through loop
      put empty into theDataA
      put empty into theStyle

      ## Since we are rendering from scratch dvControlHasBeenRendered should return false during the next two messages
      lock messages
      set the dvDataCache of theControl to empty
      unlock messages

      ## Implemented by instance of behavior
      dispatch "DataForRow" to me with theRow, theDataA, theStyle ## style is ignored for a refresh (dispatch forces target)
      dispatch "FillInData" to theControl with theDataA, theRow

      lock messages
      set the dvDataCache of theControl to NULL
      unlock messages

      _DispatchLayoutControl theControl, theRow, theRowWidth, true
      put true into updateTheScrollbars
    end if
  end repeat

  set the lockUpdates of group "dvList" of me to false

  if updateTheScrollbars then
    ## Update everything
    _CalculateContentHeight
    lock messages
    _ConfigureScrollbars ## note that messages are locked so no scrollbar drag is sent
    unlock messages
    RenderVisibleRows

    # 2015-12-21: Added so we could move objects along with the DataView.
    dispatch "DataViewDidUpdateView" to me
  end if

  unlock screen
  set the lockMessages to msgsAreLocked

  return empty
end RenderRows


/**
* \brief Removes the specified row from the view. Use when data is removed from the model.
*
* \param pRows The rows to delete.
*
* This handler is most useful when caching is turned on.
*
* \return empty
*/
command DeleteRows pRows
  local theRow, theCacheKey, theItemNo
  local theControl
  local clearTheCache
  local msgsAreLocked

  put the lockMessages into msgsAreLocked
  lock screen

  set the wholeMatches to true

  put the viewProp["cache"] of me is not among the items of "eager,lazy" into clearTheCache

  ## Go backwards so as not to mess up index offsets 11-08-2012: Not sure if this is still relevants
  sort items of pRows descending numeric

  ## Move control back into cache of available controls
  repeat for each item theRow in pRows
    put _GetCacheKeyForRow(theRow) into theCacheKey
    if sViewPropsA["controls"]["cache"][theCacheKey] is an array then
      put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into theControl

      if there is a theControl then
        if clearTheCache then
          _MoveCachedControlBackIntoCacheBin theCacheKey, theRow # this sends cleanup message
        else
          # Send message to control telling it to clean up after itself
          dispatch "CleanupAfterRowControl" to theControl

          lock messages
          if the long id of theControl is in the focusedObject then
            focus on graphic "dvBackground" of me ## engine doesn't like the focused control in a group being deleted
          end if
          delete theControl
          unlock messages

          delete local sViewPropsA["controls"]["row cache keys"][theRow] # break link between row and cache key
          delete local sViewPropsA["controls"]["cache"][theCacheKey]
        end if
      else
        # control doesn't exist but we still need to purge the cachekey stuff
        delete local sViewPropsA["controls"]["row cache keys"][theRow] # break link between row and cache key
        delete local sViewPropsA["controls"]["cache"][theCacheKey]
      end if
    end if

    # Remove from rows in use
    put itemOffset(theRow, sViewPropsA["controls"]["rows in use"]) into theItemNo
    if theItemNo > 0 then
      delete item theItemNo of sViewPropsA["controls"]["rows in use"]
    end if
  end repeat

  # If caching is on then all row -> cache keys must be updated.
  if not clearTheCache then
    _UpdateControlCache 0, 0 # This cleans up the current rows in use (HAS to happen before refreshing cache keys otherwise cached keys and rows won't match up)
    _RefreshRowCacheKeys # This remaps data cache keys to the appropriate row.
  end if

  _EnsureIntegrityOfSelectedRows

  ## Redraw everything. Note that RefreshViewRows won't reload data in cached controls, just refresh the view.
  RefreshViewRows
  set the lockMessages to msgsAreLocked

  unlock screen

  return empty
end DeleteRows


/**
* \brief Makes sure that the "hilited rows" and "first selected row" are in bounds for how many rows are in view.
*
* This is useful after internal operations which might remove rows from the view.
*
*/
private command _EnsureIntegrityOfSelectedRows
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
end _EnsureIntegrityOfSelectedRows


/**
* \brief Moves the control for an index back into the list of available controls.
*
* \param pCacheKey The cache key of the control to move back to to the cache of available controls.
* \param [pRow] Pass in the row to dissassociate the row with the the cache key.
*
* \return empty
*/
private command _MoveCachedControlBackIntoCacheBin pCacheKey, pRow
  local theControl, theItemNo, removeFromCache

  put sViewPropsA["controls"]["cache"][pCacheKey]["control"] into theControl
  if there is a theControl then
    dispatch "HideRowControl" to theControl
    set the visible of theControl to false

    # Send message to control telling it to clean up after itself
    dispatch "CleanupAfterRowControl" to theControl

    ## Move back into pool of available controls
    if the viewProp["cache"] of me is "none" then
      put theControl into \
            line (the number of lines of sViewPropsA["controls"]["available"] + 1) of sViewPropsA["controls"]["available"]
    end if
  end if

  delete local sViewPropsA["controls"]["cache"][pCacheKey]
  if pRow is an integer then
    delete local sViewPropsA["controls"]["row cache keys"][pRow] # break link
  end if

  return empty
end _MoveCachedControlBackIntoCacheBin


/**
* \brief Resizes the specified row controls. Useful for cached controls that can be resized by the user.
*
* \param pRows
*
* \return empty
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
* \brief Sets the values for scrollbars based on the content in the control.
*
* This handler will maintain the current thumbposition of the scrollbar value.
*
* \return empty
*/
private command _ConfigureScrollbars
  local msgsAreLocked, theWindowHeight
  local theEndValue, thePageIncrement
  local theVScroll

  put _GetContentWindowHeight() into theWindowHeight
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

    _SetMobileScrollerContentRect
  end if

  return empty
end _ConfigureScrollbars


/**
* \brief Prcoesses the message for the scrollbars.
*
*/
on scrollbarDrag pValue
  if the short name of the target is "dvVScrollbar" then
    --      put pValue && the viewProp["vscroll"] of me && the viewProp["content height"] of me & cr after msg
    if pValue is not the viewProp["vscroll"] of me then
      lock messages
      _SetVScroll pValue ## in case messages are locked
      unlock messages
    end if
  end if
end scrollbarDrag


/**
* \brief Called by mobile scrollbars.
*
* \return empty
*/
on scrollerDidScroll pOffsetX, pOffsetY
  -- Set the scroll values of the group based on feedback from the scroller
  -- notice that we can just use the values directly and because out-of-bounds
  -- scrolling is enabled for the group, the bounce effect needs no extra
  -- code.
  _SetVScroll pOffsetY
end scrollerDidScroll


private command _SetVScroll pValue
  local msgsAreLocked, refocusOnMe, theSelectedChunk, theOrigThumb
  local refocusOnFieldEditor = "false"

  ## First set the vscroll and draw
  put the long id of me is in the focusedObject into refocusOnMe
  put the lockMessages into msgsAreLocked
  unlock messages
  if refocusOnMe and the viewProp["field editor is open"] of me then
    put true into refocusOnFieldEditor
    put the selectedChunk into theSelectedChunk
  end if

  lock screen

  ## If an editor is present and focused then we don't want to close it when focus leaves.
  if refocusOnFieldEditor then
    lock messages
    focus on nothing
  end if

  ## Should we enable this for Lion as well?
  if the environment is not "mobile" then
    --      put max( \
        --            min(pValue, the viewProp["content height"] of me + the viewProp["content bottom padding"] of me - _GetContentWindowHeight()), \
        --            0 - the viewProp["content top padding"] of me) into pValue
    put max(0, min(pValue, the viewProp["content height"] of me - _GetContentWindowHeight())) into pValue
  end if

  --   put pValue && the viewProp["vscroll"] of me && the viewProp["content height"] of me & cr after msg

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
      _SetVScroll pValue
      exit _SetVScroll
    end if
  end if

  lock messages
  set the thumbposition of scrollbar "dvVScrollbar" of me to pValue
  unlock messages

  if refocusOnFieldEditor and there is a sViewPropsA["field editor"]["control"] then
    ## Bring focus back to the field editor but don't send any messages
    lock messages
    focus on sViewPropsA["field editor"]["control"]
    try
      select theSelectedChunk ## Make sure selection remains
    catch e
    end try
  else if refocusOnMe then
    set the dvFocus of me to true ## We like to keep focus
  end if

  unlock messages

  # 2015-12-21: Added so we could move objects along with the DataView.
  dispatch "DataViewDidUpdateView" to me

  unlock screen
  set the lockMessages to msgsAreLocked
end _SetVScroll


/**
* \brief Returns the percentage of the vscroll thumb.
*
* \return percentage.
*/
private function _GetVScrollPercent
  local theWorkingEndValue

  put the endValue of scrollbar "dvVScrollbar" of me - the thumbSize of scrollbar "dvVScrollbar" of me into theWorkingEndValue
  if theWorkingEndValue > 0 then
    return round(the thumbPosition of scrollbar "dvVScrollbar" of me) / theWorkingEndValue
  else
    return 0
  end if
end _GetVScrollPercent


/**
* \brief Returns the percentage of the vscroll thumb.
*
* \param pPercent The percentage to set the vscroll to.
*
* \return percentage.
*/
private command _SetVScrollPercent pPercent
  local theWorkingEndValue
  put the endValue of scrollbar "dvVScrollbar" of me - the thumbSize of scrollbar "dvVScrollbar" of me into theWorkingEndValue
  _SetVScroll round(theWorkingEndValue * pPercent)
end _SetVScrollPercent


/**
* \brief Draws the control based on current properties.
*
* \return Returns true if the "content height" changed while drawing.
*/
command RenderVisibleRows
  local theDataA, theStyle
  local theStartRow, theEndRow, theStartRowYOffset
  local theRowCount, theRowWidth, theOrigContentHeight
  local msgsAreLocked

  ## Throttle
  if sViewPropsA["running actions"]["vscroll"] then
    put true into sViewPropsA["running actions"]["resend vscroll"]
    return empty
  end if

  put true into sViewPropsA["running actions"]["vscroll"]

  put the lockMessages into msgsAreLocked
  unlock messages

  _GetRangeOfRowsToDisplay theStartRow, theEndRow, theStartRowYOffset  ## can alter content height

  put the viewProp["content height"] of me into theOrigContentHeight
  put the viewProp["number of rows"] of me into theRowCount
  put the viewProp["content width"] of me into theRowWidth
  --   put the viewProp["vscroll"] of me into theVScroll

  ## Update the pool of available controls
  ## and reset list of rows in use
  _UpdateControlCache theStartRow, theEndRow

  set the viewProp["first working row"] of me to theStartRow # in case developer wants to access
  set the viewProp["last working row"] of me to theEndRow

  lock screen

  local forceFillInData = "true"

  if theStartRow > 0 then
    local theTopLeft, theRowControl

    put the topleft of group "dvListMask" of me into theTopLeft
    subtract theStartRowYOffset from item 2 of theTopLeft

    set the lockUpdates of group "dvList" of me to kLockUpdatesSetting
    repeat with theRow = theStartRow to theEndRow
      ## Controls
      ## "available"
      ## "cache"
      ## "rows in use"

      ## Is there a cached control for this row?
      put sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(theRow)]["control"] into theRowControl

      ## No control? Get data and get one.
      if theRowControl is empty then
        _SetupRowControl theRow, empty, forceFillInData
        put the result into theRowControl
        if theRowControl is empty then exit repeat

        set the topleft of theRowControl to theTopLeft
        # Don't update height. We only get here if caching is off. Heights have already been determined previously.
        _DispatchLayoutControl theRowControl, theRow, theRowWidth, false
      else
        _PrepareRowForDisplay theRow, theRowControl, theRowWidth, theTopLeft
      end if

      if not the visible of theRowControl then
        # Send message to control telling it that it is being displayed
        dispatch "ShowRowControl" to theRowControl
        set the visible of theRowControl to true
      end if

      if theRow is among the items of sViewPropsA["hilited rows"] then
        _HiliteControl theRowControl, true
      else
        _HiliteControl theRowControl, false
      end if

      put the bottom of theRowControl into item 2 of theTopLeft

      # relayer row control so that tabbing through controls works as expected.
      lock messages
      relayer theRowControl to front of group "dvList" of me
      unlock messages
    end repeat
  end if ## startrow > 0

  set the lockUpdates of group "dvList" of me to false

  if the viewProp["content height"] of me is not theOrigContentHeight then
    _ConfigureScrollbars
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
* \brief Returns the cache key in sViewPropsA["controls"]["cache"] for a given row.
*
* \param pRow The row to get the key for.
* \param pRefreshKey If true then a fresh key will be retrieved for the row. Otherwise an internal cache may be used.
*
* \return Key or empty if no control is cached for the specified row.
*/
private function _GetCacheKeyForRow pRow, pRefreshKey
  if pRow is not an integer then
    return empty
  else
    local theCacheKey

    put pRefreshKey is true into pRefreshKey

    if not pRefreshKey then
      put sViewPropsA["controls"]["row cache keys"][pRow] into theCacheKey
    end if

    if theCacheKey is empty then
      put _DispatchCacheKeyForRow(pRow) into theCacheKey
    end if

    if theCacheKey is among the keys of sViewPropsA["controls"]["cache"] then
      put theCacheKey into sViewPropsA["controls"]["row cache keys"][pRow]
      return theCacheKey
    else
      return empty
    end if
  end if
end _GetCacheKeyForRow


/**
* \brief Refreshes the cache key for each row. Only applies if caching is on.
*
* \param pRemoveStaleCacheKeys If true then stale caches will be removed. Default is false.
*
* \return empty
*/
private command _RefreshRowCacheKeys pRemoveStaleCacheKeys
  local refreshKeys

  set the wholematches to true

  put the viewProp["cache"] of me is among the items of "eager,lazy" into refreshKeys
  --   put the viewProp["cache"] of me is among the items of "eager,lazy" OR \
        --         (the viewProp["cache"] of me is "none" and not the viewProp["fixed row height"] of me) into refreshKeys
  put pRemoveStaleCacheKeys is true into pRemoveStaleCacheKeys

  if refreshKeys then
    local theRow, theControl, theCacheKeys, theCacheKey

    # Make a list of cache keys, one per line
    repeat with theRow = 1 to the viewProp["number of rows"] of me
      put _DispatchCacheKeyForRow(theRow) & cr after theCacheKeys
    end repeat
    delete the last char of theCacheKeys

    # look for stale keys
    if pRemoveStaleCacheKeys then
      repeat for each key theRow in sViewPropsA["controls"]["row cache keys"]
        # Check for match between old row cache key and new row cache key
        if line theRow of theCacheKeys is not sViewPropsA["controls"]["row cache keys"][theRow] then

          # Now check if cache key is in new list at all
          if sViewPropsA["controls"]["row cache keys"][theRow] is not among the lines of theCacheKeys then

            # Nope. Clean out the cache key entry.
            put sViewPropsA["controls"]["cache"][ sViewPropsA["controls"]["row cache keys"][theRow] ]["control"] into theControl

            # Send message to control telling it to clean up after itself
            dispatch "CleanupAfterRowControl" to theControl

            lock messages
            if the long id of theControl is in the focusedObject then
              focus on graphic "dvBackground" of me ## engine doesn't like the focused control in a group being deleted
            end if
            delete theControl
            unlock messages

            delete local sViewPropsA["controls"]["cache"][ sViewPropsA["controls"]["row cache keys"][theRow] ] # delete cache entry
            delete local sViewPropsA["controls"]["row cache keys"][theRow] # break link between row and cache key
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
end _RefreshRowCacheKeys


/**
* \brief Looks to see if a control needs to be filled in with data (ghost controls) or resized and then peforms necessary actions.
*
* \param pRow The row number of the control.
* \param pRowControl Reference to the row control.
* \param pRowWidth The width to assign to the row if it must be resized.
* \param pTopLeft Optional point to set the topleft of the control to.
*
* \return Boolean. True if control was updated. False otherwise.
*/
private command _PrepareRowForDisplay pRow, pRowControl, pRowWidth, pTopLeft
  local controlWasUpdated = "false"
  local msgsAreLocked

  ## Always update
  put the lockMessages into msgsAreLocked
  lock messages
  if pTopLeft is a point then set the topleft of pRowControl to pTopLeft
  set the dvRow of pRowControl to pRow

  if the dvDataCache of pRowControl is not NULL then
    local theDataA

    ## Ghost control
    put the dvDataCache of pRowControl into theDataA
    unlock messages
    dispatch "FillInData" to pRowControl with theDataA, pRow

    lock messages
    set the dvDataCache of pRowControl to NULL
    unlock messages
    _DispatchLayoutControl pRowControl, pRow, pRowWidth, true
    put true into controlWasUpdated
  else
    ## Regular control
    if sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(pRow)]["resize"] then
      unlock messages
      _DispatchLayoutControl pRowControl, pRow, pRowWidth, true
      put true into controlWasUpdated
    end if
  end if

  set the lockMessages to msgsAreLocked

  return controlWasUpdated
end _PrepareRowForDisplay


/**
* \brief Determines the "content height" based on current properties and data.
*
* \return empty
*/
private command _CalculateContentHeight pRefreshHeight
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
    _StoreContentHeightForCachedControls
  end if

  ## Auto-hide
  _AutoHideScrollbars

  set the lockMessages to msgsAreLocked

  return empty
end _CalculateContentHeight


private command _StoreContentHeightForCachedControls
  local theRow, theContentHeight="0"

  repeat with theRow = 1 to the viewProp["number of rows"] of me
    add sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(theRow)]["height"] to theContentHeight
  end repeat
  set the viewProp["content height"] of me to theContentHeight \
        + the viewProp["content top padding"] of me + the viewProp["content bottom padding"] of me
end _StoreContentHeightForCachedControls


/**
* \brief Hides/shows the scrollbars as appropriate.
*
*/
private command _AutoHideScrollbars
  local msgsAreLocked

  put the lockMessages into msgsAreLocked
  set the lockMessages to false

  ## Auto-hide
  if the viewProp["autohide scrollbars"] of me AND sScrollerId is empty then
    if the viewProp["content height"] of me <= _GetContentWindowHeight() then
      ## hide
      if the visible of scrollbar "dvVScrollbar" of me then
        set the visible of scrollbar "dvVScrollbar" of me to false
        _ResizeListControls
        _TellControlsToResize
      end if
    else
      ## show
      if not the visible of scrollbar "dvVScrollbar" of me then
        set the visible of scrollbar "dvVScrollbar" of me to true
        _ResizeListControls
        _TellControlsToResize
      end if
    end if
  end if

  set the lockMessages to msgsAreLocked

  return empty
end _AutoHideScrollbars


/**
* \brief Caches controls for all rows in the view.
*
* \param pRefreshDataInCachedControls If true and caching is on then cached controls will not have data updated. Only non-existent controls will be added to the cache. This can speed things up when refreshing due to row order changing.
*
* How controls are cached is dependent on the 'cache' setting.
* If 'cache' is set to 'eager" then all rows are cached with FillInData being sent to them.
* If 'cache' is set to "lazy" then a ghost control is cached meaning
* that no FillInData message is sent.
*
* \return empty
*/
private command _CacheControls pRefreshDataInCachedControls
  local theRowCount, theRow
  local msgsAreLocked, theRowControl

  put pRefreshDataInCachedControls is not false into pRefreshDataInCachedControls
  put the lockMessages into msgsAreLocked

  unlock messages
  put the viewProp["number of rows"] of me into theRowCount

  lock messages

  ## Create row controls
  repeat with theRow = 1 to theRowCount
    ## Is there a cached control for this row?
    put sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(theRow)]["control"] into theRowControl

    # Get out early if not updating data
    if not pRefreshDataInCachedControls AND theRowControl is not empty then
      # control may have a text editor open
      dispatch "HideRowControl" to theRowControl
      set the visible of theRowControl to false
      next repeat
    end if

    ## If theRowControl is not empty then it will be refreshed with latest data.
    ## If it is empty then a control will be provided.
    _SetupRowControl theRow, theRowControl
    put the result into theRowControl

    if theRowControl is not empty then
      dispatch "HideRowControl" to theRowControl
      set the visible of theRowControl to false
    end if
  end repeat

  set the lockMessages to msgsAreLocked

  return empty
end _CacheControls


/**
* \brief Sets up a control for a row. Data will be filled in or cached with control based on 'cache' property.
*
* \param pRow Row to set up control for.
* \param pRowControl If passed in then used as the row control and data within it is updated. Otherwise one is provided. Passing it in is used when refreshing cached controls with new data.
* \param pForceFillInData Pass in true to force FillInData to be sent, even if lazy caching is set. Used if you are definitly about to display the row.
*
* \return Control reference
*/
private command _SetupRowControl pRow, pRowControl, pForceFillInData
  local theDataA
  local theStyle, cacheTheControl

  ## Implemented by instance of behavior
  dispatch "DataForRow" to me with pRow, theDataA, theStyle
  put pRowControl is empty into cacheTheControl

  if theStyle is empty then put "default" into theStyle

  if pRowControl is empty then
    put _GetControlOfStyle(theStyle) into pRowControl
  end if

  if pRowControl is not empty then
    if cacheTheControl then
      _CacheRowControl pRow, pRowControl
    end if

    ## If fixed row height then lock it in
    if the viewProp["fixed row height"] of me then
      set the height of pRowControl to the viewProp["row height"] of me
    end if

    ## Lock the size
    set the lockLoc of pRowControl to true

    local msgsAreLocked
    put the lockMessages into msgsAreLocked
    lock messages
    set the dvRow of pRowControl to pRow
    set the dvTemplateStyle of pRowControl to theStyle
    unlock messages

    if the viewProp["cache"] of me is not "lazy" OR pForceFillInData then
      dispatch "FillInData" to pRowControl with theDataA, pRow
      lock messages
      set the dvDataCache of pRowControl to NULL
    else ## "lazy"
      ## Just create a "ghost" control.
      ## Store data with control. It will be loaded in later as needed
      lock messages
      set the dvDataCache of pRowControl to theDataA
    end if

    set the lockMessages to msgsAreLocked
  end if

  return pRowControl
end _SetupRowControl


/**
*\brief Resizes controls by adjusting their width and calling LayoutControl.
*
* \param pStartRow First row in range of rows to resize. Default is 1.
* \param pEndrow Last row in range of rows to resize. Default is number of rows.
* \return empty
*/
private command _ResizeControls pStartRow, pEndRow
  if sViewPropsA["controls"]["cache"] is an array then
    local msgsAreLocked, theWidth, theRowControl, theRow

    put the lockMessages into msgsAreLocked
    unlock messages

    if pStartRow is not an integer then put 1 into pStartRow
    if pEndRow is not a integer then put the viewProp["number of rows"] of me into pEndRow

    put the viewProp["content width"] of me into theWidth

    repeat with theRow = pStartRow to pEndRow
      put sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(theRow)]["control"] into theRowControl
      _DispatchLayoutControl theRowControl, theRow, theWidth
    end repeat

    set the lockMessages to msgsAreLocked
  end if

  return empty
end _ResizeControls


/**
* \brief Resizes the width of a control and sends the LayoutControl message. The control will maintain it's current topleft position.
*
* The LayoutControl handler is responsible for setting the proper height of the row control.
*
* \param pRowControl The control to send the message to.
* \param pRow The row of the control.
* \param pWidth The width to set pRowControl to.
* \param pUpdateContentHeight Pass in true to update the "content height" after calling LayoutControl. This is only applicable if 'fixed row height' is false.
*
* \return empty
*/
private command _DispatchLayoutControl pRowControl, pRow, pWidth, pUpdateContentHeight
  local theRect, theVScroll, theIndex, theCacheKey, theResult
  local theHeight, msgsAreLocked

  if the viewProp["fixed row height"] of me then put false into pUpdateContentHeight

  put the lockMessages into msgsAreLocked
  lock messages
  put the rect of pRowControl into theRect
  put item 1 of theRect + pWidth into item 3 of theRect
  set the rect of pRowControl to theRect
  unlock messages

  put _GetCacheKeyForRow(pRow) into theCacheKey

  set the lockUpdates of pRowControl to kLockUpdatesSetting
  dispatch "LayoutControl" to pRowControl with theRect, pRow
  put the result into theResult
  put false into sViewPropsA["controls"]["cache"][theCacheKey]["resize"]
  set the lockUpdates of pRowControl to false

  if not the viewProp["fixed row height"] of me AND theResult is not "do not resize" then
    ## When we set up control we locked the height. We need to update the height now.
    put the rect of pRowControl into theRect
    put item 2 of theRect + the formattedHeight of pRowControl into item 4 of theRect
    set the rect of pRowControl to theRect
    put item 4 of theRect - item 2 of theRect into theHeight
  else
    put the height of pRowControl into theHeight
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
end _DispatchLayoutControl


/**
* \brief Deletes all controls, resets the vscroll and clears internal storage.
*
* \return empty
*/
command ResetView
  local i, msgsAreLocked

  put the lockMessages into msgsAreLocked
  lock screen
  lock messages

  # Cleanup rows, sending messages
  repeat for each key theKey in sViewPropsA["controls"]["cache"]
    if there is not a sViewPropsA["controls"]["cache"][theKey]["control"] then next repeat

    dispatch "CleanupAfterRowControl" to sViewPropsA["controls"]["cache"][theKey]["control"]
    delete sViewPropsA["controls"]["cache"][theKey]["control"]
  end repeat

  # This will clean up any stragglers
  repeat with i = the number of groups of group "dvList" of me down to 1
    delete group i of group "dvList" of me
  end repeat
  repeat with i = 1 to the number of controls of group "dvList" of me
    delete control 1 of group "dvList" of me
  end repeat

  set the viewProp["vscroll"] of me to 0
  set the viewProp["first working row"] of me to 0
  set the viewProp["last working row"] of me to 0
  set the thumbposition of scrollbar "dvVScrollbar" of me to 0

  put empty into sViewPropsA

  set the viewProp["content height"] of me to 0
  _AutoHideScrollbars
  _ConfigureScrollbars
  unlock screen

  set the lockMessages to msgsAreLocked

  return empty
end ResetView


/**
* \brief Dispatches the "CacheKeyForRow" message. If unhandled then the row number is returned.
*
* \param pRow The row to get the cache key for.
*
* \return Cache key
*/
private function _DispatchCacheKeyForRow pRow
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
    --      throw "CacheKeyForRow has not been implemented for the data view control " & quote & the short name of me & quote
  end if
end _DispatchCacheKeyForRow


/**
* \brief Stores a control in the cache for a row, removing the control from the pool of available controls.
*
* \param pRow The row to cache the control for.
* \param pControl The control to cache.
*
* \return empty
*/
private command _CacheRowControl pRow, pControl
  local theLineNo, i, theCacheKey, theOffsetRow

  set the wholeMatches to true

  put _DispatchCacheKeyForRow(pRow) into theCacheKey

  put lineoffset(pControl, sViewPropsA["controls"]["available"]) into theLineNo
  if theLineNo > 0 then
    delete line theLineNo of sViewPropsA["controls"]["available"]
    if sViewPropsA["controls"]["available"] is empty then
      delete local sViewPropsA["controls"]["available"]
    end if
  else
    if sViewPropsA["controls"]["available"] contains pControl then
      breakpoint
      put lineoffset(pControl, sViewPropsA["controls"]["available"]) into theLineNo
      --         local theData
      --         put "pControl:" && pControl & cr & cr after theData
      --         repeat for each line theLine in sViewPropsA["controls"]["available"]
      --            put quote & theLine & quote & cr & cr after theData
      --         end repeat
      --         put theData
      beep
    end if
  end if

  ## Store control in cache
  put pControl into sViewPropsA["controls"]["cache"][theCacheKey]["control"]
  put true into sViewPropsA["controls"]["cache"][theCacheKey]["resize"]
  put the height of pControl into sViewPropsA["controls"]["cache"][theCacheKey]["height"]

  # if caching is not on and no fixed row height then store height in lookup table
  if "control height cache" is among the keys of sViewPropsA["controls"] then
    put sViewPropsA["controls"]["cache"][theCacheKey]["height"] \
          into sViewPropsA["controls"]["control height cache"][pRow]
  end if

  return empty
end _CacheRowControl


/**
* \brief Reorders number(s) in a list by sliding them to pPosition.
*
* \param pNumberList Master list of numbers. There should be no duplicate entries.
* \param pNumbers Number(s) to sequence. The numbers do not have to be in pNumberList already.
* \param pPosition The position to move pNumbers to.
*
*\return New list of numbers.
*/
private function _ReorderNumbersInList pNumberList, pNumbers, pPosition
  local theItemNo, theNumber, i

  set the wholeMatches to true

  if pNumberList is empty then
    ## Nothing to do here really
    put pNumbers into pNumberList
  else
    ## Add all numbes to the list
    repeat for each item theNumber in pNumbers
      put itemOffset(theNumber, pNumberList) into theItemNo
      if theItemNo is 0 then
        put "," & theNumber after pNumberList
      end if
    end repeat

    ## We like valid values
    put max(1, min(pPosition, the number of items of pNumberList)) into pPosition

    ## Delete numbers in list
    repeat for each item theNumber in pNumbers
      add 1 to i
      put itemOffset(theNumber, pNumberList) into theItemNo
      if theItemNo > 0 then
        delete item theItemNo of pNumberList

        ## adjust sequence as necessary for items removed
        if i > 1 and theItemNo < pPosition then
          subtract 1 from pPosition
        end if
      end if
    end repeat

    ## Now insert numbers into list
    put pNumbers & "," before item pPosition of pNumberList
    if the last char of pNumberList is "," then delete the last char of pNumberList
  end if

  return pNumberList
end _ReorderNumbersInList

/*
* \brief Returns the working top/bottom that will show content. Padding has been taken out.
*
* \return top x, bottom x
*/
function _WorkingTopAndBottomContentCoordinates
  local theWindowHeight, theTopPadding, theBottomPadding

  put _GetContentWindowHeight() into theWindowHeight
  put max(0, the viewProp["content top padding"] of me) into theTopPadding
  put max(0, the viewProp["content bottom padding"] of me) into theBottomPadding

  return min( theTopPadding, theWindowHeight - 1) & "," & \
        the viewProp["content height"] of me - min(theBottomPadding, theWindowHeight - 1)
end _WorkingTopAndBottomContentCoordinates


/**
* \brief Determines the range of rows to show based on the current vscroll setting.
*
* \param @pStartRow Output contains the row to start on.
* \param @pEndRow Output contains the row to end on.
* \param @pStartRowYOffset Output contains the y offset for the first row from the top of the container group. <= 0.
*
* If 'fixed row height' is false then controls will be resized in this handler.
*
* \return empty
*/
private command _GetRangeOfRowsToDisplay @pStartRow, @pEndRow, @pStartRowYOffset
  local theRowCount, theVScroll, theAdditionalHeight
  local theContentHeight, theRowWidth, recalculateHeight, theIndex

  put the viewProp["number of rows"] of me into theRowCount

  if theRowCount is 0 then
    put 0 into pStartRow
    put 0 into pEndRow
    put 0 into pStartRowYOffset
    return empty
  end if

  -- vscroll / (outside world content - window height) = percentage
  -- vscroll = 23
  -- row height = 10
  -- window height = 100
  -- outside world height = 240

  if the viewProp["fixed row height"] of me then
    local theNumberOfVisibleRows

    -- vscroll div row height = pStartRow
    -- vscroll mod row height = pStartRowYOffset
    -- pStartRow + (window height / row height) = pEndRow
    -- if pStartRowYOffset < 0 then add 1 to pEndRow
    put the viewProp["vscroll"] of me into theVScroll ## may be negative if "bouncing" is supported
    --         put max(0, the viewProp["vscroll"] of me) into theVSCroll
    if theVSCroll < 0 then put abs(theVSCroll) into theAdditionalHeight

    put max(0, theVSCroll - item 1 of _WorkingTopAndBottomContentCoordinates()) div the viewProp["row height"] of me + 1 into pStartRow

    if theVScroll < item 1 of _WorkingTopAndBottomContentCoordinates() then
      put -(item 1 of _WorkingTopAndBottomContentCoordinates() - theVScroll) into pStartRowYOffset
      put (the viewProp["content window height"] of me + pStartRowYOffset + theAdditionalHeight) div the viewProp["row height"] of me into theNumberOfVisibleRows
      if the viewProp["content window height"] of me mod the viewProp["row height"] of me > 0 then
        add 1 to theNumberOfVisibleRows
      end if
    else
      put (theVSCroll - item 1 of _WorkingTopAndBottomContentCoordinates()) mod the viewProp["row height"] of me into pStartRowYOffset
      put (the viewProp["content window height"] of me + pStartRowYOffset + theAdditionalHeight) div the viewProp["row height"] of me into theNumberOfVisibleRows
      if the viewProp["content window height"] of me mod the viewProp["row height"] of me > 0 then
        add 1 to theNumberOfVisibleRows
      end if
    end if

    ## Make sure we have enough controls to scroll
    put min(theRowCount, pStartRow + theNumberOfVisibleRows) into pEndRow
    if pStartRowYOffset < 0 then
      add 1 to pEndRow
    end if

    put min(pEndRow, the viewProp["number of rows"] of me) into pEndRow

  else if the viewProp["cache"] of me is "none" then # not fixed height but not cached
    local theContentWindowHeight, theTopOfLastControl, theControlHeight

    put the viewProp["content window height"] of me into theContentWindowHeight

    ## The outer repeat loop is in case the height changes while trying to figure out the rows
    ## to display. If it does then we start everything over and recalculate.
    repeat forever
      put the viewProp["content width"] of me into theRowWidth ## this can change if scrollbar is shown/hidden!!!
      put empty into pStartRow
      put empty into pEndRow
      put empty into recalculateHeight
      put empty into theTopOfLastControl
      put item 1 of _WorkingTopAndBottomContentCoordinates() into theContentHeight
      put empty into pStartRowYOffset
      put the viewProp["vscroll"] of me into theVSCroll

      repeat with theRow = 1 to theRowCount
        -- pStartRow = last control that is <= vscroll
        -- pEndRow = control right after control that exceeds content window height
        -- pStartRowYOffset = vscroll - top of pStartRow

        put theContentHeight into theTopOfLastControl

        # We use the default height if none has been set,
        # unless the start row has been determined. In that case
        # we size the control and get actual height.
        put sViewPropsA["controls"]["control height cache"][theRow] into theControlHeight

        # NOTE: This code won't run again if 'recalculate the height' is true.

        if theControlHeight is NULL then
          if pStartRow is not empty OR (pStartRow is empty AND theContentHeight+kDefaultForNonCachedVariableHeightRows > theVScroll) then
            # PrepareRow will resize and adjust "content height". Will subtract current height so make sure it is added in.
            if sViewPropsA["controls"]["control height cache"][theRow] is NULL then
              set the viewProp["content height"] of me to the viewProp["content height"] of me - kDefaultForNonCachedVariableHeightRows
            else
              set the viewProp["content height"] of me to the viewProp["content height"] of me - sViewPropsA["controls"]["control height cache"][theRow]
            end if
            _SetupRowControl theRow
            set the viewProp["content height"] of me to the viewProp["content height"] of me + sViewPropsA["controls"]["control height cache"][theRow]

            # Need to resize before we recalculate height
            _PrepareRowForDisplay theRow, sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(theRow)]["control"], theRowWidth
            if recalculateHeight is empty and the result is true then put true into recalculateHeight

            put sViewPropsA["controls"]["control height cache"][theRow] into theControlHeight
          else
            put kDefaultForNonCachedVariableHeightRows into theControlHeight
          end if
        end if

        add theControlHeight to theContentHeight

        if pStartRow is empty then
          ## First fill in the starting row
          if theContentHeight > theVScroll then
            put theRow into pStartRow
            put theVScroll - theTopOfLastControl into pStartRowYOffset
            put 0 into theContentHeight -- reset as rest of controls must be as tall as content window so first control can scroll off.
          end if
        else
          if theContentHeight >= theContentWindowHeight then
            put theRow into pEndRow
            exit repeat
          end if
        end if
      end repeat ## loop through rows

      ## If height has to be recalculated then run the operation again
      if recalculateHeight then
        _CalculateContentHeight
        set the lockMessages to true
        _ConfigureScrollbars
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
      put empty into pStartRow
      put empty into pEndRow
      put empty into recalculateHeight
      put empty into theTopOfLastControl
      put empty into pStartRowYOffset
      --         put max(0, the viewProp["vscroll"] of me) into theVSCroll # removed for ios "bounce" effect.
      put the viewProp["vscroll"] of me into theVSCroll
      put item 1 of _WorkingTopAndBottomContentCoordinates() into theContentHeight

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
        -- pStartRow = last control that is <= vscroll
        -- pEndRow = control right after control that exceeds content window height
        -- pStartRowYOffset = vscroll - top of pStartRow

        put theContentHeight into theTopOfLastControl
        put _GetCacheKeyForRow(theRow) into theCacheKey
        if theCacheKey is empty then exit repeat ## caching hasn't occured yet. Maybe ResizeToFit was called before initializing and developer passed in bad row count?

        ## Take into account ghost or controls that need to be resized
        _PrepareRowForDisplay theRow, sViewPropsA["controls"]["cache"][theCacheKey]["control"], theRowWidth
        if recalculateHeight is empty and the result is true then put true into recalculateHeight

        put sViewPropsA["controls"]["cache"][theCacheKey]["height"] into theControlHeight
        add theControlHeight to theContentHeight

        if pStartRow is empty then
          ## First fill in the starting row
          if theContentHeight > theVScroll then
            put theRow into pStartRow
            put theVScroll - theTopOfLastControl into pStartRowYOffset
            put 0 into theContentHeight -- reset as rest of controls must be as tall as content window so first control can scroll off.
          end if
        else
          if theContentHeight >= theContentWindowHeight then
            put theRow into pEndRow
            exit repeat
          end if
        end if
      end repeat ## loop through rows

      ## If height has to be recalculated then run the operation again
      if recalculateHeight then
        _CalculateContentHeight
        set the lockMessages to true
        _ConfigureScrollbars
        set the lockMessages to false
      else
        exit repeat
      end if
    end repeat

    --      put the short name of me && "timer:" && the milliseconds - theStartTime & cr after fld "log"
  end if

  if theRowCount > 0 then
    if pStartRow is empty then
      put 1 into pStartRow # a good starting number
    end if
    if pEndRow is empty then
      put theRowCount into pEndRow
    end if
  end if

  return empty
end _GetRangeOfRowsToDisplay


/**
* \brief Updates the cache by removing controls and placing them back in the pool or just hiding them (depends on cache setting), updating 'rows in use' and 'cache indexes'.
*
* \param pStartRow The first row that should not be removed from the cache.
* \param pEndRow The last row that should not be removed from the cache.
*
* Any control that falls outside the range of pStartRow and pEnd Row will be placed back in the pool of available controls
* if they are not being cached. All controls outside of range, regardless of cache setting, will be hidden.
* In all circumstances 'rows in use' will be updated. 'row cache keys' may be updated.
*
* \return empty
*/
private command _UpdateControlCache pStartRow, pEndRow
  local theCacheSetting, theCacheKey, theCacheKeys, theRow, theRowControl
  local theRowIndexA

  set the wholeMatches to true

  put the viewProp["cache"] of me into theCacheSetting

  # Make a list of cache keys for row range, one per line
  if pStartRow > 0 then
    repeat with theRow = pStartRow to pEndRow
      put _DispatchCacheKeyForRow(theRow) & cr after theCacheKeys
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

        _MoveCachedControlBackIntoCacheBin theCacheKey, theRow

      else

        # Check for match between old row cache key and new row cache key
        put theRow - theOffset into theEffectiveRow
        if line theEffectiveRow of theCacheKeys is not sViewPropsA["controls"]["row cache keys"][theRow] then
          _MoveCachedControlBackIntoCacheBin theCacheKey, theRow
        end if

      end if
    end repeat

  else # caching is on

    # Hide any controls that are visible that are no longer in range.
    repeat for each item theRow in sViewPropsA["controls"]["rows in use"]
      put sViewPropsA["controls"]["row cache keys"][theRow] into theCacheKey

      # Out of range
      if theRow < pStartRow or theRow > pEndRow then

        put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into theRowControl

        try
          if the visible of theRowControl then
            # control may have a text editor open
            # 2016-08-03: Tried to use this method to keep controls visible that have field open.
            #             Field that is open but off screen doesn't seem to get exit/closefield messages though.
            --                  if not FieldEditorIsOpen(theRowControl) then
            # Send message if control will maintain current data
            dispatch "HideRowControl" to theRowControl
            hide theRowControl
            --               end if
          end if
        catch e
          put param(0) & cr & e
        end try

      end if
    end repeat
  end if

  ## Rebuild 'rows in use' using new range
  put empty into sViewPropsA["controls"]["rows in use"]
  if pStartRow > 0 then
    repeat with theRow = pStartRow to pEndRow
      put theRow & "," after sViewPropsA["controls"]["rows in use"]
    end repeat
    delete the last char of sViewPropsA["controls"]["rows in use"]
  end if

  return empty
end _UpdateControlCache


/**
*\brief Returns a control of the given style.
*
* \param pStyle The style of the control to return.
*
* If a control with a matching style exists in the "available" list then it will be returned.
* Otherwise a new control will be created.
*
* \return Control reference.
*/
private function _GetControlOfStyle pStyle
  local theControl

  put _FindAvailableControlOfStyle(pStyle) into theControl

  if theControl is empty then
    local theTemplatesA, theTemplate

    put the viewProp["row style templates"] of me into theTemplatesA
    put theTemplatesA[pStyle] into theTemplate
    if there is not a theTemplate then
      put param(0) && "alert: no template" & cr & "theTemplate:" && theTemplate & cr & "pStyle:" && pStyle & cr & the executioncontexts
    else
      local msgsAreLocked
      put the lockMessages into msgsAreLocked
      lock messages
      copy theTemplate to group "dvList" of me
      put _CustomControlReference(it) into theControl

      # Uncomment the following code if a newGroup message is ever needed.
      # e.g. some reason to initialize something when control is created.
      # 2014-10-15: Templates get InitializeTemplate which handles initialzation. Don't worry about newGroup.
      --         unlock messages
      --         dispatch "newGroup" to theControl # This was slightly faster then leaving messages unlocked during "copy template"
      --         lock messages

      ## Make sure a style is set
      set uTemplateStyle of theControl to pStyle

      set the lockMessages to msgsAreLocked
    end if
  end if

  return theControl
end _GetControlOfStyle


/**
* \brief Locates a row control that matches pStyle and is not "active" (i.e. is not currently in use).
*
* \param pStyle The found control will have this style.
*
* \return control reference or empty
*/
private function _FindAvailableControlOfStyle pStyle
  repeat for each line theControl in sViewPropsA["controls"]["available"]
    try ## in case control doesn't exist
      if the uTemplateStyle of theControl is pStyle then
        return theControl
      end if
    catch e
    end try
  end repeat
  return empty
end _FindAvailableControlOfStyle


/*
* \brief Creates a portable control reference.
*
* \param pControl
*
* All group referneces are removed, the main stack is removed if on a substack
* and the stack name is shortened.
*
* \return Control reference
*/
private function _CustomControlReference pControl
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
end _CustomControlReference


--> Animation


constant kFrameLength = 10
constant kAnimationLength = 300

command StartScrollAnimation pScrollTo
  CancelAnimation

  local rightNow, scrollFrom

  put true into sViewPropsA["is animating"]
  put the milliseconds into rightNow
  put round(the thumbPosition of scrollbar "dvVScrollbar" of me) into scrollFrom

  ScheduleScrollAnimation scrollFrom, pScrollTo, rightNow, "ease in out", rightNow, rightNow + kAnimationLength
end StartScrollAnimation


command CancelAnimation
  put false into sViewPropsA["is animating"]
  cancel sPendingMsgsA["UpdateScrollAnimation"]
  put empty into sPendingMsgsA["UpdateScrollAnimation"]
end CancelAnimation


command ScheduleScrollAnimation pScrollFrom, pScrollTo, pLastTime, pPhase, pPhaseStart, pPhaseEnd
  if not sViewPropsA["is animating"] then return empty

  local rightNow, theNextTime

  put the milliseconds into rightNow
  ## Synchronize to the system clock.
  put (rightNow - (rightNow mod kFrameLength)) + kFrameLength into theNextTime

  send "UpdateScrollAnimation pScrollFrom, pScrollTo, pLastTime, pPhase, pPhaseStart, pPhaseEnd" to me in theNextTime - rightNow milliseconds
  put the result into sPendingMsgsA["UpdateScrollAnimation"]
end ScheduleScrollAnimation


command UpdateScrollAnimation pScrollFrom, pScrollTo, pLastTime, pPhase, pPhaseStart, pPhaseEnd
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

  _SetVScroll theValue

  ## Make sure focus stays with us
  if the long ID of me is in theControl and (there is not a theControl or the long ID of me is not in the long ID of the focusedobject) then
    focus on graphic "dvBackground" of me
  end if

  unlock screen

  ## Schedule next animation
  if pScrollFrom > pScrollTo then
    if theValue > pScrollTo then
      ScheduleScrollAnimation pScrollFrom, pScrollTo, rightNow, pPhase, pPhaseStart, pPhaseEnd
    else
      put false into sViewPropsA["is animating"]
    end if
  else
    if theValue < pScrollTo then
      ScheduleScrollAnimation pScrollFrom, pScrollTo, rightNow, pPhase, pPhaseStart, pPhaseEnd
    else
      put false into sViewPropsA["is animating"]
    end if
  end if

  return empty
end UpdateScrollAnimation


--> Drag and Drop

local sDropStructure

setprop dvDragReorderData pValue
  put pValue into sDropStructure["drag drop data"]
end dvDragReorderData


getprop dvDragReorderData
  return sDropStructure["drag drop data"]
end dvDragReorderData


/**
* \brief Defines the default behavior for dvAcceptsDrop. Override in your dataview.
*
*/
getProp dvAcceptsDrop
  local theA
  put true into theA["above"]
  put true into theA["below"]
  return theA
end dvAcceptsDrop


/**
* \brief Sets the dragImage to a snapshot of a row.
*
* \param pRows The row(s) to use as the dragImage.
*
* \return Error message
*/
setprop dvDragImageRow pRows
  local theControl

  put sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(item 1 of pRows)]["control"] into theControl
  if theControl is not empty then
    _CreateDragImageFromControl theControl
    return empty
  else
    return "row control not found"
  end if
end dvDragImageRow


/**
* \brief Begins a drag-reorder operation.
*
* \param pOriginatingRows The rows that the user started dragging.
* \param pBoolean True to start the operation, false to stop.
*
* \return Error
*/
setprop dvTrackDragReorder [pOriginatingRows] pBoolean
  --   # temp
  --   put false into sDropStructure["tracking"]
  if pBoolean is not sDropStructure["tracking"] then
    if pBoolean then
      local theDropIndicatorGroup, theContentRect, theRect

      ## Set right away
      ## This handler will be called from dragMove most likely. This message
      ## can fired numerous times and we want getProp dvTrackDragReorder to return true immediately.
      put true into sDropStructure["tracking"]

      DeleteFieldEditor true, "enterInField" ## close and save

      sort items of pOriginatingRows ascending numeric
      put pOriginatingRows into sDropStructure["originating rows"]

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
      --         dispatch "resizeControl" to theDropIndicatorGroup # in case you want to force resizeControl even when rect doesn't change

      put the rect of theDropIndicatorGroup into sDropStructure["default drop indicator rect"]
      insert script of stack "DataView Track Drag and Drop Behavior" into front

      set the dvTargetControl of group "dvDropIndicator" of me to the long ID of me

      ## initialize index mouse is over
      dvDragMove the mouseH, the mouseV
    else
      remove script of stack "DataView Track Drag and Drop Behavior" from front
      set the visible of group "dvDropIndicator" of me to false
      put empty into sDropStructure

      if there is a group 1 of group "dvDropIndicator" of me then
        delete group 1 of group "dvDropIndicator" of me
      end if

      if there is a image "dvDragImage" of me then
        delete image "dvDragImage" of me
      end if

      put false into sDropStructure["tracking"]
    end if
  end if

  return empty
end dvTrackDragReorder


/**
* \brief Returns a boolean value indicating whether or not drag reordering is being tracked.
*
* \return Boolean
*/
getProp dvTrackDragReorder
  return sDropStructure["tracking"]
end dvTrackDragReorder


/**
* \brief Implementation of dragEnd for the view. Called from the frontscript.
*
*/
on dvDragEnd
  set the dvTrackDragReorder of me to false
  put empty into sViewPropsA["select on mouseUp"] # this is set in dvMouseDownBefore. dvMouseUp won't be sent if a drag starts, however.
end dvDragEnd


/**
* \brief Implementation of dragDrop for the view. Called from the frontscript.
*
* Sends the message DragReorderRows to the control. Parameter one is the row(s) that was being dragged.
* Parameter two is the new starting row for pTargetRows (assuming a flat list).
* Parameter three is the row that was dropped after.
*
*/
on dvDragDrop
  local processTheDrop, theDropStructure

  put empty into sViewPropsA["select on mouseUp"] # this is set in dvMouseDownBefore. dvMouseUp won't be sent if a drag starts, however.

  ## Cache before we clean up
  if the dragAction is "move" AND sDropStructure["dropped after row"] is empty then put false into processTheDrop
  else put the dragAction is not "none" into processTheDrop  ## This works better as it takes into account dropping data onto empty view from other source.
  put sDropStructure into theDropStructure

  ## If some other control displays a dialog during dragDrop, dragMove will still be sent
  ## if the mouse moves within the dialog. We don't want to process those any longer at this point.
  set the dvTrackDragReorder of me to false

  if processTheDrop then
    local theNewStartingRow

    put max(0, theDropStructure["dropped after row"]) into theDropStructure["dropped after row"]
    put theDropStructure["dropped after row"] into theNewStartingRow
    if theDropStructure["dropped after row"] < item 1 of theDropStructure["originating rows"] then add 1 to theNewStartingRow

    dispatch "DragReorderRows" with theDropStructure["originating rows"], theNewStartingRow, theDropStructure["dropped after row"]
  end if
end dvDragDrop


/**
* \brief Implementation of dragMove for the view. Called from the frontscript.
*
*/
on dvDragMove pMouseH,pMouseV

  ## Throttle calls to this
  if sViewPropsA["running actions"]["dragmove"] then
    return empty
  end if

  ## Make sure data view control will accept drop
  if the dragSource contains the long ID of me and (the mouseControl is not empty and the long id of the mouseControl contains the long ID of me) then
    set the dragAction to "move"
  end if

  put true into sViewPropsA["running actions"]["dragmove"]
  try
    _PositionDropIndicator pMouseH,pMouseV

    # This messes up behavior (e.g. escape key won't always properly cancel)
    --      ## We can't send messages so hang out until mouseloc changes
    --      repeat until (the mouseLoc is not pMouseH,pMouseV) or (mouse(1) is "up" and mouse(3) is "up")
    --         ## Throttle calls to redrawing

    --         if not sViewPropsA["running actions"]["vscroll"] then
    --            _ListGroupDragReorderAutoScroll pMouseH,pMouseV
    --            _PositionDropIndicator pMouseH, pMouseV
    --         end if
    --      end repeat
  catch e
    loggerLogMsg param(0) && "error:" & cr & e
  end try
  put false into sViewPropsA["running actions"]["dragmove"]
end dvDragMove


/**
* \brief Implementation of dragLeave. Called from frontscript.
*
* Check if mouse is outside of control on dragLeave. When mouse leaves window we don't want drag indicator showing.
*
*/
command dvDragLeave
  if the mouseH,the mouseV is not within the viewProp["content window rect"] of me then
    _SetDropIndicatorVisibility false
  end if
end dvDragLeave


/**
* \brief Positions the drop indicator during drag/drop operations.
*
* \param pMouseH The x mouse location.
* \param pMouseV The y mouse position.
*
* \return empty
*/
private command _PositionDropIndicator pMouseH, pMouseV
  local i,theX,theY
  local showDropIndicator, theDropIndicatorOffset
  local theControl, theControlIndex
  local theControlsToCheck, msgsAreLocked
  local theWindowRect
  local theHeight
  local theSequence
  local theStartControl # The top control that defines the drop region
  local theEndControl # The bottom control that defines the drop region
  local theTargetControl

  put the lockMessages into msgsAreLocked
  set the wholeMatches to true
  put false into showDropIndicator

  put the viewProp["content window rect"] of me into theWindowRect

  if (pMouseH & "," & pMouseV) is within theWindowRect then
    if the mouseControl is not empty then
      put true into showDropIndicator

      if not (the long ID of the mouseControl contains the long ID of me) then
        put false into showDropIndicator ## control over the list but not part of the list
      else
        local theTargetRow

        put the dvRowControl of the mouseControl into theTargetControl

        if theTargetControl is empty then
          if pMouseV <= (item 2 of theWindowRect + the viewProp["content top padding"] of me + 1) then
            # top padding area. Use first control.
            put sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(item 1 of sViewPropsA["controls"]["rows in use"])]["control"] into theTargetControl
          else
            ## Assume we are below the last control
            put sViewPropsA["controls"]["cache"][_GetCacheKeyForRow(item -1 of sViewPropsA["controls"]["rows in use"])]["control"] into theTargetControl
          end if
        end if

        if theTargetControl is empty then
          put 0 into sDropStructure["dropped after row"] ## no controls in list
        else
          local theItemNo

          put the dvRow of theTargetControl into theTargetRow

          ## Look for next/prev control that is not filtered out
          ## Direction we look depends on position of mouse
          ## relative to Y of control
          put item 2 of the loc of theTargetControl into theY

          ## dvAcceptsDrop returns an array with "above" and "below" keys.
          ## "none" means no drop should occur at all in that direction and searching stops.
          ## true/false otherwise.

          ## Look for start/end controls in our drop
          local acceptsADrop, theStartAcceptsADrop, theEndAcceptsADrop

          put the dvAcceptsDrop of theTargetControl into theStartAcceptsADrop

          ## Fill in some values if we already know what they are
          if theStartAcceptsADrop["above"] is true then
            put theTargetControl into theStartControl
          end if

          if theStartAcceptsADrop["below"] is true then
            put theTargetControl into theEndControl
            put theStartAcceptsADrop into theEndAcceptsADrop
          end if

          put itemOffset(theTargetRow, sViewPropsA["controls"]["rows in use"]) into theItemNo

          local theRowsToCheck, theCacheKey

          ## Now search for any missing values.
          ## Look for next control that accepts a drop
          ## Note that no search appears if the start control stopped all action below.
          if theEndControl is empty then
            if theStartAcceptsADrop["below"] is not "none" then
              put item (theItemNo + 1) to -1 of sViewPropsA["controls"]["rows in use"] into theRowsToCheck
              repeat for each item theRow in theRowsToCheck
                put _GetCacheKeyForRow(theRow) into theCacheKey

                put the dvAcceptsDrop of sViewPropsA["controls"]["cache"][theCacheKey]["control"] into acceptsADrop

                if acceptsADrop["below"] is "none" then
                  exit repeat
                else if acceptsADrop["above"] is true OR acceptsADrop["below"] is true then
                  put acceptsADrop into theEndAcceptsADrop
                  put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into theEndControl
                  exit repeat
                end if
              end repeat
            end if
          end if

          ## Look for preceding control that accepts a drop
          ## Note that no search appears if the start control stopped all action above.
          if theStartControl is empty then
            if theStartAcceptsADrop["above"] is not "none" then
              put item 1 to (theItemNo - 1) of sViewPropsA["controls"]["rows in use"] into theRowsToCheck

              # Work our way down to 1
              sort items of theRowsToCheck numeric descending

              repeat for each item theRow in theRowsToCheck
                put _GetCacheKeyForRow(theRow) into theCacheKey

                put the dvAcceptsDrop of sViewPropsA["controls"]["cache"][theCacheKey]["control"] into acceptsADrop

                if acceptsADrop["above"] is "none" then
                  exit repeat
                else if acceptsADrop["above"] is true OR acceptsADrop["below"] is true then
                  put acceptsADrop into theStartAcceptsADrop
                  put sViewPropsA["controls"]["cache"][theCacheKey]["control"] into theStartControl
                  exit repeat
                end if
              end repeat
            end if
          end if

          ## What is height of drop area as defined by start/end controls?
          --               put "is:" && theStartControl & cr & theEndControl
          if theStartControl is empty and theEndControl is empty then
            ## No drop. Hide the drop indicator
            put false into showDropIndicator
          else
            if theStartControl is empty then put theEndControl into theStartControl
            else if theEndControl is empty then put theStartControl into theEndControl

            # Figure out the drop Y coordinate
            put the bottom of theEndControl - the top of theStartControl into theHeight

            if pMouseV < (the top of theStartControl + round(theHeight / 2)) then
              # Mouse is in top-half of drop zone
              if theStartAcceptsADrop["above"] is true then
                put the top of theStartControl into theY
                put max(the dvRow of theStartControl-1, 0) into sDropStructure["dropped after row"]

              else if theStartAcceptsADrop["below"] is true then
                put the bottom of theStartControl into theY
                put the dvRow of theStartControl into sDropStructure["dropped after row"]
              else
                put false into showDropIndicator
              end if
            else
              # Mouse is in bottom half of drop zone
              if theEndAcceptsADrop["below"] is true then
                put the bottom of theEndControl into theY
                put the dvRow of theEndControl into sDropStructure["dropped after row"]

              else if theEndAcceptsADrop["above"] is true then
                put the top of theEndControl into theY
                put max(the dvRow of theEndControl-1, 0) into sDropStructure["dropped after row"]
              else
                put false into showDropIndicator
              end if
            end if

            ## Position drop indicator
            if showDropIndicator then
              put (item 4 of sDropStructure["default drop indicator rect"] - item 2 of sDropStructure["default drop indicator rect"]) / 2 div 1 into theDropIndicatorOffset ## div 1 = floor

              lock screen
              lock messages
              put item 1 of sDropStructure["default drop indicator rect"] into theX
              put min(item 4 of theWindowRect, max(item 2 of theWindowRect + theDropIndicatorOffset, theY)) into theY ## don't let outside of the List group
              put theY - theDropIndicatorOffset into theY
              set the topLeft of group "dvDropIndicator" of me to theX, theY
              unlock messages
              dispatch "PositionDropIndicator" to group 1 of group "dvDropIndicator" of me with sDropStructure["dropped after row"]
              unlock screen
            end if
          end if
        end if
      end if ## mousecontrol is part of list group control
    else
      ## mousecontrol is empty
    end if

  end if ## within rect of list

  if not showDropIndicator then
    put empty into sDropStructure["dropped after row"]
  end if

  set the lockMessages to msgsAreLocked

  _SetDropIndicatorVisibility showDropIndicator

  return empty
end _PositionDropIndicator


private command _SetDropIndicatorVisibility pBoolean
  if not pBoolean AND the visible of group "dvDropIndicator" of me then
    set the visible of group "dvDropIndicator" of me to false
    dispatch "HideDropIndicator" to group 1 of group "dvDropIndicator" of me
  else if pBoolean and not the visible of group "dvDropIndicator" of me then
    set the visible of group "dvDropIndicator" of me to true
    dispatch "ShowDropIndicator" to group 1 of group "dvDropIndicator" of me
  end if

  return empty
end _SetDropIndicatorVisibility


/**
* \brief Scrolls the view based on the position of the mouse. Used during drag/drop operations.
*
* \param pMouseH The X mouse position.
* \param pMouseV The Y mouse position.
*
* \return empty
*/
private command _ListGroupDragReorderAutoScroll pMouseH, pMouseV
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
        _SetVScroll theScroll
      end if
    end if
  end if

  return empty
end _ListGroupDragReorderAutoScroll


/**
* \brief Sets the dragImage (and associated properties) using an image created from a control.
*
* \param pControl A reference to the control to use as the dragImage.
*
* \return empty
*/
private command _CreateDragImageFromControl pControl
  local theImageOffset, isHilited

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
  put the dvHilite of pControl into isHilited
  set the dvHilite of pControl to false
  if there is a control "Background" of pControl then set the visible of control "Background" of pControl to false

  export snapshot from pControl to image "dvDragImage" of me as PNG

  set the dvHilite of pControl to isHilited
  if there is a control "Background" of pControl then set the visible of control "Background" of pControl to true

  set the dragImage to the ID of image "dvDragImage" of me
  put the clickH - the left of pControl & comma & \
        the clickV - the top of pControl into theImageOffset
  set the dragImageOffset to theImageOffset

  set the lockMessages to msgsAreLocked
  unlock screen

  return empty
end _CreateDragImageFromControl


/**
* \brief Returns the card containing this behavior.
*
* \return Card reference
*/
private function _BehaviorCard
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
end _BehaviorCard


/**
* \brief Returns the card or stack (if no card ref is present) reference of the behavior associated with a control.
*
* \param pControl A reference to a control.
*
* \return A reference to the card or stack of the behavior.
*/
function CardOfControlBehavior pControl
  local theCard, theCharNo

  put the behavior of pControl into theCard
  if theCard is not empty then
    put the long id of theCard into theCard
    put offset(" of card", theCard) into theCharNo
    if theCharNo > 0 then
      delete char 1 to (theCharNo + 3) of theCard
    else
      put offset(" of stack", theCard) into theCharNo
      if theCharNo > 0 then
        delete char 1 to (theCharNo + 3) of theCard
      end if
    end if
  end if

  return theCard
end CardOfControlBehavior


/**
* \brief Returns the stack reference of a control.
*
* \param pControl A reference to a control.
*
* \return A reference to the control stack.
*/
private function _StackOf pControl
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
end _StackOf


--> Field Editing

/**
* \brief When "true" is passed in then any open field editors will NOT be closed when they normally would. Pass in "false" to turn normal behavior back on.
*
* \param pStackRef A reference to the stack that is being suspended.
* \param pBoolean "true" suspends normal field editor closing behavior. "false" restores normal behavior.
*
* Use when a stack is suspended so that a field editor stays open.
* Note that this message is processed in the actual behavior button rather than in an instance of the data grid.
*
* \return empty
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
* \brief Returns whether or not a stack is suspended
*
* Only call on the behavior button, not an instance of the data view. Otherwise the script local
* won't have the proper value.
*
* \return Boolean
*/
getProp uStackIsSuspended [pStackRef]
  put the long id of pStackRef into pStackRef
  return pStackRef is among the keys of sViewPropsA["suspended stacks"]
end uStackIsSuspended


/**
* \brief Returns whether or not a field editor should close. Called from an instance of the data view.
*
* \param pClosingTriggeredBy The event triggering the close. If exitField or closeField then stack check is performed.
*
* \return Boolean
*/
private function _ShouldFieldEditorClose pClosingTriggeredBy
  local theTargetStack, theBehaviorStack, theStackIsSuspended, msgsAreLocked

  # If focus is leaving a field then only close if stack is not suspended.
  if pClosingTriggeredBy is among the items of "exitField,closeField" then
    put _StackOf(the long id of me) into theTargetStack
    put _StackOf(_BehaviorCard()) into theBehaviorStack
    put the lockMessages into msgsAreLocked
    set the lockMessages to false
    put the uStackIsSuspended[theTargetStack] of stack (the short name of this me) into theStackIsSuspended
    set the lockMessages to msgsAreLocked

    return not theStackIsSuspended
  else
    return true
  end if
end _ShouldFieldEditorClose


/**
* \brief Scrolls the row into view and dispatches the EditValue message to it.
*
* It is up to the control to implement the EditKey handler. Normally it will call EditFieldText for
* the field that edits the targeted key.
*
* \param pKey The key to edit.
* \param pRow The row to edit.
*
* \return Error message
*/
command EditKeyOfRow pKey, pRow
  local theCacheKey

  lock screen
  ScrollRowIntoView pRow
  put _GetCacheKeyForRow(pRow) into theCacheKey

  if sViewPropsA["controls"]["cache"][theCacheKey]["control"] is not empty then
    dispatch "EditKey" to sViewPropsA["controls"]["cache"][theCacheKey]["control"] with pKey
    unlock screen
    return empty
  else
    unlock screen
    return "no control exists for row"
  end if
end EditKeyOfRow


/**
* \brief Opens an editing field for the target field. This allows the user to edit the value for a key.
*
* \param pField A reference to the field that will be edited. The editor will appear over the top of this field.
* \param pKey The key that the field is associated with.
*
* \return empty
*/
command CreateFieldEditorForField pField, pKey
  local msgsAreLocked, theClickLine, theRow
  local theClickField, theClickChunk
  local theMargins, theBorderWidth
  local createEditorInThisGroup, theScrollSetting, theAnimSetting
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
  put the short name of _StackOf(the long id of me) is line 1 of the openStacks into thisStackHasFocus
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
  dispatch "SuspendFieldEditorClosing" to stack (the short name of this me) with _StackOf(the long id of me), false

  put the dvRowControl of pField into createEditorInThisGroup
  put the dvRow of createEditorInThisGroup into theRow
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
    if not the visible of createEditorInThisGroup then
      set the viewProp["animate selections"] of me to false ## don't animate to unseen controls
    end if
    set the dvHilitedRows of me to theRow
    set the viewProp["scroll selections into view"] of me to theScrollSetting
    set the viewProp["animate selections"] of me to theAnimSetting
  end if

  lock messages

  create field kFieldEditorName in createEditorInThisGroup
  put the long ID of it into sViewPropsA["field editor"]["control"]

  set the behavior of sViewPropsA["field editor"]["control"] to the long ID of stack "DataView Field Editor Behavior"

  set the rect of sViewPropsA["field editor"]["control"] to the rect of pField

  set the dvIsFieldEditor of sViewPropsA["field editor"]["control"] to true
  set the uIsFieldEditor of sViewPropsA["field editor"]["control"] to true ## property name for generic field editor
  set the dvTargetField of sViewPropsA["field editor"]["control"] to pField
  set the uTargetField of sViewPropsA["field editor"]["control"] to pField ## property name for generic field editor
  set the dvTargetKey of sViewPropsA["field editor"]["control"] to pKey
  set the dvScrollInPadding of sViewPropsA["field editor"]["control"] to 0,10,0,10

  unlock messages

  ## Shout our existence out to the world
  _PopulateFieldEditor pField

  lock messages
  set the dvOriginalStyledText of sViewPropsA["field editor"]["control"] to the styledText of sViewPropsA["field editor"]["control"]

  ## Bug when editing right|center-aligned text that is wider than field.
  if the textAlign of sViewPropsA["field editor"]["control"] is not "left" \
        and the formattedWidth of sViewPropsA["field editor"]["control"] >= the width of sViewPropsA["field editor"]["control"] then
    set the textAlign of sViewPropsA["field editor"]["control"] to "left"
  end if
  unlock messages

  ## 2016-03-18: If the developer selected something in the editor already then don't do anything.
  ## Deprecated behavior: User can set dvSelectAll in preOpenFieldEditor
  if the selectedField is not empty and the long id of the selectedfield is sViewPropsA["field editor"]["control"] then
  else
    if the dvSelectAll of sViewPropsA["field editor"]["control"] then
      select char 1 to -1 of sViewPropsA["field editor"]["control"]
    else
      if theClickField is not empty and theClickField is the long ID of pField then
        if theClickChunk is not empty then
          select after char (word 2 of theClickChunk) of sViewPropsA["field editor"]["control"]
        else if theClickLine is not empty then
          select after line (word 2 of theClickLine) of sViewPropsA["field editor"]["control"]
        else
          select after char -1 of sViewPropsA["field editor"]["control"]
        end if
      else
        select after char -1 of sViewPropsA["field editor"]["control"]
      end if
    end if
  end if

  if thisStackHasFocus then
    focus on sViewPropsA["field editor"]["control"]
  end if

  ## All of the scrolling around and unfocusing of controls will leave
  ## the row the field editor is in dimmed out. Explicitly highlight the
  ## row again.
  _HiliteControl the dvRowControl of sViewPropsA["field editor"]["control"], true

  local theFrontScriptButton

  ## Inserted once, never removed
  put the long id of stack "DataView Field Editor Frontscript" into theFrontScriptButton

  if theFrontScriptButton is not among the lines of the frontScripts then
    insert script of theFrontScriptButton into front
  end if

  reset the templatefield
  set the lockMessages to msgsAreLocked
  unlock screen

  return empty
end CreateFieldEditorForField


/**
* \brief Refreshes the editor field content.
*
* \return empty
*/
command RefreshFieldEditorContent
  if there is a sViewPropsA["field editor"]["control"] then
    _PopulateFieldEditor the dvTargetField of sViewPropsA["field editor"]["control"]
  end if
  return empty
end RefreshFieldEditorContent


/**
* \brief Populates editor field with content.
*
* \return empty
*/
private command _PopulateFieldEditor pField
  local theRowControl, theRowRect

  ## Shout our existence out to the world
  try
    dispatch "PreOpenFieldEditor" to pField with sViewPropsA["field editor"]["control"]
    if it is not "handled" then
      set the styledText of sViewPropsA["field editor"]["control"] to the styledText of pField
    end if

    ## Determine the rect that needs to be scrolled into view
    if the viewProp["scroll selections into view"] of me then
      put the dvRowControl of pField into theRowControl
      put the dvRectOfRow[the dvRow of theRowControl] of me into theRowRect
      add (the top of sViewPropsA["field editor"]["control"] - the top of theRowControl) to item 2 of theRowRect
      subtract (the bottom of theRowControl - the bottom of sViewPropsA["field editor"]["control"]) from item 4 of theRowRect

      ## Developer can set uPadding of field
      ScrollRectIntoView theRowRect, the dvScrollInPadding of sViewPropsA["field editor"]["control"]
    end if
  catch e
    lock messages
    delete sViewPropsA["field editor"]["control"]
    put empty into sViewPropsA["field editor"]
    unlock messages

    throw e
  end try

  return empty
end _PopulateFieldEditor



/**
* \brief Closes the field editor, optionally saving contents.
*
* \param pSaveContents Boolean value specifying whether or not to send messages to save changes.
* \param pClosingTriggeredBy The system message that triggered the closing.
*
* This is called from the field editor behaviors.
*
* \return empty
*/
command _CloseFieldEditor pSaveContents, pClosingTriggeredBy
  ## Don't process if field editor is not open
  ## OR it is already being closed (most likely e.g. escapekey triggers closing and then closeField tries to close as well)
  if there is a sViewPropsA["field editor"]["control"] and not sViewPropsA["field editor"]["closing"] then
    if _ShouldFieldEditorClose(pClosingTriggeredBy) then
      put pSaveContents is not false into pSaveContents
      DeleteFieldEditor pSaveContents, pClosingTriggeredBy
    end if
  end if
  return empty
end _CloseFieldEditor


/**
* \brief Removes focus from the editor and sends messages to open the next field editor.
*
* \param pClosingTriggeredBy The system message that triggered the closing.
*
* This is called from the field editor behaviors.
*
* \return empty
*/
command _CloseFieldEditorAndOpenNext pClosingTriggeredBy
  if _ShouldFieldEditorClose(pClosingTriggeredBy) then
    send "DeleteFieldEditorAndOpenNext pClosingTriggeredBy" to me in 0 seconds
  end if
  return empty
end _CloseFieldEditorAndOpenNext


/**
* \brief A helper function that determines if a field editor is open for a field of a particular name.
*
* \param pRowObject The row object that is asking the question.
* \param pFieldName Name of field that might have a field editor open for it.
*
* This can be called from a row template.
*
* \return Boolean
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
* \brief Deletes the field editor, optionally sending messages to save changes made in editor.
*
* \brief pSaveContents Set to true to dispatch message signaling that editor content should be saved.
* \param pClosingTriggeredBy The system message that triggered the closing.
*
* \return Empty or "cancel"
*/
command DeleteFieldEditor pSaveContents, pClosingTriggeredBy
  local theFocusedObject, msgsAreLocked, contentHasChanged
  local theField, theRow, theKey
  local theEditor, theError

  --   beep

  if pClosingTriggeredBy is empty then put "unknown" into pClosingTriggeredBy
  put the lockMessages into msgsAreLocked

  ## Make sure control still exists.
  if there is not a sViewPropsA["field editor"]["control"] then
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

  put sViewPropsA["field editor"]["control"] into theEditor
  put the dvTargetField of theEditor into theField

  lock screen

  ## So that "field editor is open" returns false
  put true into sViewPropsA["field editor"]["closing"]

  if there is a theField then
    if pSaveContents then
      put the dvRow of the dvRowControl of theEditor into theRow
      put the dvTargetKey of theEditor into theKey ## might be an array index

      set the caseSensitive to true
      put the styledText of theEditor is not the dvOriginalStyledText of theEditor into contentHasChanged
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
      if the long id of theEditor is theFocusedObject then focus on nothing ## so closeField/exitField are called
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
        --            send "_DeleteFieldEditor theEditor" to me in 0 seconds ## field itself likely triggered message so don't delete until afterwards
        _DeleteFieldEditor theEditor # this handler now keeps trying to delete
      end if

      ## If user displayed an answer dialog in any callbacks we end
      ## up with unbalanced focusOut/In messages. This causes hilites
      ## to stay grey. Force update.
      _HiliteRowsInVisibleControls

      ## Reset internals
      put empty into sViewPropsA["field editor"]
    end if
  end if

  put false into sViewPropsA["field editor"]["closing"]

  set the lockMessages to msgsAreLocked
  unlock screen

  return theError
end DeleteFieldEditor


command _DeleteFieldEditor pField
  if there is a pField then
    try
      delete pField
    catch e
      --         put param(0) && the milliseconds & cr & e
      # Script still executing? Try again.
      send "_DeleteFieldEditor pField" to me in 10 milliseconds
    end try
  end if
end _DeleteFieldEditor


/**
* \brief Deletes the field editor and sends message to view telling it to open next editing field.
*
* \param pClosingTriggeredBy The system message that triggered the closing.
* \param pDirection Pass in a value to force "next" or "previous".
*
*  The field editor will be closed with changes saved. The "OpenNextFieldEditor" message will then be
* sent to view so the developer can open another field for editing.
* Optionally sending messages to save changes made in editor. OpenNextFieldEditor has three parameters:
*     pRow: the row that was just edited.
*     pKey: the key that was just edited.
*     pDirection:either "next" or "previous".
*
* \return Empty or "cancel"
*/
command DeleteFieldEditorAndOpenNext pClosingTriggeredBy, pDirection
  local msgsAreLocked, shiftKeyIsDown
  local theRow, theKey, theDirection, theControl
  local theError

  put the lockMessages into msgsAreLocked

  ## Make sure editor exists
  if there is not a sViewPropsA["field editor"]["control"] then
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

  put _IsThisModifierSetActive("shift") into shiftKeyIsDown

  ## Get info before field might be deleted
  put the dvRow of the dvRowControl of sViewPropsA["field editor"]["control"] into theRow
  put the dvTargetKey of sViewPropsA["field editor"]["control"] into theKey

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


/**
* \brief Adds a "..." to the end of field text if the text of the field is too long.
*
* \param pFieldID The id of the field to add the trailer to.
* \param pTrailer The trailer text. The default is "..." if empty.
*
* \return Boolean. True if text was trailed off. False otherwise.
*/
command TruncateTail pFieldId, pTrailer
  local msgsAreLocked

  if pTrailer is empty then
    put "..." into pTrailer
  end if

  lock screen
  put the lockMessages into msgsAreLocked
  lock messages

  local tMaxWidth
  put the width of field ID pFieldId - the leftMargin of field ID pFieldId into tMaxWidth

  if the formattedWidth of char 1 to -1 of field ID pFieldId <= tMaxWidth then
    set the lockMessages to msgsAreLocked
    unlock screen
    return false
  end if

  local tCharCount
  put the number of chars of the text of field ID pFieldId into tCharCount

  local tFieldText
  put the styledText of field ID pFieldId into tFieldText
  set the text of field ID pFieldId to pTrailer

  local tTrailerWidth
  put the formattedWidth of char 1 to -1 of field ID pFieldId into tTrailerWidth

  set the styledText of field ID pFieldId to tFieldText

  -- The 'linear' version requires n steps, where n is the average number of characters
  -- that will fit into the field up to tMaxWidth. That version will behave well for small
  -- widths, but will degrade significantly as the width increases.

  -- This version requires log_2(n) steps, where n is the number of characters in the field
  -- this will be much faster for larger widths, but slower for very small widths when the
  -- line is very long.

  -- The maximum length of the string we want is tMaxWidth minus the trailer width
  subtract tTrailerWidth from tMaxWidth

  -- These two vars store the number of characters before the string that is too small (tLow)
  -- and the number of chars that makes the string too long (tHigh)
  local tLow, tHigh
  put 0 into tLow
  put tCharCount into tHigh

  -- tMid contains the current number of characters we are 'guessing' will fit in tWidth.
  -- We make a initial estimate based on the width of the trailer. This initial estimate should
  -- virtually eliminate any advantage the linear algorithm has over the binary search in the
  -- case of a long line fitting into a small width.
  local tMid
  put tMaxWidth div (tTrailerWidth div 2) into tMid

  -- We loop until they are one apart - in which case the char between positions tLow and tHigh
  -- contains the break width.
  repeat while tHigh - tLow > 1

    -- Compute the width of tMid characters.
    local tWidth
    put (the formattedWidth of char 1 to tMid + 1 of field ID pFieldId) into tWidth

    if tWidth > tMaxWidth then
      -- If the new width is too much, bring down the high point
      put tMid into tHigh
    else if tWidth < tMaxWidth then
      -- If the new width is too little, bring up the low point
      put tMid into tLow
    else
      -- If we have reached the target width then exit, adjusting by one (we want
      -- the number of chars that goes from too small, to too much)
      put tMid into tLow
      put tMid + 1 into tHigh
      exit repeat
    end if

    if tHigh - tLow <= 1 then
      exit repeat
    end if

    put tLow + (tHigh - tLow) div 2 into tMid
  end repeat

  -- At this point tMid will contain the number of chars that causes a transition from too
  -- short to too long.

  put pTrailer into char tMid to -1 of field ID pFieldId
  set the textFont of char tMid to -1 of field ID pFieldId to the effective textFont of field ID pFieldId

  set the lockMessages to msgsAreLocked
  unlock screen

  return true
end TruncateTail


local sControlsBeingAnimated = ""
local sDeleteAnimationLayer = "false"


/**
* \brief Reveals rows by animating them.
*
* \param pRows
* \param pShowOrHide
*
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


/**
* \brief Returns the rect where you can draw content in a group without making scrollbars appear.
*
* \param pGroup A reference to a group control.
*
* \return Rect
*/
private function _WorkingGroupRect pGroup
  local theRect, theWidth

  put the rect of pGroup into theRect
  add the leftMargin of pGroup to item 1 of theRect
  add the topMargin of pGroup to item 2 of theRect
  subtract the rightMargin of pGroup from item 3 of theRect
  subtract the bottomMargin of pGroup from item 4 of theRect
  if the hScrollbar of pGroup then subtract the scrollbarWidth of pGroup from item 4 of theRect
  if the vScrollbar of pGroup then subtract the scrollbarWidth of pGroup from item 3 of theRect
  if the showBorder of pGroup then
    put the borderWidth of pGroup into theWidth
    add theWidth to item 1 of theRect
    add theWidth to item 2 of theRect
    subtract theWidth from item 3 of theRect
    subtract theWidth from item 4 of theRect
  end if
  return theRect
end _WorkingGroupRect


private command _CancelMessage pMsg
  local theMessage,theMessages

  repeat until (comma & pMsg & comma) is not in the pendingMessages
    put the pendingMessages into theMessages
    filter theMessages with "*," & pMsg & ",*"
    repeat for each line theMessage in theMessages
      cancel item 1 of theMessage
    end REPEAT
  end repeat
end _CancelMessage

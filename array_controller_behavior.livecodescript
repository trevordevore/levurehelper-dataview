script "DataView Array Controller Behavior" with behavior "DataView Behavior"
local sDataA
local sIdToRowLookupA # cache created when _rowOfId() is called


/**
Summary: Set the array to feed to the DataView and Renders the DataView.

Parameters:
pDataA: A numerically indexed array of arrays.

Example:
put "Jane Doe" into tPeopleA[1]["name"]
put "Jone Doe" into tPeopleA[2]["name"]
set the dvData of group "MyDataView" to tPeopleA

Returns: nothing
*/
setProp dvData pDataA
  put pDataA into sDataA
  put empty into sIdToRowLookupA
  RenderView
end dvData


/**
Summary: Return the dvData array.

Returns: Array
*/
getprop dvData
  return sDataA
end dvData


command DataForRow pRow, @rDataA, @rTemplateStyle
  put sDataA[pRow] into rDataA
  if rDataA["@style"] is not empty then
    put rDataA["@style"] into rTemplateStyle
  else
    put "default" into rTemplateStyle
  end if
end DataForRow


function NumberOfRows
  return the number of elements of sDataA
end NumberOfRows


function CacheKeyForRow pRow
  return pRow
end CacheKeyForRow


/**
Summary: Deletes records from the source data array and refreshes the DataView with updated data source.

Parameters:
pRows: A comma-delimited list of ids to delete from the data source.
pRefreshView: Pass in false to prevent the view being refreshed.

Returns: nothing
*/
command DeleteIds pIds, pRefreshView
  local tId, tRows
  local tElementCount, tItemNo, tRow, tNextRowToDelete

  put pRefreshView is not false into pRefreshView

  repeat for each item tId in pIds
    put _rowOfId(tId) & "," after tRows
  end repeat
  delete the last char of tRows

  sort items of tRows numeric ascending
  put the number of elements of sDataA into tElementCount

  repeat for each item tRow in tRows
    add 1 to tItemNo

    delete local sDataA[tRow]

    put item tItemNo+1 of tRows into tNextRowToDelete
    if tNextRowToDelete is empty then
      put tElementCount+1 into tNextRowToDelete
    end if

    # Reindex
    repeat with tIndex = tRow+1 to tNextRowToDelete-1
      put sDataA[tIndex] into sDataA[tIndex-tItemNo]
    end repeat
  end repeat

  # Shorten the array.
  repeat with tRow = tElementCount-tItemNo+1 to tElementCount
    delete local sDataA[tRow]
  end repeat

  if the viewProp["cache"] of me is "none" then
    if pRefreshView then
      RefreshViewRows
    end if
  else
    # Dataview Behavior will remove the row controls and call RefreshViewRows
    DeleteRows tRows, pRefreshView
  end if
end DeleteIds


/**
Summary: Returns the `id` property of the selected row(s).

Description:
This property only returns a value if the array created in `DataForRow`
has an `id` key.

Returns: Value
*/
getProp dvHilitedIds
  local tRow, tRows, tIds

  put the dvHilitedRow of me into tRows

  if tRows is not empty then
    repeat for each item tRow in tRows
      put sDataA[tRow]["id"] & "," after tIds
    end repeat
    delete the last char of tIds
  end if

  return tIds
end dvHilitedIds


getProp dvHilitedId
  return the dvHilitedIds of me
end dvHilitedId


/**
Summary: Sets the selected row based on the `id` property of a row.

Parameters:
pForceScroll: Passed along to `dvHilitedRow` in the DataView behavior.
pIds: The ids to hilite.

Description:
This property can only be set if the array created in `DataForRow`
has an `id` key.

Returns: empty
*/
setProp dvHilitedIds[pForceScroll] pIds
  _setHilitedIds pIds, pForceScroll
end dvHilitedIds


setProp dvHilitedId[pForceScroll] pId
  _setHilitedIds pId, pForceScroll
end dvHilitedId


/**
Summary: Returns the data array of the currently selected row(s).

Description:
If a single row is selected then the array associated with that row
will be returned. If multiple rows are selected, then the result will
be a numerically indexed array of row data.

Returns: Array
*/
getProp dvHilitedData
  local tRow, tRows, tIds

  put the dvHilitedRow of me into tRows

  if the number of items of tRows is 1 then
    return sDataA[tRows]
  else
    local tDataA, i
    repeat for each item tRow in tRows
      add 1 to i
      put sDataA[tRow] into tDataA[i]
    end repeat
    return tDataA
  end if
end dvHilitedData


/**
Summary: Returns the row data associated with `pRow`.

Parameters:
pRow: The target row.

Returns: Value
*/
getProp dvRowData[pRow]
  return sDataA[pRow]
end dvRowData


/**
Summary: Sets the data associated with a row.

Parameters:
pRow: The row to update.
pDataA: The array to assign to the row.

Returns: nothing
*/
setProp dvRowData[pRow] pDataA
  put pDataA into sDataA[pRow]
end dvRowData


/**
Summary: Returns the row id associated with `pRow`.

Parameters:
pRow: The target row.

Description:
This property can only be set if the array created in `DataForRow`
has an `id` key.

Returns: nothing
*/
getProp dvRowId[pRow]
  return sDataA[pRow]["id"]
end dvRowId


/**
Summary: Returns the row(s) associated with an id(s).

Parameters:
pIds: A comma-delimited list of ids.

Description:
If no row is associated with pId then 0 is returned.

Returns: Integer
*/
getProp dvRowOfId[pId]
  return _rowOfId(pId)
end dvRowOfId


/**
Summary: Returns the row data associated with a specific `id`.

Parameters:
pId: The target `id`.

Description:
This property can only be set if the array created in `DataForRow`
has an `id` key.

Returns: Value
*/
getProp dvRowOfIdData[pId]
  local tRow

  put _rowOfId(pId) into tRow

  if tRow > 0 then
    return sDataA[tRow]
  else
    return empty
  end if
end dvRowOfIdData


/**
Summary: Sets the row data associated with a specific `id.

Parameters:
pId: The target id.
pDataA: The array to associated with the row.

Description:
Use this property to update row data without needing to update the entire array.

To update the UI call `RefreshRowOfId`.

Returns: nothing
*/
setProp dvRowOfIdData[pId] pDataA
  local tRow

  put _rowOfId(pId) into tRow

  if tRow > 0 then
    put pDataA into sDataA[tRow]
  end if

  return empty
end dvRowOfIdData


/**
Summary: Returns a specific key in a row's array.

Parameters:
pRow: The target row.
pKey: The custom key.

Returns: Mixed
*/
function GetValueForKeyInRow pRow, pKey
  return sDataA[pRow][pKey]
end GetValueForKeyInRow


/**
Summary: Sets the value of a key for a row's array.

Parameters:
pRow: The target row.
pKey: The custom key.
pValue: The value to assign to the key.

Returns: nothing
*/
command SetValueForKeyInRow pRow, pKey, pValue
  put pValue into sDataA[pRow][pKey]
  return empty
end SetValueForKeyInRow


/**
Summary: Redraws the row associated with the specified `id`.

Parameters:
pId: The target id.

Description:
Call this command after updating data in the DataView affects what is
displayed in the row.

Returns: nothing
*/
command RefreshRowOfId pId
  local tRow

  put _rowOfId(pId) into tRow

  if tRow > 0 then
    RenderRows tRow
  end if

  return empty
end RefreshRowOfId


private command _setHilitedIds pIds, pForceScroll
  local tId, tRow, tRows

  repeat for each item tId in pIds
    put _rowOfId(tId) into tRow
    if tRow > 0 then
      put tRow & "," after tRows
    end if
  end repeat
  delete the last char of tRows

  set the dvHilitedRow[pForceScroll] of me to tRows

  return empty
end _setHilitedIds


private function _rowOfId pId
  local i

  if sIdToRowLookupA is not an array then
    repeat with i = 1 to the number of elements of sDataA
      put i into sIdToRowLookupA[sDataA[i]["id"]]
    end repeat
  end if

  return max(0, sIdToRowLookupA[pId])
end _rowOfId

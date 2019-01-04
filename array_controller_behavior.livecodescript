script "DataView Array Controller Behavior" with behavior "DataView Behavior"
local sDataA


/**
Summary: Set the array to feed to the DataView.

Parameters:
pDataA: A numerically indexed array of arrays.

Example:
put "Jane Doe" into tPeopleA[1]["name"]
put "Jone Doe" into tPeopleA[2]["name"]
set the dvArray of group "MyDataView" to tPeopleA

Returns: nothing
*/
setProp dvData pDataA
  put pDataA into sDataA
end dvData


command DataForRow pRow, @rDataA, @rTemplateStyle
  put sDataA[pRow] into rDataA
  put "default" into rTemplateStyle
end DataForRow


function NumberOfRows
  return the number of elements of sDataA
end NumberOfRows


function CacheKeyForRow pRow
  return pRow
end CacheKeyForRow


on deleteKey
  dispatch "DeleteSelectedRows" to me
end deleteKey


on backspaceKey
  dispatch "DeleteSelectedRows" to me
end backspaceKey


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
    return tIds
  else
    return empty
  end if
end dvHilitedIds


getProp dvHilitedId
  return the dvHilitedIds of me
end dvHilitedId


/**
Summary: Sets the selected row based on the `id` property of a row.

Description:
This property can only be set if the array created in `DataForRow`
has an `id` key.

Returns: empty
*/
setProp dvHilitedIds pIds
  _setHilitedIds pIds
  return empty
end dvHilitedIds


setProp dvHilitedId pId
  _setHilitedIds pId
  return empty
end dvHilitedId


/**
Summary: Returns the data array of the currently selected row(s).

Description:
If the DataView allows multiple selections, and multiple rows
are selected, then the result will be a numerically indexed array
of row data.

Returns: Value
*/
getProp dvHilitedData
  local tRow, tRows, tIds

  put the dvHilitedRow of me into tRows

  if tRows is not empty then
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
  else
    return empty
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

  put _RowOfId(pId) into tRow

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

  put _RowOfId(pId) into tRow

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

  put _RowOfId(pId) into tRow

  if tRow > 0 then
    RenderRows tRow
  end if

  return empty
end RefreshRowOfId


private command _setHilitedIds pIds
  local tId, tRow, tRows

  repeat for each item tId in pIds
    put _RowOfId(tId) & "," into tRow
    if tRow is not empty then
      put tRow & "," after tRows
    end if
  end repeat
  delete the last char of tRows

  if tRows is not empty then
    set the dvHilitedRow of me to tRows
  end if

  return empty
end _setHilitedIds


private function _RowOfId pId
  local i

  repeat with i = 1 to the number of elements of sDataA
    if sDataA[i]["id"] is pId then
      return i
    end if
  end repeat

  return 0
end _RowOfId

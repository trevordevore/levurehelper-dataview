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
Summary: Returns the `id` property of the selected row.

Description:
This property only returns a value if the array created in `DataForRow`
has an `id` key.

Returns: Value
*/
getProp dvSelectedId
  local tRow

  put the dvHilitedRow of me into tRow

  if tRow > 0 then
    return sDataA[tRow]["id"]
  else
    return empty
  end if
end dvSelectedId


/**
Summary: Sets the selected row based on the `id` property of a row.

Description:
This property can only be set if the array created in `DataForRow`
has an `id` key.

Returns: empty
*/
setProp dvSelectedId pId
  local tRow

  put _RowOfId(pId) into tRow

  if tRow > 0 then
    set the dvHilitedRow of me to tRow
  end if

  return empty
end dvSelectedId


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
Summary: Returns the data array of the currently selected row.

Returns: Value
*/
getProp dvSelectedData
  local tRow

  put the dvHilitedRow of me into tRow

  if tRow > 0 then
    return sDataA[tRow]
  else
    return empty
  end if
end dvSelectedData


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


private function _RowOfId pId
  local i

  repeat with i = 1 to the number of elements of sDataA
    if sDataA[i]["id"] is pId then
      return i
    end if
  end repeat

  return 0
end _RowOfId

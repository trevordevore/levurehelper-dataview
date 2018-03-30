script "DataView Controller" with behavior "DataView Group Behavior"
local sDataA


setProp uData pDataArrayA
  put pDataArrayA into sDataA
end uData


command DataForRow pRow, @pDataA, @pTemplateStyle
  put sDataA[pRow] into pDataA
  put "default" into pTemplateStyle
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


getProp uSelectedId
  local tRow

  put the dvHilitedRow of me into tRow

  if tRow > 0 then
    return sDataA[tRow]["id"]
  else
    return empty
  end if
end uSelectedId


setProp uSelectedId pId
  local tRow

  put _RowOfId(pId) into tRow

  if tRow > 0 then
    set the dvHilitedRow of me to tRow
  end if

  return empty
end uSelectedId


setProp uRowOfIdRecord[pId] pRecordA
  local tRow

  put _RowOfId(pId) into tRow

  if tRow > 0 then
    put pRecordA into sDataA[tRow]
  end if
end uRowOfIdRecord


command RefreshRowOfId pId
  local tRow

  put _RowOfId(pId) into tRow

  if tRow > 0 then
    RenderRows tRow
  end if

  return empty
end RefreshRowOfId


getProp uSelectedRecord
  local tRow

  put the dvHilitedRow of me into tRow

  if tRow > 0 then
    return sDataA[tRow]
  else
    return empty
  end if
end uSelectedRecord


private function _RowOfId pId
  local i

  repeat with i = 1 to the number of elements of sDataA
    if sDataA[i]["id"] is pId then
      return i
    end if
  end repeat

  return 0
end _RowOfId

script "DataView Drop Indicator Behavior"
command PositionDropIndicator pDragMoveTarget, pDraggingInfoA, pRow, pDropOperation
  _resize
end PositionDropIndicator


private command _resize
  local tViewRect, tRect

  put the rect of me into tViewRect

  put the rect of graphic 1 of me into tRect
  put item 1 of tViewRect into item 1 of tRect
  put item 3 of tViewRect + 1 into item 3 of tRect
  set the rect of graphic 1 of me to tRect
end _resize

script "DataView Drop Indicator Behavior"
on resizeControl
  if the target is not me then pass resizeControl

  local theViewRect, theRect

  put the rect of me into theViewRect

  put the rect of graphic 1 of me into theRect
  put item 1 of theViewRect into item 1 of theRect
  put item 3 of theViewRect + 1 into item 3 of theRect
  set the rect of graphic 1 of me to theRect
end resizeControl

script "DataView Field Editor Frontscript"
constant kBehaviorStackName = "DataView Behavior"

/**
* \brief suspendStack occurs before exitField/closefield. Use it to tell editor not to close down.
*
*/
on suspendStack
  local theStack

  put _StackOf(the long id of me) into theStack
  dispatch "SuspendFieldEditorClosing" to stack kBehaviorStackName with _StackOf(the long id of the target), true
  --   put param(0) && the short name of the owner of the target & cr after msg
  pass suspendStack
end suspendStack


/**
* \brief Restore normal behavior on resumeStack
*
*/
on resumeStack
  local theStack

  dispatch "SuspendFieldEditorClosing" to stack kBehaviorStackName with _StackOf(the long id of the target), false
  --   put param(0) && the short name of the owner of the target & cr after msg
  pass resumeStack
end resumeStack


on openField
  --   put param(0) && the short name of _StackOf(the long id of the target) & cr after msg

  pass openField
end openField


on exitField
  --   put param(0) && the short name of _StackOf(the long id of the target) & cr after msg
  --   loggerLogMsg the short name of the target &":" && the executioncontexts
  pass exitField
end exitField


on closeField
  --   put param(0) && the short name of _StackOf(the long id of the target) & cr after msg
  pass closeField
end closeField


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

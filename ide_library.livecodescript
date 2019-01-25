script "DataView IDE Helper Library"

/**
Summary: Creates a new DataView control on the target card.

Parameters:
pName: The name of the new DataView control.
pTargetCard: A reference to the card to create the DataView on. Default is the current card of the topStack.
pBehavior: The behavior to assign to the DataView. Default is the "DataView Behavior" stack.

Description:
A DataView control is a group of controls with specific behaviors assigned
to the group and the controls in the group.

Returns: The long id of the new control.
*/
command createDataViewControl pName, pTargetCard, pBehavior
  local tControl, tTemplatesA

  if pName is empty then
    put "DataView" && the milliseconds into pName
  end if
  if pTargetCard is empty then
    put the long id of the current card of the topStack into pTargetCard
  end if
  if pBehavior is empty then
    put the long id of stack "DataView Behavior" into pBehavior
  end if

  copy group "DataView Template" of stack "DataViewControlTemplate" to pTargetCard
  put it into tControl
  set the name of tControl to pName

  set the behavior of tControl to pBehavior

  return tControl for value
end createDataViewControl


/**
Summary: Creates a new DataView after prompting the user for some options.

Parameters:
pTargetCard: A reference to the card to create the DataView on. Default is the current card of the topStack.
pBehavior: Pass in a reference to a behavior that extends the behavior of the DataView. For example, the behavior for a DataView Tree or DataView array controller. Optional.

Description:

Returns:
it: The long id of the new contorl.
*/
command createDataViewControlWithPrompts pTargetCard, pBehavior
  local tError, tPropsA, tBehavior, tControl

  if pTargetCard is empty then
    put the long id of the current card of the topStack into pTargetCard
  end if

  modal stack "CreateDataViewDialog"
  if the dialogData is "cancel" then
    put "cancel" into tError
  end if

  if tError is empty then
    put the dialogData into tPropsA

    if tPropsA["behavior name"] is not empty then
      local tParentBehavior

      put pBehavior into tParentBehavior
      if tParentBehavior is empty then
        put the long id of stack "DataView Behavior" into tParentBehavior
      end if

      _createBehavior tPropsA["behavior name"], tPropsA["behavior filename"], \
            the long id of the owner of pTargetCard, tParentBehavior
      put the result into tError

      if tError is empty then
        put the long id of stack tPropsA["behavior name"] into pBehavior
      end if
    end if
  end if

  if tError is empty then
    createDataViewControl tPropsA["name"], pTargetCard, pBehavior
    put it into tControl
  end if

  if tError is empty then
    return tControl for value
  else
    answer error tError
  end if
end createDataViewControlWithPrompts


private command _createBehavior pBehaviorName, pBehaviorFilename, pTargetStack, pParentBehavior, pScript
  local tError, tBehaviorsFolder

  put the filename of pTargetStack into tBehaviorsFolder
  if tBehaviorsFolder is empty then
    put "stack has not been saved" into tError
  end if

  set the itemDelimiter to "."
  if the number of items of pBehaviorFilename is 1 then
    put ".livecodescript" after pBehaviorFilename
  end if

  if tError is empty then
    set the itemDelimiter to "/"

    put "behaviors" into the last item of tBehaviorsFolder

    if there is not a folder tBehaviorsFolder then
      create folder tBehaviorsFolder
      put the result into tError
    end if
  end if

  if tError is empty then
    put tBehaviorsFolder & "/" & pBehaviorFilename into pBehaviorFilename

    create script only stack pBehaviorName
    close stack pBehaviorName
    if pParentBehavior is not empty then
      set the behavior of stack pBehaviorName to pParentBehavior
    end if
    set the script of stack pBehaviorName to pScript
    save stack pBehaviorName as pBehaviorFilename
    put the result into tError
  end if

  if tError is empty then
    local tStackFiles

    put the stackFiles of pTargetStack into tStackFiles
    put pBehaviorName & "," & item -2 to -1 of pBehaviorFilename into \
          line (the number of lines of tStackFiles + 1) of tStackFiles
    set the stackFiles of pTargetStack to tStackFiles
  end if

  if tError is empty then
    return empty
  else
    return tError for error
  end if
end _createBehavior

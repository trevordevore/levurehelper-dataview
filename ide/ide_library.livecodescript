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
it: The long id of the new control.
*/
command createDataViewControlUsingDialog pTargetCard, pBehavior
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

    if tPropsA["create row template"] then
      _createRowTemplate tControl
      put the result into tError
    end if
  end if

  if tError is empty then
    return tControl for value
  else if tError is not "cancel" then
    answer error tError
  end if
end createDataViewControlUsingDialog


private command _createRowTemplate pDataViewControl
  local tError, tDataViewName, tStackName, tTemplateFolder
  local tRowTemplateStackFilename, tControlTemplateFolder

  # Set up control names, folder names, and create folders
  put the short name of pDataViewControl into tDataViewName
  put tDataViewName && "Row Templates" into tStackName
  put _makeUniqueStackName(tStackName) into tStackName
  put levureAppFolder() & "/templates" into tTemplateFolder

  if there is not a folder tTemplateFolder then
    put tTemplateFolder && "folder needs to be created and added to app.yml" into tError
  end if

  if tError is empty then
    put _makeFilenameFromControlName(tStackName) into tRowTemplateStackFilename
    put _makeFolderNameFromControlName(tStackName) into tControlTemplateFolder
    put ".livecode" after tRowTemplateStackFilename
    put _makeUniqueFolderNameForFolder(tTemplateFolder, tControlTemplateFolder) into tControlTemplateFolder
    put tTemplateFolder & "/" & tControlTemplateFolder into tControlTemplateFolder
    create folder tControlTemplateFolder
    put the result into tError
  end if

  if tError is empty then
    create folder tControlTemplateFolder & "/behaviors"
    put the result into tError
  end if

  # Create row template stack that goes in ./templates folder
  if tError is empty then
    local tRowControl, tRect

    create invisible stack tStackName
    copy group "Row Template" of stack "DataViewControlTemplate" to stack tStackName
    put it into tRowControl
    set the topleft of tRowControl to 0,0
    put the rect of stack tStackName into tRect
    put item 1 of tRect + the width of tRowControl + 50 into item 3 of tRect
    put item 2 of tRect + the height of tRowControl + 50 into item 4 of tRect
    set the rect of stack tStackName to tRect
    set the visible of stack tStackName to true

    save stack tStackName as (tControlTemplateFolder & "/" & tRowTemplateStackFilename)
    put the result into tError
  end if

  # Create the behavior for the row template group
  if tError is empty then
    local tRowBehaviorTemplateFile, tBehaviorName, tBehaviorFilename, tScript

    put the filename of me into tRowBehaviorTemplateFile
    set the itemDelimiter to "/"
    put "row template script.livecodescript" into the last item of tRowBehaviorTemplateFile
    put url("binfile:" & tRowBehaviorTemplateFile) into tScript
    put textDecode(tScript, "utf8") into tScript

    put tDataViewName && "Default Row Template Behavior" into tBehaviorName
    put _makeFilenameFromControlName(tDataViewName && "Default Row Template") into tBehaviorFilename
    _createBehavior tBehaviorName, tBehaviorFilename, the long id of stack tStackName, empty, tScript
    put the result into tError
  end if

  # Assign behavior and save stack again.
  if tError is empty then
    set the behavior of tRowControl to the long id of stack tBehaviorName
    save stack tStackName as (tControlTemplateFolder & "/" & tRowTemplateStackFilename)
    put the result into tError
  end if

  if tError is empty then
    local tTemplateStylesA

    put tRowControl into tTemplateStylesA["default"]
    set the viewProp["row style templates"] of pDataViewControl to tTemplateStylesA
    set the viewProp["fixed row height"] of pDataViewControl to true
    set the viewProp["row height"] of pDataViewControl to the height of tRowControl
  end if

  if tError is empty then
    return empty for value
  else
    return tError for error
  end if
end _createRowTemplate


private function _makeUniqueStackName pStackName
  local tCounter, tStackName

  put 1 into tCounter
  put pStackName into tStackName

  repeat while there is a stack tStackName
    add 1 to tCounter
    put pStackName && tCounter into tStackName
  end repeat

  return tStackName
end _makeUniqueStackName


private function _makeFilenameFromControlName pControlName
  replace space with "_" in pControlName
  put tolower(pControlName) into pControlName
  return pControlName
end _makeFilenameFromControlName


private function _makeFolderNameFromControlName pControlName
  replace space with "-" in pControlName
  put tolower(pControlName) into pControlName
  return pControlName
end _makeFolderNameFromControlName


private function _makeUniqueFolderNameForFolder pParentFolder, pSuggestedName
  local tFolders, tFolderName, i

  put folders(pParentFolder) into tFolders

  put pSuggestedName into tFolderName

  repeat while tFolderName is among the lines of tFolders
    add 1 to i
    put pSuggestedName && i into tFolderName
  end repeat

  return tFolderName
end _makeUniqueFolderNameForFolder


private command _createBehavior pBehaviorName, pBehaviorFilename, pTargetStack, pParentBehavior, pScript
  local tError, tBehaviorsFolder

  put the filename of pTargetStack into tBehaviorsFolder
  if tBehaviorsFolder is empty then
    put quote & the short name of pTargetStack & quote && "stack has not been saved" into tError
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

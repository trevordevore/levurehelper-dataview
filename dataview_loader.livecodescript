script "DataView Assets Loader"

/**
Summary: Used to load the DataView in non-Levure applications.

Description:
Levure applications will load a DataView as a helper and automatically handles
the loading process. This script will do everything manually.

*/
on libraryStack
  if the target is not me then pass libraryStack

  local tParentFolder
  local tStackFiles, tStackFile

  put _parentFolder() into tParentFolder
  put "dataview_behavior,array_controller_behavior,scrollbar_behavior,track_drag_drop_behavior," & \
      "field_editor_behavior,drop_indicator_behavior,field_editor_frontscript" into tStackFiles

  repeat for each item tStackFile in tStackFiles
    get there is a stack (tParentFolder & "/" & tStackFile & ".livecodescript")
  end repeat

  get there is a stack (tParentFolder & "/" & "dataview.livecode")

  if the environment is "development" then
    get there is a stack (tParentFolder & "/" & "ide/row_template.livecode")
    get there is a stack (tParentFolder & "/" & "ide/create_new_dataview_dialog.livecode")
    start using stack (tParentFolder & "/" & "ide/ide_library.livecodescript")
  end if

  if the platform is "macos" then
    load extension from file (tParentFolder & "/" & "mac_scroll_wheel.lcm")
  end if

  send "__removeDataViewLoaderFromMemory" to stack "DataView Behavior" in 0 seconds
end libraryStack


command __removeDataViewLoaderFromMemory
  delete stack "DataView Assets Loader"
end __removeDataViewLoaderFromMemory


private function _parentFolder
  local tFilename
  set the itemdelimiter to "/"
  put the filename of me into tFilename
  return item 1 to -2 of tFilename
end _parentFolder

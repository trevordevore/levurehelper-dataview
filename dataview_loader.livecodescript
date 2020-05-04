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

  put _parentFolder() into tParentFolder
  if there is a stack "DataView Behavior" then
    if the environment is "development" then
      get there is a stack (tParentFolder & "/" & "ide/row_template.livecode")
      get there is a stack (tParentFolder & "/" & "ide/create_new_dataview_dialog.livecode")
      start using stack (tParentFolder & "/" & "ide/ide_library.livecodescript")
    end if

    if the platform is "macos" then
      load extension from file (tParentFolder & "/" & "mac_scroll_wheel.lcm")
    end if
  else
    answer "Please assign the stack files in the" && tParentFolder && "folder to the `mainstacks` property of your application stack file."
  end if

  stop using me
end libraryStack


private function _parentFolder
  local tFilename
  set the itemdelimiter to "/"
  put the filename of me into tFilename
  return item 1 to -2 of tFilename
end _parentFolder

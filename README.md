# DataView helper

A DataView is similar to a DataGrid form.

## Creating a DataView

Need to create an IDE helper for creating a DataView.

## Customizing templates for a DataView

Templates can go in the `app/templates` folder of a Levure project. Stacks in that folder will not be password protected so they will work with a DataView in a standalone that is otherwise password protected.

./app/templates/

./app/templates/my-row-template/

./app/templates/my-row-template/my-row-template.livecode
./app/templates/my-row-template/my-row-template-behavior.livecodescript

`InitializeTemplate`
`FillInData pDataA, pRow`
`LayoutControl pControlRect, pRow`
`HideRowControl` # if cache is `none`
`CleanupAfterRowControl`
`ShowRowControl`
`EditKey pKey`
`PreOpenFieldEditor pEditor`

pDirection: next/previous
`OpenNextFieldEditor pRow, pKey, pDirection, pActionTriggeredBy`
`CloseFieldEditor pEditor, pRow, pKey, pEventTriggeredByEvent`
`ExitFieldEditor pEditor, pRow, pKey, pEventTriggeredByEvent`

`selectedRowChanged`
`DataViewDidUpdateView`
`HeightsForRows`

`swipeRight`
`swipeLeft`

`DragReorderRows pTargetRows, pEffectiveDroppedAfterRow, pActualDroppedAfterRow`
`PositionDropIndicator pBeingDroppedAfterRow`

`HideDropIndicator`
`ShowDropIndicator`

## Creating your own custom DataView controller

Remove the `DataView Controller` behavior and handle the following:

`DataForRow pRow, @rDataA, @rTemplateStyle`
`NumberOfRows`
`CacheKeyForRow pRow`

Feed it with a database cursor, an array, etc.

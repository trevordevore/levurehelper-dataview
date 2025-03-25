# DataView Helper

A DataView displays rows of data. It is similar to a DataGrid form, a control available in the LiveCode IDE.

LiveCode Version: 8.x or higher

Platforms: Tested on Windows, macOS, and iOS.

A DataView is responsible for taking row data that your code provides and rendering it in a highly customizable way using row templates. Row data is an array of key=>value pairs. Out of the box you can assign a numerically indexed array of arrays with key=>value pairs to a DataView (see example below). But you can customize the data source any way you would like.

## Demo

The DataView Demo application includes an example of using this helper:

https://github.com/trevordevore/dataview_demo

## Installation

### Levure application

If your LiveCode application uses the Levure framework then the DataView can be added as a helper.

1. Download the latest release of **Source Code.zip|tar.gz** from https://github.com/trevordevore/levurehelper-dataview/releases
2. Unzip the contents, rename the resulting folder to **dataview**, and add the folder to the **./app/helpers** folder in your application folder.

### non-Levure applications

If your LiveCode application is not using the Levure framework then you can use the **dataview_loader.livecodescript** file to load the necessary stacks into memory.

1. Download the latest release of **Source Code.zip|tar.gz** from https://github.com/trevordevore/levurehelper-dataview/releases
2. Unzip the contents, rename the resulting folder to **dataview**, and add the folder to your application folder.
3. Using the property inspector, add the **dataview_behavior.livecodescript** stack file to the `mainstacks` property of your application stack.
4. Now add all of the remaining stack files in the **dataview** folder to the `mainstacks` property of your application stack.
5. In your application code start using the **"DataView Assets Loader"** stack and then remove it from memory.

```
start using stack "DataView Assets Loader"
delete stack "DataView Assets Loader"
```

## Creating a DataView

The DataView helper includes two commands which can create DataView group controls in the LiveCode IDE:

- `dvIdeCreateDataViewControl pName, pTargetCard, pBehavior`
- `dvIdeCreateDataViewControlUsingDialog pTargetCard, pBehavior, pRowStyleTemplateGroupsA`

`dvIdeCreateDataViewControl` will create a DataView with no additional input. The only required parameter is `pName` which will be the name of the group that is created. If `pTargetCard` is empty then the DataView group control will be added to the current card of the `topStack`. If you would like to assign a behavior to the DataView group control other than the "DataView Behavior" stack then pass a reference to it in `pBehavior`. For example, if you want to create a new DataView group control in the current card of the `topStack` that uses the DataView Array controller then you would make the following call:

```
dvIdeCreateDataViewControl "My DataView", empty, the long id of stack "DataView Array Controller Behavior"
```

`dvIdeCreateDataViewControlUsingDialog` will display a dialog with additional options. `pTargetCard` and `pBehavior` behave the same way as for `dvIdeCreateDataViewControl`.

The modal dialog that appears has a couple of additional options:

- There is a field for entering a name for the DataView group control.
- There is a checkbox for creating a row template in the *./templates* folder of your Levure application.
- There is a filed where you can enter a comma-delimited list of row template styles you want to create. One row template group will be created for each style in the list.
- There is a checkbox for specifying that you want to create a new behavior to assign to the DataView group control. This new behavior is used for your application specific code that you want to attach to the DataView. It will be saved as a script only stack in a "behaviors" folder sitting alongside the stack that the DataView is created in. The script only stack file will also be added to the `stackFiles` property of the stack.

If you pass in a value for `pBehavior` then `pBehavior` will be assigned as the behavior of the new behavior that is created. If you do not pass in `pBehavior` then the "DataView Behavior" stack will be assigned as the behavior of the new behavior.

**Note:** If you plan on adding your application specific logic directly to the DataView group control script then you do not need to create an additional behavior script. Creating the additional behavior script is only necessary if you are using version control with your application or if prefer editing your LiveCode scripts in a separate text editor.

Here is an example of creating a new DataView that uses the array controller and populating it with some test data. It is assumed that in the dialog you opted to create a row behavior. The row template that is created is coded to display a "label" key in each row.

```
dvIdeCreateDataViewControlUsingDialog empty, the long id of stack "DataView Array Controller Behavior"

put "Line 1" into tA[1]["label"]
put "Line 2" into tA[2]["label"]
put "Line 3" into tA[3]["label"]
put "Line 4" into tA[4]["label"]

set the dvData of group "My DataView" to tA
```

If you make changes to the row template group and want to see the change reflected in the DataView then issue the following calls:

```
dispatch "ResetView" to group "My DataView"
dispatch "RenderView" to group "My DataView"
```

## Assigning data to a DataView

To test that a new DataView is working you can create a simple numerically indexed array and assign it to it's `dvData` property. The default row template displays a "title" key in a field so a simple test would look like this:

```
put "Row 1" into tDataA[1]["title"]
put "Row 2" into tDataA[2]["title"]
put "Row 3" into tDataA[3]["title"]

set the dvData of group "MyDataView" to tDataA
```

## Customizing row templates

Each row in a DataView is rendered using a row template. A row template is simply a `group` that contains all of the controls necessary to display the data for a row. The group has a behavior script assigned to it that contains all of the logic for displaying row data in the template and positioning the controls in the template.

### Mapping row template groups to row styles

Each row in a DataView has a style assigned to it. The default style is `default` and that is the only style that is supported if you are using the data controller behavior script assigned to a DataView by default. If you create a [custom data controller script](#Creating-a-custom-data-controller) then you can use style names of your choosing.

Each style needs to be mapped to a group serving as a row template. You map a row template group to a row style through the `row style templates` property of a DataView. This property is an array whose keys are style names and values are a reference to a group control. Here is a simple example:

```
put the long id of group "MyRowTemplate" of stack "MyRowTemplateStack" \
    into tStyleTemplatesA["default"]
set the viewProp["row style templates"] of group "MyDataView" to tStyleTemplatesA
```

After running the above code all rows in the "MyDataView" DataView would use the "MyRowTemplate" group as the row template.

If your DataView needs more than one row template than you can use multiple styles. For example:

```
put the long id of group "HeadingTemplate" of stack "MyRowTemplateStack" \
    into tStyleTemplatesA["heading"]
put the long id of group "ParagraphTemplate" of stack "MyRowTemplateStack" \
    into tStyleTemplatesA["paragraph"]
set the viewProp["row style templates"] of group "MoreComplexView" to tStyleTemplatesA
```

After running the above code you could assign either the `heading` or `paragraph` style to each row in the "MoreComplexView" DataView and the appropriate row template group would be used.

### Where do I store row template groups?

Row templates should be stored in the `.app/templates` folder of a Levure project. Stacks in this folder are treated like a `ui` stack in that they are not loaded into memory at startup but will be loaded when the stack name is referenced in code.  What is different is that stacks in the `./app/template` folder will not be password protected which means their contents can be copied into a DataView in a standalone that is otherwise password protected.

Like the `ui` folder, each folder in the `templates` folder contains one or more LiveCode stacks as well as the supporting behavior script files. Here is an example of a `./app/templates/my-row-template/` folder that stores the behavior in a script only stack:

```
./app/templates/my-row-template/my-row-template.livecode
./app/templates/my-row-template/my-row-template-behavior.livecodescript
```

Each stack should have the following properties:

1. The stack has one card.
2. The card has one or more groups serving as a row template.
3. Each group has a behavior assigned to it.
4. If the behavior is stored in a script only stack then then assign the script only stack file to the `stackFiles` property of the stack the group is a part of.


`InitializeTemplate`
`FillInData pDataA, pRow`
`LayoutControl pControlRect, pRow`
`HideRowControl` # if cache is `none`
`CleanupAfterControl`
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

## Creating a custom data controller

A DataView doesn't have any internal knowledge of the data that it is displaying. Each time it displays a row it asks the outside world to provide the data for that row. When it needs to know how many total rows it should display it also asks the outside world. The code that provides that data can be thought of a data controller. The data controller script orchestrates moving data from a data source into a DataView and saving any changes made to data within the DataView back to the data source.

The DataView helper comes with a data controller script (`dataview_controller.livecodescript`) that is assigned as a behavior of a new DataView. This data controller script allows you to assign a numerically indexed array of data to the `dvData` property of the DataView. It will then handle feeding the data in that array to the DataView.

For more advanced cases you can remove this data controller script as the behavior and use your own data controller code. That code can reside in a different behavior script that you assign to the DataView or it might exist in another script in the message hierarchy – e.g. a `group` that the DataView is in or in the `card` or `stack` script. Regardless of where your data controller code is located, you will need to handle one message and two functions. The message is `DataForRow` and the functions are `NumberOfRows()` and `CacheKeyForRow()`. These handlers will be sent and called when you send the `RenderView` command to the DataView.

Let's look at each in turn. In the example code for each handler assume that `sData` is a numerically indexed array.

### DataForRow message

The `DataForRow` message is sent whenever the DataView needs data to associate with a row. It takes three parameters:

```
DataForRow pRow, @rDataA, @rTemplateStyle
```

- `pRow` is the number of the row that you should provide data for.
- `rDataA` is an array that you populate with the data needed to display the row.
- `rTemplateStyle` is the style to associate with the row. If you don't provide a value then `default` will be used.

Example 1:

```
command DataForRow pRow, @rDataA, @rTemplateStyle
  put sDataA[pRow] into rDataA
  put "default" into rTemplateStyle
end DataForRow
```

Example 2:

```
command DataForRow pRow, @rDataA, @rTemplateStyle
  sqlquery_moveToRecord sQueryA, pRow
  put sqlquery_currentRowToArray(sQueryA) into rDataA
  put "default" into rTemplateStyle
end DataForRow
```

### NumberOfRows function

The `NumberOfRows()` function must return the number of rows being displayed in the DataView.

Example 1:

```
function NumberOfRows
  return the number of elements of sDataA
end NumberOfRows
```

Example 2:

```
function NumberOfRows
  return sqlquery_get(sQueryA, "number of records")
end NumberOfRows
```

### CacheKeyForRow function

The `CacheKeyForRow()` function must return a unique identifier for each row. If you don't define the `CacheKeyForRow()` function in the message path then the DataView will use the row number to uniquely identify each row. If your DataView is displaying a flat list of data that cannot be reordered and that never toggles the visibility of rows then there is nothing further that needs to be done.

If, however, the row that data in your data source is associated with can change between calls to `ResetView` then you must handle `CacheKeyForRow()` and return a unique identifier for the row. For example, the primary key column from a database table will be adequate in most cases. If your DataView is displaying records from multiple tables then the primary key might not be sufficient as the primary keys from two different tables aren't necessarily unique.

```
CacheKeyForRow pRow
```

Example 1:

```
function CacheKeyForRow pRow
  return pRow
end CacheKeyForRow
```

Example 2:

```
function CacheKeyForRow pRow
  return sDataA[pRow]["id"]
end CacheKeyForRow
```

Example 3:

```
function CacheKeyForRow pRow
  return revDatabaseColumnNamed(sCursorId, "id")
end CacheKeyForRow
```

## Specifying whether or not a row is selectable

If your DataView has rows that should not be selectable by the user then return false for the `dvCanSelect` property of the row template. The following script can be added to a row template behavior:

```
getProp dvCanSelect
  return false
end dvCanSelect
```

## How caching works

`lazy`, `eager`, `none`

## Opening a field editor in a DataView

1. Dispatch `EditKeyOfRow` to the DataView
2. DataView dispatches `EditKey` to the row control.
3. Call `CreateFieldEditorForField` and pass in the field to edit in the row control.

Possible values for pEventThatTriggeredClose are `close control`,
`closeField`, `exitField`, `returnInField`, `enterInField`, and `tabKey`.

`close control` is sent when the user scrolls the row that is being edited out of view
and caching is not turned on.

## The `animate selections` property

The DataView can animate selections of rows that are not currently in view. You need to set the `viewProp["animate selections"]` property to true and have the [animationEngine](https://github.com/derbrill/animationEngine) library in use.

## The Drag Reordering API

The DataView has a built in API for drag reordering. To start a drag operation do the following:

1. Define a `dragStart` handler in your instance of the DataView.
2. In the handler set `the dvDragImageRow of me` to the first row that is being dragged. In most cases you can set the property to `item 1 of the dvHilitedRows of me` of the DataView.
3. In the handler set `the dragData["private"]` to a string that contains the necessary information for the drop. For example, line 1 of the string might be an identifier such as "file nodes" and line 2 would be `the dvHilitedRows of me`.
4. In the handler set `the dvTrackDragReorder of me to true`

At this point you will see visual feedback. A snapshot of `the dvDragImageRow` will follow the mouse around and a drop indicator will show where the drop will occur.

### ValidateRowDrop

Each time `dragMove` is called, the DataView will calculate a proposed drop row and drop operation based on the position of the mouse. It will then dispatch `ValidateRowDrop` to the DataView and pass the following parameters:

1. pDraggingInfoA: Array with `action` (the value of `dragAction`), `mouseH`, and `mouseV` keys. The `mouseH` and `mouseV` keys are the same parameters passed to `dragMove`.
2. pProposedRow: The proposed row that the drop should occur on based on the mouse vertical position.
3. pProposedDropOperation: The proposed drop operation based on the mouse vertical position. `on` or `above`.

*Note:* If the drop will occur after the last row in the DataView then the proposed row will be the number of rows in the DataView + 1 and the proposed operation will be "above".

The `ValidateRowDrop` handler can accept any of the above parameters by reference (parameter name prefixed with `@`)
and modify them. Modifying the proposed row and drop operation can be done if needed in order to redirect a drop.

If the drop should not occur over the proposed row then return `false` from `ValidateRowDrop`.

### AcceptRowDrop

When `dragDrop` is called as a result of the user "dropping" a row on the DataView your instance of the DataView will be notified with the `AcceptRowDrop` message. It will be sent the following parameters:

1. pDraggingInfoA: Array with an `action` (the `dragAction`). In addition, if keys were added to the `pDraggingInfoA` array passed by reference to `ValidateRowDrop` the those keys will be present as well.
2. pRow: The row that the drop occurred on.
3. pDropOperation: The drop operation. `on` or `above`.

This handler is where you write your application specific logic that reorders the data in the data source and refreshes the DataView.

### Customizing the row snapshot when setting the dvDragImageRow

When the `dvDragImageRow` property is set a snapshot of the corresponding row control is taken and assigned to the `dragImage` property. Three messages are sent to the row control which allow you to customize the the snapshot that is taken - `PreDragImageSnapshot`, `CreateDragImageSnapshot`, and `PostDragImageSnapshot`.

1. `PreDragImageSnapshot`: Make any customizations to the row control prior to the snapshot being taken. For example, you might hide controls in the row group control such as action menus and just leave a label field visible.
2. `CreateDragImageSnapshot pTargetSnapshotImageId`: If your code handles this message (meaning your code defines he handler and does not pass it) then it is your responsibility to export a snapshot to image id `pTargetSnapshotImageId`. Example: `export snapshot from the target to image id pTargetSnapshotImageId as PNG`. If your code doesn't handle this message then a snapshot of the row control will be exported for you.
3. In `PostDragImageSnapshot` you restore the row control to it's normal state.

These handlers will typically be defined in the row control behavior script or in the DataView instance script.

### Customizing the drop indicator

The drop indicator (the line that shows you where the drop will occur) is determined by the `viewProp["drop indicator template"]` custom property of the DataView. This property can be assigned the long id of a control (it will be converted to a rugged id when stored). If the property is empty then the drop indicator that is included with the DataView is used.

If you define your own control to use as a drop indicator then it needs a script with the following handler:

```
command PositionDropIndicator pDraggingInfoA, pRow, pDropOperation
  # Resize the control...
end PositionDropIndicator
```

Before this handler is called, the control will be have it's width resized to the width of the DataView.

The default drop indicator template is a group with a script similar to the following:

```
command PositionDropIndicator pDraggingInfoA, pRow, pDropOperation
  local tViewRect, tRect

  put the rect of me into tViewRect

  put the rect of graphic 1 of me into tRect
  put item 1 of tViewRect into item 1 of tRect
  put item 3 of tViewRect + 1 into item 3 of tRect
  set the rect of graphic 1 of me to tRect
end PositionDropIndicator
```

### Mobile and web support for drag reordering

Limited drag reordering support has been implemented for mobile and web using
mouse events and by showing the drag image within the dataview. The drag image
if used only moves vertically in the view. These drag
operations are only supported within the one dataview. To initiate a drag
reorder on mobile you need to script the drag detection with a dataview
script such as:

```
local sDetectDrag = false
on mouseDown
  if (the platform is "web" or the environment is "mobile") then
    put true into sDetectDrag
  end if

  pass mouseDown
end mouseDown

on mouseUp
  if (the platform is "web" or the environment is "mobile") then
    put false into sDetectDrag
  end if

  pass mouseUp
end mouseUp

on mouseRelease
  if (the platform is "web" or the environment is "mobile") then
    put false into sDetectDrag
  end if

  pass mouseRelease
end mouseRelease

on mouseMove \
    pMouseH, \
    pMouseV

  if (the platform is "web" or the environment is "mobile") and \
      sDetectDrag and \
      _DragBegun(pMouseH, pMouseV) then
    put false into sDetectDrag

    /* Manually set the dragAction because the dragSource can not be used
     * to detect a move */
    set the dragAction to "move"
    set the dragData["private"] to the dvRow of the dvRowControl of the target
    set the dvDragImageRow of me to the dragData["private"]
    set the dvTrackDragReorder of the dvControl of me to true
  end if

  pass mouseMove
end mouseMove

private function _DragBegun \
    pMouseH, \
    pMouseV

  return abs(sqrt((clickH()  - pMouseH) ^ 2 \
      + (clickV() - pMouseV) ^ 2 )) >= the dragDelta
end _DragBegun
```

Additional decoration of the drag image for web and mobile can be implemented
such as:

```
on PostDragImageSnapshot
  if the platform is "web" or the environment is "mobile" then
    set the blendLevel of image "dvDragImage" of me to 15
    set the innerGlow["color"] of image "dvDragImage" of me to "0,0,255"
  end if
end PostDragImageSnapshot
```

## A Note on Behaviors

This is mainly for folks who aren't using the Levure framework as they are more likely to run into the situation described below. Levure makes sure that behaviors are loaded into memory before any stacks try to load them.

Behaviors are wonderful things. Except when they don't resolve properly. Then they are terrible things because they trick you into thinking they really did resolve properly. Here is what you need to know so you don't go down a troubleshooting rabbit hole and never come out.

When the LiveCode engine finds a control which has its behavior property set it tries to resolve the behavior reference in order to find the script. If, for any reason, the engine cannot find the script that is referenced by the behavior property then the engine will silently move along as if nothing bad has happened. But something bad has happened. The behavior script wasn't loaded so any functionality that the behavior script provided will not work. When might something like this happen?

If you are storing your behaviors in script only stacks or a control in a stack that is not part of your main application then this might happen to you.

### What should you do?

A full-proof solution is to add each stack file that contains a behavior script to the `stackfiles` property of your main application stack. You can do this using the stack property inspector. By doing this the engine will always be able to track down the behavior when your application stack opens.

Be aware that if you use `dvIdeCreateRowTemplates` to create row templates that a behavior will be stored in a script only stack. While this handler will assign the script only stack file to the `stackfiles` property of the stack that contains the row template, the script only stack file will not be assigned to the `stackfiles` property of your application stack. 

For example, if your application stack 1) has a DataView in it and 2) you save the stack with row template groups loaded into the DataView then you must assign the row template behavior script only stack files to the `stackfiles` of your application stack. Otherwise when your application stack is loaded by the LiveCode engine it sees the row template groups, tries to resolve the behaviors assigned to them, can't find them, and you start wondering why your DataView is no longer functioning properly.

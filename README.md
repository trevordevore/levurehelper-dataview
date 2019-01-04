# DataView Helper

A DataView displays rows of data. It is similar to a DataGrid form, a control available in the LiveCode IDE. 

LiveCode Version: 8.x or higher
Platoforms: Tested on Windows, macOS, and iOS.

A DataView is responsible for taking row data that your code provides and rendering it in a highly customizable way using row templates. Row data is an array of key=>value pairs. Out of the box you can assign a numerically indexed array of arrays with key=>value pairs to a DataView (see example below). But you can customize the data source any way you would like. 

## Demo

The DataView Demo application includes an example of using this helper:

https://github.com/trevordevore/dataview_demo

## Creating a DataView

Need to create an IDE helper for creating a DataView. It should also create a default row template.

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

After running the above code you could assign either the `headng` or `paragraph` style to each row in the "MoreComplexView" DataView and the appropriate row template group would be used.

### Where do I store row template groups?

Row templates should be stored in the `.app/templates` folder of a Levure project. Stacks in this folder are treated like a `ui` stack in that they are not loaded into memory at startup but will be loaded when the stack name is referenced in code.  What is different is that stacks in the `./app/template` folder will not be password protected which means their contents can be copied into a DataView in a standalone that is otherwise password protected.

Like the `ui` folder, each folder in the `templates` folder contains one or more livecode stacks as well as the supporting behavior script files. Here is an example of a `./app/templates/my-row-template/` folder that stores the behavior in a script only stack:

```
./app/templates/my-row-template/my-row-template.livecode
./app/templates/my-row-template/my-row-template-behavior.livecodescript
```

Each stack should have the following properties:

1. The stack has one card.
2. The card has one or more groups serving as a row template.
3. Each group has a behavior assigned to it.
4. If the behavior is stored in a script only stack then then assign the behavior script only stack file to the `stackFiles` property of the stack the group is a part of.


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

## Creating a custom data controller

A DataView doesn't have any internal knowledge of the data that it is displaying. Each time it displays a row it asks the outside world to provide the data for that row. When it needs to know how many total rows it should display it also asks the outside world. The code that provides that data can be thought of a data controller. The data controller script orchestrates moving data from a data source into a DataView and saving any changes made to data within the DataView back to the data source.

The DataView helper comes with a data controller script (`dataview_controller.livecodescript`) that is assigned as a behavior of a new DataView. This data controller script allows you to assign a numerically indexed array of data to the `uData` property of the DataView. It will then handle feeding the data in that array to the DataView.

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

If, however, the row that data in your data source is associated with can change inbetween calls to `ResetView` then you must handle `CacheKeyForRow()` and return a unique identifier for the row. For example, the primary key column from a database table will be adequate in most cases. If your DataView is displaying records from multiple tables then the primary key might not be sufficient as the primary keys from two different tables aren't necessarily unique.

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

## Specifing whether or not a row is selectable

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
3. Call `CreateFieldEditorForField` and pass in the field to edit in the row contorl.

Possible values for pEventThatTriggeredClose are `close control`,
`closeField`, `exitField`, `returnInField`, `enterInField`, and `tabKey`.

`close control` is sent when the user scrolls the row that is being edited out of view
and caching is not turned on.

## The `animate selections` property

The DataView can animate selections of rows that are not currently in view. You need to set the `viewProp["animate selections"]` property to true and have the [animationEngine](https://github.com/derbrill/animationEngine) library in use.

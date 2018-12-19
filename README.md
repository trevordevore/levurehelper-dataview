# DataView helper

A DataView is similar to a DataGrid form.

## Creating a DataView

Need to create an IDE helper for creating a DataView.

## Customizing row templates

Each row in a DataView is represented by a row template. A row template is simply a `group` that contains all of the controls necessary to display the data for a row. The group has a behavior script assigned to it that contains all of the logic for displaying row data in the template and positioning the controls in the template.

### Mapping row template groups to row styles

Each row in a DataView has a style assigned to it. The default style is `default` but you can use style names of your choosing. Each style needs to be mapped to a group serving as a row template. You map a row template group to a row style through the `row style templates` property of a DataView. This property is an array whose keys are style names and values are a reference to a group control. Here is a simple example:

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

## Creating your own custom DataView controller

Remove the `DataView Controller` behavior and handle the following:

`DataForRow pRow, @rDataA, @rTemplateStyle`
`NumberOfRows`
`CacheKeyForRow pRow`

Feed it with a database cursor, an array, etc.

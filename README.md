# DataView helper

A DataView is similar to a Data Grid form.

## Creating a DataView

Need to create an IDE helper for creating a DataView.

## Customizing templates for a DataView

Templates can go in the `app/templates` folder of a Levure project. Stacks in that folder will not be password protected so they will work with a DataView in a standalone that is otherwise password protected.

## Creating your own custom DataView controller

Remove the `DataView Controller` behavior and handle the following:

`DataForRow`
`NumberOfRows`
`CacheKeyForRow`

Feed it with a database cursor, an array, etc.

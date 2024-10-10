# ``Reorderable``

## Overview
``Reorderable`` is a set of pure SwiftUI components that allow for easy drag-and-drop reordering operations. They enable fast, DragGesture based interactions with their elements instead of to the long press based one that comes with [`.onDrag`](https://developer.apple.com/documentation/swiftui/view/ondrag(_:))/[`.draggable`](https://developer.apple.com/documentation/swiftui/view/draggable(_:)). Here it is in action in the upcoming [Vis](https://vis.fitness) iOS app:

![An animated recording of the Vis app, where the user selects the "Reorder Blocks" option and then proceeds to drag blocks from the planned workout around, rearranging their order.](https://github.com/visfitness/reorderable/raw/main/Documentation/visdemo.gif)

## Github

The git repository as well as issue tracker for this project can be found at  [https://github.com/visfitness/reorderable](https://github.com/visfitness/reorderable).

## Topics

### Essentials

- <doc:Getting-Started>

### Components

- ``ReorderableVStack``
- ``ReorderableHStack``

### Customizing dragging

- ``ReorderableHStack/dragDisabled(_:)``
- ``SwiftUICore/View/dragHandle()``

### Using inside of a ScrollView

- ``SwiftUI/ScrollView/autoScrollOnEdges()``

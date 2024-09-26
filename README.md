# SwiftUI Reorderable
A pure SwiftUI structural component that allows for easy drag-and-drop reordering operations. It enables fast, `DragGesture` based interactions with its elements instead of to the "long press" based one that comes with [`.onDrag`](https://developer.apple.com/documentation/swiftui/view/ondrag(_:))/[`.draggable`](https://developer.apple.com/documentation/swiftui/view/draggable(_:)). Here it is in action in the upcoming [Vis](https://vis.fitness) iOS app: 

![An animated recording of the Vis app, where the user selects the "Reorder Blocks" option and then proceeds to drag blocks from the planned workout around, rearranging their order.](/Documentation/visdemo.gif)

This currently only a `ReorderableVStack` generated from a collection of identifiable data (similar to this [SwiftUI `List` initializer](https://developer.apple.com/documentation/swiftui/list/init%28_:rowcontent:%29-7vpgz)). More containers are going to come as needed, but feel free to submit an issue or a PR if there is something you'd like to see.

## Features

- Specify your own drag handle with the `.dragHandle()` modifier
- Disable/Enable dragging via the `.dragDisabled(_ dragDisabled: Bool)` modifier, which plays nicely with animations (as opposed to adding/removing a `.onDrag()` modifier)!
- Easily customize your drag state via a `isDragged` parameter passed to your `content` `ViewBuilder`. 

## Installation

This component is distributed as a **Swift Package**. Simply add the following URL to your package list:

```
https://github.com/visfitness/reorderable
```

To add this package to your XCode project, follow [these instructions](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

## Usage

> [!NOTE]
> All the following sample use the following `struct` for their data
>
> ```swift
> private struct Sample: Identifiable {
>  var color: UIColor
>  var id: Int
>  var height: CGFloat
>  
>  init(_ color: UIColor, _ id: Int, _ height: CGFloat) {
>    self.color = color
>    self.id = id
>    self.height = height
>  }
> }
> ```

### Simple Example

```swift
struct SimpleExample: View {
  @State var data = [
    Sample(UIColor.systemBlue, 1, 200),
    Sample(UIColor.systemGreen, 2, 100),
    Sample(UIColor.systemGray, 3, 300)
  ]
  
  var body: some View {
    ReorderableVStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(sample.color))
        .frame(height: sample.height)
        .padding()
    }
    .padding()
  }
}
```

### With Custom Drag Handle and Dragging Effect

```swift
struct SimpleExample: View {
  @State var data = [
    Sample(UIColor.systemBlue, 1, 200),
    Sample(UIColor.systemGreen, 2, 100),
    Sample(UIColor.systemGray, 3, 300)
  ]
  
  var body: some View {
    ReorderableVStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample, isDragged in // <------ Notice the additional `isDragged` parameter
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(height: sample.height)
        
        Image(systemName: "line.3.horizontal")
          .foregroundStyle(.secondary)
          .padding()
          .offset(x: 16)
          // This will now be the only place users can drag the view from
          .dragHandle() // <------------
      }
      .scaleEffect(isDragged ? 1.1: 1)
      .animation(.easeOut, value: isDragged)
      .padding()
    }.padding()
  }
}
```

### When Part of a `ScrollView`

> [!WARNING]
> Because this package doesn't rely on SwiftUI's native `onDrag`, it also doesn't automatically trigger auto-scrolling when users drag the element to the edge of the parent/ancestor `ScrollView`. To enable this behavior, the `autoScrollOnEdges()` modifier needs to be applied to the `ScrollView`.

```swift
struct SimpleExample: View {
  @State var data = [
    Sample(UIColor.systemBlue, 1, 200),
    Sample(UIColor.systemGreen, 2, 200),
    Sample(UIColor.systemGray, 3, 300),
    Sample(UIColor.systemMint, 4, 200),
    Sample(UIColor.systemPurple, 5, 300),
    Sample(UIColor.orange, 6, 200)
  ]
  
  var body: some View {  
    ScrollView {
      ReorderableVStack(data, onMove: { from, to in
        withAnimation {
          data.move(fromOffsets: IndexSet(integer: from),
                    toOffset: (to > from) ? to + 1 : to)
        }
      }) { sample in
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(height: sample.height)
          .padding()
      }.padding()
    }.autoScrollOnEdges() // <------- This modifier enables the autoscrolling
  }
}
```



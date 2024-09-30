# SwiftUI Reorderable
A pure SwiftUI structural component that allows for easy drag-and-drop reordering operations. It enables fast, `DragGesture` based interactions with its elements instead of to the "long press" based one that comes with [`.onDrag`](https://developer.apple.com/documentation/swiftui/view/ondrag(_:))/[`.draggable`](https://developer.apple.com/documentation/swiftui/view/draggable(_:)). Here it is in action in the upcoming [Vis](https://vis.fitness) iOS app: 

![An animated recording of the Vis app, where the user selects the "Reorder Blocks" option and then proceeds to drag blocks from the planned workout around, rearranging their order.](/Documentation/visdemo.gif)

This currently contains a `ReorderableVStack` and a `ReorderableHStack` that take in a collection of identifiable data and a `ViewBuilder` (similar to this [SwiftUI `List` initializer](https://developer.apple.com/documentation/swiftui/list/init%28_:rowcontent:%29-7vpgz)). However, because these take in a collection rather than a `Binding` to a collection, there are some key differences, namely: 

- The need for the `onMove` parameter.
- Can't directly mutate the parameter of the `ViewBuilder`.

The second point makes it kind of tedious (but not impossible, see nested sample) to nest the two containers. A version that takes in bindings will come eventually.

## Features

- Specify your own drag handle with the `.dragHandle()` modifier
- Disable/Enable dragging via the `.dragDisabled(_ dragDisabled: Bool)` modifier, which plays nicely with animations (as opposed to adding/removing a `.onDrag()` modifier)
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

### Nested `ReorderableHStack` in `ReorderableVStack`

```swift
private struct Sample2D: Identifiable {
  var id: UUID = UUID()
  var row: [Sample]
}

struct SimpleExample: View {
  @State var data: [Sample2D] = [
    .init(row: [.init(UIColor.systemBlue, 1, 200), .init(UIColor.systemGreen, 2, 100), .init(UIColor.systemGray, 3, 200)]),
    .init(row: [.init(UIColor.systemRed, 1, 200), .init(UIColor.systemMint, 2, 100), .init(UIColor.systemPurple, 3, 200)]),
    .init(row: [.init(UIColor.systemIndigo, 1, 200), .init(UIColor.systemTeal, 2, 100), .init(UIColor.systemYellow, 3, 200)]),
  ]

  ReorderableVStack(data, onMove: { from, to in
    withAnimation {
      data.move(fromOffsets: IndexSet(integer: from),
                toOffset: (to > from) ? to + 1 : to)
    }
  }) { sample in
    HStack {
      ZStack {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(Color(UIColor.systemOrange))
          .frame(width: 64, height: 64)
          .padding()
       
        Image(systemName: "line.3.horizontal")
          .foregroundStyle(.secondary)
          .padding()
      }
      .dragHandle()
      
      ReorderableHStack(sample.row, onMove: { from, to in
        withAnimation {
          let index = data.firstIndex(where: {$0.id == sample.id})!
          data[index].row.move(fromOffsets: IndexSet(integer: from),
                                   toOffset: (to > from) ? to + 1 : to)
        }
      }) { sample in
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(Color(sample.color))
          .frame(width: 64, height: 64)
          .padding()
      }
    }
  }
}
```

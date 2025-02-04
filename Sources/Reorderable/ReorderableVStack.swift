import SwiftUI

/// A view that arranges its subviews in a vertical line and allows reordering of its elements by drag and dropping.
///
/// This component uses `DragGesture` based interaction as opposed to the long press based one that comes with [`.onDrag`](https://developer.apple.com/documentation/swiftui/view/ondrag(_:))/[`.draggable`](https://developer.apple.com/documentation/swiftui/view/draggable(_:)).
///
/// > Note: While this component allows for drag-and-drop interactions, it doesn't participate in iOS standard drag-and-drop mechanism. Thus dragged elements can't be dropped into other views modified with `.onDrop`.
@available(iOS 18.0, macOS 15.0, *)
public struct ReorderableVStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Index == Int {
  
  /// Creates a reorderable vertical stack that computes its rows on demand from an underlying collection of identifiable data, with the added information of whether the user is currently dragging the element.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the vertical stack
  ///   - onMove: A callback triggered whenever two elements had their positions switched
  ///   - content: A view builder that creates the view for a single element of the list, with an extra boolean parameter indicating whether the user is currently dragging the element.
  public init(_ data: Data, onMove: @escaping (Int, Int) -> Void, content: @escaping (Data.Element, Bool) -> Content) {
    self.data = data
    self.onMove = onMove
    self.content = content
  }
  
  /// Creates a reorderable vertical stack that computes its rows on demand from an underlying collection of identifiable data.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the vertical stack
  ///   - onMove: A callback triggered whenever two elements had their positions switched
  ///   - content: A view builder that creates the view for a single element of the list.
  public init(_ data: Data, onMove: @escaping (Int, Int) -> Void, @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.data = data
    self.onMove = onMove
    self.content = { datum, _ in content(datum) }
  }
  
  var data: Data
  let onMove: (_ from: Int, _ to: Int) -> Void
  @ViewBuilder var content: (_ data: Data.Element, _ isDragged: Bool) -> Content
  
  /// The coordinate space to use for this stack.
  ///
  /// Note that this is marked with `@State`. Since the structure gets recreated anytime the data changes,
  /// we need to mark this as a state to ensure that the coordinate space remains constant.
  @State var coordinateSpaceName: String = UUID().uuidString
  
  @_documentation(visibility: internal)
  public var body: some View {
    VStack(spacing: 0) {
      ReorderableStack<VerticalContainerAxis, Data, Content>(data, coordinateSpaceName: coordinateSpaceName, onMove: onMove, content: content)
    }.coordinateSpace(name: coordinateSpaceName)
  }
}

private struct Sample: Identifiable {
  var color: UIColor
  var id: UUID = UUID()
  var height: CGFloat
  
  init(_ color: UIColor, _ height: CGFloat) {
    self.color = color
    self.height = height
  }
}

#Preview("Short Stack") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 100), Sample(UIColor.systemGray, 300)]
  
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

#Preview("Short Stack with Disable Toggle") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 100), Sample(UIColor.systemGray, 200)]
  
  @Previewable @State var disableToggle: Bool = true
  
  VStack {
    Toggle("Disable Drag", isOn: $disableToggle)
      .padding(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 36))
    
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
    .dragDisabled(disableToggle)
    .padding()
  }
}

#Preview("Short Stack with Drag State") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 100), Sample(UIColor.systemGray, 300)]
  
    ReorderableVStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample, isDragged in
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(sample.color))
        .frame(height: sample.height)
        .scaleEffect(isDragged ? 1.1: 1)
        .animation(.easeOut, value: isDragged)
        .padding()
    }
    .padding()
}

#Preview("Short Stack with Handles") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 100), Sample(UIColor.systemGray, 300)]
  
    ReorderableVStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(height: sample.height)
        
        Image(systemName: "line.3.horizontal")
          .foregroundStyle(.secondary)
          .padding()
          .offset(x: 16)
          .dragHandle()
      }
      .padding()
    }.padding()
}

#Preview("Tall Stack without Autoscroll") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 200), Sample(UIColor.systemGray, 300), Sample(UIColor.systemMint, 200), Sample(UIColor.systemPurple, 300), Sample(UIColor.orange, 200)]
  
  ScrollView {
    ReorderableVStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(height: sample.height)
        
        Image(systemName: "line.3.horizontal")
          .foregroundStyle(.secondary)
          .padding()
          .offset(x: 16)
          .dragHandle()
      }
      .padding()
    }.padding()
  }
}

#Preview("Tall Stack with Autoscroll") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 200), Sample(UIColor.systemGray, 300), Sample(UIColor.systemMint, 200), Sample(UIColor.systemPurple, 300), Sample(UIColor.orange, 200)]
  
  ScrollView {
    ReorderableVStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(height: sample.height)
        
        Image(systemName: "line.3.horizontal")
          .foregroundStyle(.secondary)
          .padding()
          .offset(x: 16)
          .dragHandle()
      }
      .padding()
    }.padding()
  }.autoScrollOnEdges()
}

#Preview("Tall Stack with Autoscroll and Content Before + After") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 200), Sample(UIColor.systemGray, 300), Sample(UIColor.systemMint, 200), Sample(UIColor.systemPurple, 300), Sample(UIColor.orange, 200)]
  
  ScrollView {
    VStack {
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(UIColor.systemIndigo))
        .frame(height: 300)
        .padding()
        .overlay {
          Text("Static Content Before")
        }
      
      ReorderableVStack(data, onMove: { from, to in
        withAnimation {
          data.move(fromOffsets: IndexSet(integer: from),
                    toOffset: (to > from) ? to + 1 : to)
        }
      }) { sample in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color(sample.color))
            .frame(height: sample.height)
          
          Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .padding()
            .offset(x: 16)
            .dragHandle()
        }
        .padding()
      }
      
      
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(UIColor.systemRed))
        .frame(height: 300)
        .padding()
        .overlay {
          Text("Static Content After")
        }
    }
  }.autoScrollOnEdges()
}

#Preview("Short Stack with Add/Remove") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 100), Sample(UIColor.systemGray, 200)
  ]
    
  VStack {
    Button {
      data.append(.init(UIColor.systemMint, 100))
    } label: {
      Text("Add Element")
    }.buttonStyle(.borderedProminent)
    
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
        .overlay {
          Button(role: .destructive) {
            data.removeAll(where: { $0.id == sample.id })
          } label : {
            Text("Remove")
          }.buttonStyle(.borderedProminent)
        }
    }
    .padding()
  }
}

private struct Sample2D: Identifiable {
  var id: UUID = UUID()
  var row: [Sample]
}

#Preview("Short Stack of Narrow Stack") {
  @Previewable @State var data: [Sample2D] = [
    .init(row: [.init(UIColor.systemBlue, 200), .init(UIColor.systemGreen, 100), .init(UIColor.systemGray, 200)]),
    .init(row: [.init(UIColor.systemRed, 200), .init(UIColor.systemMint, 100), .init(UIColor.systemPurple, 200)]),
    .init(row: [.init(UIColor.systemIndigo, 200), .init(UIColor.systemTeal, 100), .init(UIColor.systemYellow, 200)]),
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

#Preview("Using Binding") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 200), Sample(UIColor.systemGreen, 100), Sample(UIColor.systemGray, 300)]
  
  ReorderableVStack($data) { $sample in
    RoundedRectangle(cornerRadius: 32, style: .continuous)
      .fill(Color(sample.color))
      .frame(height: sample.height)
      .padding()
      .onTapGesture {
        withAnimation {
          sample.color = [UIColor.systemRed, UIColor.systemYellow, UIColor.systemMint].randomElement()!
        }
      }
  }
  .padding()
}

#Preview("Short Stack of Narrow Stack using bindings") {
  @Previewable @State var data: [Sample2D] = [
    .init(row: [.init(UIColor.systemBlue, 200), .init(UIColor.systemGreen, 100), .init(UIColor.systemGray, 200)]),
    .init(row: [.init(UIColor.systemRed, 200), .init(UIColor.systemMint, 100), .init(UIColor.systemPurple, 200)]),
    .init(row: [.init(UIColor.systemIndigo, 200), .init(UIColor.systemTeal, 100), .init(UIColor.systemYellow, 200)]),
  ]

  ReorderableVStack($data) { $sample in
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
      
      ReorderableHStack($sample.row) { $sample in
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(Color(sample.color))
          .frame(width: 64, height: 64)
          .padding()
      }
    }
  }
}

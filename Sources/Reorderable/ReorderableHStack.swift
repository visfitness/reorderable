import SwiftUI

/// A view that arranges its subviews in a horizontal line and allows reordering of its elements by drag and dropping.
///
/// Note that this doesn't participate in iOS standard drag-and-drop mechanism and thus dragged elements can't be dropped into other views modified with `.onDrop`.
@available(iOS 18.0, *)
public struct ReorderableHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Index == Int {
  
  /// Creates a reorderable horizontal stack that computes its rows on demand from an underlying collection of identifiable data, with the added information of whether the user is currently dragging the element.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the horizontal stack
  ///   - onMove: A callback triggered whenever two elements had their positions switched
  ///   - content: A view builder that creates the view for a single element of the list, with an extra boolean parameter indicating whether the user is currently dragging the element.
  public init(_ data: Data, onMove: @escaping (Int, Int) -> Void, content: @escaping (Data.Element, Bool) -> Content) {
    self.data = data
    self.onMove = onMove
    self.content = content
  }
  
  /// Creates a reorderable horizontal stack that computes its rows on demand from an underlying collection of identifiable data.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the horizontal stack
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
  
  public var body: some View {
    HStack(spacing: 0) {
      ReorderableStack<HorizontalContainerAxis, Data, Content>(data, coordinateSpaceName: coordinateSpaceName, onMove: onMove, content: content)
    }.coordinateSpace(name: coordinateSpaceName)
  }
}

private struct Sample: Identifiable {
  var color: UIColor
  var id: Int
  var width: CGFloat
  
  init(_ color: UIColor, _ id: Int, _ height: CGFloat) {
    self.color = color
    self.id = id
    self.width = height
  }
}

#Preview("Narrow Stack") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 100), Sample(UIColor.systemGreen, 2, 50), Sample(UIColor.systemGray, 3, 150)]
  
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(sample.color))
        .frame(width: sample.width)
        .padding()
    }
    .padding()
}

#Preview("Narrow Stack with Disable Toggle") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 100), Sample(UIColor.systemGreen, 2, 50), Sample(UIColor.systemGray, 3, 150)]
  
  @Previewable @State var disableToggle: Bool = true
  
  VStack {
    Toggle("Disable Drag", isOn: $disableToggle)
      .padding(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 36))
    
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(sample.color))
        .frame(width: sample.width)
        .padding()
    }
    .dragDisabled(disableToggle)
    .padding()
  }
}

#Preview("Narrow Stack with Drag State") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 100), Sample(UIColor.systemGreen, 2, 50), Sample(UIColor.systemGray, 3, 150)]
  
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample, isDragged in
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(sample.color))
        .frame(width: sample.width)
        .scaleEffect(isDragged ? 1.1: 1)
        .animation(.easeOut, value: isDragged)
        .padding()
    }
    .padding()
}

#Preview("Narrow Stack with Handles") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 100), Sample(UIColor.systemGreen, 2, 50), Sample(UIColor.systemGray, 3, 150)]
  
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(width: sample.width)
        
        Image(systemName: "line.3.horizontal")
          .foregroundStyle(.secondary)
          .padding()
          .offset(x: 16)
          .dragHandle()
      }
      .padding()
    }.padding()
}

#Preview("Wide Stack without Autoscroll") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 100), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 150), Sample(UIColor.systemMint, 4, 100), Sample(UIColor.systemPurple, 5, 150), Sample(UIColor.orange, 6, 100)]
  
  ScrollView([.horizontal]) {
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(width: sample.width)
        
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

#Preview("Wide Stack with Autoscroll") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 100), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 150), Sample(UIColor.systemMint, 4, 100), Sample(UIColor.systemPurple, 5, 150), Sample(UIColor.orange, 6, 100)]
  
  ScrollView([.horizontal]) {
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(Color(sample.color))
          .frame(width: sample.width)
        
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

#Preview("Wide Stack with Autoscroll and Content Before + After") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 200), Sample(UIColor.systemGray, 3, 300), Sample(UIColor.systemMint, 4, 200), Sample(UIColor.systemPurple, 5, 300), Sample(UIColor.orange, 6, 200)]
  
  ScrollView([.horizontal]) {
    HStack {
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(UIColor.systemIndigo))
        .frame(width: 300)
        .padding()
        .overlay {
          Text("Static Content Before")
        }
      
      ReorderableHStack(data, onMove: { from, to in
        withAnimation {
          data.move(fromOffsets: IndexSet(integer: from),
                    toOffset: (to > from) ? to + 1 : to)
        }
      }) { sample in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color(sample.color))
            .frame(width: sample.width)
          
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
        .frame(width: 300)
        .padding()
        .overlay {
          Text("Static Content After")
        }
    }
  }.autoScrollOnEdges()
}

#Preview("Narrow Stack with Add/Remove") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 200)]
    
  VStack {
    Button {
      data.append(.init(UIColor.systemMint, data.count + 2, 100))
    } label: {
      Text("Add Element")
    }.buttonStyle(.borderedProminent)
    
    ReorderableHStack(data, onMove: { from, to in
      withAnimation {
        data.move(fromOffsets: IndexSet(integer: from),
                  toOffset: (to > from) ? to + 1 : to)
      }
    }) { sample in
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color(sample.color))
        .frame(width: sample.width)
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

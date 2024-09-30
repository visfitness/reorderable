import SwiftUI

private let stackCoordinateSpaceName = "Stack"

/// A view that arranges its subviews in a vertical line and allows reordering of its elements by drag and dropping.
///
/// Note that this doesn't participate in iOS standard drag-and-drop mechanism and thus dragged elements can't be dropped into other views modified with `.onDrop`.
@available(iOS 18.0, *)
public struct ReorderableVStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Index == Int {
  
  /// Creates a reorderable vertical stack that computes its rows on demand from an underlying collection of identifiable data, with the added information of whether the user is currently dragging the element.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the vertical stack
  ///   - onMove: A callback triggered whenever two elements had their positions switched
  ///   - content: A view builder that creates the view for a single element of the list, with an extra boolean parameter indicating whether the user is currently dragging the element.
  public init(_ data: Data, onMove: @escaping (Int, Int) -> Void, content: @escaping (Data.Element, Bool) -> Content) {
    self.data = data
    self.dataKeys = Set(data.map(\.id))
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
    self.dataKeys = Set(data.map(\.id))
    self.onMove = onMove
    self.content = { datum, _ in content(datum) }
  }
  
  var data: Data
  /// The set of IDs for the elements.
  ///
  /// This is used to check whether the element from the `positions` dictionary is actually there. While we are removing the positions using `onDisappear` when an element is removed, there is a race condition where a user could start dragging something before this callback happened.
  ///
  /// Sadly, we can't just clean up the removed elemetns in `positions` in `.init` as we can't access state data in there.
  private let dataKeys: Set<Data.Element.ID>
  
  let onMove: (_ from: Int, _ to: Int) -> Void
  @ViewBuilder var content: (_ data: Data.Element, _ isDragged: Bool) -> Content
  
  /// Contains the vertical positions of all elements.
  @State private var positions: [Data.Element.ID: VerticalPosition] = [:]
  
  /// This contains both drag and scroll offsets for rendering
  @State private var displayOffset: CGFloat = 0
  
  /// The ID of the element being dragged. Nil if nothing is being dragged.
  @State private var dragging: Data.Element.ID? = nil
  
  /// These two properties are used to compute the offset due to changing the position while dragging.
  @State private var initialIndex: Data.Index? = nil
  @State private var currentIndex: Data.Index? = nil
  
  /// The ID of the last element that switched position with the dragged element.
  ///
  /// This property is so that we can prevent some hysteresis from hovering over the child we just switched to.
  @State private var lastChange: Data.Element.ID? = nil
  
  /// The ID of the element that has just been dropped and is animating into its final position.
  ///
  /// We keep track of this so that we can adjust its Z index while its animating. Else, the element might be hidden while it animates back in place.
  @State private var pendingDrop: Data.Element.ID? = nil
  
  @Environment(\.autoScrollContainerAttributes) private var scrollContainer: AutoScrollContainerAttributes?
  
  @Environment(\.dragDisabled) private var dragDisabled: Bool
  
  /// Timer used to continually scroll when dragging an element close to the top. We use this rather than an animation because SwiftUI doesn't allow configuring the `ContentOffsetChanged` animation.
  @State private var scrollTimer: Timer?
  
  /// This is the position of the drag in the ScrollView coordinate space. This is used to prevent some jiggling that can happen with the timer and the drag action.
  @State private var scrollViewDragLocation: CGFloat? = nil
  
  public var body: some View {
      VStack(spacing: 0) {
        ForEach(data) { datum in
          ReorderableElement(datum: datum, isDragged: datum.id == dragging, content: content)
            .onPreferenceChange(VerticalPositionPreferenceKey.self) { pos in
              positions[datum.id] = pos
            }
            .offset(y: offsetFor(id: datum.id))
            .zIndex(datum.id == dragging || datum.id == pendingDrop ? 10: 0)
            .environment(\.reorderableDragCallback, DragCallbacks(
              onDrag: { dragCallback($0, $1, datum) },
              onDrop:  { dropCallback($0, datum)},
              isEnabled: !dragDisabled))
            .onDisappear {
              positions.removeValue(forKey: datum.id)
            }
        }
      }.coordinateSpace(name: stackCoordinateSpaceName)

  }
  
  /// The offset of the dragged item due to it having changed position.
  ///
  /// We need this since we're using the drag offset to render the element while were dragging it. The problem  is that the element changes location while we're dragging it, but the origin of the drag remains the same.
  private var positionOffset: CGFloat {
    guard let d = dragging
    else {
      return 0;
    }
    let currentIndex = data.firstIndex(where: { $0.id == d })

    if (currentIndex! > initialIndex!) {
      return data[initialIndex!..<currentIndex!].map {
        positionIsValid($0.id) ?
        positions[$0.id]!.height :
        0.0
      }.reduce(0.0, -)
    } else if (currentIndex! < initialIndex!) {
      return data[currentIndex! + 1 ... initialIndex!].map {
        positionIsValid($0.id) ?
        positions[$0.id]!.height :
        0.0
      }.reduce(0.0, +)
    }
    
    return 0.0
  }
  
  private func offsetFor(id: Data.Element.ID) -> CGFloat {
    guard id == dragging else { return 0.0 }
    return displayOffset + positionOffset
  }
  
  /// Checks whether we're dragging an element to the edge of the container and starts scrolling if so.
  ///
  /// This definitely can be refactored.
  private func edgeCheck(_ stackDrag: DragGesture.Value, _ scrollDrag: DragGesture.Value) -> Void {
    guard let pos = scrollContainer?.position,
          let bounds = scrollContainer?.bounds,
          let scrollContentBounds = scrollContainer?.contentBounds,
          let scrollContainerOffset = scrollContainer?.offset
    else {
      return
    }
    
    let bumperSize = 52.0
    let speed = 3.0
    

    let scrollEnd = scrollContentBounds.height - bounds.height
    
    if (scrollDrag.location.y <= bumperSize && pos.wrappedValue.point?.y ?? 1.0 > 0) {
      if (scrollTimer == nil) {
        var scrollOffset = scrollContainerOffset
        var dragY = stackDrag.location.y
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
          Task { @MainActor in
            pos.wrappedValue.scrollTo(x: 0, y: scrollOffset)
            
            checkIntersection(position: dragY, dragged: dragging)
            scrollOffset -= speed
            dragY -= speed
            
            
            if (pos.wrappedValue.point?.y ?? 0.0 <= 0) {
              scrollTimer?.invalidate()
              scrollTimer = nil
            } else {
              // Put this after the check to avoid unecessary jiggle when at the top.
              displayOffset -= speed
            }
          }
        }
      }
    } else if (scrollDrag.location.y >= bounds.height - bumperSize && pos.wrappedValue.point?.y ?? 0.0 < scrollEnd) {
      if (scrollTimer == nil) {
        var scrollOffset = scrollContainerOffset
        var dragY = stackDrag.location.y
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
          Task { @MainActor in
            pos.wrappedValue.scrollTo(x: 0, y: scrollOffset)
            
            checkIntersection(position: dragY, dragged: dragging)
            scrollOffset += speed
            dragY += speed
            
            if (pos.wrappedValue.point?.y ?? bounds.height >= scrollEnd) {
              scrollTimer?.invalidate()
              scrollTimer = nil
            } else {
              // Put this after the check to avoid unecessary jiggle when at the top.
              displayOffset += speed
            }
          }
        }
      }
    } else {
      if (scrollTimer != nil) {
        scrollTimer?.invalidate()
        scrollTimer = nil
      }
    }
  }
  
  private func dragCallback(_ stackDrag: DragGesture.Value, _ scrollDrag: DragGesture.Value, _ datum: Data.Element) {

    if (scrollViewDragLocation == nil) {
      scrollViewDragLocation = scrollDrag.location.y
    }

    if (scrollTimer != nil) {
      // There is some jiggling that happens when scrolling due
      // to some drag events firing in a weird order with the scroll
      // timer. This isn't perfect but it's good enough for now.
      //
      // (Basically, make sure the user moved in the Y Axis to move
      // the offset at all.
      if (abs(scrollViewDragLocation! - scrollDrag.location.y) > 0.0) {
        displayOffset = stackDrag.translation.height
      }
    } else {
      displayOffset = stackDrag.translation.height
    }
    
    currentIndex = data.firstIndex(where: { $0.id == datum.id })
    if (dragging == nil) {
      dragging = datum.id
      initialIndex = currentIndex
    }
    
    checkIntersection(position: stackDrag.location.y, dragged: datum.id)
    scrollViewDragLocation = scrollDrag.location.y
    
    edgeCheck(stackDrag, scrollDrag)
  }
  
  /// Checks whether the given position intersects with any elements and switch its position with the dragged element if so.
  private func checkIntersection(position: CGFloat, dragged: Data.Element.ID?) {
    guard let datumId = dragged else { return }
    let intersect = positions.first(where: {
      positionIsValid($0.key) &&
        $0.value.contains(position) &&
        $0.key != datumId
    })
    
    guard let element = intersect
    else {
      lastChange = nil
      return
    }

    if (lastChange == element.key && notAtOtherEdge(currentIndex: currentIndex!, element: element, position: position)) {
      return
    } else {
      lastChange = element.key
    }
    
    onMove(currentIndex!, data.firstIndex(where: { $0.id == element.key })!)
    
    currentIndex = data.firstIndex(where: { $0.id == element.key })!
  }
  
  /// Whether the user is currently hovering over the opposite side (i.e. the bottom edge of the element below or the top edge of the element above) of the given element.
  ///
  /// This is to help with the hysteresis cases where the user wants to switch back to the position the element was even though that they're still hovering over the previous element after changing spot.
  private func notAtOtherEdge(currentIndex: Int, element: (key: Data.Element.ID, value: VerticalPosition), position: CGFloat) -> Bool {
    let edgeBumperSize = 64.0
    
    let otherIndex = data.firstIndex(where: { $0.id == element.key})!
    if (currentIndex > otherIndex) {
      if (position < element.value.top + edgeBumperSize && position > element.value.top) {
        return false
      }
    } else {
      if (position > element.value.bottom - edgeBumperSize && position < element.value.bottom) {
        return false
      }
    }
    
    return true
  }
  
  private func dropCallback(_ drag: DragGesture.Value, _ datum: Data.Element) {
    scrollTimer?.invalidate()
    scrollTimer = nil
    scrollViewDragLocation = nil
    
    withAnimation {
      pendingDrop = dragging
      lastChange = nil
      dragging = nil
      displayOffset = 0
    } completion: {
      pendingDrop = nil
    }
  }
  
  /// Checks whether the element we're checking the position for is valid.
  ///
  /// An element gets deleted, there is a moment before the `onDisappear` gets called where calling `onDrag` could result in getting positions of elements that have been removed. This method checks that the element is indeed a valid one.
  private func positionIsValid(_ id: Data.Element.ID) -> Bool {
    return dataKeys.contains(id)
  }
}

@available(iOS 18.0, *)
private struct DragCallbacks {
  let onDrag: (_ stackDrag: DragGesture.Value, _ scrollDrag: DragGesture.Value) -> Void
  let onDrop: (_ stackDrag: DragGesture.Value) -> Void

  let isEnabled: Bool
}

@available(iOS 18.0, *)
private struct DragCallbackKey: @preconcurrency EnvironmentKey {
  @MainActor static let defaultValue: DragCallbacks = .init(onDrag: { _, __ in }, onDrop: { _ in }, isEnabled: false)
}

@available(iOS 18.0, *)
extension EnvironmentValues {
  fileprivate var reorderableDragCallback: DragCallbacks {
        get { self[DragCallbackKey.self] }
        set { self[DragCallbackKey.self] = newValue }
    }
}

private struct HasDragHandlePreferenceKey: PreferenceKey {
  static var defaultValue: Bool { false }
  
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

@available(iOS 18.0, *)
struct DragHandleViewModifier: ViewModifier {
  @Environment(\.reorderableDragCallback) private var dragCallbacks
  @State var alreadyHasDragHandle: Bool = false
  
  func body(content: Content) -> some View {
    content
      .onPreferenceChange(HasDragHandlePreferenceKey.self) { alreadyHasDragHandle = $0 }
      .gesture(
        SimultaneousGesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .named(stackCoordinateSpaceName)),
          DragGesture(minimumDistance: 0, coordinateSpace: .named(scrollCoordinatesSpaceName)))
          .onChanged { values in
            // Putting these here seems to garantee the execution order
            // which eliminates some of the jiggle.
            dragCallbacks.onDrag(values.first!, values.second!)
          }
          .onEnded { values in
            dragCallbacks.onDrag(values.first!, values.second!)
            dragCallbacks.onDrop(values.first!)
          },
        isEnabled: dragCallbacks.isEnabled && !alreadyHasDragHandle)
      .preference(key: HasDragHandlePreferenceKey.self, value: true)
  }
}

@available(iOS 18.0, *)
extension View {
  /// Makes this view the handle for dragging the element of a `ReorderableVStack`.
  ///
  /// Settings this on a subview of the element will make it the only way to move the element around.
  public func dragHandle() -> some View {
    modifier(DragHandleViewModifier())
  }
}

// MARK: Subviews Related Structs

private struct VerticalPosition: Equatable {
  let top: CGFloat
  let bottom: CGFloat
  
  func contains(_ y: CGFloat) -> Bool {
    return top <= y && y <= bottom
  }
  
  var height: CGFloat {
    return bottom - top
  }
}

private struct VerticalPositionPreferenceKey: PreferenceKey {
  static var defaultValue: VerticalPosition { .init(top: 0, bottom: 0) }
  
  static func reduce(value: inout VerticalPosition, nextValue: () -> VerticalPosition) {
    value = nextValue()
  }
}

@available(iOS 18.0, *)
private struct ReorderableElement<Element: Identifiable, Content: View>: View {

  var datum: Element
  var isDragged: Bool
  @ViewBuilder var content: (_ data: Element, _ isDragged: Bool) -> Content

  var body: some View {
    content(datum, isDragged)
      .overlay(GeometryReader { proxy in
        Color.clear
          .preference(
            key: VerticalPositionPreferenceKey.self,
            value: VerticalPosition(
              top: proxy.frame(in: .named(stackCoordinateSpaceName)).minY,
              bottom: proxy.frame(in: .named(stackCoordinateSpaceName)).maxY))
      })
      .dragHandle()
  }
}


private struct Sample: Identifiable {
  var color: UIColor
  var id: Int
  var height: CGFloat
  
  init(_ color: UIColor, _ id: Int, _ height: CGFloat) {
    self.color = color
    self.id = id
    self.height = height
  }
}

#Preview("Short Stack") {
  @Previewable @State var data = [
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 300)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 200)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 300)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 300)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 200), Sample(UIColor.systemGray, 3, 300), Sample(UIColor.systemMint, 4, 200), Sample(UIColor.systemPurple, 5, 300), Sample(UIColor.orange, 6, 200)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 200), Sample(UIColor.systemGray, 3, 300), Sample(UIColor.systemMint, 4, 200), Sample(UIColor.systemPurple, 5, 300), Sample(UIColor.orange, 6, 200)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 200), Sample(UIColor.systemGray, 3, 300), Sample(UIColor.systemMint, 4, 200), Sample(UIColor.systemPurple, 5, 300), Sample(UIColor.orange, 6, 200)]
  
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
    Sample(UIColor.systemBlue, 1, 200), Sample(UIColor.systemGreen, 2, 100), Sample(UIColor.systemGray, 3, 200)]
    
  VStack {
    Button {
      data.append(.init(UIColor.systemMint, data.count + 2, 100))
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

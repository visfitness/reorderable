import SwiftUI

/// A view that arranges its subviews in a line and allows reordering of its elements by drag and dropping.
///
/// Note that this doesn't participate in iOS standard drag-and-drop mechanism and thus dragged elements can't be dropped into other views modified with `.onDrop`.
@available(iOS 18.0, macOS 15.0, *)
package struct ReorderableStack<Axis: ContainerAxis, Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable, Data.Index == Int {
  
  /// Creates a reorderable stack that computes its rows on demand from an underlying collection of identifiable data, with the added information of whether the user is currently dragging the element.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the stack
  ///   - onMove: A callback triggered whenever two elements had their positions switched
  ///   - content: A view builder that creates the view for a single element of the list, with an extra boolean parameter indicating whether the user is currently dragging the element.
  ///   -
  package init(_ data: Data, coordinateSpaceName: String, onMove: @escaping (Int, Int) -> Void, content: @escaping (Data.Element, Bool) -> Content) {
    self.data = data
    self.dataKeys = Set(data.map(\.id))
    self.coordinateSpaceName = coordinateSpaceName
    self.onMove = onMove
    self.content = content
  }
  
  /// Creates a reorderable stack that computes its rows on demand from an underlying collection of identifiable data.
  ///
  /// - Parameters:
  ///   - data: A collection of identifiable data for computing the stack
  ///   - onMove: A callback triggered whenever two elements had their positions switched
  ///   - content: A view builder that creates the view for a single element of the list.
  package init(_ data: Data, coordinateSpaceName: String, onMove: @escaping (Int, Int) -> Void, @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.data = data
    self.dataKeys = Set(data.map(\.id))
    self.coordinateSpaceName = coordinateSpaceName
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
  let coordinateSpaceName: String
  
  /// Contains the positions of all elements.
  @State private var positions: [Data.Element.ID: Axis.Position] = [:]
  
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
  
  @Environment(\.disableSensoryFeedback) private var feedbackDisabled: Bool
  
  /// Timer used to continually scroll when dragging an element close to the top. We use this rather than an animation because SwiftUI doesn't allow configuring the `ContentOffsetChanged` animation.
  @State private var scrollTimer: Timer?
  
  /// This is the position of the drag in the ScrollView coordinate space. This is used to prevent some jiggling that can happen with the timer and the drag action.
  @State private var scrollViewDragLocation: CGFloat? = nil
  
  public var body: some View {
    ForEach(data) { datum in
      ReorderableElement<Axis.Position, Data.Element, Content>(datum: datum, isDragged: datum.id == dragging, content: content, coordinateSpaceName: coordinateSpaceName)
        .onPreferenceChange(Axis.Position.Preference.self) { pos in
          Task { @MainActor in
            positions[datum.id] = pos
          }
        }
        .offset(Axis.asSize(value: offsetFor(id: datum.id)))
        .zIndex(datum.id == dragging || datum.id == pendingDrop ? 10: 0)
        .environment(\.reorderableDragCallback, DragCallbacks(
          onDrag: { dragCallback($0, $1, datum) },
          onDrop:  { dropCallback($0, datum)},
          dragCoordinatesSpaceName: coordinateSpaceName,
          isEnabled: !dragDisabled))
        .onDisappear {
          positions.removeValue(forKey: datum.id)
        }
        .sensoryFeedback(trigger: currentIndex) { old, new in
          guard !feedbackDisabled else { return nil }
          switch(old, new) {
            case (.none, .some(_)): return .selection
            case (.some(_), .none): return .selection
            case (.some(_), .some(_)): return .impact(weight: .light)
            default: return nil
          }
        }
    }
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
        positions[$0.id]!.span :
        0.0
      }.reduce(0.0, -)
    } else if (currentIndex! < initialIndex!) {
      return data[currentIndex! + 1 ... initialIndex!].map {
        positionIsValid($0.id) ?
        positions[$0.id]!.span :
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

    let scrollEnd = Axis.project(size: scrollContentBounds) - Axis.project(size: bounds)
    let scrollDragPos = Axis.project(point: scrollDrag.location)
    
    if (scrollDragPos <= bumperSize && Axis.project(maybePoint: pos.wrappedValue.point) ?? 1.0 > 0) {
      if (scrollTimer == nil) {
        var scrollOffset = Axis.project(point: scrollContainerOffset)
        var dragPos = Axis.project(point: stackDrag.location)
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
          Task { @MainActor in
            pos.wrappedValue.scrollTo(point: Axis.asPoint(value: scrollOffset))
            
            checkIntersection(position: dragPos, dragged: dragging)
            scrollOffset -= speed
            dragPos -= speed
            
            
            if (Axis.project(maybePoint: pos.wrappedValue.point) ?? 0.0 <= 0) {
              scrollTimer?.invalidate()
              scrollTimer = nil
            } else {
              // Put this after the check to avoid unecessary jiggle when at the top.
              displayOffset -= speed
            }
          }
        }
      }
    } else if (scrollDragPos >= Axis.project(size: bounds) - bumperSize && Axis.project(maybePoint: pos.wrappedValue.point) ?? 0.0 < scrollEnd) {
      if (scrollTimer == nil) {
        var scrollOffset = Axis.project(point: scrollContainerOffset)
        var dragPos = Axis.project(point: stackDrag.location)
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
          Task { @MainActor in
            pos.wrappedValue.scrollTo(point: Axis.asPoint(value: scrollOffset))
            
            checkIntersection(position: dragPos, dragged: dragging)
            scrollOffset += speed
            dragPos += speed
            
            if (Axis.project(maybePoint: pos.wrappedValue.point) ?? Axis.project(size: bounds) >= scrollEnd) {
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
      scrollViewDragLocation = Axis.project(point: scrollDrag.location)
    }

    if (scrollTimer != nil) {
      // There is some jiggling that happens when scrolling due
      // to some drag events firing in a weird order with the scroll
      // timer. This isn't perfect but it's good enough for now.
      //
      // (Basically, make sure the user moved in the Y Axis to move
      // the offset at all.
      if (abs(scrollViewDragLocation! - Axis.project(point: scrollDrag.location)) > 0.0) {
        displayOffset = Axis.project(size: stackDrag.translation)
      }
    } else {
      displayOffset = Axis.project(size: stackDrag.translation)
    }
    
    currentIndex = data.firstIndex(where: { $0.id == datum.id })
    if (dragging == nil) {
      dragging = datum.id
      initialIndex = currentIndex
    }
    
    checkIntersection(position: Axis.project(point: stackDrag.location), dragged: datum.id)
    scrollViewDragLocation = Axis.project(point: scrollDrag.location)
    
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
  private func notAtOtherEdge(currentIndex: Int, element: (key: Data.Element.ID, value: Axis.Position), position: CGFloat) -> Bool {
    let edgeBumperSize = 64.0
    
    let otherIndex = data.firstIndex(where: { $0.id == element.key})!
    if (currentIndex > otherIndex) {
      if (position < element.value.min + edgeBumperSize && position > element.value.min) {
        return false
      }
    } else {
      if (position > element.value.max - edgeBumperSize && position < element.value.max) {
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
      currentIndex = nil
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
package struct ReorderableElement<Position: AxisPosition, Element: Identifiable, Content: View>: View {
  var datum: Element
  var isDragged: Bool
  @ViewBuilder var content: (_ data: Element, _ isDragged: Bool) -> Content
  let coordinateSpaceName: String

  package var body: some View {
    content(datum, isDragged)
      .overlay(GeometryReader { proxy in
        Color.clear
          .preference(
            key: Position.Preference.self,
            value: Position(proxy.frame(in: .named(coordinateSpaceName)))
          )
      })
      .dragHandle()
  }
}

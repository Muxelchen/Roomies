import SwiftUI
import CoreData

// MARK: - Drag & Drop Task Reordering
struct DraggableTaskList: View {
    @Binding var tasks: [HouseholdTask]
    let onReorder: ([HouseholdTask]) -> Void
    
    @State private var draggedTask: HouseholdTask?
    @State private var dropTargetIndex: Int?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    DraggableTaskRow(
                        task: task,
                        isDragging: draggedTask?.id == task.id,
                        isDropTarget: dropTargetIndex == index
                    )
                    .onDrag {
                        self.draggedTask = task
        PremiumAudioHapticSystem.playButtonTap(style: .light)
                        return NSItemProvider(object: task.id?.uuidString as NSString? ?? "")
                    }
                    .onDrop(of: [.text], delegate: TaskDropDelegate(
                        task: task,
                        tasks: $tasks,
                        draggedTask: $draggedTask,
                        dropTargetIndex: $dropTargetIndex,
                        onReorder: onReorder
                    ))
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DraggableTaskRow: View {
    let task: HouseholdTask
    let isDragging: Bool
    let isDropTarget: Bool
    
    @State private var dragScale: CGFloat = 1.0
    
    var body: some View {
        GlassmorphicCard(cornerRadius: 16) {
            HStack {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
                
                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title ?? "Unknown Task")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    
                    if let dueDate = task.dueDate {
                        Text(formatDate(dueDate))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Points badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(task.points)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.1))
                )
            }
        }
        .scaleEffect(isDragging ? 1.05 : (isDropTarget ? 0.95 : 1.0))
        .opacity(isDragging ? 0.7 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTarget)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDropTarget ? Color.blue : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.2), value: isDropTarget)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TaskDropDelegate: DropDelegate {
    let task: HouseholdTask
    @Binding var tasks: [HouseholdTask]
    @Binding var draggedTask: HouseholdTask?
    @Binding var dropTargetIndex: Int?
    let onReorder: ([HouseholdTask]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTask = draggedTask,
              let fromIndex = tasks.firstIndex(where: { $0.id == draggedTask.id }),
              let toIndex = tasks.firstIndex(where: { $0.id == task.id }) else {
            return false
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            tasks.move(fromOffsets: IndexSet(integer: fromIndex),
                     toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        
        PremiumAudioHapticSystem.shared.play(.taskEdit, context: .premium)
        onReorder(tasks)
        
        self.draggedTask = nil
        self.dropTargetIndex = nil
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let toIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            dropTargetIndex = toIndex
        }
        
        PremiumAudioHapticSystem.playButtonTap(style: .light)
    }
    
    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            dropTargetIndex = nil
        }
    }
}

// MARK: - Long Press Context Menu
struct LongPressContextMenu<Content: View>: View {
    let content: Content
    let menuItems: [ContextMenuItem]
    
    @State private var showMenu = false
    @State private var menuScale: CGFloat = 0.1
    @State private var menuOpacity: Double = 0
    @State private var pressLocation: CGPoint = .zero
    
    init(@ViewBuilder content: () -> Content, menuItems: [ContextMenuItem]) {
        self.content = content()
        self.menuItems = menuItems
    }
    
    var body: some View {
        content
            .overlay(
                Group {
                    if showMenu {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismissMenu()
                            }
                        
                        ContextMenuView(
                            items: menuItems,
                            scale: menuScale,
                            opacity: menuOpacity
                        ) { item in
                            item.action()
                            dismissMenu()
                        }
                        .position(pressLocation)
                    }
                }
            )
            .onLongPressGesture(minimumDuration: 0.5) {
                showContextMenu()
            } onPressingChanged: { pressing in
                if !pressing && !showMenu {
                    // User released before menu showed
                }
            }
    }
    
    private func showContextMenu() {
        PremiumAudioHapticSystem.playButtonTap(style: .light)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showMenu = true
            menuScale = 1.0
            menuOpacity = 1.0
        }
    }
    
    private func dismissMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            menuScale = 0.1
            menuOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showMenu = false
        }
    }
}

struct ContextMenuItem {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct ContextMenuView: View {
    let items: [ContextMenuItem]
    let scale: CGFloat
    let opacity: Double
    let onSelect: (ContextMenuItem) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(items, id: \.id) { item in
                Button(action: {
                    PremiumAudioHapticSystem.playButtonTap(style: .light)
                    onSelect(item)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.title3)
                            .foregroundColor(item.color)
                            .frame(width: 24)
                        
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(ContextMenuButtonStyle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

struct ContextMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Pinch to Zoom Stats
struct PinchableStatsView: View {
    let title: String
    let value: Int
    let total: Int?
    let color: Color
    
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main stat card
            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    
                    Spacer()
                    
                    if let total = total {
                        Text("\(value)/\(total)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress visualization
                if let total = total {
                    AnimatedProgressRing(
                        progress: Double(value) / Double(total),
                        lineWidth: 8 * currentScale,
                        primaryColor: color,
                        secondaryColor: .gray
                    )
                    .frame(
                        width: 80 * currentScale,
                        height: 80 * currentScale
                    )
                    .overlay(
                        MorphingNumberView(
                            value: value,
                            fontSize: 24 * currentScale,
                            color: .primary
                        )
                    )
                }
                
                // Detailed stats (shown when zoomed)
                if showDetails {
                    DetailedStatsGrid(
                        value: value,
                        total: total,
                        color: color
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: color.opacity(0.2),
                        radius: 10 * currentScale,
                        x: 0,
                        y: 5 * currentScale
                    )
            )
            .scaleEffect(finalScale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentScale = value
                        
                        // Show details when zoomed in
                        if currentScale > 1.3 && !showDetails {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showDetails = true
                            }
                            
                            PremiumAudioHapticSystem.playButtonTap(style: .light)
                        }
                        
                        // Hide details when zoomed out
                        if currentScale < 1.1 && showDetails {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showDetails = false
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            finalScale = min(max(1.0, value), 2.0)
                            currentScale = finalScale
                            
                            // Snap back to normal if not zoomed enough
                            if finalScale < 1.2 {
                                finalScale = 1.0
                                currentScale = 1.0
                                showDetails = false
                            }
                        }
                    }
            )
        }
    }
}

struct DetailedStatsGrid: View {
    let value: Int
    let total: Int?
    let color: Color
    
    var percentage: Int {
        guard let total = total, total > 0 else { return 0 }
        return Int((Double(value) / Double(total)) * 100)
    }
    
    var remaining: Int {
        guard let total = total else { return 0 }
        return max(0, total - value)
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatDetailCard(
                label: "Completed",
                value: "\(value)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatDetailCard(
                label: "Remaining",
                value: "\(remaining)",
                icon: "clock.fill",
                color: .orange
            )
            
            StatDetailCard(
                label: "Progress",
                value: "\(percentage)%",
                icon: "chart.pie.fill",
                color: color
            )
            
            StatDetailCard(
                label: "Average",
                value: "\(value / max(1, 7))/day",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
        }
    }
}

struct StatDetailCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Pull to Refresh with Custom Animation
struct CustomPullToRefresh<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    
    @State private var pullDistance: CGFloat = 0
    @State private var isRefreshing = false
    @State private var rotation: Double = 0
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () async -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                let offset = geometry.frame(in: .global).minY
                
                Color.clear
                    .preference(key: ScrollOffsetKey.self, value: offset)
            }
            .frame(height: 0)
            
            // Refresh indicator
            if pullDistance > 0 || isRefreshing {
                RefreshIndicator(
                    pullDistance: pullDistance,
                    isRefreshing: isRefreshing,
                    rotation: rotation
                )
                .frame(height: max(0, pullDistance))
            }
            
            content
        }
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            if !isRefreshing {
                pullDistance = max(0, value)
                
                if pullDistance > 80 && !isRefreshing {
                    triggerRefresh()
                }
                
                // Rotate based on pull distance
                withAnimation(.linear(duration: 0.1)) {
                    rotation = Double(pullDistance * 3)
                }
            }
        }
    }
    
    private func triggerRefresh() {
        isRefreshing = true
        
        PremiumAudioHapticSystem.playPullToRefresh(context: .taskRefreshStart)
        
        Task {
            await onRefresh()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isRefreshing = false
                pullDistance = 0
                rotation = 0
            }
        }
    }
}

struct RefreshIndicator: View {
    let pullDistance: CGFloat
    let isRefreshing: Bool
    let rotation: Double
    
    var scale: CGFloat {
        min(1.0, pullDistance / 80)
    }
    
    var body: some View {
        ZStack {
            if isRefreshing {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
                    .opacity(Double(scale))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
struct AdvancedGestures_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Advanced Gestures Preview")
        }
    }
}

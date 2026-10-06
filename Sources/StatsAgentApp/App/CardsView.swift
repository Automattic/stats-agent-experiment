import SwiftUI

/// Cards side by side, one at a time: a two-finger swipe on a trackpad pages between them, and the arrow buttons do
/// the same with a mouse. `viewed` is called with each card shown, the first one included.
struct CardsView: View {
    let cards: [Card]
    var viewed: @MainActor (Card.ID) -> Void = { _ in }
    @State private var position: Int?

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(cards) { card in
                        CardView(card: card)
                            .padding(.horizontal, 4)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .scrollIndicators(.never)
            HStack(spacing: 16) {
                Button("Previous card", systemImage: "chevron.left") { move(by: -1) }
                    .disabled(index == 0)
                Text("\(index + 1) of \(cards.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("Next card", systemImage: "chevron.right") { move(by: 1) }
                    .disabled(index == cards.count - 1)
            }
            .labelStyle(.iconOnly)
        }
        .onAppear {
            position = cards.first?.id
            position.map(viewed)
        }
        .onChange(of: position) { _, position in
            position.map(viewed)
        }
    }

    private var index: Int {
        cards.firstIndex { $0.id == position } ?? 0
    }

    private func move(by offset: Int) {
        let target = index + offset
        guard cards.indices.contains(target) else {
            return
        }
        withAnimation {
            position = cards[target].id
        }
    }
}

/// One card: what it shows, its path and dates, and its chart.
struct CardView: View {
    let card: Card
    @Environment(\.context) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                Text(pathDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            content
            Spacer(minLength: 0)
        }
        .padding(Constants.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardStyle()
    }

    private var pathDescription: String {
        ([card.path.joined(separator: " › ")] + [card.parameters].compactMap(\.self)).joined(separator: " · ")
    }

    @ViewBuilder private var content: some View {
        switch card.content {
        case let .figure(metric, value, dateInterval, chart):
            HeroFigureView(
                figure: Card.Figure(
                    title: metric.localizedTitle,
                    value: value,
                    detail: context.formatters.dateRange.string(from: dateInterval)
                )
            )
            if let chart {
                trendChart(chart)
            }
        case let .comparison(data):
            header(for: data, showComparison: true)
            LineChartView(data: data)
                .frame(height: 220)
        case let .trend(data):
            header(for: data, showComparison: false)
            trendChart(data)
        case let .figures(figures, chart):
            if figures.count == 1 {
                HeroFigureView(figure: figures[0])
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .topLeading)], spacing: 16) {
                    ForEach(figures.indices, id: \.self) { index in
                        FigureView(figure: figures[index])
                    }
                }
            }
            if let chart {
                trendChart(chart)
            }
        case let .headlines(headlines, chart):
            ForEach(headlines.indices, id: \.self) { index in
                ChartCardHeaderView(viewModel: headlines[index])
            }
            if let chart {
                trendChart(chart)
            }
        case let .series(data, note):
            Text(note)
                .font(.callout)
                .foregroundStyle(.secondary)
            LineChartView(data: data)
                .environment(\.showComparison, !data.previousData.isEmpty)
                .frame(height: 220)
        case let .ranking(list, previous):
            RankedListView(list: list, previous: previous)
        case .notDrawn:
            Text("The app doesn't draw this stats call yet.")
                .foregroundStyle(.secondary)
        case let .failed(message):
            Text(message)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func trendChart(_ data: ChartData) -> some View {
        LineChartView(data: data)
            .environment(\.showComparison, false)
            .frame(height: 220)
    }

    private func header(for data: ChartData, showComparison: Bool) -> some View {
        ChartCardHeaderView(
            viewModel: .init(
                trend: TrendViewModel(
                    currentValue: data.currentTotal,
                    previousValue: data.previousTotal,
                    metric: data.metric
                ),
                metricTitle: data.metric.localizedTitle,
                period: context.formatters.dateRange.string(from: data.dateInterval),
                showComparison: showComparison
            )
        )
    }
}

extension EnvironmentValues {
    /// Whether the view is rendered off screen into a picture, where a scroll view's contents aren't drawn.
    @Entry var isRenderingPicture = false
}

/// Items highest first, each with a bar for its share of the top item's figure, and its change from the span before
/// when there is one.
struct RankedListView: View {
    let list: RankedList
    let previous: [String: Int]?
    @Environment(\.isRenderingPicture) private var isRenderingPicture

    var body: some View {
        if let total = list.total {
            FigureView(figure: Card.Figure(title: "Total \(list.metricTitle.lowercased())", value: total))
        }
        if list.rows.isEmpty {
            Text("Nothing to list for this span.")
                .foregroundStyle(.secondary)
        } else if isRenderingPicture {
            rows
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            ScrollView {
                rows
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 4) {
            ForEach(list.rows.indices, id: \.self) { index in
                row(list.rows[index], top: max(list.rows[0].value, 1))
            }
        }
    }

    private func row(_ row: RankedList.Row, top: Int) -> some View {
        HStack {
            Text(row.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let previous {
                change(from: previous[row.name], to: row.value)
            }
            Text(list.isPercentage ? "\(row.value)%" : StatsValueFormatter.formatNumber(row.value))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(alignment: .leading) {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Constants.Colors.blue.opacity(0.15))
                    .frame(width: geometry.size.width * CGFloat(row.value) / CGFloat(top))
            }
        }
    }

    /// A dash when the item wasn't in the earlier span's list, which can mean it was below that list's cutoff.
    private func change(from previous: Int?, to current: Int) -> some View {
        guard let previous else {
            return Text("–").foregroundStyle(.secondary)
        }
        let difference = current - previous
        let text =
            difference == 0 ? "±0" : (difference > 0 ? "+" : "−") + StatsValueFormatter.formatNumber(abs(difference))
        let color =
            difference == 0
            ? Color.secondary
            : difference > 0 ? Constants.Colors.positiveChangeForeground : Constants.Colors.negativeChangeForeground
        return Text(text).foregroundStyle(color)
    }
}

/// A card's only figure, large, with what it covers under it.
struct HeroFigureView: View {
    let figure: Card.Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(figure.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(StatsValueFormatter.formatNumber(figure.value, onlyLarge: true))
                .font(Constants.Typography.largeDisplayFont)
                .kerning(Constants.Typography.largeDisplayKerning)
            if let detail = figure.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// One labelled figure, in the type of the copied `StandaloneMetricView`.
struct FigureView: View {
    let figure: Card.Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(figure.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(StatsValueFormatter.formatNumber(figure.value, onlyLarge: true))
                .font(Constants.Typography.smallDisplayFont)
            if let detail = figure.detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

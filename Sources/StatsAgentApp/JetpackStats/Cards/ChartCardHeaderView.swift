import SwiftUI

// MARK: - ChartCardHeaderView

struct ChartCardHeaderView: View {
    struct ViewModel: Equatable {
        let trend: TrendViewModel
        let metricTitle: String
        let period: String
        var showComparison: Bool = true
        var showDisclosureIndicator: Bool = false
    }

    let viewModel: ViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: -1) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(viewModel.trend.formattedCurrentValue)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .kerning(-0.5)
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text(viewModel.metricTitle)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 2) {
                    Text(viewModel.period)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    if viewModel.showDisclosureIndicator {
                        Image(systemName: "chevron.forward")
                            .font(.system(.caption2, weight: .semibold))
                            .scaleEffect(0.8)
                            .foregroundStyle(Color.secondary)
                    }
                }
                if viewModel.showComparison {
                    Text(
                        verbatim:
                            "\(viewModel.trend.formattedChange)  \(viewModel.trend.iconSign) \(viewModel.trend.formattedPercentage)"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundColor(viewModel.trend.sentiment.foregroundColor)
                    .contentTransition(.numericText())
                    .padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.spring, value: viewModel)
    }
}

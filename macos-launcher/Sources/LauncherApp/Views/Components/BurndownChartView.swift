import Charts
import SwiftUI

/// A burndown chart showing completed vs remaining tasks over time.
struct BurndownChartView: View {
    let data: ProjectBurndownResponse

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: DesignTokens.IconSize.standard))
                    .foregroundColor(ThemeManager.current.blue)

                Text("Burndown: \(data.project)")
                    .font(.system(size: DesignTokens.TypeScale.bodyLg, weight: .semibold))
                    .foregroundColor(ThemeManager.current.text)

                Spacer()
            }

            // Chart
            if data.dataPoints.isEmpty {
                emptyChartView
            } else {
                chartView
            }

            // Summary stats
            summaryView
        }
        .padding(DesignTokens.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(ThemeManager.current.surface1)
        )
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            // Remaining tasks line (burndown)
            ForEach(data.dataPoints) { point in
                if let date = point.dateValue {
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Remaining", point.remaining)
                    )
                    .foregroundStyle(ThemeManager.current.peach)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Date", date),
                        y: .value("Remaining", point.remaining)
                    )
                    .foregroundStyle(ThemeManager.current.peach)
                    .symbolSize(30)
                }
            }

            // Completed tasks area (cumulative)
            ForEach(data.dataPoints) { point in
                if let date = point.dateValue {
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Completed", point.completedCumulative)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                ThemeManager.current.green.opacity(0.3),
                                ThemeManager.current.green.opacity(0.1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                    .foregroundStyle(ThemeManager.current.overlay0.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(ThemeManager.current.subtext0)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(ThemeManager.current.overlay0.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(ThemeManager.current.subtext0)
            }
        }
        .chartLegend(position: .top, alignment: .trailing) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                LegendItem(color: ThemeManager.current.peach, label: "Remaining")
                LegendItem(color: ThemeManager.current.green, label: "Completed")
            }
        }
        .frame(height: 200)
    }

    private var emptyChartView: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundColor(ThemeManager.current.subtext0)
            Text("No completion data available")
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(ThemeManager.current.subtext0)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary View

    private var summaryView: some View {
        HStack(spacing: DesignTokens.Spacing.large) {
            SummaryStat(
                icon: "checkmark.circle.fill",
                color: ThemeManager.current.green,
                value: data.totalCompleted,
                label: "completed"
            )

            SummaryStat(
                icon: "circle",
                color: ThemeManager.current.subtext0,
                value: data.totalTasks - data.totalCompleted,
                label: "remaining"
            )

            Spacer()

            // Progress percentage
            if data.totalTasks > 0 {
                let percentage = Int((Double(data.totalCompleted) / Double(data.totalTasks)) * 100)
                Text("\(percentage)%")
                    .font(.system(size: DesignTokens.TypeScale.title, weight: .bold))
                    .foregroundColor(ThemeManager.current.blue)
            }
        }
    }
}

// MARK: - Supporting Views

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: DesignTokens.TypeScale.caption))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }
}

private struct SummaryStat: View {
    let icon: String
    let color: Color
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.IconSize.small))
                .foregroundColor(color)
            Text("\(value) \(label)")
                .font(.system(size: DesignTokens.TypeScale.body))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }
}

// MARK: - Preview

#Preview {
    BurndownChartView(data: MockApiClient.sampleBurndown)
        .padding()
        .background(ThemeManager.current.surface0)
        .frame(width: 500)
}

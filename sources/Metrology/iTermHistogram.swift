//
//  iTermHistogram.swift
//  iTerm2
//
//  Created by George Nachman on 8/26/25.
//

extension iTermHistogram {
    @objc
    static var tabularFormatterTime: TabularFormatter {
        let formatter = TabularFormatter()
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.min_time.9daac556", defaultValue: "Min Time", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.distribution.72a23e54", defaultValue: "Distribution", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: true)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.max_time.e1b91340", defaultValue: "Max Time", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.samples.9336a289", defaultValue: "# Samples", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.mean_time.16e1fc38", defaultValue: "Mean Time", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.p50.fa4cedf3", defaultValue: "P50", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.p95.aebf8ec1", defaultValue: "P95", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: String(localized: "ui.swift.metrology.itermhistogram.total_time.893bd4a5", defaultValue: "Total Time", bundle: .main, comment: "User-facing text in iTermHistogram."), leftAligned: false)
        formatter.defineColumn(label: "", leftAligned: true)
        return formatter
    }

    @objc
    func add(to formatter: TabularFormatter, precision: Int, units: String, label: String) {
        if (count == 0) {
            return
        }

        let format = "%0.\(precision)f"

        formatter.add(row: [
            String(format: format, percentile(0.0)) + " " + units,
            graphString(),
            String(format: format, percentile(1.0)) + " " + units,
            "\(count)",
            String(format: format, sum / Double(count)) + " " + units,
            String(format: format, percentile(0.5)) + " " + units,
            String(format: format, percentile(0.95)) + " " + units,
            String(format: format, sum) + " " + units,
            label
        ])
    }
}

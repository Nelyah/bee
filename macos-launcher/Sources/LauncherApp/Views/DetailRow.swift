import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(CatppuccinTheme.subtext0)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(CatppuccinTheme.text)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DetailRow(label: "Project", value: "bee")
        DetailRow(label: "Tags", value: "code, review")
        DetailRow(label: "Status", value: "active")
    }
    .padding()
    .background(CatppuccinTheme.base)
}

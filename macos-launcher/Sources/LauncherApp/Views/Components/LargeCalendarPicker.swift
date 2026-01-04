import AppKit
import SwiftUI

/// A larger calendar picker using AppKit's NSDatePicker.
///
/// SwiftUI's `.graphical` DatePicker has a fixed small size (~250x280 points) that cannot
/// be enlarged without bitmap scaling artifacts.
///
/// This wrapper uses AppKit's `NSDatePicker` and SwiftUI scaling for a larger appearance.
struct LargeCalendarPicker: View {
    @Binding var selection: Date

    private let scale: CGFloat = 1.8
    // NSDatePicker with .yearMonthDay only - tight bounds around content
    private let nativeWidth: CGFloat = 232
    private let nativeHeight: CGFloat = 180

    var body: some View {
        NativeDatePicker(selection: $selection)
            .fixedSize()
            .scaleEffect(scale, anchor: .center)
            .frame(width: nativeWidth * scale, height: nativeHeight * scale)
    }
}

/// The actual NSViewRepresentable wrapper for NSDatePicker.
private struct NativeDatePicker: NSViewRepresentable {
    @Binding var selection: Date

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerElements = [.yearMonthDay]
        picker.dateValue = selection
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        picker.dateValue = selection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            selection.wrappedValue = sender.dateValue
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct LargeCalendarPicker_Previews: PreviewProvider {
        static var previews: some View {
            LargeCalendarPicker(selection: .constant(Date()))
                .padding()
        }
    }
#endif

import SwiftUI

struct DisclaimerView: View {
    var body: some View {
        Label {
            Text("For glanceable personal display only. This app is not a medical device, does not provide alarms, and must not be used as the sole basis for treatment decisions. Verify readings in the official Libre app when accuracy matters.")
        } icon: {
            Image(systemName: "cross.case")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

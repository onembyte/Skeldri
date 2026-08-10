import SwiftUI

struct ConnectionStatusView: View {
    let title: String; let ready: Bool; let detail: String
    var body: some View { HStack { Circle().fill(ready ? .green : .orange).frame(width: 9, height: 9); Text(title); Spacer(); Text(detail).foregroundStyle(.secondary) } }
}


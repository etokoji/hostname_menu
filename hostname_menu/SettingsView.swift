import SwiftUI

struct SettingsView: View {
    @State private var config: Configuration.Config
    let configuration: Configuration
    let dismiss: () -> Void
    private weak var hostingWindow: NSWindow?
    
    init(config: Configuration.Config, configuration: Configuration, dismiss: @escaping () -> Void, hostingWindow: NSWindow?) {
        _config = State(initialValue: config)
        self.configuration = configuration
        self.dismiss = dismiss
        self.hostingWindow = hostingWindow
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 表示設定セクション
            VStack(alignment: .leading, spacing: 6) {
                Text("Display Settings")
                    .bold()
                Toggle("Show labels in menu bar", isOn: $config.labels.showLabelsInMenuBar)
                Toggle("Show interface names in menu bar", isOn: $config.labels.showInterfaceNamesInMenuBar)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle()
            
            // ラベル設定セクション
            VStack(alignment: .leading, spacing: 6) {
                Text("Label Settings")
                    .bold()
                HStack {
                    Text("Computer Name:")
                        .frame(width: 120, alignment: .trailing)
                    TextField("", text: $config.labels.computerName)
                        .textFieldStyle(.plain)
                        .frame(width: 120)
                }
                HStack {
                    Text("Local Hostname:")
                        .frame(width: 120, alignment: .trailing)
                    TextField("", text: $config.labels.localHostname)
                        .textFieldStyle(.plain)
                        .frame(width: 120)
                }
                HStack {
                    Text("IP Address:")
                        .frame(width: 120, alignment: .trailing)
                    TextField("", text: $config.labels.ipAddress)
                        .textFieldStyle(.plain)
                        .frame(width: 120)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle()
            
            // 表示幅設定セクション
            VStack(alignment: .leading, spacing: 6) {
                Text("Width Settings")
                    .bold()
                HStack {
                    Text("Max width:")
                        .frame(width: 100, alignment: .trailing)
                    TextField("", value: $config.maxWidth, formatter: NumberFormatter())
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                    Text("pixels")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle()
            
            // ボタン
            HStack {
                Spacer()
                Button("Save") {
                    configuration.updateConfig(config)
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.top, 8)
        }
        .padding(12)
        .frame(width: 350)
    }
    
    private func closeWindow() {
        hostingWindow?.close()
    }
}

// カスタムグループボックススタイル
extension View {
    func groupBoxStyle() -> some View {
        self
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(config: Configuration.shared.config, configuration: Configuration.shared, dismiss: {}, hostingWindow: nil)
    }
}

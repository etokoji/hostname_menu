import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: Configuration.Config
    private let configuration = Configuration.shared
    
    init() {
        _config = State(initialValue: Configuration.shared.config)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 表示設定セクション
            VStack(alignment: .leading, spacing: 6) {
                Text("表示設定")
                    .bold()
                Toggle("メニューバーにラベルを表示", isOn: $config.labels.showLabelsInMenuBar)
                Toggle("メニューバーでインターフェース名を表示", isOn: $config.labels.showInterfaceNamesInMenuBar)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle()
            
            // ラベル設定セクション
            VStack(alignment: .leading, spacing: 6) {
                Text("ラベル設定")
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
                Text("表示幅設定")
                    .bold()
                HStack {
                    Text("最大幅:")
                        .frame(width: 100, alignment: .trailing)
                    TextField("", value: $config.maxWidth, formatter: NumberFormatter())
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                    Text("ピクセル")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle()
            
            // ボタン
            HStack {
                Spacer()
                Button("保存") {
                    configuration.updateConfig(config)
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
                
                Button("キャンセル") {
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
        if let window = NSApplication.shared.windows.first(where: { $0.title == "設定" }) {
            window.close()
        }
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
        SettingsView()
    }
}

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: Configuration.Config
    private let configuration = Configuration.shared
    
    init() {
        _config = State(initialValue: Configuration.shared.config)
    }
    
    var body: some View {
        VStack {
            Form {
                Section<Text, TupleView<(Toggle<Text>, Toggle<Text>)>, EmptyView> {
                    Toggle("メニューバーにラベルを表示", isOn: $config.labels.showLabelsInMenuBar)
                    Toggle("メニューバーでインターフェース名を表示", isOn: $config.labels.showInterfaceNamesInMenuBar)
                } header: {
                    Text("表示設定")
                }
                
                Section<Text, TupleView<(TextField<Text>, TextField<Text>, TextField<Text>)>, EmptyView> {
                    TextField("Computer Name ラベル", text: $config.labels.computerName)
                    TextField("Local Hostname ラベル", text: $config.labels.localHostname)
                    TextField("IP Address ラベル", text: $config.labels.ipAddress)
                } header: {
                    Text("ラベル設定")
                }
                
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
                .padding(.top)
            }
            .padding()
            .frame(width: 450)
        }
    }
    
    private func closeWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "設定" }) {
            window.close()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

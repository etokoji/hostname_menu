import Foundation

class Configuration {
    static let shared = Configuration()
    
    struct Labels: Codable {
        var computerName: String
        var localHostname: String
        var ipAddress: String
        var showLabelsInMenuBar: Bool
        var showInterfaceNamesInMenuBar: Bool
    }
    
    // 表示項目の種類
    enum DisplayItemType: Codable {
        case computerName(String)
        case localHostname(String)
        case ipAddress(interface: String?, address: String)
        
        // 設定に応じてフォーマットされたテキストを生成
        func format(config: Config) -> String {
            switch self {
            case .computerName(let value):
                return config.labels.showLabelsInMenuBar ? config.labels.computerName + value : value
                
            case .localHostname(let value):
                return config.labels.showLabelsInMenuBar ? config.labels.localHostname + value : value
                
            case .ipAddress(let interface, let address):
                let displayText: String
                if let interface = interface, config.labels.showInterfaceNamesInMenuBar {
                    displayText = "\(interface): \(address)"
                } else {
                    displayText = address
                }
                return config.labels.showLabelsInMenuBar ? config.labels.ipAddress + displayText : displayText
            }
        }
        
        // 表示テキストから表示項目を判定
        static func from(_ text: String) -> DisplayItemType {
            print("🔍 Analyzing text: '\(text)'")
            
            // IPアドレスとインターフェース名の分離
            if text.contains(":") {
                let components = text.split(separator: ":", maxSplits: 1).map(String.init)
                if components.count == 2 {
                    let interface = components[0].trimmingCharacters(in: .whitespaces)
                    let address = components[1].trimmingCharacters(in: .whitespaces)
                    print("  - Found IP Address with interface")
                    print("    * Interface: '\(interface)'")
                    print("    * Address: '\(address)'")
                    return .ipAddress(interface: interface, address: address)
                }
            }
            
            // デフォルトはインターフェースなしのIPアドレスとして扱う
            print("  - Found IP Address without interface")
            print("    * Address: '\(text)'")
            return .ipAddress(interface: nil, address: text)
        }
        
        // メニュー項目の種類を判定
        static func fromMenuItem(itemType: String, value: String) -> DisplayItemType {
            print("🔍 Creating from menu item")
            print("  - Type: '\(itemType)'")
            print("  - Value: '\(value)'")
            
            switch itemType {
            case "computerName":
                return .computerName(value)
            case "localHostname":
                return .localHostname(value)
            case "ipAddress":
                if value.contains(":") {
                    let components = value.split(separator: ":", maxSplits: 1).map(String.init)
                    if components.count == 2 {
                        let interface = components[0].trimmingCharacters(in: .whitespaces)
                        let address = components[1].trimmingCharacters(in: .whitespaces)
                        return .ipAddress(interface: interface, address: address)
                    }
                }
                return .ipAddress(interface: nil, address: value)
            default:
                return .ipAddress(interface: nil, address: value)
            }
        }
        
        // 生のテキストを取得
        var rawText: String {
            switch self {
            case .computerName(let value): return value
            case .localHostname(let value): return value
            case .ipAddress(let interface, let address):
                if let interface = interface {
                    return "\(interface): \(address)"
                } else {
                    return address
                }
            }
        }
    }
    
    struct LastDisplay: Codable {
        var displayItem: DisplayItemType
        
        init(displayItem: DisplayItemType = .ipAddress(interface: nil, address: "")) {
            self.displayItem = displayItem
        }
    }
    
    struct Config: Codable {
        var labels: Labels
        var lastDisplay: LastDisplay
        var maxWidth: CGFloat
        
        static var `default`: Config {
            Config(
                labels: Labels(
                    computerName: "Computer Name: ",
                    localHostname: "Local Hostname: ",
                    ipAddress: "IP Address: ",
                    showLabelsInMenuBar: false,
                    showInterfaceNamesInMenuBar: true
                ),
                lastDisplay: LastDisplay(
                    displayItem: .ipAddress(interface: nil, address: "")
                ),
                maxWidth: 230
            )
        }
    }
    
    private(set) var config: Config
    private let configFileName = "config.json"
    
    private var configFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.hostname-menu"
        let appDirectory = appSupport.appendingPathComponent(bundleID)
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory.appendingPathComponent(configFileName)
    }
    
    private init() {
        // デフォルト設定
        self.config = Config.default
        
        loadConfig()
        
        // 初回起動時は LocalHostname をデフォルトとして設定
        if config.lastDisplay.displayItem.rawText.isEmpty {
            if let hostname = shell("scutil --get LocalHostName") {
                config.lastDisplay.displayItem = .localHostname(hostname)
                saveConfig()
            }
        }
    }
    
    private func loadConfig() {
        guard let configUrl = configFileURL else { return }
        
        if !FileManager.default.fileExists(atPath: configUrl.path) {
            // 設定ファイルが存在しない場合は、デフォルト設定を保存
            saveConfig()
            return
        }
        
        do {
            let data = try Data(contentsOf: configUrl)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(Config.self, from: data)
        } catch {
            print("Error loading config: \(error)")
            // エラーが発生した場合は、デフォルト設定を保存
            saveConfig()
        }
    }
    
    func saveConfig() {
        guard let configUrl = configFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configUrl)
        } catch {
            print("Error saving config: \(error)")
        }
    }
    
    // 設定を更新するためのパブリックメソッド
    func updateConfig(_ newConfig: Config) {
        self.config = newConfig
        saveConfig()
        
        // 設定変更を通知
        NotificationCenter.default.post(name: NSNotification.Name("ConfigurationDidChange"), object: nil)
    }
    
    // 最後に表示していた項目を取得
    func getLastDisplayItem() -> DisplayItemType {
        return config.lastDisplay.displayItem
    }
    
    // 最後に表示した項目を更新
    func updateLastDisplay(_ item: DisplayItemType) {
        config.lastDisplay.displayItem = item
        saveConfig()
    }
    
    // メニュー項目用のフォーマット（常にラベル付き）
    func formatMenuComputerName(_ name: String) -> String {
        return config.labels.computerName + name
    }
    
    func formatMenuLocalHostname(_ hostname: String) -> String {
        return config.labels.localHostname + hostname
    }
    
    func formatMenuIPAddress(_ interface: String, _ address: String) -> String {
        return "\(interface): \(address)"
    }
}

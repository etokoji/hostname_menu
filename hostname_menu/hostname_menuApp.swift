import SwiftUI
import SystemConfiguration

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private weak var settingsWindow: NSWindow?
    
    private let config = Configuration.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if statusItem.button != nil {
            let lastDisplayItem = config.getLastDisplayItem()
            let displayText = lastDisplayItem.format(config: config.config)
            updateMenuBarDisplay(with: displayText)
        }
        
        // メニューの設定
        menu = NSMenu()
        statusItem.menu = menu
        
        // メニュー項目の更新
        updateMenuItems()
        
        // 設定変更通知の監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: NSNotification.Name("ConfigurationDidChange"),
            object: nil
        )
    }
    
    private func updateMenuBarDisplay(with text: String) {
        guard let button = statusItem.button else { return }
        
        // アイコンの設定
        // 利用可能なSF Symbols:
        // - network.badge.shield.half.filled : ネットワークセキュリティを表すアイコン
        // - server.rack : サーバーを表すアイコン
        // - globe : インターネットを表すアイコン
        // - house : ホストを表すアイコン
        // 必要なら、別のアイコンを使用する（MenuBarIcon.xcassets を参照）  
        if let image = NSImage(systemSymbolName: "house", accessibilityDescription: nil) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true  // システムカラーに合わせる
            button.image = image
        }
        
        // 利用可能なスペースを計算
        let maxWidth: CGFloat = config.config.maxWidth
        
        // テキストの幅を計算
        let font = NSFont.menuBarFont(ofSize: 0)  // 0を指定すると、システムのデフォルトサイズになる
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = (text as NSString).size(withAttributes: attributes).width
        
        // アイコンとスペースの幅
        let iconWidth: CGFloat = 18
        let spacing: CGFloat = 10
        let totalWidth = iconWidth + spacing + textWidth
        
        if totalWidth <= maxWidth {
            // 通常表示（十分なスペースがある場合）
            button.title = text
            statusItem.length = totalWidth
        } else {
            // テキストを省略して表示
            let availableTextWidth = maxWidth - (iconWidth + spacing)
            let ratio = availableTextWidth / textWidth
            let maxChars = Int(Float(text.count) * Float(ratio))
            
            if maxChars >= 10 {
                // 中央省略表示
                let half = maxChars / 2
                let start = String(text.prefix(half - 1))
                let end = String(text.suffix(half - 1))
                let truncatedText = start + "..." + end
                button.title = truncatedText
                
                // 省略後のテキスト幅を計算して設定
                let truncatedWidth = (truncatedText as NSString).size(withAttributes: attributes).width
                statusItem.length = iconWidth + spacing + truncatedWidth
            } else {
                // アイコンのみ表示
                button.title = ""
                statusItem.length = iconWidth + spacing
            }
        }
        
    }
    
    @objc func configurationDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let currentItem = self.config.getLastDisplayItem()
            let formattedText = currentItem.format(config: self.config.config)
            
            print("\n🔄 Configuration Changed")
            print("  - Current Item: \(currentItem)")
            print("  - Formatted Text: '\(formattedText)'")
            print("  - Labels Enabled: \(self.config.config.labels.showLabelsInMenuBar)")
            print("  - Interface Names Enabled: \(self.config.config.labels.showInterfaceNamesInMenuBar)")
            
            self.updateMenuBarDisplay(with: formattedText)
            self.updateMenuItems()
        }
    }
    
    private func updateMenuItems() {
        menu.removeAllItems()
        
        // コンピュータ名
        if let computerName = shell("scutil --get ComputerName") {
            let item = NSMenuItem(title: config.formatMenuComputerName(computerName), action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ("computerName", computerName)
            menu.addItem(item)
        }
        
        // ローカルホスト名
        if let localHostname = shell("scutil --get LocalHostName") {
            let item = NSMenuItem(title: config.formatMenuLocalHostname(localHostname), action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ("localHostname", localHostname)
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // IPアドレス
        let ipAddresses = getIPAddresses()
        for ip in ipAddresses where !ip.isTemporary {
            menu.addItem(makeIPAddressMenuItem(ip))
        }
        
        // 一時IPv6アドレスはサブメニューにまとめる
        let temporaryAddresses = ipAddresses.filter { $0.isTemporary }
        if !temporaryAddresses.isEmpty {
            let submenu = NSMenu()
            for ip in temporaryAddresses {
                submenu.addItem(makeIPAddressMenuItem(ip))
            }
            let temporaryItem = NSMenuItem(title: String(localized: "menuitem.temporaryAddresses"), action: nil, keyEquivalent: "")
            temporaryItem.submenu = submenu
            menu.addItem(temporaryItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // このアプリについて
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ProcessInfo.processInfo.processName
        let aboutItem = NSMenuItem(title: String(format: String(localized: "menuitem.about"), appName), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // 設定メニュー
        let settingsItem = NSMenuItem(title: String(localized: "menuitem.settings"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 終了メニュー
        let quitItem = NSMenuItem(title: String(localized: "menuitem.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
    
    private func makeIPAddressMenuItem(_ ip: NetworkInterface) -> NSMenuItem {
        let menuText = config.formatMenuIPAddress(ip.interface, ip.kind, ip.address)
        let item = NSMenuItem(title: menuText, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = ("ipAddress", "\(ip.interface):\(ip.address)")
        return item
    }
    
    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        if let itemData = sender.representedObject as? (String, String) {
            if statusItem.button != nil {
                print("\n📝 Menu Item Selected")
                print("  - Selected Item: '\(sender.title)'")
                print("  - Item Type: '\(itemData.0)'")
                print("  - Item Value: '\(itemData.1)'")
                
                let displayItem = Configuration.DisplayItemType.fromMenuItem(itemType: itemData.0, value: itemData.1)
                let formattedText = displayItem.format(config: config.config)
                
                print("  - Display Item: \(displayItem)")
                print("  - Formatted Text: '\(formattedText)'")
                print("  - Labels Enabled: \(config.config.labels.showLabelsInMenuBar)")
                print("  - Interface Names Enabled: \(config.config.labels.showInterfaceNamesInMenuBar)")
                
                updateMenuBarDisplay(with: formattedText)
                config.updateLastDisplay(displayItem)
                config.saveConfig()
            }
        }
    }
    
    @objc private func showAbout() {
        // メニューバー常駐アプリでも前面に出るようにアクティブ化する
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func showSettings() {
        if let window = settingsWindow, !window.isReleasedWhenClosed {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "settings.window.title")
        
        let settingsView = SettingsView(
            config: config.config,
            configuration: config,
            dismiss: { window.close() },
            hostingWindow: window
        )
        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        
        // ウィンドウが閉じられたときの処理を設定
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        settingsWindow = window
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // 通知の登録解除
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willCloseNotification,
                object: window
            )
            settingsWindow = nil
        }
    }
    
    private func shell(_ command: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.standardInput = nil
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getIPAddresses() -> [NetworkInterface] {
        var addresses: [NetworkInterface] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        
        let interfaceKinds = getInterfaceKinds()
        let temporaryAddresses = getTemporaryIPv6Addresses()
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                let isIPv4 = addr.sa_family == UInt8(AF_INET)
                let isIPv6 = addr.sa_family == UInt8(AF_INET6)
                
                if isIPv4 || isIPv6 {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname,
                                 socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let address = String(cString: hostname)
                        if !address.hasPrefix("fe80") && !address.hasPrefix("::1") && address != "127.0.0.1" {
                            let interface = String(cString: ptr.pointee.ifa_name)
                            addresses.append(NetworkInterface(interface: interface, address: address, isIPv4: isIPv4, kind: interfaceKinds[interface] ?? .other, isTemporary: temporaryAddresses.contains(address)))
                        }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return addresses.sorted { a, b in
            if a.isIPv4 && !b.isIPv4 { return true }
            if !a.isIPv4 && b.isIPv4 { return false }
            return a.interface < b.interface
        }
    }
    
    // 一時IPv6アドレスの一覧を取得（getifaddrs では判別できないため ifconfig の出力から取得）
    // 取得できない場合は空になり、すべてのアドレスがメインメニューに表示される
    private func getTemporaryIPv6Addresses() -> Set<String> {
        guard let output = shell("/sbin/ifconfig") else { return [] }
        
        var addresses: Set<String> = []
        for line in output.split(separator: "\n") {
            // 例: inet6 2400:db8::1 prefixlen 64 autoconf temporary
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            if fields.count >= 2, fields[0] == "inet6", fields.contains("temporary") {
                addresses.insert(String(fields[1]))
            }
        }
        return addresses
    }
    
    // BSD名（en0 など）ごとの接続種別を取得
    private func getInterfaceKinds() -> [String: InterfaceKind] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        
        var kinds: [String: InterfaceKind] = [:]
        for interface in interfaces {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let type = SCNetworkInterfaceGetInterfaceType(interface) else { continue }
            
            if type == kSCNetworkInterfaceTypeIEEE80211 {
                kinds[name] = .wifi
            } else if type == kSCNetworkInterfaceTypeEthernet || (type as String) == "Bridge" {
                // Thunderbolt Bridge の種別 "Bridge" は公開定数がないため文字列で比較
                kinds[name] = .wired
            } else {
                kinds[name] = .other
            }
        }
        return kinds
    }
}

// インターフェースの接続種別
enum InterfaceKind {
    case wifi
    case wired
    case other  // VPN（utun）など
    
    // メニューに表示する種別名（その他は表示しない）
    // NSMenuItem.image は macOS 27 で描画されないため、文字で表示する
    var menuLabel: String? {
        switch self {
        case .wifi: return String(localized: "interface.wifi")
        case .wired: return String(localized: "interface.wired")
        case .other: return nil
        }
    }
}

// ネットワークインターフェース情報を保持する構造体
struct NetworkInterface {
    let interface: String
    let address: String
    let isIPv4: Bool
    let kind: InterfaceKind
    let isTemporary: Bool
}

@main
struct hostname_menuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// 設定変更を監視するためのクラス
class ConfigurationObserver: ObservableObject {
    @Published private(set) var lastUpdate = Date()
    
    init() {
        // 設定変更通知の監視を開始
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: NSNotification.Name("ConfigurationDidChange"),
            object: nil
        )
    }
    
    @objc private func configurationDidChange() {
        // 設定が変更されたら lastUpdate を更新
        lastUpdate = Date()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

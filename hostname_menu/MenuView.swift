//
//  MenuView.swift
//  hostname_menu
//
//  Created by 江藤公二 on 2024/11/30.
//

import SwiftUI
import Network

struct NetworkInterface: Identifiable {
    let id: String
    let interface: String
    let address: String
    let isIPv4: Bool
    
    init(interface: String, address: String, isIPv4: Bool) {
        self.interface = interface
        self.address = address
        self.isIPv4 = isIPv4
        self.id = "\(interface)_\(address)"
    }
}

struct MenuView: View {
    @State private var computerName: String = ""
    @State private var localHostname: String = ""
    @State private var ipAddresses: [NetworkInterface] = []
    var showSettings: () -> Void
    var onSelect: (String, String) -> Void
    
    private let config = Configuration.shared
    
    var sortedAddresses: [NetworkInterface] {
        ipAddresses.sorted { a, b in
            if a.isIPv4 && !b.isIPv4 { return true }
            if !a.isIPv4 && b.isIPv4 { return false }
            return a.interface < b.interface
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(config.formatMenuComputerName(computerName)) {
                onSelect("computerName", computerName)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            Button(config.formatMenuLocalHostname(localHostname)) {
                onSelect("localHostname", localHostname)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            Divider()
            
            ForEach(sortedAddresses) { ip in
                Button(config.formatMenuIPAddress(ip.interface, ip.address)) {
                    onSelect("ipAddress", "\(ip.interface): \(ip.address)")
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            
            Divider()
            
            Button("設定...") {
                NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
                showSettings()
            }
            .padding(.horizontal)
            
            Divider()
            
            Button("hostname_menuを終了...") {
                quitApp()
            }
            .keyboardShortcut("Q")
        }
        .onAppear {
            updateHostInfo()
        }
    }
    
    private func updateHostInfo() {
        // Get computer name
        if let name = shell("scutil --get ComputerName") {
            computerName = name
        }
        
        // Get local hostname
        if let hostname = shell("scutil --get LocalHostName") {
            localHostname = hostname
        }
        
        // Get IP addresses
        ipAddresses = getIPAddresses()
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func getIPAddresses() -> [NetworkInterface] {
        var addresses: [NetworkInterface] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        
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
                            addresses.append(NetworkInterface(interface: interface, address: address, isIPv4: isIPv4))
                        }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return addresses
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(showSettings: {}) { _, _ in }
    }
}

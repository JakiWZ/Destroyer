import Foundation

/// Rete Wi-Fi salvata (preferita) sul Mac.
public struct WiFiNetwork: Identifiable, Hashable, Sendable {
    public var id: String { ssid }
    public let ssid: String
    public init(ssid: String) { self.ssid = ssid }
}

/// Elenca e rimuove le reti Wi-Fi salvate (preferite). La rimozione richiede admin
/// perché modifica la configurazione di rete del sistema.
public struct WiFiScanner {

    public init() {}

    /// Nome del dispositivo Wi-Fi (es. "en0"), individuato dalle porte hardware.
    private func wifiDevice() -> String? {
        let out = run(["/usr/sbin/networksetup", "-listallhardwareports"])
        // Blocchi tipo: "Hardware Port: Wi-Fi\nDevice: en0\n..."
        let blocks = out.components(separatedBy: "Hardware Port:")
        for block in blocks where block.localizedCaseInsensitiveContains("Wi-Fi") {
            for line in block.split(separator: "\n") where line.contains("Device:") {
                return line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    public func scan() -> [WiFiNetwork] {
        guard let dev = wifiDevice() else { return [] }
        let out = run(["/usr/sbin/networksetup", "-listpreferredwirelessnetworks", dev])
        return out.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("Preferred networks") }
            .map { WiFiNetwork(ssid: $0) }
    }

    /// Rimuove le reti indicate (admin, unica richiesta password).
    public func remove(_ ssids: [String]) -> Bool {
        guard let dev = wifiDevice(), !ssids.isEmpty else { return false }
        let cmds = ssids.map {
            "/usr/sbin/networksetup -removepreferredwirelessnetwork \(shellQuote(dev)) \(shellQuote($0))"
        }.joined(separator: "; ")
        let script = "do shell script \"\(escape(cmds))\" with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func run(_ argv: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

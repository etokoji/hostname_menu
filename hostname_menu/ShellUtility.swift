import Foundation

func shell(_ command: String) -> String? {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    
    do {
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return nil
    }
}

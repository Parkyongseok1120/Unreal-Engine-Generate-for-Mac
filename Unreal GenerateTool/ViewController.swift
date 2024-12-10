import Cocoa
import UniformTypeIdentifiers

class ViewController: NSViewController {
    @IBOutlet weak var textView: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    @IBAction func selectUProjectFile(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a .uproject File"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        // macOS 11 이상에서는 UTType 사용
        if #available(macOS 11.0, *) {
            if let uprojectType = UTType(filenameExtension: "uproject") {
                openPanel.allowedContentTypes = [uprojectType]
            } else {
                print("Failed to create UTType for .uproject")
            }
        } else {
            // macOS 11 이전에서는 allowedFileTypes 사용
            openPanel.allowedFileTypes = ["uproject"]
        }
        
        openPanel.begin { result in
            if result == .OK, let selectedFileURL = openPanel.url {
                // 선택된 파일 경로 처리
                print("Selected file: \(selectedFileURL.path)")
                self.processUProjectFile(selectedFileURL)
            } else {
                print("No file selected or action canceled.")
            }
        }
    }
    
    func showErrorMessage(_ message: String) {
        DispatchQueue.main.async {
            self.textView.string = message
            print(message)
        }
    }
    
    func processUProjectFile(_ fileURL: URL) {
        // 파일 읽기
        guard let fileData = try? Data(contentsOf: fileURL) else {
            print("파일을 읽을 수 없습니다.")
            return
        }
        
        // JSON 파싱
        guard let jsonObject = try? JSONSerialization.jsonObject(with: fileData, options: []) as? [String: Any] else {
            print("JSON 파싱 실패")
            return
        }
        
        // 엔진 버전 확인
        guard let engineVersion = jsonObject["EngineAssociation"] as? String else {
            print("엔진 버전을 찾을 수 없습니다.")
            return
        }
        
        // 가능한 엔진 경로들
        let possiblePaths = [
            "/Users/Shared/Epic Games/UE_\(engineVersion)",
            "/Users/\(NSUserName())/Epic Games/UE_\(engineVersion)"
        ]
        
        // 실제 존재하는 경로 찾기
        guard let enginePath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("엔진 경로를 찾을 수 없습니다: \(engineVersion)")
            return
        }
        
        // 스크립트 경로
        let scriptPath = "\(enginePath)/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"
        
        // 스크립트 존재 확인
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            print("프로젝트 생성 스크립트를 찾을 수 없습니다.")
            return
        }
        
        // 명령어 생성
        let projectPath = fileURL.path.replacingOccurrences(of: " ", with: "\\ ")
        let projectDirectory = fileURL.deletingLastPathComponent().path.replacingOccurrences(of: " ", with: "\\ ")
        
        let command = "chmod +x \"\(scriptPath)\" && cd \"\(projectDirectory)\" && \"\(scriptPath)\" -project=\"\(projectPath)\""
        
        // 명령어 실행
        executeShellCommand(command)
    }

    func executeShellCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("실행 결과:\n\(output)")
            }
            
            task.waitUntilExit()
        } catch {
            print("명령 실행 중 오류: \(error.localizedDescription)")
        }
    }
}
extension String {
    func escapedForShell() -> String {
        return self.replacingOccurrences(of: " ", with: "\\ ")
    }
}

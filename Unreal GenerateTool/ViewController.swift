import Cocoa
import UniformTypeIdentifiers

import Foundation

func hasFullDiskAccess() -> Bool {
    // 접근하려는 디렉토리 경로
    let testPath = "/Users/Shared/test_access.txt"
    
    // FileManager 인스턴스 생성
    let fileManager = FileManager.default
    
    do {
        // 파일 생성 시도
        if fileManager.fileExists(atPath: testPath) {
            // 이미 존재하는 파일을 삭제합니다.
            try fileManager.removeItem(atPath: testPath)
        }
        
        // 파일 생성
        let data = "Test".data(using: .utf8)
        fileManager.createFile(atPath: testPath, contents: data, attributes: nil)
        
        // 파일이 성공적으로 생성되면 권한이 있음
        // 성공적으로 파일을 삭제
        try fileManager.removeItem(atPath: testPath)
        return true
    } catch {
        // 오류가 발생하면 권한이 없음
        print("Error: \(error.localizedDescription)")
        requestFullDiskAccess()
        return false
    }
    
}

func requestFullDiskAccess() {
    let alert = NSAlert()
    alert.messageText = "Full Disk Access Required"
    alert.informativeText = "This application requires access to your entire disk. Please go to System Preferences > Security & Privacy > Privacy tab and enable Full Disk Access for this application."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

class ViewController: NSViewController {
    @IBOutlet weak var textView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    @IBAction func selectUProjectFile(_ sender: Any) {

        hasFullDiskAccess()

        let openPanel = NSOpenPanel()
        openPanel.title = "Select a .uproject File"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        if #available(macOS 11.0, *) {
            if let uprojectType = UTType(filenameExtension: "uproject") {
                openPanel.allowedContentTypes = [uprojectType]
            } else {
                print("Failed to create UTType for .uproject")
            }
        } else {
            openPanel.allowedFileTypes = ["uproject"]
        }

        openPanel.begin { result in
            if result == .OK, let selectedFileURL = openPanel.url {
                self.processUProjectFile(selectedFileURL)
            } else {
                print("No file selected or action canceled.")
            }
        }
    }

    func processUProjectFile(_ fileURL: URL) {
        let scriptPath = "/Users/Shared/Epic Games/UE_5.4/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"
        
        // 스크립트가 존재하는지 확인
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            showErrorMessage("프로젝트 생성 스크립트를 찾을 수 없습니다.")
            return
        }
        
        // 프로젝트 파일 경로 가져오기
        let projectPath = fileURL.path.escapedForShell()
        
        // 명령어 생성
        let command = "chmod +x \"\(scriptPath)\" && \"\(scriptPath)\" -project=\"\(projectPath)\""

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
                DispatchQueue.main.async {
                    self.textView.string = output
                    
                }
            }
            
            task.waitUntilExit()
        } catch {
            showErrorMessage("명령 실행 중 오류: \(error.localizedDescription)")
        }
    }
    
    func showErrorMessage(_ message: String) {
        DispatchQueue.main.async {
            self.textView.string = message
            print(message)
        }
    }
}

extension String {
    func escapedForShell() -> String {
        return self.replacingOccurrences(of: " ", with: "\\ ")
    }
}

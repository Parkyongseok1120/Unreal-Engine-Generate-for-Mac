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

    func processUProjectFile(_ fileURL: URL) {
        do {
            // .uproject 파일 읽기
            let fileData = try Data(contentsOf: fileURL)
            if let jsonObject = try JSONSerialization.jsonObject(with: fileData, options: []) as? [String: Any],
               let engineVersion = jsonObject["EngineAssociation"] as? String {

                // 엔진 경로 생성
                let scriptPath = "/Users/Shared/Epic Games/UE_\(engineVersion)/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"

                // 실행 명령 생성
                let projectPath = fileURL.path.escapedForShell()
                let projectDirectory = fileURL.deletingLastPathComponent().path.escapedForShell()
                let command = "cd \(projectDirectory) && \(scriptPath.escapedForShell()) -project=\(projectPath)"

                print("Executing command: \(command)")
                self.executeCommand(command)
            } else {
                print("Failed to parse EngineAssociation from \(fileURL.path)")
                textView.string = "Failed to read engine version from the .uproject file."
            }
        } catch {
            print("Error reading .uproject file: \(error)")
            textView.string = "Error reading the .uproject file: \(error.localizedDescription)"
        }
    }

    func executeCommand(_ command: String) {
        DispatchQueue.global().async {
            let task = Process()
            task.launchPath = "/bin/zsh" // 터미널 명령 실행
            task.arguments = ["-c", command]
            
            // 출력 스트림을 잡기 위해 파이프 설정
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            task.launch()
            
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: output, encoding: .utf8) ?? ""
            
            task.waitUntilExit()
            DispatchQueue.main.async {
                self.textView.string = "Command execution completed.\n\nOutput:\n\(outputString)"
                print("Command execution output: \(outputString)")
            }
        }
    }
}

// Shell 경로에 사용할 수 있도록 문자열 변환
extension String {
    func escapedForShell() -> String {
        return self.replacingOccurrences(of: " ", with: "\\ ")
    }
}

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
            do {
                // .uproject 파일 읽기
                let fileData = try Data(contentsOf: fileURL)
                if let jsonObject = try JSONSerialization.jsonObject(with: fileData, options: []) as? [String: Any],
                   let engineVersion = jsonObject["EngineAssociation"] as? String {

                    // 엔진 버전으로 경로 구성
                    let scriptPath = "/Users/Shared/Epic Games/UE_\(engineVersion)/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"

                    // 실행 명령 구성
                    let command = "cd \(fileURL.deletingLastPathComponent().path.escapedForShell()) && \(scriptPath.escapedForShell()) -project=\(fileURL.path.escapedForShell()) -Rider"

                    // 명령 실행
                    self.executeShellCommand(command)
                } else {
                    print("Failed to parse EngineAssociation from \(fileURL.path)")
                }
            } catch {
                print("Error reading .uproject file: \(error)")
            }
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

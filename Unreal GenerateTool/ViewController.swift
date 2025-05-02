import Cocoa
import UniformTypeIdentifiers

// MARK: - Main ViewController
class ViewController: NSViewController {
    @IBOutlet weak var textView: NSTextView!
    
    private let unrealEngine = UnrealEngineService()
    private let fileManager = FileManager.default
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Actions
    @IBAction func selectUProjectFile(_ sender: Any) {
        let openPanel = createFileOpenPanel(
            title: "Select a .uproject File",
            fileExtension: "uproject",
            canChooseFiles: true,
            canChooseDirectories: false
        )

        openPanel.begin { [weak self] result in
            guard let self = self,
                  result == .OK,
                  let selectedFileURL = openPanel.url else {
                print("No file selected or action canceled.")
                return
            }
            
            self.processUProjectFile(selectedFileURL)
        }
    }
    
    // MARK: - UProject Processing
    private func processUProjectFile(_ fileURL: URL) {
        do {
            guard let engineVersion = try unrealEngine.getEngineVersion(from: fileURL) else {
                showErrorMessage("Failed to parse EngineAssociation from \(fileURL.path)")
                return
            }
            
            let defaultScriptPath = unrealEngine.getDefaultScriptPath(forVersion: engineVersion)
            
            if fileManager.fileExists(atPath: defaultScriptPath) {
                executeGenerateProjectFilesScript(
                    scriptPath: defaultScriptPath,
                    projectPath: fileURL
                )
            } else {
                promptForEngineDirectory(defaultPath: defaultScriptPath, projectFile: fileURL)
            }
        } catch {
            showErrorMessage("Error reading .uproject file: \(error)")
        }
    }
    
    private func promptForEngineDirectory(defaultPath: String, projectFile: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 먼저 경고창 표시
            let alert = NSAlert()
            alert.messageText = "Engine Not Found"
            alert.informativeText = "No engine downloaded from Epic Games Launcher was found. If you are using a GitHub source build version, please specify the GenerateProjectFiles.sh file path or select the parent directory containing the Engine folder."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Ok")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                return // 사용자가 취소를 누른 경우
            }
            
            // 사용자가 확인을 누른 경우 파일 선택 다이얼로그 표시
            let openPanel = self.createFileOpenPanel(
                title: "Select GenerateProjectFiles.sh or Engine Parent Directory",
                message: "Please select the GenerateProjectFiles.sh file from your engine source build. (It is typically located in the Engine/Build/BatchFiles/Mac/ directory)",
                promptButton: "Select",
                fileExtension: "sh",
                canChooseFiles: true,
                canChooseDirectories: false
            )
            
            // 초기 디렉토리 설정 (사용자 홈 디렉토리 내 가능성 있는 위치)
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            if let documents = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
                openPanel.directoryURL = documents
            }
            
            openPanel.begin { result in
                guard result == .OK, let selectedURL = openPanel.url else { return }
                
                // 선택된 sh 파일 직접 사용
                if selectedURL.pathExtension == "sh" {
                    self.executeGenerateProjectFilesScript(
                        scriptPath: selectedURL.path,
                        projectPath: projectFile
                    )
                } else {
                    // 만약 sh 파일이 아닌 다른 것을 선택했다면 Engine 디렉토리 찾기 시도
                    self.findEngineAndExecuteScript(
                        inDirectory: selectedURL,
                        projectFile: projectFile
                    )
                }
            }
        }
    }
    
    private func findEngineAndExecuteScript(inDirectory directory: URL, projectFile: URL) {
        // 직접 sh 파일을 선택한 경우
        if directory.pathExtension == "sh" && directory.lastPathComponent.contains("GenerateProjectFiles.sh") {
            executeGenerateProjectFilesScript(
                scriptPath: directory.path,
                projectPath: projectFile
            )
            return
        }
        
        // 디렉토리를 선택한 경우 Engine 폴더 찾기 시도
        if let enginePath = unrealEngine.findEngineDirectory(in: directory) {
            let scriptPath = "\(enginePath)/Build/BatchFiles/Mac/GenerateProjectFiles.sh"
            
            if fileManager.fileExists(atPath: scriptPath) {
                executeGenerateProjectFilesScript(
                    scriptPath: scriptPath,
                    projectPath: projectFile
                )
            } else {
                showErrorMessage("GenerateProjectFiles.sh not found in selected Engine directory: \(scriptPath)")
                
                // sh 파일을 직접 선택하도록 다시 프롬프트
                promptForEngineDirectory(defaultPath: scriptPath, projectFile: projectFile)
            }
        } else {
            showErrorMessage("Engine directory not found in the selected path: \(directory.path)")
            
            // sh 파일을 직접 선택하도록 다시 프롬프트
            promptForEngineDirectory(defaultPath: directory.path, projectFile: projectFile)
        }
    }
    
    // MARK: - Script Execution
    private func executeGenerateProjectFilesScript(scriptPath: String, projectPath: URL) {
        let projectDir = projectPath.deletingLastPathComponent().path.escapedForShell()
        let command = "cd \(projectDir) && \(scriptPath.escapedForShell()) -project=\(projectPath.path.escapedForShell()) -Rider"
        
        executeShellCommand(command)
    }
    
    private func executeShellCommand(_ command: String) {
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
                print("Result :\n\(output)")
                DispatchQueue.main.async { [weak self] in
                    self?.textView.string = output
                }
            }

            task.waitUntilExit()
        } catch {
            showErrorMessage("ErrorCode : \(error.localizedDescription)")
        }
    }
    
    // MARK: - UI Helpers
    private func createFileOpenPanel(
        title: String,
        message: String? = nil,
        promptButton: String? = nil,
        fileExtension: String? = nil,
        canChooseFiles: Bool = true,
        canChooseDirectories: Bool = false
    ) -> NSOpenPanel {
        let openPanel = NSOpenPanel()
        openPanel.title = title
        openPanel.message = message
        openPanel.prompt = promptButton
        openPanel.canChooseFiles = canChooseFiles
        openPanel.canChooseDirectories = canChooseDirectories
        openPanel.allowsMultipleSelection = false
        
        // 특정 파일 탐색 경로 안내 추가
        if message?.contains("GenerateProjectFiles.sh") == true {
            // 일반적인 Unreal Engine 소스 빌드 위치에 대한 힌트 추가
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            let commonPaths = [
                "\(homePath)/UE_Source/UnrealEngine/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh",
                "\(homePath)/Documents/UnrealEngine/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh",
                "\(homePath)/Projects/UnrealEngine/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh",
            ]
            
            let pathHints = commonPaths.joined(separator: "\n")
            openPanel.message = (message ?? "") + "\n\n일반적인 소스 빌드 위치:\n" + pathHints
        }
        
        if let fileExtension = fileExtension {
            if #available(macOS 11.0, *) {
                if let fileType = UTType(filenameExtension: fileExtension) {
                    openPanel.allowedContentTypes = [fileType]
                } else {
                    print("Failed to create UTType for .\(fileExtension)")
                }
            } else {
                openPanel.allowedFileTypes = [fileExtension]
            }
        }
        
        return openPanel
    }
    
    private func showErrorMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.textView.string = message
            print(message)
        }
    }
}

// MARK: - UnrealEngine Service
class UnrealEngineService {
    
    // 엔진 버전 파싱
    func getEngineVersion(from projectFile: URL) throws -> String? {
        let fileData = try Data(contentsOf: projectFile)
        guard let jsonObject = try JSONSerialization.jsonObject(with: fileData, options: []) as? [String: Any],
              let engineVersion = jsonObject["EngineAssociation"] as? String else {
            return nil
        }
        return engineVersion
    }
    
    // 기본 스크립트 경로 얻기
    func getDefaultScriptPath(forVersion version: String) -> String {
        return "/Users/Shared/Epic Games/UE_\(version)/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"
    }
    
    // Engine 폴더 찾기
    func findEngineDirectory(in directory: URL) -> String? {
        let fileManager = FileManager.default
        
        // 1. 선택한 디렉토리가 바로 Engine 폴더인지 확인
        if directory.lastPathComponent == "Engine" {
            return directory.path
        }
        
        // 2. 선택한 디렉토리 내에 Engine 폴더가 있는지 확인
        let enginePath = directory.appendingPathComponent("Engine").path
        if fileManager.fileExists(atPath: enginePath) {
            return enginePath
        }
        
        // 3. 선택한 디렉토리 내의 모든 항목 검색 (1단계 깊이만)
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    let subEnginePath = item.appendingPathComponent("Engine").path
                    if fileManager.fileExists(atPath: subEnginePath) {
                        return subEnginePath
                    }
                }
            }
        } catch {
            print("Error searching directory: \(error)")
        }
        
        return nil
    }
}

// MARK: - Extensions
extension String {
    func escapedForShell() -> String {
        // 기본 이스케이프는 공백만 처리
        // 필요에 따라 확장 가능
        return self.replacingOccurrences(of: " ", with: "\\ ")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "&", with: "\\&")
    }
}

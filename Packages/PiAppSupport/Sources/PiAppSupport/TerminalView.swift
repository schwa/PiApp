import SwiftUI
import SwiftTerm

#if os(macOS)
/// A SwiftUI view that wraps SwiftTerm's LocalProcessTerminalView for macOS.
public struct TerminalView: View {
    private let shell: String
    private let arguments: [String]
    private let environment: [String]?
    private let currentDirectory: String?

    @State private var terminalView: LocalProcessTerminalView?

    public init(
        shell: String = "/bin/zsh",
        arguments: [String] = [],
        environment: [String]? = nil,
        currentDirectory: String? = nil
    ) {
        self.shell = shell
        self.arguments = arguments
        self.environment = environment
        self.currentDirectory = currentDirectory
    }

    public var body: some View {
        ViewAdaptor<LocalProcessTerminalView>(
            make: {
                let view = LocalProcessTerminalView(frame: .zero)
                view.startProcess(
                    executable: shell,
                    args: arguments,
                    environment: environment,
                    currentDirectory: currentDirectory
                )
                return view
            }
        )
    }
}

#elseif os(iOS) || os(visionOS)
/// A SwiftUI view that wraps SwiftTerm's TerminalView for iOS/visionOS.
public struct TerminalView: View {
    public init() {}

    public var body: some View {
        ViewAdaptor<SwiftTerm.TerminalView>(
            make: {
                let view = SwiftTerm.TerminalView(frame: .zero)
                view.feed(text: "Terminal ready.\r\n")
                return view
            }
        )
    }
}
#endif

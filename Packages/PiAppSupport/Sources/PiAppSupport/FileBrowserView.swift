import SwiftUI
import Foundation

public struct FileBrowserView: View {
    @State private var currentPath: URL
    @State private var items: [FileItem] = []
    @State private var selectedItem: FileItem?
    @State private var errorMessage: String?
    @State private var fileContent: String?
    @State private var showingFileContent = false
    
    private let fileManager = FileManager.default
    
    public init() {
        #if os(macOS)
        _currentPath = State(initialValue: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        #else
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        _currentPath = State(initialValue: documentsURL)
        #endif
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Path bar
                pathBar
                
                Divider()
                
                if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if items.isEmpty {
                    ContentUnavailableView {
                        Label("Empty Folder", systemImage: "folder")
                    } description: {
                        Text("This folder is empty")
                    }
                } else {
                    List(items, selection: $selectedItem) { item in
                        FileRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                handleDoubleTap(item)
                            }
                            .onTapGesture(count: 1) {
                                selectedItem = item
                            }
                            .contextMenu {
                                Button {
                                    handleDoubleTap(item)
                                } label: {
                                    Label(item.isDirectory ? "Open" : "View", systemImage: item.isDirectory ? "folder" : "doc.text")
                                }
                                
                                #if os(macOS)
                                Button {
                                    revealInFinder(item)
                                } label: {
                                    Label("Reveal in Finder", systemImage: "folder.badge.questionmark")
                                }
                                #endif
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Files")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        loadDirectory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewFolder()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewFile()
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
            .refreshable {
                loadDirectory()
            }
            .sheet(isPresented: $showingFileContent) {
                fileContentSheet
            }
            .onAppear {
                loadDirectory()
            }
        }
    }
    
    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    navigateToRoot()
                } label: {
                    Image(systemName: "house")
                }
                .buttonStyle(.borderless)
                
                ForEach(pathComponents, id: \.self) { component in
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    
                    Button(component.lastPathComponent) {
                        navigateTo(component)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private var pathComponents: [URL] {
        var components: [URL] = []
        var url = currentPath
        let rootPath = rootURL.path
        
        while url.path != rootPath && url.path != "/" {
            components.insert(url, at: 0)
            url = url.deletingLastPathComponent()
        }
        
        return components
    }
    
    private var rootURL: URL {
        #if os(macOS)
        return URL(fileURLWithPath: "/")
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
    }
    
    private var fileContentSheet: some View {
        NavigationStack {
            ScrollView {
                if let content = fileContent {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    Text("Unable to read file")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(selectedItem?.name ?? "File")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showingFileContent = false
                    }
                }
            }
        }
    }
    
    private func loadDirectory() {
        errorMessage = nil
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            items = contents.compactMap { url -> FileItem? in
                guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                    return nil
                }
                
                return FileItem(
                    url: url,
                    isDirectory: resourceValues.isDirectory ?? false,
                    size: resourceValues.fileSize ?? 0,
                    modificationDate: resourceValues.contentModificationDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }
    
    private func handleDoubleTap(_ item: FileItem) {
        if item.isDirectory {
            currentPath = item.url
            loadDirectory()
        } else {
            // Try to read and display text file
            selectedItem = item
            if let content = try? String(contentsOf: item.url, encoding: .utf8) {
                fileContent = content
                showingFileContent = true
            } else {
                fileContent = nil
                showingFileContent = true
            }
        }
    }
    
    private func navigateToRoot() {
        currentPath = rootURL
        loadDirectory()
    }
    
    private func navigateTo(_ url: URL) {
        currentPath = url
        loadDirectory()
    }
    
    private func createNewFolder() {
        let newFolderURL = currentPath.appendingPathComponent("New Folder")
        var finalURL = newFolderURL
        var counter = 1
        
        while fileManager.fileExists(atPath: finalURL.path) {
            finalURL = currentPath.appendingPathComponent("New Folder \(counter)")
            counter += 1
        }
        
        do {
            try fileManager.createDirectory(at: finalURL, withIntermediateDirectories: false)
            loadDirectory()
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }
    
    private func createNewFile() {
        let newFileURL = currentPath.appendingPathComponent("untitled.txt")
        var finalURL = newFileURL
        var counter = 1
        
        while fileManager.fileExists(atPath: finalURL.path) {
            finalURL = currentPath.appendingPathComponent("untitled \(counter).txt")
            counter += 1
        }
        
        do {
            try "".write(to: finalURL, atomically: true, encoding: .utf8)
            loadDirectory()
        } catch {
            errorMessage = "Failed to create file: \(error.localizedDescription)"
        }
    }
    
    #if os(macOS)
    private func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    #endif
    
    private func deleteItem(_ item: FileItem) {
        do {
            try fileManager.removeItem(at: item.url)
            loadDirectory()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let size: Int
    let modificationDate: Date?
    
    var name: String {
        url.lastPathComponent
    }
    
    var icon: String {
        if isDirectory {
            return "folder.fill"
        }
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift":
            return "swift"
        case "js", "ts", "jsx", "tsx":
            return "doc.text"
        case "json":
            return "curlybraces"
        case "md", "markdown":
            return "doc.richtext"
        case "txt":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            return "photo"
        case "pdf":
            return "doc.fill"
        case "zip", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc"
        }
    }
    
    var iconColor: Color {
        if isDirectory {
            return .blue
        }
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift":
            return .orange
        case "js", "ts", "jsx", "tsx":
            return .yellow
        case "json":
            return .green
        case "md", "markdown":
            return .purple
        default:
            return .secondary
        }
    }
    
    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct FileRow: View {
    let item: FileItem
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .foregroundStyle(item.iconColor)
                .frame(width: 24)
            
            Text(item.name)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.formattedSize)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
    }
}

#if canImport(UIKit)
import UIKit
fileprivate extension Color {
    init(uiColor: UIColor) {
        self = Color(uiColor)
    }
}
#elseif canImport(AppKit)
import AppKit
fileprivate extension Color {
    init(uiColor: NSColor) {
        self = Color(nsColor: uiColor)
    }
}
fileprivate extension UIColor {
    static var secondarySystemBackground: NSColor { .windowBackgroundColor }
}
fileprivate typealias UIColor = NSColor
#endif

#Preview {
    FileBrowserView()
}

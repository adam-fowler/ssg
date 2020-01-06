import Files
import Foundation
import Ink

public extension Markdown {
    static let targetPathKey = "_TARGET_PATH_KEY_"
    
    var targetPath: String? {
        get { metadata[Self.targetPathKey] }
        set(value) { metadata[Self.targetPathKey] = value }
    }
}

public class Content {
    public struct SourceMarkdown {
        public let file: File
        public let lastModified: Date
        public var targetPath: String
        public var markdown: Markdown
    }

    init(_ folder: Folder) {
        self.rootFolder = folder

        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "d MMM yyy HH:mm:ss"
        self.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    }

    /// load markdown for posts and pages
    func load() throws {
        let postsFolder = try rootFolder.subfolder(at: "posts")
        self.posts = try loadMarkdown(from: postsFolder, includeSubFolders: false).map {
            var sourceMarkdown = $0
            sourceMarkdown.markdown.metadata["type"] = "post"
            sourceMarkdown.targetPath = $0.targetPath
            for processor in markdownProcessors {
                sourceMarkdown.markdown = processor(sourceMarkdown.markdown)
            }
            return sourceMarkdown
        }.sorted { $0.lastModified > $1.lastModified }

        let pagesFolder = try rootFolder.subfolder(at: "pages")
        self.pages = try loadMarkdown(from: pagesFolder, includeSubFolders: true).map {
            var sourceMarkdown = $0
            sourceMarkdown.markdown.metadata["type"] = "page"
            sourceMarkdown.targetPath = $0.file.path(relativeTo: pagesFolder).split(separator: ".").dropLast().joined() + ".html"
            sourceMarkdown.targetPath = $0.targetPath
            for processor in markdownProcessors {
                sourceMarkdown.markdown = processor(sourceMarkdown.markdown)
            }
            return sourceMarkdown
        }.sorted { $0.lastModified > $1.lastModified }
    }

    /// load markdown files from folder
    func loadMarkdown(from folder: Folder, includeSubFolders: Bool) throws -> [SourceMarkdown] {
        let parser = MarkdownParser()

        let pages = try folder.files.map { (file)->SourceMarkdown in
            let contents = try file.readAsString(encodedAs: .utf8)
            var lastModified = file.modificationDate ?? Date(timeIntervalSince1970: 0)
            let markdown = parser.parse(contents)
            if let createdOn = markdown.metadata["published_on"] {
                if let date = dateFormatter.date(from: createdOn) {
                    lastModified = date
                }
            }
            return SourceMarkdown(file:file,
                                  lastModified: lastModified,
                                  targetPath: "\(file.nameExcludingExtension).html",
                                  markdown: markdown)
        }
        
        if includeSubFolders {
            return try folder.subfolders.reduce(pages) { result, folder in
                let pages = try self.loadMarkdown(from: folder, includeSubFolders: true)
                return result + pages
            }
        }
        return pages
    }

    public var posts: [SourceMarkdown] = []
    public var pages: [SourceMarkdown] = []

    var rootFolder: Folder
    var dateFormatter: DateFormatter
    var markdownProcessors: [(Markdown) -> Markdown] = []
}

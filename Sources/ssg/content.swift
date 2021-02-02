import Files
import Foundation
import Ink

public extension Markdown {
    static let targetPathKey = "_TARGET_PATH_KEY_"
    static let idKey = "_ID_KEY_"
    static let prevPostKey = "_PREV_POST_KEY_"
    static let nextPostKey = "_NEXT_POST_KEY_"

    var targetPath: String? {
        get { metadata[Self.targetPathKey] }
        set(value) { metadata[Self.targetPathKey] = value }
    }
    
    private func get<T: LosslessStringConvertible>(key: String) -> T? {
        if let id = metadata[key] {
            return T(id)
        }
        return nil
    }
    
    private mutating func set<T: LosslessStringConvertible>(key: String, value:T?) {
        if let value = value {
            metadata[key] = value.description
        } else {
            metadata[key] = nil
        }
    }
    
    var id: Int? {
        get { return get(key: Self.idKey) }
        set(value) { set(key: Self.idKey, value: value) }
    }
    
    var prevPost: Int? {
        get { return get(key: Self.prevPostKey) }
        set(value) { set(key: Self.prevPostKey, value: value) }
    }
    
    var nextPost: Int? {
        get { return get(key: Self.nextPostKey) }
        set(value) { set(key: Self.nextPostKey, value: value) }
    }

    var isPrivate: Bool {
        metadata["private"]  == "true" || metadata["ignore"]  == "true"
    }
}

public class Content {
    public struct SourceMarkdown {
        public let file: File
        public let lastModified: Date
        public var targetPath: String
        public var markdown: Markdown
    }

    public var posts: [SourceMarkdown] = []
    public var pages: [SourceMarkdown] = []

    init(_ folder: Folder) {
        self.rootFolder = folder

        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "d MMM yyy HH:mm:ss"
        self.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        self.folderDateFormatter = DateFormatter()
        self.folderDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.folderDateFormatter.dateFormat = "yyyy'/'MM"
        self.folderDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        markdownProcessors.append {
            var markdown = $0
            if let title = markdown.metadata["title"] {
                markdown.title = title
            } else {
                markdown.metadata["title"] = markdown.title
            }
            return markdown
        }
    }

    /// get post with id
    public func getPost(with id: Int) -> Markdown? {
        let idString = String(id)
        return posts.first { $0.markdown.metadata[Markdown.idKey] == idString }?.markdown
    }
    
    /// get post with id
    public func getPage(with id: Int) -> Markdown? {
        let idString = String(id)
        return pages.first { $0.markdown.metadata[Markdown.idKey] == idString }?.markdown
    }

    public var publicPosts: [Content.SourceMarkdown] {
        return posts.filter {
            return !$0.markdown.isPrivate
        }
    }

    public var publicPages: [Content.SourceMarkdown] {
        return pages.filter {
            return !$0.markdown.isPrivate
        }
    }

    /// load markdown for posts and pages
    func load() throws {
        let postsFolder = try rootFolder.subfolder(at: "posts")
        self.posts = try loadMarkdown(from: postsFolder, includeSubFolders: false).map {
            var sourceMarkdown = $0
            sourceMarkdown.markdown.metadata["type"] = "post"
            // work out target path
            let folder = folderDateFormatter.string(from: $0.lastModified)
            sourceMarkdown.targetPath = "\(folder)/\($0.file.path(relativeTo: postsFolder).split(separator: ".").dropLast().joined()).html"
            sourceMarkdown.markdown.targetPath = sourceMarkdown.targetPath
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
            sourceMarkdown.markdown.targetPath = sourceMarkdown.targetPath
            for processor in markdownProcessors {
                sourceMarkdown.markdown = processor(sourceMarkdown.markdown)
            }
            return sourceMarkdown
        }.sorted { $0.lastModified > $1.lastModified }
        
        // remove posts/pages that are flagged as drafts
        posts = posts.compactMap { guard $0.markdown.metadata["draft"] == nil else {return nil}; return $0 }
        pages = pages.compactMap { guard $0.markdown.metadata["draft"] == nil else {return nil}; return $0 }

        calculateNextPreviousPostIds()
    }

    /// load markdown files from folder
    func loadMarkdown(from folder: Folder, includeSubFolders: Bool) throws -> [SourceMarkdown] {

        let pages = try folder.files.map { (file)->SourceMarkdown in
            print("Loading \(file.name)")
            let contents = try file.readAsString(encodedAs: .utf8)
            var lastModified = file.modificationDate ?? Date(timeIntervalSince1970: 0)
            var markdown = parser.parse(contents)
            
            // set id and increment, ensures every block of markdown has a unique id
            markdown.id = currentId
            currentId = currentId + 1
            
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

    /// calculate next/previous post ids
    func calculateNextPreviousPostIds() {
        guard posts.count > 0 else {return}
        var nextPost: Int? = nil
        var nextPostIndex: Int? = nil
        for i in 0..<posts.count {
            // don't include private posts
            if !posts[i].markdown.isPrivate {
                if let nextPostIndex = nextPostIndex {
                    posts[nextPostIndex].markdown.prevPost = posts[i].markdown.id
                }
                posts[i].markdown.nextPost = nextPost
                nextPostIndex = i
                nextPost = posts[i].markdown.id
            }
        }
    }
    

    var markdownProcessors: [(Markdown) -> Markdown] = []
    var parser = MarkdownParser()
    var dateFormatter: DateFormatter

    private var rootFolder: Folder
    private var folderDateFormatter: DateFormatter
    private var currentId: Int = 0
}

import Files
import Foundation
import Ink
import Plot
import Reading

open class Site {
    public typealias Metadata = [String: String]

    public struct Configuration {
        public var name: String
        public var url: String
        public var description: String
        public var language: Language
        public var cdn: String?
        
        public init(name: String, url : String, description: String, language: Language, cdn: String? = nil) {
            self.name = name
            self.url = url
            self.description = description
            self.language = language
            self.cdn = cdn
        }
    }

    public var config: Configuration
    public var rootFolder: Folder
    public var htmlFolder: Folder
    public var content: Content
    
    public init(configuration: Configuration, src: Folder, dest: Folder) {
        self.config = configuration
        // ensure the website address doesn't end with a "/"
        if config.url.last == "/" {
            config.url = String(config.url.dropLast())
        }

        self.rootFolder = src
        self.htmlFolder = dest

        self.content = Content(src)
        self.siteMap = XMLSitemap()
        
        // add markdown URL editor for CDN address
        if var cdn = config.cdn {
            if cdn.last == "/" {
                cdn = String(cdn.dropLast())
            }
            addImageURLPrefix(cdn)
        }

        // add contents generator that outputs a pages main content
        addContentsGenerator { markdown in
            return .div(
                .class("content_body"),
                .raw(markdown.html)
            )
        }
        
        // add standard website head entries
        addHeadGenerator(standardHead)
    }
    
    public func load() throws {
        try content.load()
    }
    
    public func addMarkdownModifier(_ modifier: Modifier) {
        content.parser.addModifier(modifier)
    }
    
    public func addMarkdownProcessor(_ cb: @escaping (Markdown) -> Markdown) {
        content.markdownProcessors.append(cb)
    }
    
    public func addFileProcessor(for extension: String, process: @escaping (File, Folder) throws -> ()) {
        fileProcessors[`extension`] = process
    }
    
    public func addHeadGenerator(_ cb: @escaping (Metadata)->[Node<HTML.HeadContext>]) {
        headGenerators.append(cb)
    }
    
    public func addHeaderGenerator(_ cb: @escaping (Metadata)->Node<HTML.BodyContext>) {
        headerGenerators.append(cb)
    }
    
    public func addContentsGenerator(_ cb: @escaping (Markdown)->Node<HTML.BodyContext>) {
        contentsGenerators.append(cb)
    }
    
    public func insertContentsGenerator(_ cb: @escaping (Markdown)->Node<HTML.BodyContext>, at index: Int) {
        contentsGenerators.insert(cb, at: index)
    }
    
    public func addFooterGenerator(_ cb: @escaping (Metadata)->Node<HTML.BodyContext>) {
        footerGenerators.append(cb)
    }
    
    public func addEndGenerator(_ cb: @escaping (Metadata)->Node<HTML.BodyContext>) {
        endGenerators.append(cb)
    }
    
    /// copy contents of folder to another folder
    public func syncFolder(folderName: String) throws {
        let srcFolder = try rootFolder.subfolder(at: folderName)
        let targetFolder = try htmlFolder.createSubfolderIfNeeded(at: folderName)
        try targetFolder.delete()
        try srcFolder.copy(to: htmlFolder)
    }
    
    /// copy contents of folder to another folder
    public func syncFolder(folderName: String, targetFolder: String) throws {
        let srcFolder = try rootFolder.subfolder(at: folderName)
        let targetFolder = try htmlFolder.createSubfolderIfNeeded(at: targetFolder)
        for file in srcFolder.files.includingHidden {
            if let targetFile = try? targetFolder.file(at: file.name) {
                try targetFile.delete()
            }
            try file.copy(to: targetFolder)
        }
    }
    
    /// copy contents of folder and minimize to another folder
    public func syncAndProcessFolder(source: String, target: String? = nil, includeHidden: Bool = false) throws {
        let target = target ?? source
        let sourceFolder = try rootFolder.subfolder(at: source)
        let targetFolder = try htmlFolder.createSubfolderIfNeeded(at: target)
        try syncAndProcessFolder(sourceFolder: sourceFolder, targetFolder: targetFolder, includeHidden: includeHidden)
    }

    public func syncAndProcessFolder(sourceFolder: Folder, targetFolder: Folder, includeHidden: Bool = false) throws {
        var files = sourceFolder.files
        if includeHidden {
            files = files.includingHidden
        }
        for file in files {
            if let targetFile = try? targetFolder.file(at: file.name) {
                guard let targetDate = targetFile.modificationDate,
                    let sourceDate = file.modificationDate,
                    targetDate < sourceDate else { continue }
                try targetFile.delete()
            }
            print("Sync \(file.name)")
            try copyAndProcessFile(file: file, destination: targetFolder)
        }
        
        for folder in sourceFolder.subfolders {
            let targetSubFolder = try targetFolder.createSubfolderIfNeeded(at: folder.name)
            try syncAndProcessFolder(sourceFolder: folder, targetFolder: targetSubFolder, includeHidden: includeHidden)
        }
    }
    
    public func copyAndProcessFile(file: File, destination: Folder) throws {
        for (ext, process) in fileProcessors {
            if file.extension == ext {
                try process(file, destination)
                return
            }
        }
        try file.copy(to: destination)
    }
    
    /// output HTML files for all the website posts
    public func outputPostsHTML() throws {
        for post in content.posts {
            try outputHTML(markdown: post.markdown, path: post.targetPath, lastModified: post.file.modificationDate ?? post.lastModified, priority: 0.25)
        }
    }
    
    /// output HTML files for all the website pages
    public func outputPagesHTML() throws {
        for page in content.pages {
            try outputHTML(markdown: page.markdown, path: page.targetPath, lastModified: page.file.modificationDate ?? page.lastModified, priority: 1.0)
        }
    }

    /// output HTML file given a title, contents and path to save to
    func outputHTML(markdown: Markdown, path: String, lastModified: Date = Date(), priority: Double = 0.5) throws {
        try outputHTML(contents: contents(markdown), metadata: markdown.metadata, path: path, lastModified: lastModified, priority: priority)
    }
    
    public func contents(_ markdown: Markdown) -> Node<HTML.BodyContext> {
        return .div (
            .if(markdown.metadata["type"] != nil,
                .unwrap(markdown.metadata["type"]) {.class("section \($0)")},
                else: .class("section")),
            .forEach(contentsGenerators) {
                .group($0(markdown))
            }
        )
    }
    
    /// output HTML file given a title, contents and path to save to
    public func outputHTML(contents: Node<HTML.BodyContext>, metadata: Metadata, path: String, lastModified: Date = Date(), priority: Double = 0.5) throws {
        var metadata = metadata
        // if target path isn't set in the metadata set it now
        if metadata[Markdown.targetPathKey] == nil {
            metadata[Markdown.targetPathKey] = path
        }
        var language = config.language
        // markdown can override the page language
        if let pageLanguage = metadata["lang"] {
            language = Language(rawValue: pageLanguage) ?? config.language
        }
        let html = HTML(
            .lang(language),
            .head(
                .forEach(headGenerators) {
                    .group($0(metadata))
                }
            ),
            .body(
                .if(metadata["no_header"] == nil,
                    .div(
                        .class("header"),
                        .forEach(headerGenerators) {
                            .group($0(metadata))
                        }
                    )
                ),
                .div(
                    .class("content"),
                    .id("main"),
                    contents
                ),
                .if(metadata["no_footer"] == nil,
                    .div(
                        .class("footer"),
                        .forEach(footerGenerators) {
                            .group($0(metadata))
                        }
                    )
                ),
                .forEach(endGenerators) {
                    .group($0(metadata))
                }
            )
        )
        _ = try htmlFolder.createFile(at: path, contents: Data(html.render().utf8))
        siteMap.addEntry(url: "\(config.url)/\(path)", lastModified: lastModified, priority: priority)
    }
    
    public func outputXMLSitemap() throws {
        try siteMap.output(htmlFolder)
    }
    
    public func outputRSSFeed() throws {
        let filename = "feed.xml"
        let rss = RSS(
            .title(config.name),
            .description(config.description),
            .link(config.url),
            .language(config.language),
            .lastBuildDate(Date(), timeZone: content.dateFormatter.timeZone),
            .pubDate(Date(), timeZone: content.dateFormatter.timeZone),
            .ttl(Int(1440)),
            .atomLink("\(config.url)/\(filename)"),
            .forEach(content.posts[0..<10]) { item in
                .item(
                    .unwrap(item.markdown.metadata[Markdown.targetPathKey]) {
                        .group(
                            .guid("\(config.url)/\($0)"),
                            .link("\(config.url)/\($0)")
                        )
                    },
                    .title(item.markdown.metadata["title"] ?? config.url),
                    .description(item.markdown.brief()),
                    .pubDate(item.lastModified, timeZone: content.dateFormatter.timeZone),
                    .content(item.markdown.html)
                )
            }
        )
        _ = try htmlFolder.createFile(at: filename, contents: Data(rss.render().utf8))
    }
    /// Return standard head data
    func standardHead(_ metadata: Metadata) -> [Node<HTML.HeadContext>] {
        return [
            .encoding(.utf8),
            .siteName(config.url),
            .title(metadata["title"] != nil ? "\(metadata["title"]!) - \(config.name)" : config.name),
            .unwrap(metadata["description"]) {.description($0)},
            .unwrap(metadata[Markdown.targetPathKey]) {.url("\(config.url)/\($0)")},
            .if(metadata["socialmedia_image"] != nil,
                .unwrap(metadata["socialmedia_image"]) {.socialImageLink($0)},
                else: .unwrap(metadata["featured_image"]) {.socialImageLink($0)}
            ),
            .twitterCardType(.summaryLargeImage)
        ]
    }
    
    func installFile(_ filename: String, to folder: String) throws {
        let sourceFolder = try File(path:#file).parent
        let targetFolder = try htmlFolder.createSubfolderIfNeeded(at: folder)
        if let jsFile = try sourceFolder?.file(at: filename) {
            if let targetFile = try? targetFolder.file(at: jsFile.name) {
                try targetFile.delete()
            }
            try jsFile.copy(to: targetFolder)
        }
    }

    func addImageURLPrefix(_ prefix: String) {
        addMarkdownModifier(Modifier(target: .images) { input in
            let reader = Reader(input.html)
            let speechMarks = Set("'\"")
            do {
                guard try reader.read("<img src=") else { throw Reader.Error.unexpected }
                guard try reader.read(speechMarks) else { throw Reader.Error.unexpected }
                let url = try reader.read(until: speechMarks)
                guard url[url.startIndex] == "/" else { return input.html }
                try reader.advance()
                let remains = reader.readUntilTheEnd()
                return "<img src=\"\(prefix)\(url)\"\(remains)"
            } catch {
                return input.html
            }
        })
        
        addMarkdownProcessor {
            var markdown = $0
            if let featuredImage = markdown.metadata["featured_image"],
                featuredImage[featuredImage.startIndex] == "/" {
                markdown.metadata["featured_image"] = prefix + featuredImage
            }
            if let socialMediaImage = markdown.metadata["socialmedia_image"],
                socialMediaImage[socialMediaImage.startIndex] == "/" {
                markdown.metadata["socialmedia_image"] = prefix + socialMediaImage
            }
            return markdown
        }
    }
    
    private var siteMap: XMLSitemap
    
    private var headGenerators: [(Metadata)->[Node<HTML.HeadContext>]] = []
    private var headerGenerators: [(Metadata)->Node<HTML.BodyContext>] = []
    private var contentsGenerators: [(Markdown)->Node<HTML.BodyContext>] = []
    private var footerGenerators: [(Metadata)->Node<HTML.BodyContext>] = []
    private var endGenerators: [(Metadata)->Node<HTML.BodyContext>] = []
    private var fileProcessors: [String: (File, Folder) throws -> ()] = [:]
}


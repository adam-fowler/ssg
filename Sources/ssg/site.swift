import Files
import Foundation
import Ink
import Plot

open class Site {
    public typealias Metadata = [String: String]
    
    public var webSiteName: String
    public var webSiteAddress: String
    public var language: Language
    public var rootFolder: Folder
    public var htmlFolder: Folder
    public var content: Content
    
    public init(webSiteName: String, address: String, language: Language = .english, src: Folder, dest: Folder) {
        self.webSiteName = webSiteName
        // ensure the website address doesn't end with a "/"
        if address.last == "/" {
            self.webSiteAddress = String(address.dropLast())
        } else {
            self.webSiteAddress = address
        }
        self.language = language
        self.rootFolder = src
        self.htmlFolder = dest

        self.content = Content(src)
        self.siteMap = XMLSitemap()
        
        addContentsGenerator { markdown in
            return .div(
                .class("content_body"),
                .raw(markdown.html)
            )
        }
        
        addHeadGenerator(standardHead)
    }
    
    public func load() throws {
        try content.load()
    }
    
    public func addFileProcessor(for extension: String, process: @escaping (File, Folder) throws -> ()) {
        fileProcessors[`extension`] = process
    }
    
    public func addMarkdownProcessor(_ cb: @escaping (Markdown) -> Markdown) {
        content.markdownProcessors.append(cb)
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
        var language = self.language
        // markdown can override the page language
        if let pageLanguage = metadata["lang"] {
            language = Language(rawValue: pageLanguage) ?? self.language
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
                )
            )
        )
        _ = try htmlFolder.createFile(at: path, contents: Data(html.render().utf8))
        siteMap.addEntry(url: "\(webSiteAddress)/\(path)", lastModified: lastModified, priority: priority)
    }
    
    public func outputXMLSitemap() throws {
        try siteMap.output(htmlFolder)
    }
    
    /// Return standard head data
    func standardHead(_ metadata: Metadata) -> [Node<HTML.HeadContext>] {
        return [
            .encoding(.utf8),
            .siteName(webSiteName),
            .title(metadata["title"] != nil ? "\(metadata["title"]!) - \(webSiteName)" : "Viewfinder Preview"),
            .unwrap(metadata["description"]) {.description($0)},
            .unwrap(metadata[Markdown.targetPathKey]) {.url("\(webSiteAddress)/\($0)")},
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

    private var siteMap: XMLSitemap
    
    private var headGenerators: [(Metadata)->[Node<HTML.HeadContext>]] = []
    private var headerGenerators: [(Metadata)->Node<HTML.BodyContext>] = []
    private var contentsGenerators: [(Markdown)->Node<HTML.BodyContext>] = []
    private var footerGenerators: [(Metadata)->Node<HTML.BodyContext>] = []
    private var fileProcessors: [String: (File, Folder) throws -> ()] = [:]
}


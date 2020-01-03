import Files
import Foundation
import Ink
import Plot

open class Site {
    public typealias Metadata = [String: String]
    
    public init(address: String, src: Folder, dest: Folder) {
        self.address = address
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
    }
    
    public func load() throws {
        try content.load()
    }
    
    public func addHeadGenerator(_ cb: @escaping (Metadata)->[Node<HTML.HeadContext>]) {
        headGenerator.append(cb)
    }
    
    public func addHeaderGenerator(_ cb: @escaping (Metadata)->Node<HTML.BodyContext>) {
        headerGenerator.append(cb)
    }
    
    public func addContentsGenerator(_ cb: @escaping (Markdown)->Node<HTML.BodyContext>) {
        contentsGenerator.append(cb)
    }
    
    public func insertContentsGenerator(_ cb: @escaping (Markdown)->Node<HTML.BodyContext>, at index: Int) {
        contentsGenerator.insert(cb, at: index)
    }
    
    public func addFooterGenerator(_ cb: @escaping (Metadata)->Node<HTML.BodyContext>) {
        footerGenerator.append(cb)
    }
    
    /// copy contents of folder to another folder
    public func syncFolder(folderName: String) throws {
        let srcFolder = try rootFolder.subfolder(at: folderName)
        let targetFolder = try htmlFolder.createSubfolderIfNeeded(at: folderName)
        try targetFolder.delete()
        try srcFolder.copy(to: htmlFolder)
    }
    
    /// copy contents of folder and minimize to another folder
    public func syncAndMinimizeFolder(folderName: String) throws {
        let srcFolder = try rootFolder.subfolder(at: folderName)
        let targetFolder = try htmlFolder.createSubfolderIfNeeded(at: folderName)
        for file in srcFolder.files {
            let contents = try file.readAsString(encodedAs: .utf8)
            try targetFolder.createFile(at: file.name, contents: Data(contents.utf8))
        }
    }
    
    /// output HTML files for all the website posts
    public func outputPostsHTML() throws {
        for post in content.posts {
            try outputHTML(markdown: post.markdown, path: "posts/\(post.file.nameExcludingExtension).html", lastModified: post.file.modificationDate ?? post.lastModified, priority: 0.25)
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
        try outputHTML(title: markdown.title, contents: contents(markdown), metadata: markdown.metadata, path: path, lastModified: lastModified, priority: priority)
    }
    
    public func contents(_ markdown: Markdown) -> Node<HTML.BodyContext> {
        return .div (
            .class("content \(markdown.metadata["type"] ?? "")"),
            .forEach(contentsGenerator) {
                .group($0(markdown))
            }
        )
    }
    
    /// output HTML file given a title, contents and path to save to
    public func outputHTML(title: String?, contents: Node<HTML.BodyContext>, metadata: Metadata, path: String, lastModified: Date = Date(), priority: Double = 0.5) throws {
        let html = HTML(
            .head(
                .forEach(headGenerator) {
                    .group($0(metadata))
                }
            ),
            .body(
                .div(
                    .class("header"),
                    .forEach(headerGenerator) {
                        .group($0(metadata))
                    }
                ),
                contents,
                .div(
                    .class("footer"),
                    .forEach(footerGenerator) {
                        .group($0(metadata))
                    }
                )
            )
        )
        _ = try htmlFolder.createFile(at: path, contents: Data(html.render().utf8))
        siteMap.addEntry(url: "\(address)/\(path)", lastModified: lastModified, priority: priority)
    }
    
    public func outputXMLSitemap() throws {
        try siteMap.output(htmlFolder)
    }
    
    var address: String
    var rootFolder: Folder
    var htmlFolder: Folder
    public var content: Content
    var siteMap: XMLSitemap
    
    var headGenerator: [(Metadata)->[Node<HTML.HeadContext>]] = []
    var headerGenerator: [(Metadata)->Node<HTML.BodyContext>] = []
    var contentsGenerator: [(Markdown)->Node<HTML.BodyContext>] = []
    var footerGenerator: [(Metadata)->Node<HTML.BodyContext>] = []
}


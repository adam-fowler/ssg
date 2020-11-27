import Foundation
import Ink
import Plot

public extension Node where Context: HTML.BodyContext {
    static func brief(_ sourceMarkdown: Content.SourceMarkdown, numCharacters: Int = 512, dateFormatter: DateFormatter? = nil, nodeToAppend: Node<HTML.BodyContext> = .empty) -> Self {
        let markdown = sourceMarkdown.markdown
        return .div (
            .class("brief"),
            .unwrap(markdown.metadata["title"]) {
                .div(
                    .class("brief_header"),
                    .a(
                        .unwrap(markdown.targetPath) {
                            .href("/\($0)")
                        },
                        .h2(.text($0))
                    )
                )
            },
            .unwrap(dateFormatter) {
                .div(
                    .class("brief_date"),
                    .text($0.string(from: sourceMarkdown.lastModified))
                )
            },
            .unwrap(markdown.metadata["featured_image"]) {
                .div(
                    .class("brief_image"),
                    .a(
                        .unwrap(markdown.targetPath) {
                            .href("/\($0)")
                        },
                        .img(.src($0))
                    )
                )
            },
            .div(
                .class("brief_body"),
                .p(.raw(markdown.brief(numCharacters: numCharacters)))
            ),
            nodeToAppend
        )
    }

    static func latest(_ content: Content, numPosts: Int = 5, numCharacters: Int = 512, dateFormatter: DateFormatter? = nil, insert: (Content.SourceMarkdown)->Node<HTML.BodyContext> = { _ in return .empty }) -> Self {
        let endIndex = min(numPosts, content.publicPosts.count)
        let postsForPage = content.publicPosts[0..<endIndex]
        return .div (
            .class("latest"),
            .forEach(postsForPage) {
                .brief($0, numCharacters: numCharacters, dateFormatter: dateFormatter, nodeToAppend: insert($0))
            }
        )
    }
}

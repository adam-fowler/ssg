import Ink
import Plot

public extension Node where Context: HTML.BodyContext {
    static func brief(_ markdown: Markdown) -> Self {
        return .div (
            .class("brief"),
            .unwrap(markdown.metadata["title"]) {
                .div(
                    .class("brief_header"),
                    .a(
                        .unwrap(markdown.targetPath) {
                            .href($0)
                        },
                        .h2(.text($0))
                    )
                )
            },
            .unwrap(markdown.metadata["featured_image"]) {
                .div(
                    .class("brief_image"),
                    .a(
                        .unwrap(markdown.targetPath) {
                            .href($0)
                        },
                        .img(.src($0))
                    )
                )
            },
            .div(
                .class("brief_body"),
                .p(.raw(markdown.brief()))
            )
        )
    }

    static func latest(_ content: Content, numPosts: Int = 5) -> Self {
        let endIndex = min(numPosts, content.posts.count)
        let postsForPage = content.posts[0..<endIndex]
        return .div (
            .class("latest"),
            .forEach(postsForPage) {
                .brief($0.markdown)
            }
        )
    }
}

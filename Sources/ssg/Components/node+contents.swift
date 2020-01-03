import Ink
import Plot

extension Node where Context: HTML.BodyContext {
    static func contents(_ markdown: Markdown) -> Self {
        return .div (
            .class("content \(markdown.metadata["type"] ?? "")"),
            .unwrap(markdown.metadata["title"]) {
                .div(
                    .h1(
                        .class("content_header post_header"),
                        .text($0)
                    )
                )
            },
            .div(
                .class("content_body"),
                .raw(markdown.html)
            )/*,
            .if(markdown.metadata["type"] == "post",
                .unwrap(markdown.tags) {
                    .tags($0)
                }
            )*/
        )
    }
}



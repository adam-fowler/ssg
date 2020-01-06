import Plot

public struct Menu {
    public init(_ entries: [(text: String, link: String)]) {
        self.entries = entries
    }
    let entries: [(text: String, link: String)]
}

public extension Node where Context: HTML.BodyContext {
    static func menu(_ menu: Menu) -> Self {
        return .div(
            .class("menu section"),
            .forEach(menu.entries) {
                .span(
                    .class("menu_item"),
                    .a(.href($0.link), .text($0.text))
                )
            }
        )
    }
}


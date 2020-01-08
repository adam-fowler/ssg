import Files
import Foundation
import Ink
import Plot

public extension Node where Context: HTML.BodyContext {
    static func cookieNotice(message: String? = nil) -> Self {
        return .div(
            .id("cookie-notice"),
            .style("display: none;"),
            .span(
                .id("cookie-notice-text"),
                .raw(message ?? "We use cookies to ensure we give the best experience on our website. If you continue to use this website we will assume you agree with this.")
            ),
            .a(.id("cookie-notice-button"), .href(""), .onclick("cookieNoticeAccept();"), .text("Ok")),
            .script(.text("var script=document.createElement('script');script.onload=function (){cookieNotice()};script.src='/js/cookie-notice.js';document.head.appendChild(script);"))
        )
    }
}

public extension Site {
    func installCookieJS() throws {
        try installFile("js/cookie-notice.js", to: "js")
    }
}

import Foundation
import Ink
import Plot

public extension Markdown {
    var tags: [String]? { metadata["tags"]?.split(whereSeparator: {!$0.isLetter && !$0.isNumber}).map { String($0) } }
}

public extension Markdown {
    func brief(numCharacters: Int = 512) -> String {
        var index = html.startIndex
        var inParagraph = false
        var paragraph: [Character] = []
        while(index != html.endIndex) {
            if inParagraph {
                if html[index...html.index(index, offsetBy: 3)] == "</p>" {
                    inParagraph = false
                    index = html.index(index, offsetBy: 4)
                    continue
                } else {
                    paragraph.append(html[index])
                    if paragraph.count == numCharacters {
                        break
                    }
                }
            } else {
                if html[index] == "<", html[index...html.index(index, offsetBy: 2)] == "<p>" {
                    inParagraph = true
                    index = html.index(index, offsetBy: 3)
                    continue
                }
            }
            index = html.index(after: index)
        }
        // if we didn't reach the end of the text, need to rewind until we hit a space
        if index != html.endIndex {
            while(paragraph.popLast() != " ") {}
            if paragraph.last == "." {
                _ = paragraph.popLast()
            }
            // add ellipsis
            paragraph.append("\u{2026}")
        }
        return String(paragraph)
    }
}


// Extensions to Plot. Attributes not supported in Plot

import Plot

public extension Node where Context: HTMLContext {
    /// Assign an ID to the current element.
    /// - parameter id: The ID to assign.
    static func onclick(_ js: String) -> Node {
        .attribute(named: "onclick", value: js)
    }

}

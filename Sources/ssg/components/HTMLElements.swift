// Extensions to Plot. Nodes not supported in Plot

import Plot

public extension Node where Context: HTML.BodyContext {
    /// Assign an ID to the current element.
    /// - parameter id: The ID to assign.
    static func googleAnalytics(_ propertyId: String) -> Node {
        return .script(.text("""
                            (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
                            (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
                            m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
                            })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');
                            
                            ga('create', '\(propertyId)', 'auto');
                            ga('send', 'pageview');
                            """
            ))
    }

}

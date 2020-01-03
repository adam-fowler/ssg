import Files
import Foundation
import Plot

class XMLSitemap {
    struct SitemapEntry {
        let url: String
        let lastModified: Date
        let priority: Double
    }
    
    func addEntry(url: String, lastModified: Date, priority: Double) {
        entries.append(SitemapEntry(url:url, lastModified: lastModified, priority: priority))
    }
    
    /// output XML sitemap
    func output(_ folder: Folder) throws {
        let siteMap = self.entries.sorted { $0.priority > $1.priority}
        let xml = SiteMap(
            .forEach(siteMap) {
                .url(.loc($0.url), .lastmod($0.lastModified), .priority($0.priority))
            }
        )
        _ = try folder.createFile(at: "sitemap.xml", contents: Data(xml.render().utf8))
    }
    
    var entries: [SitemapEntry] = []
}

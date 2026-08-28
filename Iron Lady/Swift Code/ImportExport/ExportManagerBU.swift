import Foundation
import ZIPFoundation
import CoreData

struct ExportManager {

    static func exportGroup(_ group: CrmGroup, completion: @escaping (URL?) -> Void) {
        do {
            let crumbs = (group.value(forKey: "breadcrumbs") as? Set<Breadcrumb>) ?? []
            let groupExport = CrmGroupExport(
                id: group.id ?? UUID(),
                groupName: group.groupName,
                groupDescription: group.groupDescription,
                dateCreated: group.dateCreated,
                breadcrumbs: crumbs.map {
                    BreadcrumbExport(
                        id: $0.id ?? UUID(),
                        name: $0.name,
                        city: $0.city,
                        state: $0.state,
                        streetAddress: $0.streetAddress,
                        zipCode: $0.zipCode,
                        dateDropped: $0.dateDropped,
                        latitude: $0.latitude,
                        longitude: $0.longitude,
                        isFavorite: $0.isFavorite,
                        note: $0.note,
                        photoURL: $0.photoURL
                    )
                }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(groupExport)

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let jsonURL = tempDir.appendingPathComponent("group.json")
            try jsonData.write(to: jsonURL)

            let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("GroupExport-\(UUID().uuidString).zip")
            try FileManager.default.zipItem(at: tempDir, to: zipURL)
            try FileManager.default.removeItem(at: tempDir)

            completion(zipURL)
        } catch {
            print(error)
            completion(nil)
        }
    }
}

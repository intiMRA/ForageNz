import AppKit
import ForageCatalogue
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downscales and re-encodes imported photos so what lands in the repo is already within
/// budget. Nothing is copied at original size — a 6 MB phone photo would blow the whole
/// allowance on its own.
enum PhotoImporter {
    enum Failure: Error, LocalizedError {
        case unreadable(String)
        case encodeFailed(String)
        case writeFailed(String)
        case stillTooLarge(name: String, bytes: Int)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name): "Couldn't read \(name) as an image."
            case .encodeFailed(let name): "Couldn't encode \(name) as HEIC."
            case .writeFailed(let detail): "Couldn't write the photo — \(detail)"
            case .stillTooLarge(let name, let bytes):
                "\(name) is still \(bytes / 1024) KB after compression. Crop it and try again."
            }
        }
    }

    /// Imports one file, returning the photo record to attach to the entry.
    ///
    /// Caption and credit are deliberately left blank: validation then flags them, so an
    /// unattributed photo can't quietly ship.
    static func importPhoto(
        from source: URL,
        speciesId: String,
        existing: [SpeciesPhoto],
        into directory: URL,
        fileManager: FileManager = .default
    ) throws -> SpeciesPhoto {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw Failure.unreadable(source.lastPathComponent)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: CataloguePhotos.maximumPixelSize
        ]
        guard let scaled = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw Failure.unreadable(source.lastPathComponent)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = nextFileName(speciesId: speciesId, existing: existing, directory: directory, fileManager: fileManager)
        let destination = directory.appending(path: fileName)

        let data = NSMutableData()
        guard let writer = CGImageDestinationCreateWithData(
            data, UTType.heic.identifier as CFString, 1, nil
        ) else {
            throw Failure.encodeFailed(source.lastPathComponent)
        }
        CGImageDestinationAddImage(writer, scaled, [
            kCGImageDestinationLossyCompressionQuality: CataloguePhotos.compressionQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(writer) else {
            throw Failure.encodeFailed(source.lastPathComponent)
        }

        guard data.length <= CataloguePhotos.maximumBytesPerPhoto else {
            throw Failure.stillTooLarge(name: source.lastPathComponent, bytes: data.length)
        }

        do {
            try (data as Data).write(to: destination, options: .atomic)
        } catch {
            throw Failure.writeFailed(String(describing: error))
        }

        return SpeciesPhoto(fileName: fileName, caption: "", credit: "")
    }

    /// Removes the file backing a photo. Called only after it's dropped from the entry.
    static func deleteFile(
        for photo: SpeciesPhoto,
        in directory: URL,
        fileManager: FileManager = .default
    ) {
        try? fileManager.removeItem(at: directory.appending(path: photo.fileName))
    }

    /// First index not already taken, checking disk too so a deleted-then-re-added photo
    /// can't collide with a file that is still there.
    private static func nextFileName(
        speciesId: String,
        existing: [SpeciesPhoto],
        directory: URL,
        fileManager: FileManager
    ) -> String {
        let taken = Set(existing.map(\.fileName))
        var index = 1
        while true {
            let candidate = CataloguePhotos.fileName(speciesId: speciesId, index: index)
            let onDisk = fileManager.fileExists(atPath: directory.appending(path: candidate).path)
            if !taken.contains(candidate) && !onDisk { return candidate }
            index += 1
        }
    }
}

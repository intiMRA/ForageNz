import Foundation

/// Runs `Tools/fetch_catalogue_photos.py --top-up` for one entry, so a reviewer who has run
/// the tray dry can ask for more without leaving the editor.
///
/// The editor shells out rather than reimplementing the fetch. Licence filtering, the
/// NZ-only place filter, the spread-across-observations ranking and the HEIC encode all live
/// in that script and are covered by its tests; a second implementation here would be a
/// second set of rules about what may ship.
enum PhotoFetcher {
    enum Failure: Error, LocalizedError, Equatable {
        case noInterpreter
        case scriptMissing(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noInterpreter:
                "No Python 3.11+ found. The fetcher needs one — try `python3 -m venv .venv` in the repo."
            case .scriptMissing(let path): "Couldn't find \(path)."
            case .failed(let detail): detail
            }
        }
    }

    /// What one run did, as the script reported it.
    struct Outcome: Sendable {
        /// How many candidates landed in the tray. Zero is a normal answer, not a fault: for
        /// an endemic with few observers there may be nothing else shippable in existence.
        let staged: Int
        let message: String
    }

    /// Candidates to stage beyond what the entry is short, so there is something to reject.
    ///
    /// Asking for exactly the shortfall makes "pick the best" meaningless — the keep rate on
    /// the first staged batches was about a half, so a one-photo gap wants a few to choose
    /// between.
    static let reviewSlack = 3

    static let relativeScriptPath = "Tools/fetch_catalogue_photos.py"

    /// Interpreters to try, best first. The repo's own virtualenv wins: it is what the test
    /// suite runs under, and macOS's `/usr/bin/python3` is 3.8, which cannot import the
    /// script's `enum.StrEnum`.
    private static let interpreterCandidates = [
        ".venv/bin/python",
        "/opt/homebrew/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python3"
    ]

    /// Stages more candidates for one entry and returns what the script said.
    ///
    /// Reads the catalogue **from disk**, so photos kept or removed but not yet saved are
    /// invisible to it — which only costs a duplicate offer, never a wrong one.
    /// - Parameter worldwide: lets observations from outside New Zealand fill what New Zealand
    ///   cannot. Off by default, and a per-entry judgement about one species rather than a
    ///   setting: the NZ-only filter exists because habitat prose is NZ-specific, which is
    ///   true of a fungus on a particular substrate and not of a bamboo culm.
    nonisolated static func topUp(
        speciesId: String,
        target: Int,
        catalogueURL: URL,
        stagingDirectory: URL,
        worldwide: Bool = false
    ) async throws -> Outcome {
        let root = repositoryRoot(for: catalogueURL)
        let script = root.appending(path: relativeScriptPath)
        guard FileManager.default.fileExists(atPath: script.path) else {
            throw Failure.scriptMissing(relativeScriptPath)
        }
        guard let interpreter = interpreter(under: root) else { throw Failure.noInterpreter }

        let output = try run(
            interpreter: interpreter,
            arguments: [
                script.path,
                "--only", speciesId,
                "--top-up",
                "--per-species", String(target + reviewSlack),
                "--catalogue", catalogueURL.path,
                "--staging", stagingDirectory.path
            ] + (worldwide ? ["--worldwide"] : []),
            workingDirectory: root
        )
        return outcome(from: output, speciesId: speciesId)
    }

    // MARK: - Running

    private static func run(
        interpreter: URL,
        arguments: [String],
        workingDirectory: URL
    ) throws -> String {
        let process = Process()
        process.executableURL = interpreter
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw Failure.failed("Couldn't start the fetcher — \(error.localizedDescription)")
        }

        // Read before waiting: a full pipe buffer deadlocks a process that is still printing.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw Failure.failed(lastMeaningfulLine(of: text) ?? "The fetcher exited \(process.terminationStatus).")
        }
        return text
    }

    /// The script's own per-entry line, e.g. `  puha: 4 of 4 staged` or a reason there are none.
    private static func outcome(from output: String, speciesId: String) -> Outcome {
        let line = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.hasPrefix("\(speciesId):") }

        guard let line else {
            return Outcome(staged: 0, message: lastMeaningfulLine(of: output) ?? "Nothing to fetch.")
        }
        let detail = String(line.dropFirst(speciesId.count + 1)).trimmingCharacters(in: .whitespaces)
        let staged = Int(detail.prefix { $0.isNumber }) ?? 0
        return Outcome(staged: staged, message: detail)
    }

    private static func lastMeaningfulLine(of text: String) -> String? {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { !$0.isEmpty }
    }

    // MARK: - Locating

    private static func repositoryRoot(for catalogueURL: URL) -> URL {
        var root = catalogueURL
        for _ in 0..<CatalogueLocator.relativePath.split(separator: "/").count {
            root = root.deletingLastPathComponent()
        }
        return root
    }

    /// First candidate that exists and is new enough to run the script.
    private static func interpreter(under root: URL) -> URL? {
        for candidate in interpreterCandidates {
            let url = candidate.hasPrefix("/")
                ? URL(fileURLWithPath: candidate)
                : root.appending(path: candidate)
            guard FileManager.default.isExecutableFile(atPath: url.path) else { continue }
            if isSupported(url) { return url }
        }
        return nil
    }

    private static func isSupported(_ interpreter: URL) -> Bool {
        let process = Process()
        process.executableURL = interpreter
        process.arguments = ["-c", "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

import Foundation

/// A three-way merge of the catalogue, entry by entry.
///
/// The editor holds the whole catalogue in memory and a save rewrites the whole file, so any
/// write by someone else — `catalogue-tool`, the Python tools under `Tools/`, a `git pull` —
/// turns the next save into a choice between two whole files. That choice lost the five bamboo
/// entries and the Passiflora fill once already.
///
/// Both sides almost never touch the same entry, so "whose file wins" is the wrong question.
/// This answers the right one per entry, against the copy the editor last read (`base`):
///
/// * changed on one side only — take that side;
/// * changed on both to the same thing — no conflict, either will do;
/// * changed on both to different things — a **collision**: the editor's copy is kept, because
///   that is the text in front of the person pressing the button, and the id is reported so
///   they can go and look rather than find out later;
/// * deleted on one side and edited on the other — the edit wins and it is reported. A deletion
///   is cheap to repeat and an entry is expensive to rewrite.
enum CatalogueMerge {
    struct Outcome: Equatable {
        var species: [ForageSpecies]
        /// Ids whose content came from disk — what a plain overwrite would have destroyed.
        var fromDisk: [String] = []
        /// Ids where both sides changed the same entry and the editor's copy was kept.
        var collisions: [String] = []
    }

    static func merge(
        base: [String: ForageSpecies],
        disk: [ForageSpecies],
        editor: [ForageSpecies]
    ) -> Outcome {
        let diskById = Dictionary(uniqueKeysWithValues: disk.map { ($0.id, $0) })
        let editorById = Dictionary(uniqueKeysWithValues: editor.map { ($0.id, $0) })

        var outcome = Outcome(species: [])
        for id in Set(diskById.keys).union(editorById.keys).union(base.keys).sorted() {
            let before = base[id]
            let onDisk = diskById[id]
            let inEditor = editorById[id]

            // Identical on both sides, including both-deleted: nothing to decide.
            if onDisk == inEditor {
                if let kept = onDisk { outcome.species.append(kept) }
                continue
            }

            let diskChanged = onDisk != before
            let editorChanged = inEditor != before

            switch (diskChanged, editorChanged) {
            case (true, false):
                // Only disk moved — including a deletion the editor never saw.
                if let kept = onDisk {
                    outcome.species.append(kept)
                    outcome.fromDisk.append(id)
                }
            case (false, true):
                if let kept = inEditor { outcome.species.append(kept) }
            case (true, true):
                // Both moved, differently. Keep the editor's, unless the editor's move was a
                // deletion — then disk's surviving entry is the one worth more.
                outcome.collisions.append(id)
                if let kept = inEditor ?? onDisk {
                    outcome.species.append(kept)
                    if inEditor == nil { outcome.fromDisk.append(id) }
                }
            case (false, false):
                // Unreachable: equal to base on both sides means equal to each other, which
                // the first check already returned. Kept total rather than fatal.
                if let kept = inEditor ?? onDisk { outcome.species.append(kept) }
            }
        }

        outcome.species.sort(by: ForageSpecies.displayOrder)
        return outcome
    }
}

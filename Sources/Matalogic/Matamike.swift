import Foundation
import SwiftUI

enum MatamikeAction: Hashable, Sendable {
    case addEncore(projectID: UUID, title: String)
}

struct MatamikeReply: Hashable, Sendable {
    var text: String
    var action: MatamikeAction?

    init(_ text: String, action: MatamikeAction? = nil) {
        self.text = text
        self.action = action
    }
}

struct MatamikeMessage: Identifiable, Hashable, Sendable {
    enum Role: Hashable, Sendable { case user, assistant }
    let id: UUID
    var role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

protocol MatamikeProviding: Sendable {
    func reply(
        to message: String,
        project: SongProject?,
        availableProjects: [SongProject]
    ) async -> MatamikeReply
}

struct LocalMatamikeProvider: MatamikeProviding {
    func reply(
        to message: String,
        project: SongProject?,
        availableProjects: [SongProject]
    ) async -> MatamikeReply {
        let text = message.lowercased()
        let projectName = project?.title ?? "deinem Projekt"

        if text.contains("zugabe") || text.contains("encore") {
            if let match = availableProjects.first(where: {
                text.contains($0.title.lowercased())
            }) {
                return MatamikeReply(
                    "Klar — \(match.title) liegt jetzt als Zugabe bereit. 💀🎸",
                    action: .addEncore(projectID: match.id, title: match.title)
                )
            }

            if let current = project, text.contains("diesen song") || text.contains("den song") {
                return MatamikeReply(
                    "Klar — \(current.title) liegt jetzt als Zugabe bereit. 💀🎸",
                    action: .addEncore(projectID: current.id, title: current.title)
                )
            }

            let titles = availableProjects.map(\.title).joined(separator: ", ")
            return MatamikeReply(
                titles.isEmpty
                    ? "Ich habe noch keinen Song, den ich als Zugabe eintragen kann. Importiere zuerst einen Song."
                    : "Welchen Song soll ich als Zugabe eintragen? Ich kenne aktuell: \(titles)."
            )
        }

        if text.contains("logic") || text.contains("import") {
            return MatamikeReply("Für \(projectName): Exportiere aus Logic einen Master als WAV/AIFF und idealerweise eine MIDI-Datei mit Tempo und Markern. Stems können in einen Ordner namens ‘Stems’. Ich erkenne das Paket beim Import automatisch.")
        }
        if text.contains("text") || text.contains("lyrics") || text.contains("songtext") {
            return MatamikeReply("Ich kann TXT, LRC und SRT einlesen. LRC und SRT bringen Zeitinformationen direkt mit; bei einfachem TXT können wir das Timing später an der Waveform setzen oder automatisch schätzen.")
        }
        if text.contains("video") || text.contains("shot") || text.contains("musikvideo") {
            return MatamikeReply("Für ein konsistentes Musikvideo zuerst Referenzfotos für Personen, Outfit und Location sammeln. Danach teilen wir \(projectName) in kurze Shots und schicken nur die freigegebenen Einstellungen an den Video-Provider.")
        }
        if text.contains("bpm") || text.contains("tempo") || text.contains("marker") {
            let bpm = project?.bpm.map { "\(Int($0.rounded())) BPM" } ?? "noch kein Tempo"
            let markers = project?.markers.count ?? 0
            return MatamikeReply("Aktuell sehe ich \(bpm) und \(markers) Marker. Tempo und Logic-Marker kann Matalogic aus einer Standard-MIDI-Datei übernehmen.")
        }
        if text.contains("was fehlt") || text.contains("status") {
            guard let project else { return MatamikeReply("Wähle zuerst einen Song aus oder importiere ein Logic-Paket, dann kann ich den Projektstatus prüfen.") }
            var missing: [String] = []
            if project.masterAudioURL == nil { missing.append("Master-Audio") }
            if project.lyrics.isEmpty { missing.append("Lyrics") }
            if project.references.isEmpty { missing.append("Referenzbilder") }
            if project.shots.isEmpty { missing.append("Storyboard/Shots") }
            return MatamikeReply(
                missing.isEmpty
                    ? "Sieht gut aus: Die wichtigsten Bausteine sind vorhanden. Als Nächstes können wir Shots rendern."
                    : "Als Nächstes fehlen vor allem: \(missing.joined(separator: ", "))."
            )
        }

        return MatamikeReply("Ich bin Matamike 💀🎸. Ich helfe dir bei Logic-Import, Lyrics, Referenzbildern, Storyboard, Video-Rendering und Live-Set. Du kannst mir auch einfach sagen: ‘Pack Midnight Highway als Zugabe rein.’")
    }
}

@MainActor
final class MatamikeChatModel: ObservableObject {
    @Published var messages: [MatamikeMessage] = [
        MatamikeMessage(role: .assistant, text: "¡Hola! Ich bin Matamike. 💀🎸 Was bauen wir an deinem Song?")
    ]
    @Published var input = ""
    @Published var isReplying = false

    private let provider: any MatamikeProviding

    init(provider: any MatamikeProviding = LocalMatamikeProvider()) {
        self.provider = provider
    }

    func send(
        project: SongProject?,
        availableProjects: [SongProject],
        onAction: @escaping (MatamikeAction) -> Void
    ) {
        let outgoing = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty, !isReplying else { return }
        input = ""
        messages.append(MatamikeMessage(role: .user, text: outgoing))
        isReplying = true

        Task {
            let reply = await provider.reply(
                to: outgoing,
                project: project,
                availableProjects: availableProjects
            )
            messages.append(MatamikeMessage(role: .assistant, text: reply.text))
            if let action = reply.action { onAction(action) }
            isReplying = false
        }
    }
}

struct MatamikeChatView: View {
    let project: SongProject?
    let availableProjects: [SongProject]
    var compact = false
    let onAction: (MatamikeAction) -> Void

    @StateObject private var model = MatamikeChatModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                MatamikeAvatar(size: compact ? 46 : 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Matamike").font(compact ? .headline : .title2.bold())
                    Text("Dein kreativer Assistent").foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages) { message in
                        HStack {
                            if message.role == .assistant {
                                Text(message.text)
                                    .padding(10)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                                Spacer(minLength: 24)
                            } else {
                                Spacer(minLength: 24)
                                Text(message.text)
                                    .padding(10)
                                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    if model.isReplying { ProgressView().controlSize(.small) }
                }
                .padding()
            }

            if !compact {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        quickPrompt("Was fehlt noch?")
                        quickPrompt("Diesen Song als Zugabe")
                        quickPrompt("Hilf mir beim Musikvideo")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }

            Divider()
            HStack {
                TextField("Schreibe Matamike …", text: $model.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding()
        }
        .frame(minWidth: compact ? 300 : 420, minHeight: compact ? 420 : 560)
    }

    private func quickPrompt(_ text: String) -> some View {
        Button(text) {
            model.input = text
            send()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func send() {
        model.send(
            project: project,
            availableProjects: availableProjects,
            onAction: onAction
        )
    }
}

struct MatamikeAvatar: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(.quaternary)
            Text("💀")
                .font(.system(size: size * 0.52))
                .offset(y: size * 0.03)
            SombreroShape()
                .fill(.primary)
                .frame(width: size * 0.78, height: size * 0.26)
                .offset(y: -size * 0.29)
            Text("🎸")
                .font(.system(size: size * 0.30))
                .rotationEffect(.degrees(-22))
                .offset(x: size * 0.27, y: size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Matamike, Skelett mit Sombrero und Gitarre")
    }
}

private struct SombreroShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let brim = CGRect(x: 0, y: rect.height * 0.62, width: rect.width, height: rect.height * 0.30)
        path.addEllipse(in: brim)
        path.move(to: CGPoint(x: rect.width * 0.30, y: rect.height * 0.66))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.66),
            control: CGPoint(x: rect.width * 0.50, y: -rect.height * 0.25)
        )
        path.closeSubpath()
        return path
    }
}

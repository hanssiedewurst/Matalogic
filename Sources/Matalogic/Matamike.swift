import Foundation
import SwiftUI

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
    func reply(to message: String, project: SongProject?) async -> String
}

struct LocalMatamikeProvider: MatamikeProviding {
    func reply(to message: String, project: SongProject?) async -> String {
        let text = message.lowercased()
        let projectName = project?.title ?? "deinem Projekt"

        if text.contains("logic") || text.contains("import") {
            return "Für \(projectName): Exportiere aus Logic einen Master als WAV/AIFF und idealerweise eine MIDI-Datei mit Tempo und Markern. Stems können in einen Ordner namens ‘Stems’. Ich erkenne das Paket beim Import automatisch."
        }
        if text.contains("text") || text.contains("lyrics") || text.contains("songtext") {
            return "Ich kann TXT, LRC und SRT einlesen. LRC und SRT bringen Zeitinformationen direkt mit; bei einfachem TXT können wir das Timing später an der Waveform setzen oder automatisch schätzen."
        }
        if text.contains("video") || text.contains("shot") || text.contains("musikvideo") {
            return "Für ein konsistentes Musikvideo zuerst Referenzfotos für Personen, Outfit und Location sammeln. Danach teilen wir \(projectName) in kurze Shots und schicken nur die freigegebenen Einstellungen an den Video-Provider."
        }
        if text.contains("bpm") || text.contains("tempo") || text.contains("marker") {
            let bpm = project?.bpm.map { "\(Int($0.rounded())) BPM" } ?? "noch kein Tempo"
            let markers = project?.markers.count ?? 0
            return "Aktuell sehe ich \(bpm) und \(markers) Marker. Tempo und Logic-Marker kann Matalogic aus einer Standard-MIDI-Datei übernehmen."
        }
        if text.contains("was fehlt") || text.contains("status") {
            guard let project else { return "Wähle zuerst einen Song aus oder importiere ein Logic-Paket, dann kann ich den Projektstatus prüfen." }
            var missing: [String] = []
            if project.masterAudioURL == nil { missing.append("Master-Audio") }
            if project.lyrics.isEmpty { missing.append("Lyrics") }
            if project.references.isEmpty { missing.append("Referenzbilder") }
            if project.shots.isEmpty { missing.append("Storyboard/Shots") }
            return missing.isEmpty ? "Sieht gut aus: Die wichtigsten Bausteine sind vorhanden. Als Nächstes können wir Shots rendern." : "Als Nächstes fehlen vor allem: \(missing.joined(separator: ", "))."
        }

        return "Ich bin Matamike 💀🎸. Ich helfe dir bei Logic-Import, Lyrics, Songstruktur, Referenzbildern, Storyboard und Video-Rendering. Frag mich zum Beispiel: ‘Was fehlt noch?’ oder ‘Wie importiere ich den Song aus Logic?’"
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

    func send(project: SongProject?) {
        let outgoing = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty, !isReplying else { return }
        input = ""
        messages.append(MatamikeMessage(role: .user, text: outgoing))
        isReplying = true

        Task {
            let response = await provider.reply(to: outgoing, project: project)
            messages.append(MatamikeMessage(role: .assistant, text: response))
            isReplying = false
        }
    }
}

struct MatamikeChatView: View {
    let project: SongProject?
    @StateObject private var model = MatamikeChatModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                MatamikeAvatar(size: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Matamike").font(.title2.bold())
                    Text("Matalogic Assistant").foregroundStyle(.secondary)
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
                                Spacer(minLength: 40)
                            } else {
                                Spacer(minLength: 40)
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

            Divider()
            HStack {
                TextField("Frag Matamike …", text: $model.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.send(project: project) }
                Button("Senden") { model.send(project: project) }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 560)
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
        .accessibilityLabel("Matamike, skeleton with sombrero and guitar")
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

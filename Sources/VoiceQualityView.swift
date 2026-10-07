// SPDX-License-Identifier: MIT
import SwiftUI

struct VoiceQualityView: View {
    let reading: VoiceQualityReading

    private var color: Color {
        switch reading.state {
        case .good: return mint
        case .quiet, .pending: return .yellow
        case .unclear, .loud: return .orange
        case .clipping: return .red
        case .inactive, .waiting, .pause: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("LEISE")
                Spacer()
                Text("ZIELBEREICH")
                Spacer()
                Text("LAUT")
            }
            .font(.system(size: 8, weight: .medium)).tracking(0.7)
            .foregroundStyle(.white.opacity(0.4))
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Color.red.frame(width: geometry.size.width * 0.10)
                    Color.orange.frame(width: geometry.size.width * 0.10)
                    Color.yellow.frame(width: geometry.size.width * 0.15)
                    mint.frame(width: geometry.size.width * 0.30)
                    Color.yellow.frame(width: geometry.size.width * 0.15)
                    Color.orange.frame(width: geometry.size.width * 0.10)
                    Color.red.frame(width: geometry.size.width * 0.10)
                }
                .clipShape(Capsule())
                .opacity(reading.position == nil ? 0.28 : 0.75)
                if let position = reading.position {
                    Capsule().fill(.white)
                        .frame(width: 3, height: 16)
                        .shadow(color: .black.opacity(0.8), radius: 2)
                        .position(x: max(2, min(geometry.size.width - 2, geometry.size.width * position)),
                                  y: geometry.size.height / 2)
                }
            }
            .frame(height: 7)
            HStack(spacing: 5) {
                Image(systemName: reading.state == .good ? "checkmark.circle.fill" : "waveform")
                Text(reading.state.label)
            }
            .font(.system(size: 10, weight: .medium)).foregroundStyle(color)
            .lineLimit(1)
        }
        .frame(width: 250)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stimm-Check")
        .accessibilityValue(reading.state.label)
        .help("Der Zeiger zeigt den Mikrofonpegel: links leise, Mitte Zielbereich, rechts laut. Grün im Hinweis bedeutet zusätzlich eine aktuelle Übereinstimmung mit deinem Text. Pegelgrenzen sind Näherungswerte. Kein objektiver Aussprachetest; Akzent, Störgeräusche und Erkennungsverzögerung können den Hinweis beeinflussen.")
    }
}

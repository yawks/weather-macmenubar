import SwiftUI

struct MoonPhaseView: View {
    let info: MoonPhaseInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phase de lune")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 20) {
                VStack(spacing: 6) {
                    RealisticMoonDisk(phase: info.phase)
                        .frame(width: 84, height: 84)

                    Text(info.phaseName)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    MoonTimeBlock(label: "Lever de lune",  date: info.moonrise)
                    MoonTimeBlock(label: "Coucher de lune", date: info.moonset)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

private struct MoonTimeBlock: View {
    let label: String
    let date: Date?

    private var isNextDay: Bool {
        guard let d = date else { return false }
        return !Calendar.current.isDateInToday(d)
    }

    private var timeText: String {
        guard let d = date else { return "--:--" }
        return d.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(timeText)
                    .font(.title3.bold())
                if isNextDay {
                    Text("dem.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - RealisticMoonDisk

struct RealisticMoonDisk: View {
    let phase: Double  // 0 = nouvelle lune, 0.5 = pleine lune

    var body: some View {
        Canvas { ctx, size in
            let r  = min(size.width, size.height) / 2 - 1
            let cx = size.width  / 2
            let cy = size.height / 2
            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

            // 1. Fond noir (espace)
            ctx.fill(Path(ellipseIn: rect), with: .color(.black))

            // 2. Sphère lunaire — gradient radial légèrement décentré pour l'effet 3D
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(white: 0.92), location: 0.00),
                        .init(color: Color(white: 0.74), location: 0.50),
                        .init(color: Color(white: 0.46), location: 1.00),
                    ]),
                    center: CGPoint(x: cx - r * 0.05, y: cy - r * 0.12),
                    startRadius: 0,
                    endRadius: r * 1.05
                )
            )

            // 3. Mares et cratères pour la texture de surface
            //    (dx, dy, rayon fraction, opacité)
            let features: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (-0.05, -0.22, 0.28, 0.09),   // mare Imbrium
                ( 0.18,  0.18, 0.20, 0.07),   // mare Tranquillitatis
                (-0.28,  0.24, 0.16, 0.07),   // mare Nubium
                ( 0.30, -0.32, 0.08, 0.22),   // crater Tycho
                (-0.38, -0.08, 0.06, 0.18),   // crater Copernicus
                ( 0.08,  0.42, 0.05, 0.14),   // petit cratère
                (-0.12, -0.42, 0.04, 0.16),   // petit cratère
            ]
            for (dx, dy, rf, opacity) in features {
                let fx = cx + r * dx
                let fy = cy + r * dy
                let fr = r * rf
                ctx.fill(
                    Path(ellipseIn: CGRect(x: fx - fr, y: fy - fr, width: fr * 2, height: fr * 2)),
                    with: .color(Color(white: 0.28).opacity(opacity))
                )
            }

            // 4. Ombre de phase par-dessus la sphère
            let isNewMoon  = phase < 0.02 || phase > 0.98
            let isFullMoon = abs(phase - 0.5) < 0.02

            if isNewMoon {
                // Plein noir avec légère lueur terrestre
                ctx.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.91)))
            } else if !isFullMoon {
                let shadow = shadowPath(phase: phase, cx: cx, cy: cy, r: r)
                // Légère transparence = simuler la lumière cendrée (earthshine)
                ctx.fill(shadow, with: .color(Color(red: 0.04, green: 0.06, blue: 0.14).opacity(0.87)))
            }
        }
        .clipShape(Circle())
        .shadow(color: Color.white.opacity(0.18), radius: 6)
    }

    // Construit le chemin de la zone d'ombre
    private func shadowPath(phase: Double, cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var path = Path()
        let steps = 80
        let waxing = phase < 0.5
        // norm : 0 = nouvelle/pleine lune, 0.5 = quartier, 1 = pleine/nouvelle lune
        let norm = waxing ? (phase / 0.5) : ((phase - 0.5) / 0.5)
        // Rayon x du terminateur (cosinus pour avoir +r→0→-r au fil des phases)
        let tXR = r * cos(norm * .pi)

        path.move(to: CGPoint(x: cx, y: cy - r))

        if waxing {
            // Demi-cercle gauche : haut → gauche → bas (sens horaire visuel)
            for i in 1...steps {
                let a = -.pi / 2 - .pi * Double(i) / Double(steps)
                path.addLine(to: CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)))
            }
        } else {
            // Demi-cercle droit : haut → droite → bas
            for i in 1...steps {
                let a = -.pi / 2 + .pi * Double(i) / Double(steps)
                path.addLine(to: CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)))
            }
        }

        // Terminateur : bas → haut (ellipse verticale)
        for i in 0...steps {
            let a = .pi / 2 - .pi * Double(i) / Double(steps)
            path.addLine(to: CGPoint(x: cx + tXR * cos(a), y: cy + r * sin(a)))
        }

        path.closeSubpath()
        return path
    }
}

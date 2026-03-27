import SwiftUI
import PosterKit

struct PiDayPosterView: View {
    let entry: PosterEntry
    
    var body: some View {
        ZStack {
            // Background: Liquid Glass gradient based on the theme
            entry.palette.background
                .ignoresSafeArea()
            
            // Subtle Pi digit canvas in the background
            PiPosterCanvasView(entry: entry)
                .opacity(0.15)
                .ignoresSafeArea()
            
            // Primary foreground: today's date highlighted in Pi
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text(entry.date.formatted(.dateTime.day().month().year()))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.palette.ink)
                    
                    if let match = entry.match {
                        Text("is at digit \(match.storedPosition.formatted())")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(entry.palette.mutedInk)
                    } else {
                        Text("not found in first 5B digits")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(entry.palette.mutedInk)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(entry.palette.border, lineWidth: 1)
                )
                
                Spacer()
                    .frame(height: 100) // Leave space for Lock Screen clock and widgets
            }
            .padding()
        }
    }
}

struct PiPosterCanvasView: View {
    let entry: PosterEntry
    
    var body: some View {
        // Simplified digit wall for the wallpaper background
        let pi = "3.141592653589793238462643383279502884197169399375105820974944592"
        let digits = String(repeating: pi, count: 20)
        
        ScrollView(.vertical, showsIndicators: false) {
            Text(digits)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .kerning(4)
                .lineSpacing(12)
                .foregroundStyle(entry.palette.ink)
                .multilineTextAlignment(.center)
        }
        .disabled(true) // Static wallpaper
    }
}

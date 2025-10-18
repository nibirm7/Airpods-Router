//
//  GlassModifier.swift
//  AirPodsRouter
//
//  Created by Abdullah Khan on 2025-10-17.
//  Updated with Liquid Glass aesthetic - macOS Tahoe 26 inspired
//

import SwiftUI

/// Premium Liquid Glass effect following Apple's 2025 design language
/// Features: adaptive opacity, specular highlights, responsive lensing, dynamic depth
struct GlassEffect: ViewModifier {
    var cornerRadius: CGFloat = 14
    var opacity: Double = 0.18
    var blur: CGFloat = 22
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Adaptive tint based on system appearance
    private var adaptiveTint: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }
    
    // Specular highlight intensity shifts with environment
    private var specularIntensity: Double {
        colorScheme == .dark ? 0.35 : 0.25
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base ultra-thin material layer - adaptive foundation
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)
                    
                    // Adaptive color tint for environmental harmony
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(adaptiveTint)
                    
                    // Primary diagonal gradient - liquid glass shimmer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(specularIntensity),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: blur)
                    
                    // Specular highlight layer - responsive lensing effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 1,
                                endRadius: 120
                            )
                        )
                        .blur(radius: 12)
                    
                    // Angular gradient rim - light refraction on edges
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.7)
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            lineWidth: 1.2
                        )
                        .opacity(0.8)
                    
                    // Inner soft border - depth layering
                    RoundedRectangle(cornerRadius: cornerRadius - 0.5)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                        .padding(0.5)
                }
            )
            // Multi-layer shadow for physical depth
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.04), radius: 32, x: 0, y: 16)
    }
}

extension View {
    /// Apply premium Liquid Glass effect with adaptive depth and environmental harmony
    /// - Parameters:
    ///   - cornerRadius: Corner curvature (default: 14)
    ///   - opacity: Base material opacity (default: 0.18)
    ///   - blur: Gradient blur intensity (default: 22)
    func glassEffect(
        cornerRadius: CGFloat = 14,
        opacity: Double = 0.18,
        blur: CGFloat = 22
    ) -> some View {
        modifier(GlassEffect(cornerRadius: cornerRadius, opacity: opacity, blur: blur))
    }
}

//
//  CustomRoundedStyle.swift
//  Radium
//
//  Created by Ethan John Lagera on 7/16/26.
//
//  Ported from TrackCount

import SwiftUI

/// A rounded style with a thin material background and padding.
struct AdaptiveBackgroundModifier<S: Shape>: ViewModifier {
    let isInteractive: Bool
    let tint: Color?
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shape: S
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if isInteractive {
                content
                    .glassEffect(.regular.interactive().tint(tint), in: shape)
            } else {
                content
                    .glassEffect(.regular.tint(tint), in: shape)
            }
        } else {
            content
                .background(
                    shape
                        .foregroundStyle(.thinMaterial)
                        .backgroundStyle(.tint.opacity(0.25))
                )
        }
    }
}

/// Liquid Glass / Tinted Button Background
struct AdaptiveGlassButtonModifier<S: Shape>: ViewModifier {
    let prominent: Bool
    let tint: Color?
    let shape: S
    
    func body(content: Content) -> some View {
        let tintColor = tint != nil ? tint : prominent ? .blue : .primary
        if #available(iOS 26.0, *) {
            content
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .glassEffect(
                    .regular
                        .tint(tintColor)
                        .interactive(),
                    in: shape
                )
        } else {
            if prominent {
                content
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .buttonStyle(.borderedProminent)
                    .tint(tintColor)
            } else {
                content
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .buttonStyle(.bordered)
                    .tint(tintColor)
            }
        }
    }
}

// Extend View for easier usage
extension View {
    /// A rounded style with a thin material background and padding.
    func adaptiveBackground(
        interactive: Bool = false,
        tint: Color? = nil,
        padding: CGFloat = 12,
        cornerRadius: CGFloat = 8,
        in shape: some Shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    ) -> some View {
        self.modifier(AdaptiveBackgroundModifier(isInteractive: interactive, tint: tint, padding: padding, cornerRadius: cornerRadius, shape: shape))
    }
    
    /// A button style with a liquid glass / tinted background.
    func adaptiveGlassButton(
        prominent: Bool = false,
        tint: Color? = nil,
        in shape: some Shape = Capsule()
    ) -> some View {
        self.modifier(AdaptiveGlassButtonModifier(prominent: prominent, tint: tint, shape: shape))
    }
}

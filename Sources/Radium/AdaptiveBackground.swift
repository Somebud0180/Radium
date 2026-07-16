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
    var isInteractive: Bool
    var tint: Color?
    var padding: CGFloat
    var cornerRadius: CGFloat
    var shape: S
    
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

// Liquid Glass / Tinted (Conditional) Button Modifier
struct AdaptiveGlassConditionalButtonModifier<S: Shape>: ViewModifier {
    let condition: Bool
    let tint: Color
    let shape: S
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                    .tint(condition ? tint.opacity(0.9) : .secondary)
                    .interactive()
                    ,in: shape
                )
        } else {
            content
                .background(condition ? tint.opacity(0.9) : .secondary, in: shape)
        }
    }
}

/// Liquid Glass / Tinted Button Background
struct AdaptiveGlassButtonModifier<S: Shape>: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let tintStrength: CGFloat
    let tint: Color
    let shape: S
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let tintColor = colorScheme == .dark ? tint.opacity(0.2) : tint.opacity(tintStrength)
            if tintStrength == 0.0 {
                content
                    .glassEffect(
                        .regular
                        .interactive()
                        ,in: shape
                    )
            } else {
                content
                    .glassEffect(
                        .regular
                        .tint(tintColor)
                        .interactive()
                        ,in: shape
                    )
            }
        } else {
            let tintColor = colorScheme == .dark ? tint.opacity(0.2) : tint.opacity(tintStrength)
            content
                .background(tintColor, in: shape)
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
    
    /// A button style with a liquid glass / tinted background that changes based on a condition.
    func adaptiveGlassConditionalButton(
        condition: Bool,
        tint: Color,
        in shape: some Shape = Capsule()
    ) -> some View {
        self.modifier(AdaptiveGlassConditionalButtonModifier(condition: condition, tint: tint, shape: shape))
    }
    
    /// A button style with a liquid glass / tinted background.
    func adaptiveGlassButton(
        tintStrength: CGFloat = 0.8,
        tintColor: Color = Color.white,
        in shape: some Shape = Capsule()
    ) -> some View {
        self.modifier(AdaptiveGlassButtonModifier(tintStrength: tintStrength, tint: tintColor, shape: shape))
    }
}

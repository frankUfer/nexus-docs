//
//  Binding.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 28.03.25.
//

import SwiftUI

// MARK: - Lift: Optionales Binding -> nicht-optional mit Default (lazy)
extension Binding {
    /// Hebt ein Binding auf `Value?` auf ein nicht-optionalens Binding an.
    /// Der Default wird lazy erzeugt (z. B. für `UUID()`, `Date()`).
    init(_ source: Binding<Value?>, default defaultValue: @autoclosure @escaping () -> Value) {
        self.init(
            get: { source.wrappedValue ?? defaultValue() },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}

// MARK: - Teil-Bindings (Sub-Bindings)
extension Binding {
    /// Unter-Binding auf eine NICHT-optionale Property.
    func subBinding<T>(_ keyPath: WritableKeyPath<Value, T>) -> Binding<T> {
        Binding<T>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    /// Unter-Binding auf eine optionale Property – liefert Binding<T?>
    /// Praktisch für Picker, die direkt mit Optionalen arbeiten (.tag(Optional(...))).
    func subBindingOpt<T>(_ keyPath: WritableKeyPath<Value, T?>) -> Binding<T?> {
        Binding<T?>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    /// Unter-Binding auf eine optionale Property mit lazy Default (Binding<T>).
    /// Gut für Textfelder/Slider, die immer einen Wert erwarten.
    func subBinding<T>(
        _ keyPath: WritableKeyPath<Value, T?>,
        default defaultValue: @autoclosure @escaping () -> T
    ) -> Binding<T> {
        Binding<T>(
            get: { self.wrappedValue[keyPath: keyPath] ?? defaultValue() },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Convenience: onEdit-Hook (setzt z. B. Dirty-Flag)
extension Binding {
    /// Ruft `handler()` auf, sobald in dieses Binding geschrieben wird.
    func onEdit(_ handler: @escaping () -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler()
            }
        )
    }
}

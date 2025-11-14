//
//  ContentView.swift
//  ElixirCounter
//
//  Created by Thomas Noone on 2025-11-14.
//

import SwiftUI

struct ContentView: View {
    // Elixir state
    @State private var elixir: Int = 5
    private let elixirCap = 10
    
    // Phases
    private enum Phase {
        case regulation    // 3:00 -> 0, 1x to 2x at 1:00
        case overtime      // 2:00 -> 0, 2x to 3x at 1:00
    }
    @State private var phase: Phase = .regulation
    
    // Timer state (in seconds)
    @State private var remainingSeconds: Int = 180 // regulation starts at 3 minutes
    
    // Run control
    @State private var isRunning: Bool = false
    @State private var tickerTask: Task<Void, Never>? = nil
    
    // UI formatting helpers
    private var phaseDuration: Int {
        switch phase {
        case .regulation: return 180
        case .overtime: return 120
        }
    }
    
    private var isAfterFirstMinute: Bool {
        // For both phases, threshold is 60s remaining
        remainingSeconds <= 60
    }
    
    private var elixirMultiplier: Double {
        switch phase {
        case .regulation:
            return isAfterFirstMinute ? 2.0 : 1.0
        case .overtime:
            return isAfterFirstMinute ? 3.0 : 2.0
        }
    }
    
    private var currentElixirInterval: TimeInterval {
        // Base 2.8s divided by multiplier
        2.8 / elixirMultiplier
    }
    
    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var phaseTitle: String {
        switch phase {
        case .regulation:
            return isAfterFirstMinute ? "Double Elixir" : "Single Elixir"
        case .overtime:
            return isAfterFirstMinute ? "Triple Elixir (Overtime)" : "Double Elixir (Overtime)"
        }
    }
    
    private var phaseColor: Color {
        switch phase {
        case .regulation:
            return isAfterFirstMinute ? .purple : .blue
        case .overtime:
            return .red
        }
    }
    
    // Max allowed spend is current elixir + 2, capped by the largest button (9)
    private var maxSpend: Int {
        min(elixir + 2, 9)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Clash Royale Elixir Counter")
                .font(.title2)
                .bold()
            
            // Timer and phase
            VStack(spacing: 8) {
                Text(formattedTime)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(phase == .overtime ? .red : .primary)
                
                Text(phaseTitle)
                    .font(.headline)
                    .foregroundStyle(phaseColor)
            }
            
            // Elixir display
            VStack(spacing: 8) {
                Text("Elixir")
                    .font(.headline)
                Text("\(elixir)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(elixir == elixirCap ? .green : .primary)
                
                // Progress bar to 10
                GeometryReader { geo in
                    let width = geo.size.width
                    let progress = CGFloat(elixir) / CGFloat(elixirCap)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 10)
                            .fill(phaseColor.opacity(0.7))
                            .frame(width: width * progress)
                            .animation(.easeInOut(duration: 0.2), value: elixir)
                    }
                }
                .frame(height: 18)
            }
            .padding(.horizontal)
            
            // Controls
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button(isRunning ? "Reset" : "Start") {
                        if isRunning {
                            resetMatch()
                        } else {
                            startMatch()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    if isRunning {
                        Button("Pause") {
                            pauseMatch()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button("Resume") {
                            resumeMatch()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(remainingSeconds == 180 && elixir == 5 && phase == .regulation) // nothing to resume if never started
                    }
                }
                
                // Subtract buttons 1-9 with overdraw protection (allow up to elixir + 2)
                VStack(spacing: 12) {
                    Text("Subtract Elixir (max spend: \(maxSpend))")
                        .font(.headline)
                    let rows = [
                        [1, 2, 3],
                        [4, 5, 6],
                        [7, 8, 9]
                    ]
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { value in
                                Button("-\(value)") {
                                    subtractElixir(value)
                                }
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .disabled(elixir == 0 || value > maxSpend)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onDisappear {
            // Ensure tasks are cancelled if view goes away
            tickerTask?.cancel()
            tickerTask = nil
        }
    }
    
    // MARK: - Control
    
    private func startMatch() {
        // Reset to known starting state and run
        elixir = 6
        phase = .regulation
        remainingSeconds = 180
        isRunning = true
        startTicker()
    }
    
    private func resetMatch() {
        isRunning = false
        tickerTask?.cancel()
        tickerTask = nil
        elixir = 6
        phase = .regulation
        remainingSeconds = 180
    }
    
    private func pauseMatch() {
        isRunning = false
        tickerTask?.cancel()
        tickerTask = nil
    }
    
    private func resumeMatch() {
        guard remainingSeconds > 0 else { return }
        isRunning = true
        startTicker()
    }
    
    private func subtractElixir(_ amount: Int) {
        guard amount > 0 else { return }
        // Enforce the overdraw rule (can spend at most elixir + 2)
        let allowed = min(amount, elixir + 2)
        elixir = max(0, elixir - allowed)
    }
    
    // MARK: - Ticker Task
    
    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { @MainActor in
            // Tick the match timer every 0.1 seconds for smooth UI,
            // and accumulate time toward the elixir increment interval.
            var lastUpdate = Date()
            var elixirAccumulator: TimeInterval = 0
            var matchAccumulator: TimeInterval = 0
            
            while !Task.isCancelled, isRunning {
                guard remainingSeconds > 0 else {
                    // Transition or stop when this phase ends
                    handlePhaseCompletion()
                    // If we transitioned to a new phase and are still running, continue loop
                    if !isRunning { break }
                    // Reset timing anchors for next phase
                    lastUpdate = Date()
                    elixirAccumulator = 0
                    matchAccumulator = 0
                    continue
                }
                
                // Sleep a short time to drive updates
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
                // Calculate delta time in seconds
                let now = Date()
                let dt = now.timeIntervalSince(lastUpdate)
                lastUpdate = now
                
                // Update match timer
                matchAccumulator += dt
                while matchAccumulator >= 1.0 && remainingSeconds > 0 {
                    remainingSeconds -= 1
                    matchAccumulator -= 1.0
                }
                
                // Update elixir gain
                if elixir < elixirCap {
                    elixirAccumulator += dt
                    let interval = currentElixirInterval
                    while elixirAccumulator >= interval && elixir < elixirCap {
                        elixir += 1
                        elixirAccumulator -= interval
                    }
                } else {
                    // If capped, reset accumulator so we don't "store up" increments
                    elixirAccumulator = 0
                }
            }
        }
    }
    
    @MainActor
    private func handlePhaseCompletion() {
        switch phase {
        case .regulation:
            // Enter overtime: 2 minutes, keep running, red theme
            phase = .overtime
            remainingSeconds = 120
            // keep isRunning as-is to continue
        case .overtime:
            // Match over
            isRunning = false
        }
    }
}

#Preview {
    ContentView()
}

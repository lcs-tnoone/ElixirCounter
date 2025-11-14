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
    
    // Match timer state (in seconds)
    @State private var remainingSeconds: Int = 180 // 3 minutes
    private let doubleElixirThreshold: Int = 60 // when remaining <= 60s
    
    // Run control
    @State private var isRunning: Bool = false
    @State private var tickerTask: Task<Void, Never>? = nil
    
    // UI formatting helpers
    private var isDoubleElixir: Bool {
        remainingSeconds <= doubleElixirThreshold
    }
    
    private var currentElixirInterval: TimeInterval {
        isDoubleElixir ? 1.4 : 2.8
    }
    
    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Clash Royale Elixir Counter")
                .font(.title2)
                .bold()
            
            // Timer and phase
            VStack(spacing: 8) {
                Text(formattedTime)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text(isDoubleElixir ? "Double Elixir" : "Single Elixir")
                    .font(.headline)
                    .foregroundStyle(isDoubleElixir ? .purple : .secondary)
            }
            
            // Elixir display
            VStack(spacing: 8) {
                Text("Elixir")
                    .font(.headline)
                Text("\(elixir)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(elixir == elixirCap ? .green : .primary)
                
                // Simple progress bar to 10
                GeometryReader { geo in
                    let width = geo.size.width
                    let progress = CGFloat(elixir) / CGFloat(elixirCap)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDoubleElixir ? Color.purple.opacity(0.7) : Color.blue.opacity(0.7))
                            .frame(width: width * progress)
                            .animation(.easeInOut(duration: 0.2), value: elixir)
                    }
                }
                .frame(height: 16)
            }
            .padding(.horizontal)
            
            // Controls
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button(isRunning ? "Reset" : "Start") {
                        if isRunning {
                            resetMatch()
                        } else {
                            startMatch()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if isRunning {
                        Button("Pause") {
                            pauseMatch()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Resume") {
                            resumeMatch()
                        }
                        .buttonStyle(.bordered)
                        .disabled(remainingSeconds == 180 && elixir == 5) // nothing to resume if never started
                    }
                }
                
                // Subtract buttons 1-9
                VStack(spacing: 10) {
                    Text("Subtract Elixir")
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
                                .buttonStyle(.bordered)
                                .disabled(elixir == 0)
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
        elixir = 5
        remainingSeconds = 180
        isRunning = true
        startTicker()
    }
    
    private func resetMatch() {
        isRunning = false
        tickerTask?.cancel()
        tickerTask = nil
        elixir = 5
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
        elixir = max(0, elixir - amount)
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
            
            while !Task.isCancelled, isRunning, remainingSeconds > 0 {
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
            
            // End of match or cancelled
            if remainingSeconds <= 0 {
                isRunning = false
            }
        }
    }
}

#Preview {
    ContentView()
}

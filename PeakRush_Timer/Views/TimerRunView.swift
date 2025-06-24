import SwiftUI
import UserNotifications
import AVFoundation

struct TimerRunView: View {
    @ObservedObject var viewModel: TimerRunViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
                
            VStack(spacing: 30) {
                HStack {
                    Button {
                        viewModel.stopTimer()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                            Text("Back")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                    }
                        
                    Spacer()
                }
                .overlay(
                    Text("PeakRush")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                    
                HStack(spacing: 12) {
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat")
                                .font(.title3)
                                .foregroundStyle(.green)
                                .frame(width: 20, height: 20)
                            
                            Text("SETS")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 25)
                            
                        Text("\(viewModel.timerModel.sets)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(height: 24)
                    }
                    .frame(width: 120, height: 70)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 20, height: 20)
                                
                            Text("INTERVAL")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 25)
                            
                        Text("\(String(format: "%02d", viewModel.timerModel.minutes)):\(String(format: "%02d", viewModel.timerModel.seconds))")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(height: 24)
                    }
                    .frame(width: 120, height: 70)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 20, height: 20)
                                
                            Text("Total")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 25)
                            
                        Text("\(String(format: "%02d", viewModel.timerModel.totalWorkoutMinutes)):\(String(format: "%02d", viewModel.timerModel.totalWorkoutSeconds))")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(height: 24)
                    }
                    .frame(width: 120, height: 70)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 16) {
                    Text(viewModel.intensityText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.intensityColor)
                        .multilineTextAlignment(.center)
                    
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray), lineWidth: 8)
                            .frame(width: 250, height: 250)
                        
                        Circle()
                            .stroke(viewModel.circleColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 250, height: 250)
                        
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.timerModel.isCurrentIntensityLow ? "figure.walk" : "figure.run")
                                .font(.largeTitle)
                                .foregroundStyle(viewModel.iconColor)
                            
                            Text("\(String(format: "%02d", viewModel.timerModel.currentMinutes)):\(String(format: "%02d", viewModel.timerModel.currentSeconds))")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                            
                            Text("Set \(viewModel.timerModel.currentSet)/\(viewModel.timerModel.sets)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.black)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                    
                Spacer()
                    
                VStack(spacing: 12) {
                    if !viewModel.timerModel.isTimerCompleted {
                        Button {
                            if viewModel.timerModel.isTimerRunning {
                                viewModel.pauseTimer()
                            } else {
                                viewModel.startTimer()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.timerModel.isTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                
                                Text(viewModel.timerModel.isTimerRunning ? "Pause Timer" : "Start Timer")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: viewModel.timerModel.isTimerRunning ? [.blue, .blue] : [.green, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: (viewModel.timerModel.isTimerRunning ? Color.orange : Color.green).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Button {
                            viewModel.resetTimer()
                        } label : {
                            Text("Reset Timer")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            viewModel.resetTimer()
                        } label : {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                
                                Text("Start Again")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                        
                    Button {
                        viewModel.stopTimer()
                        dismiss()
                    } label: {
                        Text("Modify Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.initializeTimer()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
    }
}

#Preview {
    TimerRunView(viewModel: TimerRunViewModel(timerModel: TimerModel(minutes: 0, seconds: 10, sets: 2, isLowIntensity: true)))
}

import SwiftUI

struct TimerConfigView: View {
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var sets = 0
    @State private var isLowIntensity = true
    
    private var isConfigurationValid: Bool {
        return sets > 0 && (minutes > 0 || seconds > 0)
    }
    
    private var totalWorkoutDuration: Int {
        return (minutes * 60 + seconds) * 2 * sets
    }

    private var totalMinutes: Int {
        return totalWorkoutDuration / 60
    }

    private var totalSeconds: Int {
        return totalWorkoutDuration % 60
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {

                VStack(spacing: 4) {
                    Text("PeakRush")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Interval Timer")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
                
//                HStack(spacing: 12) {
//                    VStack(spacing: 8) {
//                        HStack(spacing: 6) {
//                            Image(systemName: "timer")
//                                .font(.title3)
//                                .foregroundStyle(.blue)
//                            
//                            Text("INTERVAL")
//                                .font(.headline)
//                                .foregroundStyle(.secondary)
//                                .textCase(.uppercase)
//                                .tracking(0.5)
//                        }
//                        
//                        Text("\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))")
//                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
//                            .foregroundStyle(.primary)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 16)
//                    .background(Color(.systemBackground))
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
//                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
//                    
//                    VStack(spacing: 8) {
//                        HStack(spacing: 6) {
//                            Image(systemName: "repeat")
//                                .font(.title3)
//                                .foregroundStyle(.green)
//                            
//                            Text("SETS")
//                                .font(.headline)
//                                .foregroundStyle(.secondary)
//                                .textCase(.uppercase)
//                                .tracking(0.5)
//                        }
//                        
//                        Text("\(sets)")
//                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
//                            .foregroundStyle(.primary)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 16)
//                    .background(Color(.systemBackground))
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
//                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
//                }
//                .padding(.horizontal, 20)
                
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                
                                Text("Interval")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            
                            HStack(spacing: 16) {
                                VStack(spacing: 6) {
                                    Picker("Minutes", selection: $minutes) {
                                        ForEach(0..<60, id: \.self) { minute in
                                            Text("\(minute)")
                                                .font(.system(size: 20))
                                                .tag(minute)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 60, height: 100)
                                    .clipped()
                                    
                                    Text("MIN")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(spacing: 6) {
                                    Picker("Seconds", selection: $seconds) {
                                        ForEach(0..<60, id: \.self) { second in
                                            Text("\(second)")
                                                .font(.system(size: 20))
                                                .tag(second)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 60, height: 100)
                                    .clipped()
                                    
                                    Text("SEC")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "repeat")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                
                                Text("Sets")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            
                            VStack(spacing: 6) {
                                Picker("Sets", selection: $sets) {
                                    ForEach(0..<30, id: \.self) { set in
                                        Text("\(set)")
                                            .font(.system(size: 20))
                                            .tag(set)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60, height: 100)
                                .clipped()
                                
                                Text("SETS")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                HStack {

                    Text("Start with Low Intensity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isLowIntensity)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Workout Duration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text("A Set consists of 1 Low & 1 High Intensity phase")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(String(format: "%02d", totalMinutes)):\(String(format: "%02d", totalSeconds))")
                        .font(.system(size: 21, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                NavigationLink(destination: TimerRunView(
                    minutes: minutes,
                    seconds: seconds,
                    sets: sets,
                    isLowIntensity: isLowIntensity,
                    totalWorkoutMinutes: totalMinutes,
                    totalWorkoutSeconds: totalSeconds
                )) {
                    HStack(spacing: 8) {
                        Text("Let's Go")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: isConfigurationValid ? [.blue, .cyan] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: isConfigurationValid ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(!isConfigurationValid)
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    TimerConfigView()
}

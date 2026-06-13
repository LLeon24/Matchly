//
//  ProgramsMapView.swift
//  Matchly
//
//  Created on 11/16/25.
//

import SwiftUI
import MapKit
import CoreLocation
import OSLog

private let programsMapLogger = Logger(subsystem: "com.matchly", category: "ProgramsMapView")

struct ProgramsMapView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of USA
            span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
        )
    )
    @State private var selectedProgram: Program?
    @State private var showProgramDetail = false
    @State private var mapType: MapStyle = .standard
    
    private var programAnnotations: [ProgramAnnotation] {
        // Show all programs - use fallback coordinates if city/state missing
        dataManager.programs.map { program in
            ProgramAnnotation(program: program)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(position: $cameraPosition) {
                    ForEach(programAnnotations) { annotation in
                        Annotation("", coordinate: annotation.coordinate) {
                            ProgramMapPin(
                                program: annotation.program,
                                isSelected: selectedProgram?.id == annotation.program.id,
                                onTap: {
                                    selectedProgram = annotation.program
                                    withAnimation {
                                        cameraPosition = .region(
                                            MKCoordinateRegion(
                                                center: annotation.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
                                            )
                                        )
                                    }
                                }
                            )
                        }
                    }
                }
                .mapStyle(mapType)
                .ignoresSafeArea()
                .padding(.bottom, 90) // Space for custom tab bar
                
                // Program detail card at bottom - positioned above tab bar
                if let program = selectedProgram {
                    VStack {
                        Spacer()
                        ProgramMapCard(program: program) {
                            showProgramDetail = true
                        } onDismiss: {
                            selectedProgram = nil
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 90) // Space above tab bar
                    }
                }
                
                // Map type selector
                VStack {
                    HStack {
                        Spacer()
                        Menu {
                            Button(action: { mapType = .standard }) {
                                Label("Standard", systemImage: "map")
                            }
                            Button(action: { mapType = .hybrid }) {
                                Label("Hybrid", systemImage: "location")
                            }
                        } label: {
                            Image(systemName: "map")
                                .font(.arial(size: 18))
                                .foregroundColor(AppColors.primaryBlue)
                                .padding(10)
                                .glassCircleButtonStyle()
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle("Programs Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        fitAllPrograms()
                    }) {
                        Image(systemName: "location.magnifyingglass")
                            .foregroundColor(AppColors.primaryBlue)
                    }
                }
            }
            .sheet(isPresented: $showProgramDetail) {
                if let program = selectedProgram {
                    NavigationView {
                        ProgramEntryView(program: program)
                    }
                }
            }
            .onAppear {
                if programAnnotations.isEmpty {
                    // Default to USA center
                } else {
                    fitAllPrograms()
                }
            }
        }
    }
    
    private func fitAllPrograms() {
        guard !programAnnotations.isEmpty else { return }
        
        let coordinates = programAnnotations.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 39.8283
        let maxLat = coordinates.map { $0.latitude }.max() ?? 39.8283
        let minLon = coordinates.map { $0.longitude }.min() ?? -98.5795
        let maxLon = coordinates.map { $0.longitude }.max() ?? -98.5795
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let latDelta = max((maxLat - minLat) * 1.3, 5.0)
        let lonDelta = max((maxLon - minLon) * 1.3, 5.0)
        
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                )
            )
        }
    }
}

struct ProgramAnnotation: Identifiable {
    let id: String
    let program: Program
    let coordinate: CLLocationCoordinate2D
    
    init(program: Program) {
        self.id = program.id
        self.program = program
        // Use address if available, otherwise fall back to city/state, then state center, then USA center
        if let address = program.address, !address.isEmpty {
            self.coordinate = GeocodingHelper.coordinate(for: address, city: program.city, state: program.state)
        } else if !program.city.isEmpty && !program.state.isEmpty {
            self.coordinate = GeocodingHelper.coordinate(for: program.city, state: program.state)
        } else if !program.state.isEmpty {
            // If only state is available, use state center
            self.coordinate = GeocodingHelper.coordinate(for: program.state)
        } else {
            // Fallback to center of USA if no location data
            self.coordinate = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
        }
    }
}

struct ProgramMapPin: View {
    let program: Program
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main pin circle
                Circle()
                    .fill(isSelected ? AppColors.accentPink : AppColors.primaryBlue)
                    .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Icon inside pin - star if signaled, mappin otherwise
                if program.signalType != .none {
                    // Signal indicator - star inside the pin
                    Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                        .foregroundColor(.white)
                        .font(.arial(size: isSelected ? 18 : 16, weight: .bold))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                } else {
                    // Regular pin icon when not signaled
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)
                        .font(.arial(size: isSelected ? 20 : 18, weight: .bold))
                }
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct ProgramMapCard: View {
    let program: Program
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // Hospital name with signal indicator
                            HStack(alignment: .top, spacing: 6) {
                                Text(HospitalNameFormatter.format(program.hospital))
                                    .font(.arial(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Signal indicator - subtle
                                if program.signalType != .none {
                                    Image(systemName: program.signalType == .gold ? "star.fill" : "star")
                                        .font(.arial(size: 14))
                                        .foregroundColor(program.signalType == .gold ? .yellow : .gray)
                                        .padding(.top, 2) // Align with first line of text
                                }
                            }
                            
                            if let address = program.address, !address.isEmpty {
                                Text(address)
                                    .font(.arial(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("\(program.city), \(program.state)")
                                    .font(.arial(size: 12))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(program.city), \(program.state)")
                                    .font(.arial(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.arial(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        // Specialty badge - matching style from other views
                        if !program.specialty.isEmpty {
                            let specialtyColor = SpecialtyFormatter.color(for: program.specialty)
                            let specialtyAbbrev = SpecialtyFormatter.abbreviation(for: program.specialty)
                            
                            HStack(spacing: 3) {
                                Image(systemName: "stethoscope")
                                    .font(.arial(size: 10))
                                Text(specialtyAbbrev)
                                    .font(.arial(size: 12, weight: .semibold))
                            }
                            .foregroundColor(specialtyColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(specialtyColor.opacity(0.15))
                            .cornerRadius(8)
                        }
                        
                        // Score
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.arial(size: 12))
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", program.finalScore))
                                .font(.arial(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        // Open in Maps button
                        Button(action: {
                            openInMaps()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                    .font(.arial(size: 12))
                                Text("Directions")
                                    .font(.arial(size: 12, weight: .medium))
                            }
                            .foregroundColor(AppColors.primaryBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassChipStyle(tint: AppColors.primaryBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
    }
    
    private func openInMaps() {
        // Use full address if available, otherwise use hospital + city + state
        let addressString: String
        if let address = program.address, !address.isEmpty {
            addressString = "\(address), \(program.city), \(program.state)"
        } else if !program.hospital.isEmpty {
            addressString = "\(program.hospital), \(program.city), \(program.state)"
        } else if !program.name.isEmpty {
            addressString = "\(program.name), \(program.city), \(program.state)"
        } else {
            addressString = "\(program.city), \(program.state)"
        }
        
        Task { @MainActor in
            do {
                let location = try await geocodeAddress(addressString)
                let mapItem = MKMapItem(location: location, address: nil)
                mapItem.name = program.hospital.isEmpty ? (program.name.isEmpty ? "Program Location" : program.name) : program.hospital
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } catch {
                programsMapLogger.error("Geocoding error: \(error.localizedDescription, privacy: .public)")
                // Fallback: use city/state coordinates from GeocodingHelper
                let fallbackCoordinate = GeocodingHelper.coordinate(for: program.city, state: program.state)
                let fallbackLocation = CLLocation(latitude: fallbackCoordinate.latitude, longitude: fallbackCoordinate.longitude)
                let mapItem = MKMapItem(location: fallbackLocation, address: nil)
                mapItem.name = program.hospital.isEmpty ? (program.name.isEmpty ? "Program Location" : program.name) : program.hospital
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }
        }
    }
    
    private func geocodeAddress(_ addressString: String) async throws -> CLLocation {
        // Use modern GeocodingHelper which uses MKLocalSearch (iOS 13+) or CLGeocoder fallback
        return try await GeocodingHelper.geocodeAddress(addressString)
    }
}


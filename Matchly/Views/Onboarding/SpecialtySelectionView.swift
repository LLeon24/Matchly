//
//  SpecialtySelectionView.swift
//  Matchly
//
//  Created by Leoh N. Leon II on 11/14/25.
//

import SwiftUI

struct SpecialtySelectionView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var searchText = ""
    @State private var showCustomInput = false
    @State private var customSpecialty = ""
    @State private var showWeightsSetup = false
    @State private var selectedSpecialties: Set<String> = []
    
    let specialties = [
        "Internal Medicine", "Family Medicine", "Emergency Medicine", "Pediatrics",
        "General Surgery", "OB/GYN", "Psychiatry", "Neurology", "Anesthesiology",
        "Radiology", "Pathology", "Orthopedics", "ENT", "Urology", "PM&R",
        "Dermatology", "Neurosurgery", "Child Neurology", "Nuclear Medicine",
        "Radiation Oncology", "Plastic Surgery", "Ophthalmology", "Interventional Radiology - Integrated",
        "Thoracic Surgery - Integrated", "Vascular Surgery - Integrated", "Transitional Year",
        "Aerospace Medicine", "Occupational and Environmental Medicine",
        "Public Health and General Preventive Medicine", "Osteopathic Neuromusculoskeletal Medicine"
    ]
    
    var filteredSpecialties: [String] {
        if searchText.isEmpty {
            return specialties
        }
        return specialties.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Your Specialty")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, 20)
                    
                    Text("Choose the specialty you're applying to")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search specialties...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Specialty list - multi-select
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSpecialties, id: \.self) { specialty in
                            SpecialtyRow(
                                specialty: specialty,
                                isSelected: selectedSpecialties.contains(specialty)
                            ) {
                                toggleSpecialty(specialty)
                            }
                        }
                        
                        // Add custom specialty option
                        Button(action: {
                            showCustomInput = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Other Specialty")
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Continue button
                if !selectedSpecialties.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        Button(action: {
                            saveSpecialties()
                            showWeightsSetup = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Continue with \(selectedSpecialties.count) Specialty\(selectedSpecialties.count == 1 ? "" : "ies")")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                Spacer()
                            }
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Custom Specialty", isPresented: $showCustomInput) {
                TextField("Enter specialty name", text: $customSpecialty)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    if !customSpecialty.isEmpty {
                        selectedSpecialties.insert(customSpecialty)
                        customSpecialty = ""
                    }
                }
            } message: {
                Text("Enter the name of your specialty")
            }
            .fullScreenCover(isPresented: $showWeightsSetup) {
                WeightsSetupView()
            }
            .onAppear {
                loadSelectedSpecialties()
            }
        }
    }
    
    private func toggleSpecialty(_ specialty: String) {
        if selectedSpecialties.contains(specialty) {
            selectedSpecialties.remove(specialty)
        } else {
            selectedSpecialties.insert(specialty)
        }
    }
    
    private func saveSpecialties() {
        dataManager.preferences.specialties = Array(selectedSpecialties).sorted()
        // Keep backward compatibility
        if let first = selectedSpecialties.first {
            dataManager.preferences.specialty = first
        }
        dataManager.savePreferences()
    }
    
    private func loadSelectedSpecialties() {
        if !dataManager.preferences.specialties.isEmpty {
            selectedSpecialties = Set(dataManager.preferences.specialties)
        } else if let single = dataManager.preferences.specialty {
            selectedSpecialties = [single]
        }
    }
}

struct SpecialtyRow: View {
    let specialty: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 22))
                
                Text(specialty)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    SpecialtySelectionView()
}

